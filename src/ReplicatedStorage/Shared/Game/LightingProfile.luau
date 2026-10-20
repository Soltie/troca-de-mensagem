--!strict
-- Direção de luz/pós, sem APIs do engine: valores e orçamentos verificáveis no Lune.
local Config = require("../Config")
local Profile = {}
export type RGB = { number }
export type Grade = { tint: RGB, contrast: number, saturation: number, brightness: number }

-- Lua fria e pontos quentes: preserva as cores dos brinquedos sem iluminar todos os cantos.
Profile.World = {
	clock = 0.3,
	brightness = 0.75, -- lua fraca: o exterior é lido pelas luzes da casa e pela lanterna (20/10: levemente mais clara)
	ambient = { 16, 18, 26 },
	ambientPower = { 24, 25, 31 },
	-- Sob o telhado a casa é escura (a lanterna é a fonte principal), mas nunca preta. 21/10 (crítico, v2 "parece
	-- fim de tarde"): ambiente mais baixo; quem deixa ler portas e caminho é a luz de presença fraca e o luar
	-- que entra pelas janelas (`Moonlight`), fontes que o jogador vê. Com energia, um pouco mais e mais neutro.
	ambientIndoor = { 30, 32, 42 },
	ambientIndoorPower = { 44, 42, 44 },
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
	-- 21/10 (crítico v3): 5,6 → 4,4. Com a casa escura, o feixe cheio estourava em branco no lençol do sofá e no
	-- tijolo do porão; continua o foco forte e redondo que o humano aprovou, só sem clipar.
	brightness = 4.4,
	spill = 0.2,
	spillRange = 8,
	angle = 36,
	range = 64,
	-- Borda em degradê (pedido de 20/10): quatro anéis cada vez mais abertos e fracos em volta do foco.
	halo = {
		{ angle = 46, share = 0.3, reach = 0.85 },
		{ angle = 58, share = 0.12, reach = 0.7 },
		{ angle = 72, share = 0.05, reach = 0.5 },
		{ angle = 90, share = 0.015, reach = 0.32 },
	},
}
-- Luz de presença (estilo DOORS): luar fraco, sem sombra, preso à câmera, só dentro de casa. No Future o
-- Ambient sozinho não levanta a madeira escura (medido em 20/10: Ambient 66 ainda deixa o hall preto); esta
-- luz garante ler paredes, portas e piso a ~10 studs e deixa o fundo do corredor no escuro. Com a lanterna
-- ligada ela cai para `flashlight` (a lanterna vira a fonte principal); em cena cinematográfica, desliga.
-- Só existe no cliente (cada jogador vê a sua; ninguém ilumina a sala dos outros). Alcance curto (14): o Tung a
-- 15 studs nunca é revelado por ela; e quando ele chega perto (`near`..`far` studs) ela se apaga, para a silhueta
-- dele vir só da lanterna e dos olhos (pedido do crítico, 20/10).
Profile.Fill = { brightness = 1.7, range = 14, flashlight = 0.15, near = 6, far = 22, nearShare = 0.1 }
function Profile.fill(indoor: number, flashlightOn: boolean, cinematic: boolean, creature: number?): number
	if cinematic then
		return 0
	end
	local fill = Profile.Fill
	local base = fill.brightness * math.clamp(indoor, 0, 1)
	local k = math.clamp(((creature or math.huge) - fill.near) / (fill.far - fill.near), 0, 1)
	base *= fill.nearShare + (1 - fill.nearShare) * k
	return if flashlightOn then base * fill.flashlight else base
end
-- Porão (abaixo de `below` em Y): sem luar, terra e madeira úmida. Mais quente, mais sujo e mais escuro que a
-- casa (o crítico achou o porão cinza-azulado e limpo). A luz de presença cai e fica âmbar suja.
Profile.Basement = {
	below = -2,
	ambient = { 18, 15, 12 },
	fillColor = { 176, 138, 96 },
	fill = 0.45,
	tint = { 255, 232, 205 },
	saturation = 0.12, -- soma ao grade: recupera o marrom
	contrast = 0.08, -- cantos mais fundos
}
-- Luar pelas janelas da fachada (`WindowPane`): luz fria entrando no cômodo, a fonte visível do escuro legível.
-- O vidro fica escuro e meio transparente (antes era um retângulo branco liso) para ver a noite lá fora.
Profile.Moonlight = {
	brightness = 0.9,
	range = 18,
	angle = 70,
	glass = { 38, 48, 62 },
	transparency = 0.55,
}
-- Tetos de gesso claro (forros e teto do hall) estouravam sob a lanterna e as luminárias: escurecidos para um
-- gesso velho e encardido. `ceiling` multiplica a cor original (uma vez por peça).
Profile.Ceilings = {
	names = {
		RoomCeiling = true,
		RoomCeilingPanel = true,
		CorridorCeilingPanel = true,
		FoyerCeilingPanel = true,
		CorridorRoof = true,
	},
	shade = 0.5,
}
-- Placas de caminho (SurfaceGui das plaquinhas "SALA DE ESTAR", "COZINHA"...): eram o ponto mais claro do hall.
Profile.Signs = { lightInfluence = 0.75, brightness = 0.6 }
-- Feixe perto de uma superfície (teto, parede) estourava em branco: abaixo de `full` studs o brilho cai até
-- `floor` (a 2 studs). Longe nada muda, então o alcance de leitura das pistas fica igual.
-- 21/10: alcance 12 → 18 (o teto do hall, alto e claro, ficava a ~12–16 studs e ainda estourava) e piso 0,35.
Profile.FlashlightNear = { full = 18, close = 2, floor = 0.35, upward = 0.7 }
function Profile.nearDim(distance: number): number
	local near = Profile.FlashlightNear
	local t = math.clamp((distance - near.close) / (near.full - near.close), 0, 1)
	-- Curva suave (smoothstep): sem degrau perceptível ao aproximar.
	t = t * t * (3 - 2 * t)
	return near.floor + (1 - near.floor) * t
end
-- Apontada para cima (componente Y da direção do feixe), a lanterna cai até `upward`: tetos são de gesso claro
-- e não guardam pista; o feixe forte é para o chão e as paredes.
function Profile.aimDim(lookY: number): number
	local k = math.clamp((lookY - 0.45) / 0.4, 0, 1)
	return 1 + (Profile.FlashlightNear.upward - 1) * k
end
-- Filtro de cor "frio" (opção B, escolhida pelo humano): azulado, menos saturado e mais contraste, por cima do tom
-- de cada ambiente.
-- 20/10: contraste 0,14 -> 0,08; somado ao do interior esmagava os pretos e apagava a madeira escura.
Profile.Look = { tint = { 196, 218, 255 }, saturation = -0.25, contrast = 0.08, brightness = 0.02 }
-- Progressão por capítulo (a casa piora a cada um): mais fria, mais névoa, um pouco menos de cor (no máximo -0,05:
-- o âmbar dos interativos, o piano e os fusíveis precisam continuar se destacando). A exposição e o piso de
-- leitura não mudam, para não haver salto de brilho nem escuro ilegível. 6+ é a mata (perfil `Forest`).
-- `cold` puxa o ambiente para o luar (#8FA3C8) mantendo a luminância; `fog` multiplica o alcance da névoa.
export type ChapterLook = { cold: number, fog: number, saturation: number }
Profile.Moon = { 143, 163, 200 }
Profile.Chapters = {
	{ cold = 0, fog = 1, saturation = 0 }, -- 1: casa velha comum
	{ cold = 0.15, fog = 0.92, saturation = -0.02 }, -- 2: tábuas incham
	{ cold = 0.3, fog = 0.84, saturation = -0.03 }, -- 3: seiva e musgo
	{ cold = 0.45, fog = 0.76, saturation = -0.04 }, -- 4: porão de raízes
	{ cold = 0.55, fog = 0.7, saturation = -0.05 }, -- 5: a casa se levanta (o fogo tem grade próprio)
} :: { ChapterLook }

function Profile.chapter(stage: number): ChapterLook
	local index = math.clamp(math.floor(stage), 1, #Profile.Chapters)
	return Profile.Chapters[index]
end

function Profile.luma(c: RGB): number
	return 0.2126 * c[1] + 0.7152 * c[2] + 0.0722 * c[3]
end

-- Esfria uma cor rumo ao luar sem mudar a luminância (o jogador não sente salto de brilho).
function Profile.chill(color: RGB, cold: number): RGB
	local k = math.clamp(cold, 0, 1)
	local scale = Profile.luma(color) / Profile.luma(Profile.Moon)
	local out = {}
	for i = 1, 3 do
		out[i] = color[i] + (Profile.Moon[i] * scale - color[i]) * k
	end
	return out
end
Profile.Forest = {
	ambient = { 28, 36, 46 },
	outdoor = { 58, 74, 94 },
	fog = { 17, 25, 33 },
	fogStart = 14,
	fogScale = 0.62,
	exposure = 0.04,
}
Profile.ShadowBudget = 2 -- mais a lanterna própria; colegas nunca ganham sombras
Profile.ShadowDistance = 60
Profile.TransitionRate = 1.8

function Profile.grade(indoor: number, power: number, cold: number?, chapterSaturation: number?): Grade
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	local chill = math.clamp(cold or 0, 0, 1)
	-- Cor local continua reconhecível; energia aquece só o interior; capítulos tardios esfriam um pouco.
	local base = { (240 + inside * on * 12) * (1 - 0.06 * chill), 246 + inside * on * 2, 255 - inside * on * 18 }
	local look = Profile.Look
	return {
		tint = { base[1] * look.tint[1] / 255, base[2] * look.tint[2] / 255, base[3] * look.tint[3] / 255 },
		-- Dentro de casa: mais contraste e cor mais lavada (pretos fundos, luz quente só onde bate).
		contrast = 0.08 + inside * 0.04 + look.contrast,
		saturation = -0.04 - inside * 0.06 + look.saturation + math.clamp(chapterSaturation or 0, -0.2, 0),
		brightness = 0.005 + look.brightness,
	}
end

-- Ambiente final: noite fria lá fora, preenchimento quente dentro de casa, mata por cima de tudo.
function Profile.ambient(indoor: number, power: number, forest: number, cold: number?): RGB
	local inside = math.clamp(indoor, 0, 1)
	local on = math.clamp(power, 0, 1)
	local wild = math.clamp(forest, 0, 1)
	local base = {}
	for i = 1, 3 do
		local night = Profile.World.ambient[i] + (Profile.World.ambientPower[i] - Profile.World.ambient[i]) * on
		local house = Profile.World.ambientIndoor[i]
			+ (Profile.World.ambientIndoorPower[i] - Profile.World.ambientIndoor[i]) * on
		base[i] = night + (house - night) * inside
	end
	local chilled = Profile.chill(base, cold or 0)
	local out = {}
	for i = 1, 3 do
		out[i] = chilled[i] + (Profile.Forest.ambient[i] - chilled[i]) * wild
	end
	return out
end

function Profile.exposure(indoor: number, power: number): number
	-- Sem o reforço de exposição dentro de casa que deixava os cômodos claros; energia acrescenta pouco.
	-- 20/10: base 0,2 (antes 0,08) a pedido do humano, "levemente mais claro".
	return 0.2 + math.clamp(indoor, 0, 1) * 0.03 * math.clamp(power, 0, 1)
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
