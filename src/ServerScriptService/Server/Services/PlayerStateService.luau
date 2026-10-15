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
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local PlayerRules = require("../Game/PlayerRules")
local ServerNet = require("../Net/ServerNet")

type Stance = PlayerRules.Stance

type PlayerState = {
	stance: Stance,
	battery: BatteryModel.State,
	wantsLight: boolean,
	publishedBattery: number,
	breath: PlayerRules.Breath,
	hidden: string?,
	hideExit: CFrame?,
	lastExitAt: number,
	speedCheck: PlayerRules.SpeedCheck,
	lastPosition: Vector3?,
	lastValid: CFrame?,
	gasps: number,
}

local P = Config.Player
local TICK = 0.2
local log = Logger.new("PlayerStateService")

local states: { [Player]: PlayerState } = {}
local noiseHandler: ((position: Vector3, radius: number) -> ())? = nil

local function newState(): PlayerState
	return {
		stance = "Stand",
		battery = BatteryModel.new(),
		wantsLight = true,
		publishedBattery = -1,
		breath = PlayerRules.newBreath(),
		hidden = nil,
		hideExit = nil,
		lastExitAt = -math.huge,
		speedCheck = PlayerRules.newSpeedCheck(),
		lastPosition = nil,
		lastValid = nil,
		gasps = 0,
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
	state.wantsLight = on
	BatteryModel.setOn(state.battery, on)
	publishLight(player, state)
end

local function setHoldBreath(player: Player, hold: boolean)
	local state = stateOf(player)
	local now = os.clock()
	if not state.hidden then
		player:SetAttribute("HoldBreath", false)
		return
	end
	if hold then
		PlayerRules.holdBreath(state.breath, now)
	else
		PlayerRules.releaseBreath(state.breath, now)
	end
	player:SetAttribute("HoldBreath", state.breath.holding)
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
		if BatteryModel.step(state.battery, TICK) then
			publishLight(player, state)
			log.info("%s flashlight died (battery empty)", player.Name)
		end
		publishBattery(player, state)

		if PlayerRules.stepBreath(state.breath, now) == "gasp" then
			player:SetAttribute("HoldBreath", false)
			state.gasps += 1
			player:SetAttribute("Gasps", state.gasps)
			local _, root = parts(player)
			local handler = noiseHandler
			if handler and root then
				handler(root.Position, P.GaspNoiseRadius)
			end
		end
		validateSpeed(player, state, now)
	end
end

local PlayerStateService = {
	Name = "PlayerStateService",
}

function PlayerStateService.Start()
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
	BatteryModel.setOn(state.battery, true)
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
	state.breath = PlayerRules.newBreath()
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
	state.hideExit = nil
	state.lastExitAt = os.clock()
	PlayerRules.releaseBreath(state.breath, os.clock())
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

function PlayerStateService.battery(player: Player): number
	return stateOf(player).battery.charge
end

function PlayerStateService.addBattery(player: Player, amount: number?)
	local state = stateOf(player)
	BatteryModel.addPickup(state.battery, amount)
	-- Se o jogador queria luz e ela tinha apagado, volta a acender.
	if state.wantsLight and not state.battery.on then
		BatteryModel.setOn(state.battery, true)
		publishLight(player, state)
	end
	publishBattery(player, state, true)
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
