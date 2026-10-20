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
	require("./Services/TelemetryService"),
	require("./Services/StoreService"),
	require("./Services/WorldService"),
	require("./Services/PlayerStateService"),
	require("./Services/PresenceService"),
	require("./Services/LobbyService"),
	require("./Services/CreatureService"),
	require("./Services/CaptureSequenceService"),
	require("./Services/PropService"),
	require("./Services/CosmeticService"),
	require("./Services/CollectibleService"),
	require("./Services/RoundService"),
	require("./Services/RewardService"),
	require("./Services/PerkService"),
	require("./Services/CoinService"),
	require("./Services/FootprintService"),
	require("./Services/LightningService"),
	require("./Services/FireService"),
	require("./Services/GustService"),
	require("./Services/LockerSearchService"),
	require("./Services/EscapeRunService"),
	require("./Services/TensionDirector"),
	require("./Services/ForestHazardService"),
	require("./Services/TunnelService"),
	require("./Services/ChapterMomentService"),
	require("./Services/DoorSwapService"),
	require("./Services/TungVisitService"),
	require("./Services/DifficultyService"),
	require("./Services/DebugService"), -- só age no Studio
}

-- O runtime coop reutiliza o estado corporal por jogador quando o polish está presente.
local roundRuntime: any = require("./Services/RoundService")
if type(roundRuntime.setPlayerAdapter) == "function" then
	for _, service in services do
		if service.Name == "PlayerStateService" then
			roundRuntime.setPlayerAdapter(service)
		end
	end
end

local count = Loader.boot(services, { label = "Server" })
log.info("boot OK (%d services)", count)
