--!strict
--[[
	DebugService: ponte de depuração SÓ NO STUDIO (não existe em servidor ao vivo).

	Por quê: o `execute_luau` do MCP roda em outra VM; um `require` lá cria uma cópia nova dos
	módulos e não enxerga o estado real do jogo. Uma BindableFunction atravessa essa fronteira.

	Uso (MCP, execute_luau, datamodel_type = "Server"):
		local bridge = game:GetService("ServerStorage").DebugBridge
		return bridge:Invoke("state")
		bridge:Invoke("placeCreature", Vector3.new(0, 0, -22))
		bridge:Invoke("freezeCreature", true)

	Comandos: state | awaken | freezeCreature(bool) | placeCreature(Vector3) | teleport(Vector3) | restart
	          checkpoint | grant("fuses"|"insert"|"breakers"|"key") | setBattery(0..1) | fall(id) | holdOff(s)
	          storeGrant(fichas, creditos) | endRound("Won"|"Lost") | tape | seasonXp(xp) | analytics
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CollectibleService = require("./CollectibleService")
local CreatureService = require("./CreatureService")
local PlayerStateService = require("./PlayerStateService")
local PropService = require("./PropService")
local RoundService = require("./RoundService")
local StoreService = require("./StoreService")
local TelemetryService = require("./TelemetryService")
local WorldService = require("./WorldService")

local log = Logger.new("DebugService")

local function encode(value: any): any
	if typeof(value) == "Vector3" then
		return string.format("%.1f,%.1f,%.1f", value.X, value.Y, value.Z)
	elseif type(value) == "table" then
		local out = {}
		for key, item in value do
			out[key] = encode(item)
		end
		return out
	end
	return value
end

local commands: { [string]: (...any) -> any } = {
	forestChapter = function(chapter: number)
		return (RoundService :: any).debugForest(chapter)
	end,
	lightingPower = function(on: boolean)
		WorldService.setPower(on)
		return "ok"
	end,
	state = function()
		local players = {}
		for _, player in Players:GetPlayers() do
			players[player.Name] = PlayerStateService.snapshot(player)
		end
		return HttpService:JSONEncode(encode({
			round = RoundService.snapshot(),
			creature = CreatureService.state(),
			players = players,
		}))
	end,
	awaken = function()
		CreatureService.activate(nil)
		return "ok"
	end,
	freezeCreature = function(value: boolean)
		CreatureService.setFrozen(value)
		return "ok"
	end,
	placeCreature = function(position: Vector3)
		CreatureService.debugPlace(position)
		return "ok"
	end,
	teleport = function(position: Vector3)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if character then
				character:PivotTo(CFrame.new(position))
				PlayerStateService.markTeleported(player)
			end
		end
		return "ok"
	end,
	checkpoint = function()
		-- RoundService pode ser o runtime da campanha (Codex); estes comandos são do modo solo.
		(RoundService :: any).continueFromCheckpoint()
		return "ok"
	end,
	grant = function(what: string)
		(RoundService :: any).debugGrant(what, Players:GetPlayers()[1])
		return "ok"
	end,
	setBattery = function(value: number)
		for _, player in Players:GetPlayers() do
			PlayerStateService.addBattery(player, value - PlayerStateService.battery(player))
		end
		return "ok"
	end,
	fall = function(id: string)
		return PropService.debugFall(id)
	end,
	storeGrant = function(fichas: number, creditos: number)
		for _, player in Players:GetPlayers() do
			StoreService.debugGrant(player, fichas or 0, creditos or 0)
		end
		return "ok"
	end,
	endRound = function(result: string)
		local player = Players:GetPlayers()[1]
		if player then
			if result == "Won" then
				(RoundService :: any).win(player)
			else
				(RoundService :: any).lose(player)
			end
		end
		return "ok"
	end,
	seasonXp = function(amount: number)
		for _, player in Players:GetPlayers() do
			StoreService.debugSeasonXp(player, amount or 0)
		end
		return "ok"
	end,
	-- Últimos eventos de analytics (no Studio nada vai para a Roblox; fica só aqui).
	analytics = function()
		return HttpService:JSONEncode(TelemetryService.history())
	end,
	tape = function()
		return HttpService:JSONEncode(encode(CollectibleService.debugState()))
	end,
	holdOff = function(seconds: number)
		CreatureService.holdOff(seconds)
		return "ok"
	end,
	restart = function()
		RoundService.restart()
		return "ok"
	end,
}

local DebugService = {
	Name = "DebugService",
}

function DebugService.Init()
	if not RunService:IsStudio() then
		return
	end
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "DebugBridge"
	bridge.OnInvoke = function(command: string, ...: any): any
		local handler = commands[command]
		if not handler then
			return `unknown command "{command}"`
		end
		log.debug("debug command %s", command)
		return handler(...)
	end
	bridge.Parent = ServerStorage
end

return DebugService
