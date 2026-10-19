--!strict
--[[
	RoundService: dono da rodada (autoritativo).

	Fases: Loading -> Intro -> Playing -> Won | Lost -> (reiniciar tudo | continuar do checkpoint) -> Intro ...
	- Spawna o jogador em primeira pessoa (CharacterAutoLoads desligado: só nasce quando a rodada manda).
	- Trata os remotes Interact / RequestRestart via ServerNet (Guard + rate limit) e valida TODA
	  interação aqui: fase, existência, distância, linha de visão e se a ação é possível.
	  (SetFlashlight / SetStance / SetHoldBreath ficam no PlayerStateService.)
	- Objetivo: fusíveis -> quadro -> disjuntores na ordem -> energia (checkpoint) -> portão -> saída.
	- Publica o estado em ReplicatedStorage.GameState (atributos) para a UI.
]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require("@game/ReplicatedStorage/Shared/Config")
-- Um único dono da rodada; o runtime solo abaixo permanece disponível para regressão/polish.
if require("../Campaign/CampaignMode").enabled() then
	return require("../Campaign/CampaignRuntime") :: any
end
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local BreakerPuzzle = require("../Game/BreakerPuzzle")
local Checkpoint = require("../Game/Checkpoint")
local HideRules = require("../Game/HideRules")
local Objectives = require("../Game/Objectives")
local RoundRules = require("../Game/RoundRules")
local ServerNet = require("../Net/ServerNet")
local CollectibleService = require("./CollectibleService")
local CreatureService = require("./CreatureService")
local PlayerStateService = require("./PlayerStateService")
local WorldService = require("./WorldService")

type Response = Types.InteractResponse

local log = Logger.new("RoundService")

local objectives: Objectives.State = Objectives.new(Config.Game.FusesTotal)
local breakers: BreakerPuzzle.State = BreakerPuzzle.new({ 1, 2, 3 })
local checkpoint: Checkpoint.Snapshot? = nil
local phase: RoundRules.Phase = "Loading"
local roundId = 0
local roundSeed = 0
local playingSince = 0
local awakened = false
local started = false
local lastBreakerErrorAt = -math.huge

local function publish()
	GameState.set("FusesTotal", objectives.total)
	GameState.set("FusesCollected", Objectives.collectedCount(objectives))
	GameState.set("FusesHeld", objectives.held)
	GameState.set("FusesInserted", objectives.inserted)
	GameState.set("PowerOn", objectives.powerOn)
	GameState.set("GateOpen", objectives.gateOpen)
	GameState.set("HasKey", objectives.hasKey)
	GameState.set("BreakersOn", objectives.breakersOn)
	GameState.set("Objective", Objectives.objectiveKey(objectives))
	GameState.set("CreatureActive", CreatureService.isActive())
	GameState.set("CheckpointReady", Checkpoint.isUsable(checkpoint))
end

local function setPhase(nextPhase: RoundRules.Phase): boolean
	if not RoundRules.canTransition(phase, nextPhase) then
		log.warn("invalid phase transition %s -> %s", phase, nextPhase)
		return false
	end
	log.info("phase %s -> %s (round %d)", phase, nextPhase, roundId)
	phase = nextPhase
	GameState.set("Phase", nextPhase)
	return true
end

local function characterParts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, if hrp and hrp:IsA("BasePart") then hrp else nil, humanoid
end

local function setFrozen(player: Player, frozen: boolean)
	local _, hrp = characterParts(player)
	if hrp and not PlayerStateService.isHidden(player) then
		hrp.Anchored = frozen
	end
end

-- Fim de rodada (uma vez só: só sai de Playing).
local function endRound(player: Player, result: "Won" | "Lost")
	if phase ~= "Playing" then
		return
	end
	-- Horário de fim ANTES da fase: o cliente monta a tela final ao ver a fase mudar.
	GameState.set("RoundEndedAt", workspace:GetServerTimeNow())
	setPhase(result)
	CreatureService.freeze()
	setFrozen(player, true)
	publish()
end

local function spawnPlayer(player: Player, at: CFrame, battery: number?)
	local myRound = roundId
	player:LoadCharacterAsync()
	if myRound ~= roundId then
		return
	end
	local character, _, humanoid = characterParts(player)
	if not character then
		return
	end
	character:PivotTo(at)
	if humanoid then
		humanoid.WalkSpeed = Config.Player.WalkSpeed
		humanoid.UseJumpPower = false
		humanoid.JumpHeight = Config.Player.JumpHeight
		humanoid.Died:Connect(function()
			if phase == "Playing" and myRound == roundId then
				endRound(player, "Lost")
			end
		end)
	end
	PlayerStateService.resetForSpawn(player, battery)
	PlayerStateService.markTeleported(player)
	setFrozen(player, phase ~= "Playing")
end

local function awaken()
	if awakened then
		return
	end
	awakened = true
	CreatureService.activate(nil)
	publish()
end

local function noise(position: Vector3, radius: number)
	CreatureService.makeNoise(position - Vector3.yAxis * position.Y, radius)
end

-- Linha de visão cabeça -> objeto (aceita acertar o próprio objeto ou algo colado nele).
local function canReach(character: Model, item: WorldService.Interactable): boolean
	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart")
		then head.Position
		else (character:GetPivot().Position + Vector3.yAxis * 1.5)
	local targetPosition = item.focus.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(origin, targetPosition - origin, params)
	if hit == nil then
		return true
	end
	if hit.Instance == item.focus or hit.Instance:IsDescendantOf(item.model) then
		return true
	end
	return (hit.Position - targetPosition).Magnitude <= 1.5
end

-- Checkpoint: gravado uma vez por rodada, quando a energia volta.
local function saveCheckpoint(player: Player?)
	if checkpoint and Checkpoint.isUsable(checkpoint) then
		return
	end
	local doors, locked = WorldService.doorSnapshot()
	checkpoint = Checkpoint.capture({
		objectives = objectives,
		doors = doors,
		locked = locked,
		battery = if player then PlayerStateService.battery(player) else Config.Battery.StartCharge,
		breakerOrder = breakers.order,
		taken = WorldService.takenSnapshot(),
	})
	log.info("checkpoint saved (round %d)", roundId)
end

local function powerOn(myRound: number, player: Player?)
	if myRound ~= roundId or phase ~= "Playing" then
		return
	end
	if Objectives.powerOn(objectives) then
		WorldService.setPower(true)
		WorldService.setInteractEnabled("panel", false)
		for i = 1, Config.Puzzle.Breakers do
			WorldService.setInteractEnabled(`breaker_{i}`, false)
		end
		awaken()
		CreatureService.setHunt(true)
		saveCheckpoint(player)
		publish()
		log.info("power restored")
	end
end

local function breakerMask(): { boolean }
	local mask = {}
	for i = 1, Config.Puzzle.Breakers do
		mask[i] = BreakerPuzzle.isUp(breakers, i)
	end
	return mask
end

local function pressBreaker(player: Player, id: string, position: Vector3): Response
	local index = tonumber(string.match(id, "%d+"))
	if not index then
		return { accepted = false, message = "unknown" }
	end
	local can, reason = Objectives.canUseBreakers(objectives)
	if not can then
		WorldService.breakerFeedback("denied")
		return { accepted = false, message = reason or "not_available", kind = "BreakerDenied" }
	end
	if os.clock() - lastBreakerErrorAt < Config.Puzzle.ErrorCooldown then
		return { accepted = false, message = "not_available" }
	end
	local result = BreakerPuzzle.press(breakers, index)
	if result == "already" then
		return { accepted = false, message = "not_available" }
	elseif result == "wrong" then
		lastBreakerErrorAt = os.clock()
		WorldService.breakerFeedback("wrong")
		local myRound = roundId
		task.delay(0.5, function()
			if myRound == roundId and not objectives.breakersOn then
				WorldService.setBreakers(breakerMask())
			end
		end)
		noise(position, Config.Puzzle.ErrorNoiseRadius)
		log.info("breaker wrong order (pressed %d)", index)
		return { accepted = false, message = "breaker_wrong", kind = "BreakerWrong" }
	elseif result == "solved" then
		WorldService.setBreakers(breakerMask())
		WorldService.breakerFeedback("solved")
		Objectives.solveBreakers(objectives)
		noise(position, 30)
		publish()
		task.delay(Config.Game.PowerOnDelay, powerOn, roundId, player)
		return { accepted = true, message = "breakers_done", kind = "BreakerSolved" }
	end
	WorldService.setBreakers(breakerMask())
	WorldService.breakerFeedback("ok")
	noise(position, 10)
	return { accepted = true, message = "breaker_ok", kind = "Breaker" }
end

local function useDoor(player: Player, id: string, action: string, position: Vector3): Response
	if WorldService.isLocked(id) then
		if objectives.hasKey and action ~= "alt" and Objectives.useKey(objectives, id) then
			WorldService.unlockDoor(id, player)
			noise(position, 8)
			publish()
			return { accepted = true, message = "door_unlocking", kind = "Unlock" }
		end
		WorldService.rattleDoor(id)
		noise(position, Config.Doors.RattleNoise)
		return { accepted = false, message = "door_locked", kind = "DoorLocked" }
	end
	if action == "alt" then
		if not WorldService.altDoor(id) then
			return { accepted = false, message = "not_available" }
		end
		noise(position, Config.Doors.CrackNoise)
		return { accepted = true, message = "door_cracked", kind = "Door" }
	end
	local ok, state = WorldService.useDoor(id)
	if not ok then
		return { accepted = false, message = "not_available" }
	end
	noise(position, Config.Doors.OpenNoise)
	return { accepted = true, message = if state == "open" then "door_opened" else "door_closed", kind = "Door" }
end

local function hide(player: Player, id: string, position: Vector3, alive: boolean): Response
	local locker = WorldService.locker(id)
	if not locker then
		return { accepted = false, message = "unknown" }
	end
	if PlayerStateService.hiddenId(player) == id then
		locker.occupant = nil
		PlayerStateService.exitHide(player)
		WorldService.swingLocker(id)
		noise(position, 8)
		return { accepted = true, message = "hide_exit", kind = "HideExit" }
	end
	local ok, reason = HideRules.canEnter({
		playing = phase == "Playing",
		alive = alive,
		occupied = locker.occupant ~= nil and locker.occupant ~= player,
		alreadyHidden = PlayerStateService.isHidden(player),
		sinceExit = PlayerStateService.sinceExit(player),
	})
	if not ok then
		return { accepted = false, message = reason or "not_available" }
	end
	local saw = HideRules.sawEntry(CreatureService.secondsSinceSeen(), CreatureService.isChasing())
	if not PlayerStateService.enterHide(player, id, locker.inside, locker.eye, locker.exit, locker.front, saw) then
		return { accepted = false, message = "not_available" }
	end
	locker.occupant = player
	WorldService.swingLocker(id)
	noise(position, 8)
	return { accepted = true, message = "hide_enter", kind = "Hide" }
end

local function interact(player: Player, id: string, action: string?): Response
	-- Fita VHS colecionável: validada e entregue à equipe pelo CollectibleService.
	if id == CollectibleService.TAPE_ID then
		return CollectibleService.collect(player)
	end
	local character, hrp, humanoid = characterParts(player)
	local item = WorldService.interactable(id)
	local distance = if hrp and item then (hrp.Position - item.focus.Position).Magnitude else math.huge
	local alive = humanoid ~= nil and humanoid.Health > 0
	local ok, reason = RoundRules.validateInteraction({
		phase = phase,
		exists = item ~= nil,
		enabled = item ~= nil and item.enabled,
		alive = alive,
		distance = distance,
		maxDistance = if item then item.maxDistance else 0,
		tolerance = Config.Game.InteractTolerance,
		lineOfSight = character ~= nil and item ~= nil and canReach(character, item),
	})
	if not ok or not item then
		return { accepted = false, message = reason or "unknown" }
	end
	-- Escondido, só dá para sair do armário.
	if PlayerStateService.isHidden(player) and item.kind ~= "Hide" then
		return { accepted = false, message = "not_available" }
	end
	local position = item.focus.Position
	local kind = item.kind

	if kind == "Fuse" then
		local collected, err = Objectives.collect(objectives, id)
		if not collected then
			return { accepted = false, message = err or "not_available" }
		end
		WorldService.setFuseCollected(id)
		CreatureService.setFuses(Objectives.collectedCount(objectives))
		if not awakened then
			task.delay(1.2, function()
				if phase == "Playing" then
					awaken()
				end
			end)
		end
		noise(position, 45)
		publish()
		return { accepted = true, message = "fuse_taken", kind = "Fuse" }
	elseif kind == "Panel" then
		local inserted, err = Objectives.insert(objectives)
		if inserted == 0 then
			return { accepted = false, message = err or "no_fuses" }
		end
		WorldService.setPanelFuses(objectives.inserted)
		noise(position, 30)
		publish()
		return {
			accepted = true,
			message = if Objectives.isPanelComplete(objectives) then "panel_ready" else "fuses_inserted",
			kind = "Panel",
		}
	elseif kind == "Breaker" then
		return pressBreaker(player, id, position)
	elseif kind == "Door" then
		return useDoor(player, id, action or "use", position)
	elseif kind == "Gate" then
		local opened, err = Objectives.openGate(objectives)
		if not opened then
			return { accepted = false, message = err or "not_available" }
		end
		WorldService.openGate()
		noise(position, 200)
		publish()
		return { accepted = true, message = "gate_opening", kind = "Gate" }
	elseif kind == "Note" then
		return { accepted = true, message = "", note = id, kind = "Note" }
	elseif kind == "Key" then
		local takenKey, err = Objectives.takeKey(objectives)
		if not takenKey then
			return { accepted = false, message = err or "not_available" }
		end
		WorldService.setTaken(id)
		publish()
		return { accepted = true, message = "key_taken", kind = "Key" }
	elseif kind == "Battery" then
		WorldService.setTaken(id)
		PlayerStateService.addBattery(player)
		return { accepted = true, message = "battery_taken", kind = "Battery" }
	elseif kind == "Hide" then
		return hide(player, id, position, alive)
	end
	return { accepted = false, message = "unknown" }
end

local function tick()
	if phase ~= "Playing" then
		return
	end
	for _, player in Players:GetPlayers() do
		local _, hrp = characterParts(player)
		if hrp then
			local position = hrp.Position
			if not objectives.enteredBuilding and WorldService.isInsideBuilding(position) then
				objectives.enteredBuilding = true
				publish()
			end
			if Objectives.canWin(objectives) and WorldService.isInExitZone(position) then
				endRound(player, "Won")
				return
			end
			if position.Y < -60 then
				hrp.CFrame = WorldService.spawnCFrame()
				PlayerStateService.markTeleported(player)
			end
		end
	end
	if not awakened and os.clock() - playingSince >= Config.Game.AwakenAfter then
		awaken()
	end
end

local function beginPlaying(myRound: number, delay: number)
	task.delay(delay, function()
		if myRound ~= roundId or phase ~= "Intro" then
			return
		end
		setPhase("Playing")
		playingSince = os.clock()
		GameState.set("RoundStartedAt", workspace:GetServerTimeNow())
		for _, player in Players:GetPlayers() do
			setFrozen(player, false)
		end
	end)
end

-- Fase atual -> Intro (reinício a partir das telas finais ou forçado pela depuração).
local function enterIntro()
	if phase ~= "Loading" and phase ~= "Won" and phase ~= "Lost" then
		-- Reinício forçado (depuração): volta por Lost para manter as transições válidas.
		phase = "Lost"
	end
	setPhase("Intro")
end

-- Começa (ou recomeça) a rodada do zero: mundo, criatura, objetivo, jogadores. Apaga o checkpoint.
local function restart()
	roundId += 1
	local myRound = roundId
	objectives = Objectives.new(Config.Game.FusesTotal)
	checkpoint = nil
	awakened = false
	lastBreakerErrorAt = -math.huge
	roundSeed = Config.Game.FuseSeed or (os.time() + roundId)
	local rng = Random.new(roundSeed)
	WorldService.resetRound(rng)
	breakers = BreakerPuzzle.new(BreakerPuzzle.shuffle(Config.Puzzle.Breakers, function(a: number, b: number): number
		return rng:NextInteger(a, b)
	end))
	local order = BreakerPuzzle.describe(breakers.order)
	WorldService.setProcedure(order)
	GameState.set("BreakerOrder", order)
	CreatureService.reset()
	enterIntro()
	GameState.set("FromCheckpoint", false)
	GameState.set("RoundId", roundId)
	GameState.set("RoundStartedAt", 0)
	GameState.set("RoundEndedAt", 0)
	publish()
	for _, player in Players:GetPlayers() do
		task.spawn(spawnPlayer, player, WorldService.spawnCFrame(), nil)
	end
	beginPlaying(myRound, Config.Game.IntroDuration)
end

-- Continua do checkpoint: mesmo sorteio da rodada, progresso/portas/itens do snapshot, Vigia em trégua.
local function continueFromCheckpoint()
	local snapshot = checkpoint
	if not snapshot or not Checkpoint.isUsable(snapshot) then
		restart()
		return
	end
	local data = Checkpoint.restore(snapshot)
	roundId += 1
	local myRound = roundId
	objectives = data.objectives
	lastBreakerErrorAt = -math.huge
	-- Mesmo sorteio da rodada: fusíveis, chave e pilhas nos mesmos lugares.
	WorldService.resetRound(Random.new(roundSeed))
	for fuseId in objectives.collected do
		WorldService.setFuseCollected(fuseId)
	end
	WorldService.setPanelFuses(objectives.inserted)
	WorldService.applyTaken(data.taken)
	WorldService.applyDoors(data.doors, data.locked)
	breakers = BreakerPuzzle.new(data.breakerOrder)
	breakers.progress = #breakers.order
	breakers.solved = true
	WorldService.setProcedure(BreakerPuzzle.describe(breakers.order))
	WorldService.setBreakers(breakerMask())
	WorldService.setPower(true)
	WorldService.setInteractEnabled("panel", false)
	for i = 1, Config.Puzzle.Breakers do
		WorldService.setInteractEnabled(`breaker_{i}`, false)
	end
	CreatureService.reset()
	CreatureService.setFuses(Objectives.collectedCount(objectives))
	awakened = false
	enterIntro()
	GameState.set("FromCheckpoint", true)
	GameState.set("RoundId", roundId)
	GameState.set("RoundStartedAt", 0)
	GameState.set("RoundEndedAt", 0)
	publish()
	for _, player in Players:GetPlayers() do
		task.spawn(spawnPlayer, player, WorldService.checkpointCFrame(), data.battery)
	end
	-- O Vigia acorda longe de quem voltou e espera a trégua antes de caçar.
	task.delay(0.6, function()
		if myRound ~= roundId then
			return
		end
		awaken()
		CreatureService.setHunt(true)
		CreatureService.holdOff(Config.Checkpoint.GraceTime + Config.Checkpoint.IntroDuration)
		publish()
	end)
	log.info("continuing from checkpoint (round %d)", roundId)
	beginPlaying(myRound, Config.Checkpoint.IntroDuration)
end

local RoundService = {
	Name = "RoundService",
}

function RoundService.Init()
	Players.CharacterAutoLoads = false
	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	StarterPlayer.CameraMaxZoomDistance = 0.5
	StarterPlayer.CameraMinZoomDistance = 0.5
	GameState.serverCreate()
	CreatureService.onCapture(function(player: Player)
		endRound(player, "Lost")
	end)
	PlayerStateService.setNoiseHandler(noise)
	PlayerStateService.setExpelHandler(function(_player: Player, lockerId: string)
		local locker = WorldService.locker(lockerId)
		if locker then
			locker.occupant = nil
		end
		WorldService.swingLocker(lockerId, true)
	end)
end

function RoundService.Start()
	ServerNet.onInvoke("Interact", {
		args = {
			Guard.string({ maxLength = 32, pattern = "[%w_]+" }),
			Guard.optional(Guard.literal("use", "alt")),
		},
		rateLimit = { capacity = 6, refillPerSecond = 3 },
	}, interact)

	ServerNet.onInvoke("RequestRestart", {
		args = { Guard.optional(Guard.literal("full", "checkpoint")) },
		rateLimit = { capacity = 2, refillPerSecond = 0.5 },
	}, function(_player: Player, mode: string?): Response
		if not RoundRules.canRestart(phase) then
			return { accepted = false, message = "not_available" }
		end
		if mode == "checkpoint" and phase == "Lost" and Checkpoint.isUsable(checkpoint) then
			continueFromCheckpoint()
		else
			restart()
		end
		return { accepted = true, message = "" }
	end)

	local function onPlayer(player: Player)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMaxZoomDistance = 0.5
		player.CameraMinZoomDistance = 0.5
		if not started then
			started = true
			restart()
		else
			task.spawn(spawnPlayer, player, WorldService.spawnCFrame(), nil)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end

	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick :: () -> any)
			if not ok then
				log.error("tick failed: %s", tostring(err))
			end
		end
	end)
end

function RoundService.restart()
	restart()
end

function RoundService.continueFromCheckpoint()
	continueFromCheckpoint()
end

function RoundService.lose(player: Player)
	endRound(player, "Lost")
end

function RoundService.win(player: Player)
	endRound(player, "Won")
end

function RoundService.getPhase(): RoundRules.Phase
	return phase
end

-- Depuração: pula etapas (só usado pelo DebugService no Studio).
function RoundService.debugGrant(what: string, player: Player?)
	if what == "fuses" then
		for id in WorldService.get().fuseModels do
			if Objectives.collect(objectives, id) then
				WorldService.setFuseCollected(id)
			end
		end
		CreatureService.setFuses(Objectives.collectedCount(objectives))
	elseif what == "insert" then
		Objectives.insert(objectives)
		WorldService.setPanelFuses(objectives.inserted)
	elseif what == "breakers" then
		breakers.progress = #breakers.order
		breakers.solved = true
		WorldService.setBreakers(breakerMask())
		if Objectives.solveBreakers(objectives) then
			powerOn(roundId, player)
		end
	elseif what == "key" then
		Objectives.takeKey(objectives)
	end
	publish()
end

function RoundService.snapshot(): { [string]: any }
	return {
		phase = phase,
		roundId = roundId,
		collected = Objectives.collectedCount(objectives),
		held = objectives.held,
		inserted = objectives.inserted,
		breakersOn = objectives.breakersOn,
		breakerOrder = BreakerPuzzle.describe(breakers.order),
		breakerProgress = breakers.progress,
		powerOn = objectives.powerOn,
		gateOpen = objectives.gateOpen,
		hasKey = objectives.hasKey,
		unlocked = objectives.unlocked,
		entered = objectives.enteredBuilding,
		awakened = awakened,
		checkpoint = Checkpoint.isUsable(checkpoint),
	}
end

return RoundService
