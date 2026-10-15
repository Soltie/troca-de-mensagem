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
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CreatureService = require("./CreatureService")
local RoundService = require("./RoundService")

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
	state = function()
		return HttpService:JSONEncode(encode({
			round = RoundService.snapshot(),
			creature = CreatureService.state(),
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
			end
		end
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
