--!strict
--[[
	Trava de sessão dos dados do jogador (pura, testada no Lune).

	Só um servidor por vez escreve os dados de um jogador: ao carregar, o servidor grava
	`sessionLock = { job = JobId, at = os.time() }` (UpdateAsync). Outro servidor que encontrar a
	trava ainda válida espera e tenta de novo; depois de TTL sem renovação (servidor caiu) pode tomar.
	O autosave renova a trava; sair do jogo a libera. Isso evita que uma reconexão rápida faça
	um servidor antigo sobrescrever compras/progresso gravados pelo novo.
]]

export type Lock = { job: string, at: number }

local SessionLock = {}

-- Segundos sem renovação para considerar a trava abandonada (> 2 autosaves).
SessionLock.TTL = 300
-- Tentativas ao carregar antes de tomar a trava à força, e espera entre elas (s).
SessionLock.Attempts = 4
SessionLock.RetryDelay = 3

-- Este servidor pode assumir/escrever os dados?
function SessionLock.canTake(current: Lock?, job: string, now: number, ttl: number?): boolean
	if current == nil or type(current) ~= "table" then
		return true
	end
	if current.job == job then
		return true
	end
	local at = if type(current.at) == "number" then current.at else 0
	return now - at >= (ttl or SessionLock.TTL)
end

function SessionLock.make(job: string, now: number): Lock
	return { job = job, at = now }
end

return SessionLock
