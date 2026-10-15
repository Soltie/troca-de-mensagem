--!strict
--[[
	RoundService: dono da rodada (autoritativo).

	Fases: Loading -> Intro -> Playing -> Won | Lost -> (reiniciar) -> Intro ...
	- Spawna o jogador em primeira pessoa (CharacterAutoLoads desligado: só nasce quando a rodada manda).
	- Trata os remotes Interact / SetFlashlight / RequestRestart via ServerNet (Guard + rate limit) e
	  valida TODA interação aqui: fase, existência, distância, linha de visão e se a ação é possível.
	- Publica o estado em ReplicatedStorage.GameState (atributos) para a UI.
]]

local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local Objectives = require("../Game/Objectives")
local RoundRules = require("../Game/RoundRules")
local ServerNet = require("../Net/ServerNet")
local CreatureService = require("./CreatureService")
local WorldService = require("./WorldService")

type Response = Types.InteractResponse

local log = Logger.new("RoundService")

local objectives: Objectives.State = Objectives.new(Config.Game.FusesTotal)
local phase: RoundRules.Phase = "Loading"
local roundId = 0
local playingSince = 0
local awakened = false
local started = false

local function publish()
	GameState.set("FusesTotal", objectives.total)
	GameState.set("FusesCollected", Objectives.collectedCount(objectives))
	GameState.set("FusesHeld", objectives.held)
	GameState.set("FusesInserted", objectives.inserted)
	GameState.set("PowerOn", objectives.powerOn)
	GameState.set("GateOpen", objectives.gateOpen)
	GameState.set("Objective", Objectives.objectiveKey(objectives))
	GameState.set("CreatureActive", CreatureService.isActive())
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
	if hrp then
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

local function spawnPlayer(player: Player)
	local myRound = roundId
	player:LoadCharacter()
	if myRound ~= roundId then
		return
	end
	local character, _, humanoid = characterParts(player)
	if not character then
		return
	end
	character:PivotTo(WorldService.spawnCFrame())
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
	player:SetAttribute(Tags.Attr.Flashlight, true)
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
local function canReach(character: Model, item: any): boolean
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

local function powerOn(myRound: number)
	if myRound ~= roundId or phase ~= "Playing" then
		return
	end
	if Objectives.powerOn(objectives) then
		WorldService.setPower(true)
		awaken()
		CreatureService.setHunt(true)
		publish()
		log.info("power restored")
	end
end

local function interact(player: Player, id: string): Response
	local character, hrp, humanoid = characterParts(player)
	local item = WorldService.interactable(id)
	local distance = if hrp and item then (hrp.Position - item.focus.Position).Magnitude else math.huge
	local ok, reason = RoundRules.validateInteraction({
		phase = phase,
		exists = item ~= nil,
		enabled = item ~= nil and item.enabled,
		alive = humanoid ~= nil and humanoid.Health > 0,
		distance = distance,
		maxDistance = if item then item.maxDistance else 0,
		tolerance = Config.Game.InteractTolerance,
		lineOfSight = character ~= nil and item ~= nil and canReach(character, item),
	})
	if not ok or not item then
		return { accepted = false, message = reason or "unknown" }
	end
	local position = item.focus.Position

	if item.kind == "Fuse" then
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
		return { accepted = true, message = "fuse_taken" }
	elseif item.kind == "Panel" then
		local inserted, err = Objectives.insert(objectives)
		if inserted == 0 then
			return { accepted = false, message = err or "no_fuses" }
		end
		WorldService.setPanelFuses(objectives.inserted)
		noise(position, 50)
		publish()
		if Objectives.isPanelComplete(objectives) then
			local myRound = roundId
			task.delay(Config.Game.PowerOnDelay, powerOn, myRound)
			return { accepted = true, message = "power_restored" }
		end
		return { accepted = true, message = "fuses_inserted" }
	elseif item.kind == "Door" then
		local toggled, nowOpen = WorldService.toggleDoor(id)
		if not toggled then
			return { accepted = false, message = "not_available" }
		end
		noise(position, 18)
		return { accepted = true, message = if nowOpen then "door_opened" else "door_closed" }
	elseif item.kind == "Gate" then
		local opened, err = Objectives.openGate(objectives)
		if not opened then
			return { accepted = false, message = err or "not_available" }
		end
		WorldService.openGate()
		noise(position, 200)
		publish()
		return { accepted = true, message = "gate_opening" }
	elseif item.kind == "Note" then
		return { accepted = true, message = "", note = id }
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
			end
		end
	end
	if not awakened and os.clock() - playingSince >= Config.Game.AwakenAfter then
		awaken()
	end
end

-- Começa (ou recomeça) a rodada do zero: mundo, criatura, objetivo, jogadores.
local function restart()
	roundId += 1
	local myRound = roundId
	objectives = Objectives.new(Config.Game.FusesTotal)
	awakened = false
	local seed = Config.Game.FuseSeed or (os.time() + roundId)
	WorldService.resetRound(Random.new(seed))
	CreatureService.reset()
	if phase ~= "Loading" and phase ~= "Won" and phase ~= "Lost" then
		-- Reinício forçado (depuração): volta por Lost para manter as transições válidas.
		phase = "Lost"
	end
	setPhase("Intro")
	GameState.set("RoundId", roundId)
	GameState.set("RoundStartedAt", 0)
	GameState.set("RoundEndedAt", 0)
	publish()
	for _, player in Players:GetPlayers() do
		task.spawn(spawnPlayer, player)
	end
	task.delay(Config.Game.IntroDuration, function()
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
end

function RoundService.Start()
	ServerNet.onInvoke("Interact", {
		args = { Guard.string({ maxLength = 32, pattern = "[%w_]+" }) },
		rateLimit = { capacity = 6, refillPerSecond = 3 },
	}, interact)

	ServerNet.onEvent("SetFlashlight", {
		args = { Guard.boolean() },
		rateLimit = { capacity = 10, refillPerSecond = 5 },
	}, function(player: Player, on: boolean)
		player:SetAttribute(Tags.Attr.Flashlight, on)
	end)

	ServerNet.onInvoke("RequestRestart", {
		args = {},
		rateLimit = { capacity = 2, refillPerSecond = 0.5 },
	}, function(_player: Player): Response
		if not RoundRules.canRestart(phase) then
			return { accepted = false, message = "not_available" }
		end
		restart()
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
			task.spawn(spawnPlayer, player)
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

function RoundService.lose(player: Player)
	endRound(player, "Lost")
end

function RoundService.win(player: Player)
	endRound(player, "Won")
end

function RoundService.getPhase(): RoundRules.Phase
	return phase
end

function RoundService.snapshot(): { [string]: any }
	return {
		phase = phase,
		roundId = roundId,
		collected = Objectives.collectedCount(objectives),
		held = objectives.held,
		inserted = objectives.inserted,
		powerOn = objectives.powerOn,
		gateOpen = objectives.gateOpen,
		entered = objectives.enteredBuilding,
		awakened = awakened,
	}
end

return RoundService
