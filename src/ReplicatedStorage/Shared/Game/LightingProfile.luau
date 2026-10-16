--!strict
-- Direção de luz/pós, sem APIs do engine: valores e orçamentos verificáveis no Lune.
local Config = require("../Config")
local Profile = {}
export type RGB = { number }
export type Grade = { tint: RGB, contrast: number, saturation: number, brightness: number }

-- Noite de lua cheia, legível para crianças: névoa lilás, ambiente azulado e contraste suave.
-- O medo vem do Tung Tung e do som, não de tela preta.
Profile.World = {
	clock = 0.3,
	brightness = 2.1,
	ambient = { 58, 54, 88 },
	ambientPower = { 84, 76, 98 },
	outdoor = { 96, 104, 152 },
	fog = { 46, 40, 82 },
	fogPower = { 60, 54, 92 },
	fogStart = 28,
	fogEnd = 240,
	fogEndPower = 280,
	shadowSoftness = 0.25,
	diffuse = 0.35,
	specular = 0.35,
}
Profile.Bloom = { intensity = 0.34, size = 18, threshold = 1.25 }
Profile.Flashlight = { brightness = 3.1, spill = 0.22, angle = 48 }
Profile.ShadowBudget = 2 -- mais a lanterna própria; colegas nunca ganham sombras
Profile.ShadowDistance = 60
Profile.TransitionRate = 1.8

function Profile.grade(indoor: number, power: number): Grade
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	-- Cores vivas (saturação positiva); dentro de casa com energia, um toque quente.
	return {
		tint = { 240 + inside * on * 12, 238 + inside * on * 6, 255 - inside * on * 22 },
		contrast = 0.06 + inside * 0.03,
		saturation = 0.12 - inside * 0.04,
		brightness = 0.02,
	}
end

function Profile.exposure(indoor: number, power: number): number
	return 0.22 + math.clamp(indoor, 0, 1) * (0.14 - 0.08 * math.clamp(power, 0, 1))
end

function Profile.fogEnd(base: number, danger: number): number
	return base + (math.min(base, Config.Effects.DangerFogEnd) - base) * math.clamp(danger, 0, 1)
end

function Profile.approach(current: number, target: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-Profile.TransitionRate * math.max(0, dt)))
end

-- Falha rara, com identidade estável por luminária; sem ruído aleatório a cada quadro.
function Profile.flicker(now: number, seed: number, marked: boolean, flashes: boolean): number
	if not flashes then
		return 1
	end
	local phase = (now + seed * 0.371) % 7.3
	if marked and phase < 0.09 then
		return 0.48
	end
	return 0.98 + 0.02 * math.sin(now * 3.1 + seed)
end

function Profile.shadowBudget(quality: number): number
	-- 0 = automático. Não força a qualidade escolhida pelo jogador.
	return if quality > 0 and quality <= 3 then 0 else Profile.ShadowBudget
end

export type Candidate = { id: string, distance: number, range: number, enabled: boolean }
function Profile.selectShadows(candidates: { Candidate }, budget: number): { [string]: boolean }
	local near = {}
	for _, candidate in candidates do
		if candidate.enabled and candidate.distance <= math.min(Profile.ShadowDistance, candidate.range + 12) then
			table.insert(near, candidate)
		end
	end
	table.sort(near, function(a, b)
		if a.distance == b.distance then
			return a.id < b.id
		end
		return a.distance < b.distance
	end)
	local chosen = {}
	for i = 1, math.min(math.max(0, math.floor(budget)), #near) do
		chosen[near[i].id] = true
	end
	return chosen
end
return table.freeze(Profile)
