--!strict
--[[
	PlayerStateService: estado do CORPO do jogador no servidor (autoritativo).

	- Postura (remote SetStance): agachar baixa o corpo (HipHeight) e a velocidade; levantar só
	  com espaço acima da cabeça (mesma checagem do cliente, feita de novo aqui).
	- Lanterna com bateria (remote SetFlashlight): o cliente pede, o servidor decide pela carga
	  (BatteryModel). Publica a carga no atributo "Battery" (só quando muda o bastante).
	- Esconderijo: entrar/sair do armário (pedido via Interact, tratado pelo RoundService) e
	  segurar a respiração (remote SetHoldBreath), com arquejo forçado que faz barulho.
	- Validação de velocidade: mede o deslocamento real e devolve o jogador à última posição
	  válida se passar do limite da postura por tempo demais (PlayerRules).

	Atributos no Player (replicam para o cliente; o CreatureService lê os do esconderijo):
	  Stance, Battery, Flashlight, Hidden (id ou ""), HiddenAt (Vector3), HiddenSeen (bool),
	  HideEye (CFrame), HoldBreath (bool), Gasps (contador)
]]

local Players = game:GetService("Players")

local BatteryModel = require("@game/ReplicatedStorage/Shared/Game/BatteryModel")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Oxygen = require("../Game/Oxygen")
local CreatureService: any = nil
local PlayerRules = require("../Game/PlayerRules")
local ServerNet = require("../Net/ServerNet")

type Stance = PlayerRules.Stance

type PlayerState = {
	stance: Stance,
	battery: BatteryModel.State,
	wantsLight: boolean,
	publishedBattery: number,
	breath: PlayerRules.Breath,
	oxygen: Oxygen.State,
	breathNoiseAt: number,
	movementNoiseAt: number,
	hidden: string?,
	hideExit: CFrame?,
	lastExitAt: number,
	speedCheck: PlayerRules.SpeedCheck,
	lastPosition: Vector3?,
	lastValid: CFrame?,
	gasps: number,
	-- Escondido e espiando pela fresta desde (os.clock); nil = não está espiando.
	peekSince: number?,
}

local P = Config.Player
local TICK = 0.2
local log = Logger.new("PlayerStateService")

local states: { [Player]: PlayerState } = {}
local noiseHandler: ((position: Vector3, radius: number) -> ())? = nil
-- Expulsão do armário por falta de ar: quem liga (RoundService/campanha) libera o armário e abre a porta.
local expelHandler: ((player: Player, lockerId: string) -> ())? = nil
local leaveHide: (player: Player) -> () = function() end

local function newState(): PlayerState
	return {
		stance = "Stand",
		battery = BatteryModel.new(),
		wantsLight = true,
		publishedBattery = -1,
		breath = PlayerRules.newBreath(),
		oxygen = Oxygen.new(),
		breathNoiseAt = 0,
		movementNoiseAt = 0,
		hidden = nil,
		hideExit = nil,
		lastExitAt = -math.huge,
		speedCheck = PlayerRules.newSpeedCheck(),
		lastPosition = nil,
		lastValid = nil,
		gasps = 0,
		peekSince = nil,
	}
end

local function stateOf(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = newState()
		states[player] = state
	end
	return state
end

local function parts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return character, if root and root:IsA("BasePart") then root else nil, humanoid
end

local function isPlaying(): boolean
	return GameState.get("Phase") == "Playing"
end

local function standHipHeight(character: Model, humanoid: Humanoid): number
	local stored = character:GetAttribute("StandHipHeight")
	if type(stored) == "number" then
		return stored
	end
	character:SetAttribute("StandHipHeight", humanoid.HipHeight)
	return humanoid.HipHeight
end

local function publishLight(player: Player, state: PlayerState)
	player:SetAttribute(Tags.Attr.Flashlight, state.battery.on)
end

local function publishBattery(player: Player, state: PlayerState, force: boolean?)
	local charge = math.floor(state.battery.charge * 200 + 0.5) / 200
	if force or math.abs(charge - state.publishedBattery) >= 0.005 then
		state.publishedBattery = charge
		player:SetAttribute("Battery", charge)
	end
end

-- Há espaço para levantar? (topo da cabeça agachado ~ raiz + 2.3; precisa de CrouchDrop + folga)
local function canStand(character: Model, root: BasePart): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup
	local height = P.CrouchDrop + P.StandClearance
	local center = root.Position + Vector3.new(0, 2.3 + height / 2, 0)
	return #workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(1.6, height, 1.2), params) == 0
end

local function applyStance(player: Player, state: PlayerState, stance: Stance)
	local character, _, humanoid = parts(player)
	if not character or not humanoid then
		return
	end
	local stand = standHipHeight(character, humanoid)
	state.stance = stance
	humanoid.HipHeight = if stance == "Crouch" then math.max(0.25, stand - P.CrouchDrop) else stand
	humanoid.WalkSpeed = PlayerRules.walkSpeed(stance)
	humanoid.JumpHeight = if stance == "Crouch" then 0 else P.JumpHeight
	player:SetAttribute("Stance", stance)
end

local function setStance(player: Player, stance: Stance)
	local state = stateOf(player)
	local character, root, humanoid = parts(player)
	if not character or not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if state.hidden or not isPlaying() or state.stance == stance then
		-- Responde com o estado atual (o cliente corrige a previsão).
		player:SetAttribute("Stance", state.stance)
		return
	end
	if stance == "Stand" and not canStand(character, root) then
		player:SetAttribute("Stance", state.stance)
		return
	end
	applyStance(player, state, stance)
end

local function setFlashlight(player: Player, on: boolean)
	local state = stateOf(player)
	if Config.House.Enabled and player:GetAttribute("HasFlashlight") ~= true then
		on = false
	end
	state.wantsLight = on
	BatteryModel.setOn(state.battery, on)
	publishLight(player, state)
end

-- Espiar pela fresta (só escondido). O relógio da queda fica no servidor (tick).
local function setPeek(player: Player, peek: boolean)
	local state = stateOf(player)
	if peek and state.hidden and not state.peekSince then
		state.peekSince = os.clock()
	elseif not peek then
		state.peekSince = nil
	end
	player:SetAttribute("Peeking", state.peekSince ~= nil)
end
local function setHoldBreath(player: Player, hold: boolean)
	local state = stateOf(player)
	local _, _, humanoid = parts(player)
	if
		hold
		and (
			not isPlaying()
			or player:GetAttribute("CampaignStatus") ~= "Active"
			or not humanoid
			or humanoid.Health <= 0
		)
	then
		return
	end
	Oxygen.request(state.oxygen, hold, os.clock())
	player:SetAttribute("HoldBreath", state.oxygen.holding)
end

local function validateSpeed(player: Player, state: PlayerState, now: number)
	local character, root, humanoid = parts(player)
	if not character or not root or not humanoid or root.Anchored or state.hidden or not isPlaying() then
		state.lastPosition = nil
		return
	end
	local position = root.Position
	local last = state.lastPosition
	state.lastPosition = position
	if not last then
		state.lastValid = root.CFrame
		return
	end
	local delta = position - last
	local speed = Vector3.new(delta.X, 0, delta.Z).Magnitude / TICK
	local verdict = PlayerRules.checkSpeed(state.speedCheck, speed, PlayerRules.maxSpeed(state.stance), now)
	if verdict == "ok" then
		state.lastValid = root.CFrame
	elseif verdict == "correct" and state.lastValid then
		log.warn("speed check: %s moved %.1f studs/s (stance %s); correcting", player.Name, speed, state.stance)
		character:PivotTo(state.lastValid)
		state.lastPosition = nil
	end
end

local function tick()
	local now = os.clock()
	for player, state in states do
		if player.Parent == nil then
			continue
		end
		-- Melhoria "Bateria de Lítio" (nível publicado pelo StoreService): a carga dura mais.
		local level = tonumber(player:GetAttribute("PerkBateria")) or 0
		if BatteryModel.step(state.battery, TICK, 1 / Perks.factor("bateria", level)) then
			-- Pilha reserva (consumível Pilha Extra, armado pelo PerkService): entra sozinha.
			if player:GetAttribute("SpareBattery") == true then
				player:SetAttribute("SpareBattery", false)
				BatteryModel.addPickup(state.battery, Perks.EXTRA_BATTERY)
				if state.wantsLight then
					BatteryModel.setOn(
						state.battery,
						not Config.House.Enabled or player:GetAttribute("HasFlashlight") == true
					)
				end
				log.info("%s spare battery kicked in", player.Name)
			else
				log.info("%s flashlight died (battery empty)", player.Name)
			end
			publishLight(player, state)
			publishBattery(player, state, true)
		end
		publishBattery(player, state)

		local _, root, humanoid = parts(player)
		local active = isPlaying()
			and player:GetAttribute("CampaignStatus") == "Active"
			and humanoid
			and humanoid.Health > 0
		if not active then
			Oxygen.request(state.oxygen, false, now)
		end
		if active and Oxygen.step(state.oxygen, TICK, now) then
			player:SetAttribute("DeathCause", "oxygen")
			if humanoid then
				humanoid.Health = 0
			end
		end
		-- Espiando pela fresta tempo demais: escorrega, a porta abre e ele cai para fora fazendo barulho.
		local hiddenIn = state.hidden
		if active and hiddenIn and state.peekSince and now - state.peekSince >= Config.Hide.PeekMax then
			state.peekSince = nil
			if expelHandler then
				expelHandler(player, hiddenIn)
			end
			leaveHide(player)
			player:SetAttribute("HideFellAt", os.clock())
			if root and noiseHandler then
				noiseHandler(root.Position, Config.Hide.FallNoise)
			end
		end
		player:SetAttribute("Oxygen", math.floor(state.oxygen.value))
		player:SetAttribute("HoldBreath", state.oxygen.holding)
		local creature = CreatureService and CreatureService.state()
		local distance = if creature
				and creature.active
				and root
			then (root.Position - creature.position).Magnitude
			else math.huge
		local intensity = if distance < 18 then 1 elseif distance < 35 then 0.7 elseif distance < 65 then 0.3 else 0
		player:SetAttribute("BreathIntensity", if state.oxygen.holding then 0 else intensity)
		if active and root and not state.oxygen.holding and intensity >= 0.7 and now >= state.breathNoiseAt then
			state.breathNoiseAt = now + 1.2
			if noiseHandler then
				noiseHandler(root.Position, 18)
			end
		end
		if active and root and not state.hidden and now >= state.movementNoiseAt then
			local velocity = root.AssemblyLinearVelocity
			local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
			if speed > 1 then
				state.movementNoiseAt = now + 0.4
				local radius = if state.stance == "Crouch" then 3 elseif speed > P.WalkSpeed + 2 then 35 else 8
				local factor =
					math.max(0.5, Perks.factor("silencio", tonumber(player:GetAttribute("PerkSilencio")) or 0))
				if noiseHandler then
					noiseHandler(root.Position, radius * factor)
				end
			end
		end
		validateSpeed(player, state, now)
	end
end

local PlayerStateService = {
	Name = "PlayerStateService",
}

function PlayerStateService.Start()
	CreatureService = require("./CreatureService")
	ServerNet.onEvent("SetFlashlight", {
		args = { Guard.boolean() },
		rateLimit = { capacity = 10, refillPerSecond = 5 },
	}, setFlashlight)

	ServerNet.onEvent("SetStance", {
		args = { Guard.literal("Stand", "Crouch") },
		rateLimit = { capacity = 8, refillPerSecond = 4 },
	}, function(player: Player, stance: Stance)
		setStance(player, stance)
	end)

	ServerNet.onEvent("SetPeek", {
		args = { Guard.boolean() },
		rateLimit = { capacity = 8, refillPerSecond = 4 },
	}, setPeek)
	ServerNet.onEvent("SetHoldBreath", {
		args = { Guard.boolean() },
		rateLimit = { capacity = 8, refillPerSecond = 4 },
	}, setHoldBreath)

	Players.PlayerRemoving:Connect(function(player: Player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick :: () -> any)
			if not ok then
				log.error("tick failed: %s", tostring(err))
			end
		end
	end)
end

-- Ligação da expulsão do armário (ver tick): libera o armário e balança a porta.
function PlayerStateService.setExpelHandler(handler: (player: Player, lockerId: string) -> ())
	expelHandler = handler
end
-- Barulho do jogador (arquejo). O RoundService liga isto ao CreatureService.
function PlayerStateService.setNoiseHandler(handler: (position: Vector3, radius: number) -> ())
	noiseHandler = handler
end

-- Personagem novo (rodada ou checkpoint): de pé, visível, lanterna pedida, bateria dada.
function PlayerStateService.resetForSpawn(player: Player, battery: number?)
	local previous = states[player]
	local state = newState()
	if previous then
		state.gasps = previous.gasps
	end
	state.battery = BatteryModel.new(battery)
	states[player] = state
	local character, root, humanoid = parts(player)
	if character and humanoid then
		standHipHeight(character, humanoid)
	end
	applyStance(player, state, "Stand")
	BatteryModel.setOn(state.battery, not Config.House.Enabled or player:GetAttribute("HasFlashlight") == true)
	publishLight(player, state)
	publishBattery(player, state, true)
	player:SetAttribute("Hidden", "")
	player:SetAttribute("HiddenSeen", false)
	player:SetAttribute("HoldBreath", false)
	player:SetAttribute("Gasps", state.gasps)
	state.lastValid = if root then root.CFrame else nil
end

-- Teleporte legítimo (spawn, debug, sair do armário): não conta como velocidade.
function PlayerStateService.markTeleported(player: Player)
	local state = stateOf(player)
	state.lastPosition = nil
	state.speedCheck.overSince = nil
	local _, root = parts(player)
	state.lastValid = if root then root.CFrame else state.lastValid
end

function PlayerStateService.stance(player: Player): Stance
	return stateOf(player).stance
end

function PlayerStateService.isHidden(player: Player): boolean
	return stateOf(player).hidden ~= nil
end

function PlayerStateService.hiddenId(player: Player): string?
	return stateOf(player).hidden
end

function PlayerStateService.sinceExit(player: Player): number
	return os.clock() - stateOf(player).lastExitAt
end

--[[
	Entra no armário `id`: o corpo fica ancorado em `inside`, a câmera do cliente olha por `eye`
	(atributo HideEye) e sai em `exit`. `sawEntry` = o Vigia viu entrar.
]]
function PlayerStateService.enterHide(
	player: Player,
	id: string,
	inside: CFrame,
	eye: CFrame,
	exit: CFrame,
	front: Vector3,
	sawEntry: boolean
): boolean
	local state = stateOf(player)
	local character, root = parts(player)
	if not character or not root or state.hidden then
		return false
	end
	if state.stance ~= "Stand" then
		applyStance(player, state, "Stand")
	end
	state.hidden = id
	state.hideExit = exit
	Oxygen.request(state.oxygen, false, os.clock())
	root.Anchored = true
	character:PivotTo(inside)
	player:SetAttribute("HiddenAt", front)
	player:SetAttribute("HiddenSeen", sawEntry)
	player:SetAttribute("HideEye", eye)
	player:SetAttribute("HoldBreath", false)
	player:SetAttribute("Hidden", id)
	log.info("%s hid in %s (seen=%s)", player.Name, id, tostring(sawEntry))
	return true
end

function PlayerStateService.exitHide(player: Player): boolean
	local state = stateOf(player)
	local character, root = parts(player)
	if not state.hidden then
		return false
	end
	local exit = state.hideExit
	state.hidden = nil
	state.peekSince = nil
	player:SetAttribute("Peeking", false)
	state.hideExit = nil
	state.lastExitAt = os.clock()
	Oxygen.request(state.oxygen, false, os.clock())
	if character and root then
		if exit then
			character:PivotTo(exit)
		end
		root.Anchored = not isPlaying()
	end
	player:SetAttribute("Hidden", "")
	player:SetAttribute("HiddenSeen", false)
	player:SetAttribute("HoldBreath", false)
	PlayerStateService.markTeleported(player)
	return true
end
leaveHide = function(player: Player)
	PlayerStateService.exitHide(player)
end

function PlayerStateService.battery(player: Player): number
	return stateOf(player).battery.charge
end

function PlayerStateService.addBattery(player: Player, amount: number?)
	local state = stateOf(player)
	BatteryModel.addPickup(state.battery, amount)
	-- Se o jogador queria luz e ela tinha apagado, volta a acender.
	if state.wantsLight and not state.battery.on then
		BatteryModel.setOn(state.battery, not Config.House.Enabled or player:GetAttribute("HasFlashlight") == true)
		publishLight(player, state)
	end
	publishBattery(player, state, true)
end

function PlayerStateService.addOxygen(player: Player, amount: number): boolean
	local state = stateOf(player).oxygen
	if state.dead then
		return false
	end
	state.value = math.min(100, state.value + amount)
	return true
end
function PlayerStateService.grantFlashlight(player: Player)
	player:SetAttribute("HasFlashlight", true)
	setFlashlight(player, true)
end
function PlayerStateService.snapshot(player: Player): { [string]: any }
	local state = stateOf(player)
	return {
		stance = state.stance,
		battery = state.battery.charge,
		light = state.battery.on,
		hidden = state.hidden,
		holding = state.breath.holding,
	}
end

return PlayerStateService
