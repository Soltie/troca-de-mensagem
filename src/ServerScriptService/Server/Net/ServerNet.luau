--!strict
--[[
	Único jeito de tratar remotes no servidor. Cada handler ganha:
	  1. rate limit por jogador (token bucket),
	  2. validação de TODOS os argumentos (Guard) — argumentos a mais são rejeitados,
	  3. pcall no handler: erro interno não vaza para o cliente.

	RemoteFunction responde sempre com Types.Result:
		{ ok = true, data = ... }  ou  { ok = false, error = "rate_limited" | "invalid_arguments" | "internal_error" }

	O servidor é autoritativo: o handler decide tudo; o cliente só pede.
]]

local Players = game:GetService("Players")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local RateLimiter = require("@game/ReplicatedStorage/Shared/Net/RateLimiter")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Types = require("@game/ReplicatedStorage/Shared/Types")

export type HandlerOptions = {
	-- Um validador por argumento, na ordem. Lista vazia = o remote não aceita argumentos.
	args: { Guard.Validator },
	-- Padrão: Config.Net.DefaultRateLimit.
	rateLimit: { capacity: number, refillPerSecond: number }?,
}

local log = Logger.new("ServerNet")
local limiters: { RateLimiter.RateLimiter } = {}
local registered: { [string]: boolean } = {}

Players.PlayerRemoving:Connect(function(player: Player)
	for _, limiter in limiters do
		limiter.reset(player.UserId)
	end
end)

local function prepare(name: string, options: HandlerOptions)
	if registered[name] then
		error(`[ServerNet] handler for "{name}" already registered`, 3)
	end
	registered[name] = true
	local rate = options.rateLimit or Config.Net.DefaultRateLimit
	local limiter = RateLimiter.new({ capacity = rate.capacity, refillPerSecond = rate.refillPerSecond })
	table.insert(limiters, limiter)
	return limiter, Guard.args(options.args)
end

local ServerNet = {}

-- RemoteFunction (cliente -> servidor com resposta).
function ServerNet.onInvoke<T>(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> T)
	local remote = Remotes.serverFunction(name)
	local limiter, validate = prepare(name, options)

	remote.OnServerInvoke = function(player: Player, ...: any): Types.Result<T>
		if not limiter.allow(player.UserId) then
			log.debug("%s rate limited for %s", name, player.Name)
			return { ok = false, error = "rate_limited" }
		end
		local valid, reason = validate(table.pack(...))
		if not valid then
			log.warn("rejected %s from %s: %s", name, player.Name, reason or "?")
			return { ok = false, error = "invalid_arguments" }
		end
		local success, result = pcall(handler, player, ...)
		if not success then
			log.error("handler %s failed for %s: %s", name, player.Name, tostring(result))
			return { ok = false, error = "internal_error" }
		end
		return { ok = true, data = result }
	end
end

-- RemoteEvent (cliente -> servidor, sem resposta). Chamadas inválidas são descartadas.
function ServerNet.onEvent(name: string, options: HandlerOptions, handler: (player: Player, ...any) -> ())
	local remote = Remotes.serverEvent(name)
	local limiter, validate = prepare(name, options)

	remote.OnServerEvent:Connect(function(player: Player, ...: any)
		if not limiter.allow(player.UserId) then
			log.debug("%s rate limited for %s", name, player.Name)
			return
		end
		local valid, reason = validate(table.pack(...))
		if not valid then
			log.warn("rejected %s from %s: %s", name, player.Name, reason or "?")
			return
		end
		local success, err = pcall(handler :: (Player, ...any) -> any, player, ...)
		if not success then
			log.error("handler %s failed for %s: %s", name, player.Name, tostring(err))
		end
	end)
end

return ServerNet
