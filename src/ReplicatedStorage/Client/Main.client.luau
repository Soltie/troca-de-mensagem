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
	-- Primeiro: a tela de carregamento cobre a entrada desde o primeiro quadro.
	require("./Controllers/LoadingController"),
	require("./Controllers/SettingsController"),
	require("./Controllers/TransitionController"),
	require("./Controllers/AudioController"),
	require("./Controllers/CharacterController"),
	require("./Controllers/CameraController"),
	require("./Controllers/CharacterAnimatorController"),
	require("./Controllers/BodyAudioController"),
	require("./Controllers/FlashlightController"),
	require("./Controllers/FearController"),
	require("./Controllers/LightingController"),
	require("./Controllers/RetroFxController"),
	require("./Controllers/WorldFxController"),
	require("./Controllers/RainController"),
	require("./Controllers/FireController"),
	require("./Controllers/WetnessController"),
	require("./Controllers/WindowScareController"),
	require("./Controllers/ArtController"),
	require("./Controllers/TensionController"),
	require("./Controllers/ScreenFxController"),
	require("./Controllers/ThreatFeedbackController"),
	require("./Controllers/CreatureVisualController"),
	require("./Controllers/ThreatWarningController"),
	require("./Controllers/ScareController"),
	require("./Controllers/GuidingLightController"),
	require("./Controllers/SanityController"),
	require("./Controllers/CursedLockerController"),
	require("./Controllers/GustController"),
	require("./Controllers/BreathTestController"),
	require("./Controllers/EscapeRunController"),
	require("./Controllers/JumpscareController"),
	require("./Controllers/GameUiController"),
	require("./Controllers/InteractionController"),
	require("./Controllers/HudController"),
	require("./Controllers/HapticsController"),
	require("./Controllers/CosmeticController"),
	require("./Controllers/StoreController"),
	require("./Controllers/CampaignController"),
	require("./Controllers/CoinController"),
	require("./Controllers/TouchControlsController"),
	require("./Controllers/SpectatorController"),
	require("./Controllers/CinematicController"),
	require("./Controllers/MainMenuController"),
	require("./Controllers/ContinueController"),
	require("./Controllers/StoryController"),
	require("./Controllers/TelevisionController"),
	require("./Controllers/TrailerController"), -- só age no Studio (gravação do trailer)
	require("./Controllers/UiFeedbackController"),
}

local count = Loader.boot(controllers, { label = "Client" })
log.info("boot OK (%d controllers)", count)
