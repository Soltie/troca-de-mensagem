--!strict
--[[
	Regras puras da rodada: transições de fase e validação de interação.
	O servidor nunca confia no cliente: toda interação passa por validateInteraction.
	Testado no Lune.
]]

export type Phase = "Loading" | "Intro" | "Playing" | "Won" | "Lost"

export type InteractionContext = {
	phase: Phase,
	exists: boolean,
	enabled: boolean,
	alive: boolean,
	distance: number,
	maxDistance: number,
	tolerance: number,
	lineOfSight: boolean,
}

local TRANSITIONS: { [Phase]: { [Phase]: boolean } } = {
	Loading = { Intro = true },
	Intro = { Playing = true },
	Playing = { Won = true, Lost = true },
	Won = { Intro = true },
	Lost = { Intro = true },
}

local RoundRules = {}

function RoundRules.canTransition(from: Phase, to: Phase): boolean
	local allowed = TRANSITIONS[from]
	return allowed ~= nil and allowed[to] == true
end

function RoundRules.canRestart(phase: Phase): boolean
	return phase == "Won" or phase == "Lost"
end

-- Ordem importa: a primeira regra violada define o motivo devolvido ao cliente.
function RoundRules.validateInteraction(ctx: InteractionContext): (boolean, string?)
	if ctx.phase ~= "Playing" then
		return false, "not_playing"
	end
	if not ctx.alive then
		return false, "dead"
	end
	if not ctx.exists then
		return false, "unknown"
	end
	if not ctx.enabled then
		return false, "not_available"
	end
	if ctx.distance ~= ctx.distance or ctx.distance > ctx.maxDistance + ctx.tolerance then
		return false, "too_far"
	end
	if not ctx.lineOfSight then
		return false, "blocked"
	end
	return true, nil
end

-- Formata segundos como MM:SS para as telas finais.
function RoundRules.formatTime(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	return string.format("%02d:%02d", total // 60, total % 60)
end

return RoundRules
