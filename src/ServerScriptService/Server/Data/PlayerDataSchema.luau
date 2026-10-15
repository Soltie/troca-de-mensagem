--!strict
--[[
	Formato dos dados persistidos do jogador + migração de versões antigas.
	Puro: testável no Lune.

	Para mudar o formato:
	  1. altere Types.PlayerData e TEMPLATE;
	  2. suba Config.Data.SchemaVersion;
	  3. trate a conversão em migrate() (dados antigos nunca podem quebrar o load).
]]

local Config = require("@game/ReplicatedStorage/Shared/Config")
local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")
local Types = require("@game/ReplicatedStorage/Shared/Types")

local TEMPLATE: Types.PlayerData = TableUtil.deepFreeze({
	schemaVersion = Config.Data.SchemaVersion,
	sessions = 0,
	firstJoin = 0,
	lastJoin = 0,
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
	local data = TableUtil.reconcile(raw, TEMPLATE)
	-- Exemplo de migração futura:
	-- if data.schemaVersion < 2 then ... data.schemaVersion = 2 end
	data.schemaVersion = Config.Data.SchemaVersion
	return data
end

return PlayerDataSchema
