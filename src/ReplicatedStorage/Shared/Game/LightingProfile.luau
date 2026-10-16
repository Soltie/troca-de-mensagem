--!strict
-- Direção de luz/pós, sem APIs do engine: valores e orçamentos verificáveis no Lune.
local Config = require("../Config")
local Profile = {}
export type RGB = { number }
export type Grade = { tint: RGB, contrast: number, saturation: number, brightness: number }

Profile.World = {
	clock = 0.3,
	brightness = 0.85,
	ambient = { 17, 20, 29 },
	ambientPower = { 25, 28, 33 },
	outdoor = { 54, 65, 85 },
	fog = { 25, 32, 43 },
	fogPower = { 30, 36, 44 },
	fogStart = 16,
	fogEnd = 142,
	fogEndPower = 164,
	shadowSoftness = 0.35,
	diffuse = 0.12,
	specular = 0.2,
}
Profile.Bloom = { intensity = 0.19, size = 14, threshold = 1.65 }
Profile.Flashlight = { brightness = 2.25, spill = 0.16, angle = 42 }
Profile.ShadowBudget = 2 -- mais a lanterna própria; colegas nunca ganham sombras
Profile.ShadowDistance = 55
Profile.TransitionRate = 1.8

function Profile.grade(indoor: number, power: number): Grade
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	return {
		tint = { 237 + inside * on * 10, 244 + inside * on * 3, 255 - inside * on * 15 },
		contrast = 0.075 + inside * 0.025,
		saturation = -0.12 - inside * 0.035,
		brightness = 0.005,
	}
end

function Profile.exposure(indoor: number, power: number): number
	return 0.08 + math.clamp(indoor, 0, 1) * (0.08 - 0.06 * math.clamp(power, 0, 1))
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
