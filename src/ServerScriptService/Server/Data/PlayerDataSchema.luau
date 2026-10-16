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
]]

local Config = require("@game/ReplicatedStorage/Shared/Config")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")
local Types = require("@game/ReplicatedStorage/Shared/Types")

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
})

local PlayerDataSchema = {}

function PlayerDataSchema.template(): Types.PlayerData
	return TableUtil.deepCopy(TEMPLATE)
end

-- Converte qualquer valor salvo (inclusive nil ou lixo) em PlayerData válido.
function PlayerDataSchema.migrate(raw: unknown): Types.PlayerData
	if type(raw) ~= "table" then
		return PlayerDataSchema.template()
	end
	-- v1 -> v2: os campos novos vêm do template (reconcile preenche o que falta).
	local data = TableUtil.reconcile(raw, TEMPLATE)
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
	data.schemaVersion = Config.Data.SchemaVersion
	return data
end

return PlayerDataSchema
