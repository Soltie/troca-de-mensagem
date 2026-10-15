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

-- Resposta do remote "Interact" / "RequestRestart" (dentro do envelope Result).
-- message = chave de Text.Messages; note = id do bilhete a exibir;
-- kind = tipo do objeto (o cliente anima a resposta aprovada: pegar item, chave, disjuntor...).
export type InteractResponse = {
	accepted: boolean,
	message: string,
	note: string?,
	kind: string?,
}

return {}
