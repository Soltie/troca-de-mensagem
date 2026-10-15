--!strict
--[[
	Constantes do projeto. Só valores, nada de lógica nem APIs do Roblox.
	Tudo é congelado: tentar alterar em runtime gera erro.
]]

local TableUtil = require("./Util/TableUtil")
local Types = require("./Types")

local Config = {
	-- Nível mínimo de log exibido.
	LogLevel = "Info" :: Types.LogLevel,

	Net = {
		-- Pasta criada pelo servidor em ReplicatedStorage com todos os remotes.
		RemotesFolderName = "Remotes",
		-- Tempo máximo (s) que o cliente espera um remote aparecer.
		ClientWaitTimeout = 15,
		-- Rate limit padrão por jogador, por remote (token bucket).
		DefaultRateLimit = { capacity = 10, refillPerSecond = 5 },
	},

	Data = {
		-- Nome base do DataStore. No Studio (modo real) recebe o sufixo "_Studio".
		StoreName = "PlayerData_v1",
		SchemaVersion = 1,
		AutosaveInterval = 120,
		RetryAttempts = 3,
		RetryBaseDelay = 1,
		-- Só afeta o Studio. "auto": usa DataStore real se houver acesso, senão mock.
		-- "mock": sempre mock. "real": exige acesso (erro se não houver).
		StudioMode = "auto" :: "auto" | "mock" | "real",
		KickOnLoadFailure = true,
		-- BindToClose tem ~30s no total; deixamos folga.
		ShutdownTimeout = 25,
	},

	Debug = {
		ShowHud = true,
	},
}

return TableUtil.deepFreeze(Config)
