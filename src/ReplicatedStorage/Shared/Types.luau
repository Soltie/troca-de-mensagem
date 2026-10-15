--!strict
--[[
	Tipos compartilhados entre servidor e cliente.
	Este módulo não tem lógica: só `export type`. Importe com:
		local Types = require("@game/ReplicatedStorage/Shared/Types")
]]

export type LogLevel = "Debug" | "Info" | "Warn" | "Error"

-- Envelope padrão de resposta de RemoteFunction (ver Server/Net/ServerNet).
export type Result<T> = { ok: true, data: T } | { ok: false, error: string }

-- Modo de persistência do PlayerDataService.
export type DataMode = "real" | "mock"

-- Dados persistidos de cada jogador. Mudou o formato? Suba Config.Data.SchemaVersion
-- e trate a migração em Server/Data/PlayerDataSchema.
export type PlayerData = {
	schemaVersion: number,
	sessions: number,
	firstJoin: number,
	lastJoin: number,
}

-- Resposta do smoke test "Ping".
export type PingResponse = {
	message: string,
	serverTime: number,
	dataMode: DataMode,
	sessions: number,
}

return {}
