--!strict
--[[
	Raio que atinge quem está ao ar livre (puro, testado no Lune).
	- A cada `RollEvery` segundos ao ar livre, cada jogador tem `chance(stage, last)` de virar alvo.
	- O alvo recebe aviso no chão (brilho + estalo) por `WarnTime` segundos; se ainda estiver a menos de
	  `KillRadius` do ponto quando cair, é derrubado (mesmo fluxo da captura: resgate / segunda chance).
	- No último capítulo (a fuga) a chance é bem maior. Logo após o início do capítulo ou de outro raio, nada.
]]

local LightningRules = {}

LightningRules.RollEvery = 8
LightningRules.WarnTime = 1.6
LightningRules.KillRadius = 4.5
-- Segundos sem raio no começo do capítulo e depois de cada raio (por jogador).
LightningRules.StartGrace = 25
LightningRules.Cooldown = 30
-- Chance por rolagem: capítulos normais ~1 raio a cada 4-5 min ao ar livre; na fuga ~1 por minuto.
LightningRules.BaseChance = 0.03
LightningRules.FinalChance = 0.13

function LightningRules.chance(stage: number, lastStage: number): number
	if stage >= lastStage then
		return LightningRules.FinalChance
	end
	return LightningRules.BaseChance
end

-- Pode rolar agora? (tempo de capítulo e intervalo desde o último raio no jogador)
function LightningRules.canRoll(sinceStageStart: number, sinceLastStrike: number): boolean
	return sinceStageStart >= LightningRules.StartGrace and sinceLastStrike >= LightningRules.Cooldown
end

-- Acertou? Distância horizontal entre o ponto marcado e onde o jogador está quando o raio cai.
function LightningRules.hits(markX: number, markZ: number, x: number, z: number): boolean
	local dx, dz = x - markX, z - markZ
	return dx * dx + dz * dz <= LightningRules.KillRadius * LightningRules.KillRadius
end

return table.freeze(LightningRules)
