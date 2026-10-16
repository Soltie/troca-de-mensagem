--!strict
-- Regras puras de apresentação: o estado global da criatura não é uma captura de toda a equipe.
local Config = require("../Config")

local Presentation = {}

function Presentation.playing(phase: string, status: string?): boolean
	return phase == "Playing" and (status == nil or status == "Active")
end

function Presentation.mode(mode: string, targetId: number?, userId: number, status: string?): string
	if status ~= nil and status ~= "Active" then
		return "Dormant"
	end
	if (mode == "Chase" or mode == "Capture") and targetId ~= userId then
		-- Compatibilidade solo com snapshots antigos; coop exige alvo explícito.
		if status == nil and (targetId == nil or targetId == 0) then
			return mode
		end
		return "Patrol"
	end
	return mode
end

function Presentation.captured(previousStatus: string?, status: string?, previousPhase: string?, phase: string): boolean
	if status ~= nil then
		return status == "Downed" and previousStatus ~= nil and previousStatus ~= "Downed"
	end
	return previousPhase ~= nil and previousPhase ~= "Lost" and phase == "Lost"
end

function Presentation.effects(fear: number, playing: boolean, flashes: boolean, retro: boolean)
	local value = if playing then math.clamp(fear, 0, 1) else 0
	local panic = math.clamp((value - 0.8) / 0.2, 0, 1)
	return {
		fear = value,
		vignette = if retro then value * 0.65 else 0,
		grain = if retro then value else 0,
		fog = if retro then value * value else 0,
		blur = if flashes then panic * Config.Effects.PanicBlur else 0,
		glitch = if flashes then panic else 0,
	}
end

return Presentation
