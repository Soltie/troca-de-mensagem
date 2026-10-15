--!strict
--[[
	Regras puras dos esconderijos (armários). Testadas no Lune.

	Esconder-se é uma fuga de verdade: se o Vigia NÃO te viu entrar, ele perde o rastro, vai
	até onde te viu por último e procura. Ele te acha se:
	  - viu você entrar (perseguição com visão recente) e chega ao armário; ou
	  - fica perto do armário por NoticeTime sem você prender a respiração (ele ouve).
]]

local Config = require("@game/ReplicatedStorage/Shared/Config")

export type EnterContext = {
	playing: boolean,
	alive: boolean,
	occupied: boolean,
	alreadyHidden: boolean,
	-- Segundos desde que saiu de um esconderijo (math.huge se nunca).
	sinceExit: number,
}

export type FoundContext = {
	sawEntry: boolean,
	creatureActive: boolean,
	-- Distância do Vigia ao armário.
	distance: number,
	holdingBreath: boolean,
	-- Tempo contínuo (s) que o Vigia está dentro de NoticeRange com você respirando.
	exposedTime: number,
	captureRange: number,
}

local H = Config.Hide

local HideRules = {}

function HideRules.canEnter(ctx: EnterContext): (boolean, string?)
	if not ctx.playing then
		return false, "not_playing"
	end
	if not ctx.alive then
		return false, "dead"
	end
	if ctx.alreadyHidden then
		return false, "not_available"
	end
	if ctx.occupied then
		return false, "hide_occupied"
	end
	if ctx.sinceExit < H.ExitCooldown then
		return false, "not_available"
	end
	return true, nil
end

-- Viu entrar? `sinceSeen` = segundos desde a última vez que o Vigia te enxergou.
function HideRules.sawEntry(sinceSeen: number, chasing: boolean): boolean
	return chasing and sinceSeen <= H.SawEntryWindow
end

-- Acumula o tempo de exposição (Vigia perto e você respirando). Zera quando ele se afasta.
function HideRules.exposure(previous: number, distance: number, holdingBreath: boolean, dt: number): number
	if distance > H.NoticeRange then
		return 0
	end
	if holdingBreath then
		return previous
	end
	return previous + dt
end

function HideRules.found(ctx: FoundContext): boolean
	if not ctx.creatureActive then
		return false
	end
	if ctx.sawEntry and ctx.distance <= ctx.captureRange + 1.5 then
		return true
	end
	return ctx.distance <= H.NoticeRange and not ctx.holdingBreath and ctx.exposedTime >= H.NoticeTime
end

return HideRules
