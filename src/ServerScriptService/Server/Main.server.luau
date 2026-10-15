--!strict
--[[
	Ponto de entrada ÚNICO do servidor. Não crie outros Scripts de servidor:
	adicione um Service em ./Services e registre-o na lista abaixo.
]]

local Loader = require("@game/ReplicatedStorage/Shared/Loader")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")

local log = Logger.new("Server")

-- Todos os remotes existem antes de qualquer Service rodar.
Remotes.setupServer()

-- A ordem importa: Init e Start são chamados exatamente nesta ordem.
-- { any }: cada Service tem campos próprios; o Loader valida Name/Init/Start em runtime.
local services: { any } = {
	require("./Services/PlayerDataService"),
	require("./Services/WorldService"),
	require("./Services/CreatureService"),
	require("./Services/RoundService"),
	require("./Services/DebugService"), -- só age no Studio
}

local count = Loader.boot(services, { label = "Server" })
log.info("boot OK (%d services)", count)
