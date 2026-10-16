--!strict
--[[
	Lista de servidores do menu (puro). Cada servidor publica um registro curto no MemoryStore
	(LobbyService); aqui ficam o formato, a validação do que vem de fora e a ordem de exibição.

	Ordem: servidores no lobby com vaga primeiro (dá para escolher o modo junto), depois partidas em
	andamento com vaga (a pessoa entra como espera e joga a próxima etapa), por mais jogadores.
]]

export type Entry = {
	job: string,
	players: number,
	max: number,
	-- "Story" | "Standard" | "" (ainda votando)
	mode: string,
	-- Fase da campanha (Lobby, Playing, Intermission, Extracting, Won, Lost)
	phase: string,
	stage: number,
	updated: number,
}

local ServerList = {}

-- Registros mais velhos que isso são servidores que caíram sem se apagar.
ServerList.TTL = 90
ServerList.REFRESH = 20
ServerList.MAX_ROWS = 20

-- JobId da Roblox (GUID, 36 caracteres).
function ServerList.validJob(job: unknown): boolean
	return type(job) == "string" and #job == 36 and string.match(job, "^[%x%-]+$") ~= nil
end

local PHASES = { Lobby = true, Playing = true, Intermission = true, Extracting = true, Won = true, Lost = true }

-- Valida um registro vindo do MemoryStore (nunca confie no formato).
function ServerList.decode(raw: unknown, job: string): Entry?
	if type(raw) ~= "table" or not ServerList.validJob(job) then
		return nil
	end
	local r = raw :: { [string]: any }
	local players, max, stage, updated = r.players, r.max, r.stage, r.updated
	if type(players) ~= "number" or type(max) ~= "number" or type(updated) ~= "number" then
		return nil
	end
	if players ~= players or max ~= max or players < 0 or max < 1 or max > 50 then
		return nil
	end
	local phase = if type(r.phase) == "string" and PHASES[r.phase] then r.phase else "Lobby"
	local mode = if r.mode == "Story" or r.mode == "Standard" then r.mode else ""
	return {
		job = job,
		players = math.floor(math.min(players, max)),
		max = math.floor(max),
		mode = mode,
		phase = phase,
		stage = if type(stage) == "number" and stage == stage then math.clamp(math.floor(stage), 0, 9) else 0,
		updated = updated,
	}
end

function ServerList.alive(entry: Entry, now: number): boolean
	return now - entry.updated <= ServerList.TTL
end

-- Dá para entrar? (vivo, com vaga, não é o próprio servidor, partida não terminando)
function ServerList.joinable(entry: Entry, selfJob: string, now: number): (boolean, string?)
	if entry.job == selfJob then
		return false, "server_self"
	end
	if not ServerList.alive(entry, now) then
		return false, "server_gone"
	end
	if entry.players >= entry.max then
		return false, "server_full"
	end
	return true, nil
end

local function rank(entry: Entry): number
	if entry.phase == "Lobby" then
		return 0
	elseif entry.phase == "Won" or entry.phase == "Lost" then
		return 2
	end
	return 1
end

-- Só servidores vivos; o próprio fica de fora. Lobby com vaga primeiro, depois mais cheios.
function ServerList.sorted(entries: { Entry }, selfJob: string, now: number): { Entry }
	local list: { Entry } = {}
	for _, entry in entries do
		if entry.job ~= selfJob and ServerList.alive(entry, now) then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		local fullA, fullB = a.players >= a.max, b.players >= b.max
		if fullA ~= fullB then
			return not fullA
		end
		local ra, rb = rank(a), rank(b)
		if ra ~= rb then
			return ra < rb
		end
		if a.players ~= b.players then
			return a.players > b.players
		end
		return a.job < b.job
	end)
	while #list > ServerList.MAX_ROWS do
		table.remove(list)
	end
	return list
end

return table.freeze(ServerList)
