--!strict
--[[
	Smoke test técnico: chama o remote "Ping" uma vez no boot, loga a resposta
	e mostra latência + modo de dados no HUD. Remova junto com o PingService.
]]

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local HudController = require("./HudController")

local log = Logger.new("PingController")

local PingController = {
	Name = "PingController",
}

local function ping()
	local remote = Remotes.clientFunction("Ping")
	local startedAt = os.clock()
	local ok, response = pcall(function()
		return remote:InvokeServer("hello")
	end)
	local elapsedMs = math.floor((os.clock() - startedAt) * 1000 + 0.5)

	if not ok then
		log.error("ping failed: %s", tostring(response))
		HudController.setLine("ping", "ping: ERROR")
		return
	end

	local result = response :: Types.Result<Types.PingResponse>
	if result.ok then
		local data = result.data
		log.info(
			"ping OK: %q in %d ms (dataMode=%s, sessions=%d)",
			data.message,
			elapsedMs,
			data.dataMode,
			data.sessions
		)
		HudController.setLine("ping", `ping: {elapsedMs} ms`)
		HudController.setLine("data", `data: {data.dataMode} (sessions: {data.sessions})`)
	else
		log.warn("ping rejected: %s", result.error)
		HudController.setLine("ping", `ping: rejected ({result.error})`)
	end
end

function PingController.Start()
	task.spawn(ping)
end

return PingController
