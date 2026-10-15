--!strict
--[[
	Smoke test técnico (não é mecânica de jogo): o cliente chama "Ping" e o servidor
	responde com o eco da mensagem, a hora do servidor e o estado do PlayerData.
	Prova o caminho completo Remotes -> ServerNet (validação + rate limit) -> Service.
	Pode ser removido quando o jogo tiver remotes reais (remova também o PingController).
]]

local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local ServerNet = require("../Net/ServerNet")
local PlayerDataService = require("./PlayerDataService")

local log = Logger.new("PingService")

local PingService = {
	Name = "PingService",
}

function PingService.Start()
	ServerNet.onInvoke("Ping", {
		args = { Guard.string({ maxLength = 64 }) },
		rateLimit = { capacity = 5, refillPerSecond = 1 },
	}, function(player: Player, message: string): Types.PingResponse
		local data = PlayerDataService.waitFor(player, 5)
		local dataMode: Types.DataMode = PlayerDataService.getMode()
		log.info("ping from %s: %q", player.Name, message)
		return {
			message = message,
			serverTime = workspace:GetServerTimeNow(),
			dataMode = dataMode,
			sessions = if data then data.sessions else 0,
		}
	end)
end

return PingService
