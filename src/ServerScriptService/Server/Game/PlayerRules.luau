--!strict
--[[
	Regras puras do corpo do jogador (testadas no Lune), aplicadas pelo PlayerStateService:
	- velocidade máxima aceita por postura e checagem com tolerância e carência (anti speed hack
	  sem punir lag ou empurrão);
	- segurar a respiração (só escondido): duração máxima, arquejo forçado e recarga.
]]

local Config = require("@game/ReplicatedStorage/Shared/Config")

export type Stance = "Stand" | "Crouch"

export type SpeedCheck = {
	overSince: number?,
}

export type SpeedVerdict = "ok" | "over" | "correct"

export type Breath = {
	holding: boolean,
	since: number,
	cooldownUntil: number,
}

local P = Config.Player

local PlayerRules = {}

-- Velocidade horizontal máxima permitida (sem tolerância) para a postura.
function PlayerRules.maxSpeed(stance: Stance): number
	if stance == "Crouch" then
		return P.CrouchSpeed
	end
	return P.SprintSpeed
end

-- WalkSpeed inicial que o servidor aplica ao trocar de postura.
function PlayerRules.walkSpeed(stance: Stance): number
	if stance == "Crouch" then
		return P.CrouchSpeed
	end
	return P.WalkSpeed
end

function PlayerRules.newSpeedCheck(): SpeedCheck
	return { overSince = nil }
end

--[[
	`speed` = velocidade horizontal medida no servidor; `allowed` = limite da postura.
	"over" enquanto passa do limite dentro da carência; "correct" quando passou tempo demais
	(o service devolve o jogador à última posição válida). Depois de "correct" a contagem zera.
]]
function PlayerRules.checkSpeed(check: SpeedCheck, speed: number, allowed: number, now: number): SpeedVerdict
	if speed ~= speed or speed <= allowed * P.SpeedTolerance then
		check.overSince = nil
		return "ok"
	end
	local since = check.overSince
	if since == nil then
		check.overSince = now
		return "over"
	end
	if now - since >= P.SpeedGrace then
		check.overSince = nil
		return "correct"
	end
	return "over"
end

function PlayerRules.newBreath(): Breath
	return { holding = false, since = 0, cooldownUntil = 0 }
end

-- Começa a prender a respiração. Recusa durante a recarga.
function PlayerRules.holdBreath(breath: Breath, now: number): boolean
	if breath.holding or now < breath.cooldownUntil then
		return false
	end
	breath.holding = true
	breath.since = now
	return true
end

-- Solta a respiração voluntariamente (sem arquejo).
function PlayerRules.releaseBreath(breath: Breath, now: number)
	if breath.holding then
		breath.holding = false
		breath.cooldownUntil = now + P.HoldBreathCooldown * 0.5
	end
end

-- Avança o relógio. Retorna "gasp" quando o fôlego acabou (solta à força, faz barulho).
function PlayerRules.stepBreath(breath: Breath, now: number): "gasp"?
	if breath.holding and now - breath.since >= P.HoldBreathMax then
		breath.holding = false
		breath.cooldownUntil = now + P.HoldBreathCooldown
		return "gasp"
	end
	return nil
end

return PlayerRules
