--!strict
-- Direção de luz/pós, sem APIs do engine: valores e orçamentos verificáveis no Lune.
local Config = require("../Config")
local Profile = {}
export type RGB = { number }
export type Grade = { tint: RGB, contrast: number, saturation: number, brightness: number }

-- Lua fria e pontos quentes: preserva as cores dos brinquedos sem iluminar todos os cantos.
Profile.World = {
	clock = 0.3,
	brightness = 1.05,
	ambient = { 19, 22, 32 },
	ambientPower = { 27, 28, 36 },
	-- Sob o telhado: preenchimento quente e baixo, para nenhum cômodo virar tela preta sem energia.
	ambientIndoor = { 44, 37, 34 },
	ambientIndoorPower = { 54, 46, 40 },
	outdoor = { 65, 74, 100 },
	fog = { 30, 36, 51 },
	fogPower = { 35, 40, 53 },
	fogStart = 24,
	fogEnd = 190,
	fogEndPower = 210,
	shadowSoftness = 0.3,
	diffuse = 0.14,
	specular = 0.22,
}
Profile.Bloom = { intensity = 0.1, size = 10, threshold = 1.9 }
Profile.Flashlight = { brightness = 2.7, spill = 0.11, angle = 40 }
Profile.Forest = {
	ambient = { 21, 28, 36 },
	outdoor = { 49, 63, 81 },
	fog = { 17, 25, 33 },
	fogStart = 14,
	fogScale = 0.62,
	exposure = -0.04,
}
Profile.ShadowBudget = 2 -- mais a lanterna própria; colegas nunca ganham sombras
Profile.ShadowDistance = 60
Profile.TransitionRate = 1.8

function Profile.grade(indoor: number, power: number): Grade
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	-- Cor local continua reconhecível; energia aquece só o interior.
	return {
		tint = { 240 + inside * on * 12, 246 + inside * on * 2, 255 - inside * on * 18 },
		contrast = 0.075 + inside * 0.025,
		saturation = -0.035 - inside * 0.025,
		brightness = 0.005,
	}
end

-- Ambiente final: noite fria lá fora, preenchimento quente dentro de casa, mata por cima de tudo.
function Profile.ambient(indoor: number, power: number, forest: number): RGB
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	local wild = math.clamp(forest, 0, 1)
	local out = {}
	for i = 1, 3 do
		local night = Profile.World.ambient[i] + (Profile.World.ambientPower[i] - Profile.World.ambient[i]) * on
		local house = Profile.World.ambientIndoor[i]
			+ (Profile.World.ambientIndoorPower[i] - Profile.World.ambientIndoor[i]) * on
		local base = night + (house - night) * inside
		out[i] = base + (Profile.Forest.ambient[i] - base) * wild
	end
	return out
end

function Profile.exposure(indoor: number, power: number): number
	return 0.08 + math.clamp(indoor, 0, 1) * (0.08 - 0.06 * math.clamp(power, 0, 1))
end

-- Luz decorativa não deve preencher salas vizinhas nem competir com a lanterna.
-- Nomes desconhecidos (pistas, moedas e efeitos de missão) conservam seus valores.
function Profile.fixture(name: string, brightness: number, range: number): (number, number)
	if name == "NightLight" then
		return brightness * 0.55, math.min(range, 18)
	elseif name == "Candle" then
		return brightness * 0.8, math.min(range, 22)
	elseif name == "LampShade" then
		return brightness, math.min(range, 14)
	end
	return brightness, range
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
