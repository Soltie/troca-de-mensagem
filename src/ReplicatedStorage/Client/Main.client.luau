--!strict
--[[
	Ponto de entrada ÚNICO do cliente: Script com RunContext = Client em ReplicatedStorage
	(recomendação oficial; ver docs/DECISIONS.md). Não use .client.luau em Starter*:
	lá o original E a cópia rodam. Adicione Controllers em ./Controllers e registre abaixo.
]]

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Loader = require("@game/ReplicatedStorage/Shared/Loader")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")

local log = Logger.new("Client")

-- A ordem importa: Init e Start são chamados exatamente nesta ordem.
-- { any }: cada Controller tem campos próprios; o Loader valida Name/Init/Start em runtime.
local controllers: { any } = {
	require("./Controllers/HudController"),
	require("./Controllers/PingController"),
}

local count = Loader.boot(controllers, { label = "Client" })
log.info("boot OK (%d controllers)", count)
