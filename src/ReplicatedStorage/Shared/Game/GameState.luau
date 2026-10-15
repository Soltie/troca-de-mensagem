--!strict
--[[
	Estado da rodada, replicado do servidor para o cliente por ATRIBUTOS em
	ReplicatedStorage.GameState (Configuration criada pelo servidor em runtime).

	- Servidor: GameState.serverCreate() uma vez; depois GameState.set(nome, valor).
	- Cliente: GameState.wait() e GameState.observe(callback) recebe um Snapshot a cada mudança.

	O servidor é a única fonte da verdade: o cliente só lê.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

export type Phase = "Loading" | "Intro" | "Playing" | "Won" | "Lost"
export type ObjectiveKey = "enter" | "fuses" | "insert" | "escape" | "run"

export type Snapshot = {
	phase: Phase,
	roundId: number,
	objective: ObjectiveKey,
	fusesTotal: number,
	fusesCollected: number,
	fusesHeld: number,
	fusesInserted: number,
	powerOn: boolean,
	gateOpen: boolean,
	creatureActive: boolean,
	roundStartedAt: number,
	roundEndedAt: number,
}

local INSTANCE_NAME = "GameState"

local DEFAULTS: { [string]: any } = {
	Phase = "Loading",
	RoundId = 0,
	Objective = "enter",
	FusesTotal = 3,
	FusesCollected = 0,
	FusesHeld = 0,
	FusesInserted = 0,
	PowerOn = false,
	GateOpen = false,
	CreatureActive = false,
	RoundStartedAt = 0,
	RoundEndedAt = 0,
}

local GameState = {}

GameState.INSTANCE_NAME = INSTANCE_NAME

function GameState.serverCreate(): Configuration
	assert(RunService:IsServer(), "[GameState] serverCreate must run on the server")
	local existing = ReplicatedStorage:FindFirstChild(INSTANCE_NAME)
	if existing then
		return existing :: Configuration
	end
	local config = Instance.new("Configuration")
	config.Name = INSTANCE_NAME
	for name, value in DEFAULTS do
		config:SetAttribute(name, value)
	end
	config.Parent = ReplicatedStorage
	return config
end

local function instance(): Configuration
	local config = ReplicatedStorage:FindFirstChild(INSTANCE_NAME)
	assert(config, "[GameState] not created yet")
	return config :: Configuration
end

function GameState.set(name: string, value: any)
	assert(DEFAULTS[name] ~= nil, `[GameState] unknown attribute "{name}"`)
	instance():SetAttribute(name, value)
end

function GameState.get(name: string): any
	return instance():GetAttribute(name)
end

-- Cliente: espera a instância aparecer (o servidor cria no boot).
function GameState.wait(timeout: number?): Configuration
	local config = ReplicatedStorage:WaitForChild(INSTANCE_NAME, timeout or 30)
	assert(config, "[GameState] timed out waiting for ReplicatedStorage.GameState")
	return config :: Configuration
end

function GameState.snapshotOf(config: Instance): Snapshot
	local function attr(name: string): any
		local value = config:GetAttribute(name)
		if value == nil then
			return DEFAULTS[name]
		end
		return value
	end
	return {
		phase = attr("Phase"),
		roundId = attr("RoundId"),
		objective = attr("Objective"),
		fusesTotal = attr("FusesTotal"),
		fusesCollected = attr("FusesCollected"),
		fusesHeld = attr("FusesHeld"),
		fusesInserted = attr("FusesInserted"),
		powerOn = attr("PowerOn"),
		gateOpen = attr("GateOpen"),
		creatureActive = attr("CreatureActive"),
		roundStartedAt = attr("RoundStartedAt"),
		roundEndedAt = attr("RoundEndedAt"),
	}
end

function GameState.snapshot(): Snapshot
	return GameState.snapshotOf(instance())
end

-- Chama `callback(snapshot, mudouAtributo)` agora e a cada mudança. Retorna função para desconectar.
function GameState.observe(callback: (snapshot: Snapshot, changed: string?) -> ()): () -> ()
	local config = GameState.wait()
	callback(GameState.snapshotOf(config), nil)
	local connection = config.AttributeChanged:Connect(function(name: string)
		callback(GameState.snapshotOf(config), name)
	end)
	return function()
		connection:Disconnect()
	end
end

return GameState
