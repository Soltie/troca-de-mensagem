--!strict
--[[
	Formato dos dados persistidos do jogador + migração de versões antigas.
	Puro: testável no Lune.

	Para mudar o formato:
	  1. altere Types.PlayerData e TEMPLATE;
	  2. suba Config.Data.SchemaVersion;
	  3. trate a conversão em migrate() (dados antigos nunca podem quebrar o load).

	Versões:
	  1  sessões e datas de entrada.
	  2  economia/cosméticos/progressão (carteira, XP, itens, equipados, fitas, diário,
	     estatísticas, recibos de compra) e trava de sessão. Contas v1 recebem tudo zerado.
	  3  passe de temporada (season: id, XP de temporada e níveis entregues por trilha).
	     Contas v2 começam a temporada do zero.
	  4  vantagens pagas (perks, consumables, loadout, boosts) e progresso da história (story).
	     Contas v3 começam sem melhorias, sem estoque e sem capítulos.
]]

local Config = require("@game/ReplicatedStorage/Shared/Config")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")
local Types = require("@game/ReplicatedStorage/Shared/Types")

local Preferences = require("@game/ReplicatedStorage/Shared/Game/HousePreferences")
local TEMPLATE: Types.PlayerData = TableUtil.deepFreeze({
	schemaVersion = Config.Data.SchemaVersion,
	sessions = 0,
	firstJoin = 0,
	lastJoin = 0,
	wallet = { fichas = 0, creditos = 0 },
	xp = 0,
	rewardedLevel = 1,
	owned = {},
	equipped = {
		flashlight = StoreCatalog.Defaults.flashlight,
		uniform = StoreCatalog.Defaults.uniform,
		filter = StoreCatalog.Defaults.filter,
		title = StoreCatalog.Defaults.title,
	},
	tapes = {},
	daily = { lastDay = 0, streak = 0, spinDay = 0, spinsUsed = 0 },
	stats = { runs = 0, escapes = 0, captures = 0, chests = 0, stages = 0 },
	purchases = {},
	oncePurchases = {},
	season = { id = "", xp = 0, free = {}, premium = {} },
	perks = {},
	consumables = {},
	loadout = {},
	boosts = { fichasUntil = 0, xpUntil = 0 },
	story = { cleared = {}, flawless = {} },
	house = { cleared = {}, flawless = {}, endings = {}, achievements = {}, preferences = { shaders = 1, quality = 0 } },
})

-- Mapa { [string]: number } saneado (lixo vira vazio; números inválidos somem).
local function numberMap(value: unknown, max: number): { [string]: number }
	local clean: { [string]: number } = {}
	if type(value) ~= "table" then
		return clean
	end
	for key, n in value :: { [any]: any } do
		if type(key) == "string" and type(n) == "number" and n == n and n >= 0 and n ~= math.huge then
			clean[key] = math.min(math.floor(n), max)
		end
	end
	return clean
end

local function finiteOr(value: any, fallback: number): number
	return if type(value) == "number" and value == value and math.abs(value) ~= math.huge then value else fallback
end

local PlayerDataSchema = {}

function PlayerDataSchema.template(): Types.PlayerData
	return TableUtil.deepCopy(TEMPLATE)
end

-- Converte qualquer valor salvo (inclusive nil ou lixo) em PlayerData válido.
function PlayerDataSchema.migrate(raw: unknown): Types.PlayerData
	if type(raw) ~= "table" then
		return PlayerDataSchema.template()
	end
	-- v1 -> v2 -> v3 -> v4: os campos novos vêm do template (reconcile preenche o que falta).
	local data = TableUtil.reconcile(raw, TEMPLATE)
	local h = data.house :: any
	if type(h) ~= "table" then
		h = {}
	end
	data.house = {
		preferences = Preferences.sanitize(h.preferences),
		cleared = numberMap(h.cleared, 2147483647),
		flawless = numberMap(h.flawless, 2147483647),
		endings = numberMap(h.endings, 2147483647),
		achievements = numberMap(h.achievements, 2147483647),
	}
	-- v6: preferências gráficas individuais; preserva volumes/conforto e todo o progresso v5.
	if data.house.preferences.shaders == nil then
		data.house.preferences.shaders = 1
	end
	if data.house.preferences.quality == nil then
		data.house.preferences.quality = 0
	end
	-- Valores corrompidos não podem travar a economia.
	for _, currency in StoreCatalog.CURRENCIES do
		local value = (data.wallet :: any)[currency]
		if type(value) ~= "number" or value ~= value or value < 0 then
			(data.wallet :: any)[currency] = 0
		end
	end
	if type(data.xp) ~= "number" or data.xp ~= data.xp or data.xp < 0 then
		data.xp = 0
	end
	-- Temporada corrompida: recomeça do zero (melhor do que travar a entrega das trilhas).
	local season = data.season :: any
	if
		type(season) ~= "table"
		or type(season.id) ~= "string"
		or type(season.xp) ~= "number"
		or season.xp ~= season.xp
		or season.xp == math.huge
		or season.xp < 0
		or type(season.free) ~= "table"
		or type(season.premium) ~= "table"
	then
		data.season = { id = "", xp = 0, free = {}, premium = {} }
	end
	-- v4: níveis e estoques nunca negativos/NaN; bônus e história com formato fixo.
	data.perks = numberMap(data.perks, 5)
	data.consumables = numberMap(data.consumables, 99)
	local loadout: { [string]: boolean } = {}
	if type(data.loadout) == "table" then
		for key, on in data.loadout :: { [any]: any } do
			if type(key) == "string" and on == true then
				loadout[key] = true
			end
		end
	end
	data.loadout = loadout
	local boosts = if type(data.boosts) == "table" then data.boosts :: any else {}
	data.boosts = { fichasUntil = finiteOr(boosts.fichasUntil, 0), xpUntil = finiteOr(boosts.xpUntil, 0) }
	local story = if type(data.story) == "table" then data.story :: any else {}
	data.story = { cleared = numberMap(story.cleared, 2 ^ 40), flawless = numberMap(story.flawless, 2 ^ 40) }
	data.schemaVersion = Config.Data.SchemaVersion
	return data
end

return PlayerDataSchema
