--!strict
-- Direção de luz/pós, sem APIs do engine: valores e orçamentos verificáveis no Lune.
local Config = require("../Config")
local Profile = {}
export type RGB = { number }
export type Grade = { tint: RGB, contrast: number, saturation: number, brightness: number }

-- Lua fria e pontos quentes: preserva as cores dos brinquedos sem iluminar todos os cantos.
Profile.World = {
	clock = 0.3,
	brightness = 0.8, -- lua fraca: o exterior é lido pelas luzes da casa e pela lanterna (20/10: um pouco mais clara)
	ambient = { 16, 18, 26 },
	ambientPower = { 24, 25, 31 },
	-- Sob o telhado a casa é escura (a lanterna é a fonte principal); com energia, só um pouco menos.
	ambientIndoor = { 12, 11, 12 },
	ambientIndoorPower = { 30, 27, 24 },
	outdoor = { 36, 42, 58 },
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
-- Lanterna mais forte (aprovada pelo humano em 19/10/2026): o feixe revela o cômodo; fora dele continua escuro.
-- `halo`: cones extras em volta do feixe (abertura, fração do brilho, fração do alcance) para a luz cair aos poucos.
-- Foco redondo e nítido (pedido do humano): cone principal mais fechado e forte; auréola fraca só para a borda
-- não cortar seco; quase nada de luz espalhada em volta da mão.
Profile.Flashlight = {
	brightness = 5.6,
	spill = 0.2,
	spillRange = 8,
	angle = 36,
	range = 64,
	-- Borda em degradê (pedido de 20/10): quatro anéis cada vez mais abertos e fracos em volta do foco.
	halo = {
		{ angle = 46, share = 0.42, reach = 0.9 },
		{ angle = 58, share = 0.22, reach = 0.8 },
		{ angle = 72, share = 0.1, reach = 0.62 },
		{ angle = 90, share = 0.04, reach = 0.42 },
	},
}
-- Filtro de cor "frio" (opção B, escolhida pelo humano): azulado, menos saturado e mais contraste, por cima do tom
-- de cada ambiente.
Profile.Look = { tint = { 196, 218, 255 }, saturation = -0.25, contrast = 0.14, brightness = 0.02 }
Profile.Forest = {
	ambient = { 28, 36, 46 },
	outdoor = { 58, 74, 94 },
	fog = { 17, 25, 33 },
	fogStart = 14,
	fogScale = 0.62,
	exposure = 0.08,
}
Profile.ShadowBudget = 2 -- mais a lanterna própria; colegas nunca ganham sombras
Profile.ShadowDistance = 60
Profile.TransitionRate = 1.8

function Profile.grade(indoor: number, power: number): Grade
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	-- Cor local continua reconhecível; energia aquece só o interior.
	local base = { 240 + inside * on * 12, 246 + inside * on * 2, 255 - inside * on * 18 }
	local look = Profile.Look
	return {
		tint = { base[1] * look.tint[1] / 255, base[2] * look.tint[2] / 255, base[3] * look.tint[3] / 255 },
		-- Dentro de casa: mais contraste e cor mais lavada (pretos fundos, luz quente só onde bate).
		contrast = 0.08 + inside * 0.04 + look.contrast,
		saturation = -0.04 - inside * 0.06 + look.saturation,
		brightness = 0.005 + look.brightness,
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
	-- Sem o reforço de exposição dentro de casa que deixava os cômodos claros; energia acrescenta pouco.
	-- 20/10: base 0,3 (antes 0,08) a pedido do humano, "um pouco menos escuro".
	return 0.3 + math.clamp(indoor, 0, 1) * 0.03 * math.clamp(power, 0, 1)
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

-- Névoa que vem e vai ao ar livre (0 = limpo, 1 = banco mais denso), sem ritmo perceptível: duas ondas lentas.
Profile.FogBank = { depth = 0.58, period = 150, cross = 67, color = { 58, 64, 76 } }
function Profile.fogBank(now: number): number
	local a = math.sin(now * 2 * math.pi / Profile.FogBank.period)
	local b = math.sin(now * 2 * math.pi / Profile.FogBank.cross + 1.3)
	return math.clamp(0.5 + 0.35 * a + 0.25 * b, 0, 1)
end

-- Fator do alcance da névoa: só ao ar livre (`outside` 0..1) o banco aproxima a névoa.
function Profile.fogScale(now: number, outside: number): number
	return 1 - Profile.FogBank.depth * Profile.fogBank(now) * math.clamp(outside, 0, 1)
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
