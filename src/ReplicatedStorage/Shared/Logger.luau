--!strict
--[[
	Logger com escopo e nível mínimo.

		local log = Logger.new("PlayerDataService")
		log.info("loaded %s", player.Name)   --> [PlayerDataService] loaded Fulano

	Formatação via string.format só acontece quando há argumentos extras.
	Puro: roda no Roblox e no Lune. Para testes, troque a saída com Logger.setSink.
]]

local Config = require("./Config")
local Types = require("./Types")

type LogLevel = Types.LogLevel

export type Sink = (level: LogLevel, line: string) -> ()

export type Logger = {
	scope: string,
	debug: (message: string, ...any) -> (),
	info: (message: string, ...any) -> (),
	warn: (message: string, ...any) -> (),
	error: (message: string, ...any) -> (),
}

local LEVEL_ORDER: { [LogLevel]: number } = {
	Debug = 1,
	Info = 2,
	Warn = 3,
	Error = 4,
}

local function defaultSink(level: LogLevel, line: string)
	if level == "Warn" or level == "Error" then
		warn(line)
	else
		print(line)
	end
end

local minLevel: LogLevel = Config.LogLevel
local sink: Sink = defaultSink

local Logger = {}

function Logger.setLevel(level: LogLevel)
	minLevel = level
end

function Logger.getLevel(): LogLevel
	return minLevel
end

-- Passe nil para voltar à saída padrão (print/warn).
function Logger.setSink(newSink: Sink?)
	sink = newSink or defaultSink
end

function Logger.format(scope: string, level: LogLevel, message: string, ...: any): string
	local text = if select("#", ...) > 0 then string.format(message, ...) else message
	local prefix = if level == "Error" then "ERROR: " else ""
	return `[{scope}] {prefix}{text}`
end

function Logger.new(scope: string): Logger
	local function emit(level: LogLevel, message: string, ...: any)
		if LEVEL_ORDER[level] < LEVEL_ORDER[minLevel] then
			return
		end
		sink(level, Logger.format(scope, level, message, ...))
	end

	return {
		scope = scope,
		debug = function(message: string, ...: any)
			emit("Debug", message, ...)
		end,
		info = function(message: string, ...: any)
			emit("Info", message, ...)
		end,
		warn = function(message: string, ...: any)
			emit("Warn", message, ...)
		end,
		error = function(message: string, ...: any)
			emit("Error", message, ...)
		end,
	}
end

return Logger
