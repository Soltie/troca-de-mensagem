--!strict
--[[
	PlayerDataService: carrega, mantém em memória e salva os dados de cada jogador.

	- Retry com backoff em toda chamada de DataStore (Util/Retry).
	- Autosave periódico (Config.Data.AutosaveInterval).
	- Salva ao sair (PlayerRemoving) e no desligamento (BindToClose), esperando os saves pendentes.
	- Modo mock automático no Studio quando não há acesso às APIs (ou a place não é publicada).
	  Em servidor ao vivo NUNCA usa mock: falha de load = kick (evita sobrescrever dados reais).
	- No Studio em modo real, usa um DataStore separado (sufixo "_Studio").

	API:
		PlayerDataService.get(player)                 -> PlayerData? (tabela viva; não guarde referência)
		PlayerDataService.waitFor(player, timeout?)   -> PlayerData? (yield)
		PlayerDataService.update(player, mutator)     -> boolean
		PlayerDataService.save(player)                -> boolean (yield)
		PlayerDataService.getMode()                   -> ("real" | "mock", motivo)

	TODO(session-locking): dois servidores podem ter o mesmo jogador por alguns segundos
	(teleporte/reconexão) e o último save vence. Antes de lançar com dados valiosos, implemente
	lock de sessão (campo de lock no UpdateAsync com expiração) ou adote ProfileStore.
	Ver docs/ARCHITECTURE.md#playerdata.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Retry = require("@game/ReplicatedStorage/Shared/Util/Retry")
local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local MockDataStore = require("../Data/MockDataStore")
local PlayerDataSchema = require("../Data/PlayerDataSchema")

type Store = MockDataStore.Store

type Profile = {
	key: string,
	data: Types.PlayerData,
}

local log = Logger.new("PlayerDataService")

local mode: Types.DataMode = "mock"
local modeReason = "not initialized"
local store: Store? = nil
local profiles: { [Player]: Profile } = {}
local pendingSaves = 0
local shuttingDown = false

local function storeName(): string
	if RunService:IsStudio() then
		return Config.Data.StoreName .. "_Studio"
	end
	return Config.Data.StoreName
end

local function chooseMode(): (Types.DataMode, string)
	if not RunService:IsStudio() then
		return "real", "live server"
	end
	local studioMode = Config.Data.StudioMode
	if studioMode == "mock" then
		return "mock", "Config.Data.StudioMode = mock"
	end
	if game.GameId == 0 then
		if studioMode == "real" then
			error("[PlayerDataService] StudioMode is 'real' but the place is not published")
		end
		return "mock", "place not published (GameId = 0)"
	end
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(storeName()):GetAsync("__probe")
	end)
	if ok then
		return "real", "Studio has API access"
	end
	if studioMode == "real" then
		error(`[PlayerDataService] StudioMode is 'real' but DataStore is unavailable: {err}`)
	end
	return "mock", `no API access: {err}`
end

local function getStore(): Store
	assert(store, "[PlayerDataService] used before Init")
	return store
end

local function retryOptions(label: string): Retry.Options
	return {
		attempts = Config.Data.RetryAttempts,
		baseDelay = Config.Data.RetryBaseDelay,
		maxDelay = 10,
		onRetry = function(attempt: number, err: string, delay: number)
			log.warn("%s failed (attempt %d), retrying in %.1fs: %s", label, attempt, delay, err)
		end,
	}
end

local function saveProfile(player: Player, profile: Profile): boolean
	local snapshot = TableUtil.deepCopy(profile.data)
	local userId = player.UserId
	pendingSaves += 1
	local ok, _, err = Retry.run(function()
		return getStore():UpdateAsync(profile.key, function(_current: any)
			-- userIds associa a chave ao jogador (pedidos de remoção de dados / GDPR).
			return snapshot, { userId }
		end)
	end, retryOptions(`save {profile.key}`))
	pendingSaves -= 1
	if ok then
		log.debug("saved %s", player.Name)
	else
		log.error("save failed for %s: %s", player.Name, err or "?")
	end
	return ok
end

local function loadProfile(player: Player)
	local key = `Player_{player.UserId}`
	local ok, raw, err = Retry.run(function()
		return getStore():GetAsync(key)
	end, retryOptions(`load {key}`))

	if player.Parent == nil then
		return -- saiu durante o load; nada mudou, nada a salvar
	end
	if not ok then
		log.error("load failed for %s: %s", player.Name, err or "?")
		if Config.Data.KickOnLoadFailure then
			player:Kick("Could not load your data. Please rejoin in a moment.")
		end
		return
	end

	local data = PlayerDataSchema.migrate(raw)
	local now = os.time()
	if data.firstJoin == 0 then
		data.firstJoin = now
	end
	data.lastJoin = now
	data.sessions += 1
	profiles[player] = { key = key, data = data }
	log.info("loaded %s (mode=%s, sessions=%d)", player.Name, mode, data.sessions)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end
	profiles[player] = nil
	saveProfile(player, profile)
end

local function onShutdown()
	shuttingDown = true
	for player, profile in profiles do
		profiles[player] = nil
		task.spawn(saveProfile, player, profile)
	end
	local deadline = os.clock() + Config.Data.ShutdownTimeout
	while pendingSaves > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
	if pendingSaves > 0 then
		log.error("shutdown with %d saves still pending", pendingSaves)
	end
end

local function autosaveLoop()
	while not shuttingDown do
		task.wait(Config.Data.AutosaveInterval)
		for player, profile in profiles do
			task.spawn(saveProfile, player, profile)
		end
	end
end

local PlayerDataService = {
	Name = "PlayerDataService",
}

function PlayerDataService.Init()
	mode, modeReason = chooseMode()
	if mode == "real" then
		store = DataStoreService:GetDataStore(storeName()) :: any
	else
		store = MockDataStore.new()
	end
	log.info("mode=%s (%s)", mode, modeReason)
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	game:BindToClose(onShutdown)
	task.spawn(autosaveLoop)
end

function PlayerDataService.get(player: Player): Types.PlayerData?
	local profile = profiles[player]
	return if profile then profile.data else nil
end

function PlayerDataService.waitFor(player: Player, timeout: number?): Types.PlayerData?
	local deadline = os.clock() + (timeout or 10)
	while profiles[player] == nil and player.Parent ~= nil and os.clock() < deadline do
		task.wait(0.1)
	end
	return PlayerDataService.get(player)
end

-- Altera os dados do jogador. Retorna false se os dados ainda não foram carregados.
function PlayerDataService.update(player: Player, mutator: (data: Types.PlayerData) -> ()): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	mutator(profile.data)
	return true
end

function PlayerDataService.save(player: Player): boolean
	local profile = profiles[player]
	if profile == nil then
		return false
	end
	return saveProfile(player, profile)
end

function PlayerDataService.getMode(): (Types.DataMode, string)
	return mode, modeReason
end

return PlayerDataService
