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
	-- v2: economia, cosméticos e progressão (regras em Shared/Game/Economy).
	wallet: { fichas: number, creditos: number },
	xp: number,
	-- Último nível cujas recompensas já foram entregues.
	rewardedLevel: number,
	owned: { [string]: boolean },
	-- Tipo de cosmético -> id equipado (flashlight, uniform, filter, title).
	equipped: { [string]: string },
	-- Fitas colecionáveis -> quando achou (os.time).
	tapes: { [string]: number },
	daily: { lastDay: number, streak: number, spinDay: number, spinsUsed: number },
	stats: { runs: number, escapes: number, captures: number, chests: number, stages: number },
	-- Recibos de compra já concedidos (idempotência do ProcessReceipt) -> os.time.
	purchases: { [string]: number },
	-- Produtos de compra única já entregues (ex.: pacote inicial) -> os.time.
	oncePurchases: { [string]: number },
	-- v3: passe de temporada (regras em Shared/Game/Season). `id` = temporada a que xp e
	-- recompensas se referem (outra temporada zera tudo). free/premium = níveis cuja recompensa
	-- já foi entregue em cada trilha; chave = nível em texto ("1".."30"), porque o DataStore salva JSON.
	season: { id: string, xp: number, free: { [string]: boolean }, premium: { [string]: boolean } },
	-- v4: vantagens pagas (regras em Shared/Game/Perks): nível de cada melhoria, estoque de
	-- consumíveis, kit de uso automático e bônus de tempo (os.time em que acabam).
	perks: { [string]: number },
	consumables: { [string]: number },
	loadout: { [string]: boolean },
	boosts: { fichasUntil: number, xpUntil: number },
	-- v4: modo história (Shared/Game/StoryRewards): capítulo -> os.time da 1ª vitória / da 1ª sem quedas.
	story: { cleared: { [string]: number }, flawless: { [string]: number } },
	-- Trava de sessão (um servidor por vez escreve os dados). Ver Server/Data/SessionLock.
	sessionLock: { job: string, at: number }?,
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
