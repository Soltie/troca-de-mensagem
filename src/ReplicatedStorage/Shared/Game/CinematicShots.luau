--!strict
--[[
	Câmeras da casa e matemática pura. Varanda z=64; portão da floresta z=98.
	Abertura/lobby/fuga usam o exterior; StoryCatalog enquadra os interiores fixos.
	Sem game/task/CFrame: CinematicController converte os vetores em câmera.
]]

export type Vec = { x: number, y: number, z: number }
export type Ease = "linear" | "inOut" | "out" | "in"
-- Como se entra NESTE plano: estática de fita, piscar de olhos ou corte seco.
export type Cut = "static" | "blink" | "hard"

export type Shot = {
	-- Carimbo da câmera ("CÂMERA 2 · PÁTIO").
	label: string,
	from: Vec,
	to: Vec,
	lookFrom: Vec,
	lookTo: Vec,
	duration: number,
	fov: number,
	ease: Ease,
	-- Tremor de câmera na mão (0..1); 0 = câmera de segurança fixa.
	handheld: number,
	cut: Cut,
}

export type Sequence = {
	name: string,
	shots: { Shot },
	-- Cartela do primeiro plano e legendas distribuídas pela duração (opcionais).
	title: string?,
	subtitle: string?,
	captions: { string }?,
}

local function v(x: number, y: number, z: number): Vec
	return table.freeze({ x = x, y = y, z = z })
end

local function shot(values: Shot): Shot
	assert(values.duration > 0, "[CinematicShots] duration must be positive")
	assert(values.fov >= 20 and values.fov <= 90, "[CinematicShots] fov out of range")
	return table.freeze(values)
end

local CinematicShots = {}

-- Câmeras da casa: varanda em z=64, portão em z=98; todas as trajetórias externas.
CinematicShots.Opening = table.freeze({
	name = "Opening",
	title = "A CASA AMALDIÇOADA",
	subtitle = "03:12 / A FITA NÃO TERMINOU",
	captions = table.freeze({
		"Uma televisão acesa. Uma casa vazia há trinta anos.",
		"Na fita, alguém deixou a porta aberta para vocês.",
		"Se ouvirem três pancadas, não respondam.",
	}),
	shots = table.freeze({
		shot({
			label = "FLORESTA / 03:12",
			from = v(8, 7, 123),
			to = v(6, 6, 113),
			lookFrom = v(0, 9, 64),
			lookTo = v(0, 8, 64),
			duration = 3.2,
			fov = 54,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "A CASA / FITA ENCONTRADA",
			from = v(-30, 11, 85),
			to = v(-22, 10, 81),
			lookFrom = v(0, 12, 64),
			lookTo = v(0, 10, 64),
			duration = 3,
			fov = 52,
			ease = "inOut",
			handheld = 0.12,
			cut = "hard",
		}),
		shot({
			label = "TRÊS PANCADAS",
			from = v(7, 5, 80),
			to = v(4, 5, 74),
			lookFrom = v(3, 5, 65),
			lookTo = v(3, 5, 65),
			duration = 2.8,
			fov = 48,
			ease = "inOut",
			handheld = 0.2,
			cut = "hard",
		}),
	}),
}) :: Sequence
CinematicShots.Stage = table.freeze({
	name = "Stage",
	shots = table.freeze({
		shot({
			label = "VARANDA / RETORNO",
			from = v(-16, 7, 82),
			to = v(-12, 6, 78),
			lookFrom = v(0, 5, 64),
			lookTo = v(0, 5, 64),
			duration = 1.8,
			fov = 54,
			ease = "inOut",
			handheld = 0,
			cut = "hard",
		}),
		shot({
			label = "O MESMO ENDEREÇO",
			from = v(6, 5, 77),
			to = v(4, 5, 74),
			lookFrom = v(0, 5, 65),
			lookTo = v(0, 5, 65),
			duration = 1.7,
			fov = 52,
			ease = "inOut",
			handheld = 0.12,
			cut = "hard",
		}),
	}),
}) :: Sequence
CinematicShots.Escape = table.freeze({
	name = "Escape",
	title = "A ÚLTIMA FITA",
	subtitle = "FORA DA CASA",
	captions = table.freeze({
		"O coração parou. As paredes perderam a voz.",
		"Na televisão, a fita continua. Agora ela mostra a floresta.",
	}),
	shots = table.freeze({
		shot({
			label = "FLORESTA / FIM DA FITA",
			from = v(8, 6, 112),
			to = v(12, 8, 130),
			lookFrom = v(0, 8, 66),
			lookTo = v(0, 10, 64),
			duration = 6,
			fov = 56,
			ease = "inOut",
			handheld = 0.1,
			cut = "hard",
		}),
	}),
}) :: Sequence
CinematicShots.Attract = table.freeze({
	name = "Attract",
	shots = table.freeze({
		shot({
			label = "CANAL 03 / A CASA",
			from = v(-24, 12, 89),
			to = v(-24, 12, 89),
			lookFrom = v(0, 14, 64),
			lookTo = v(0, 10, 64),
			duration = 5,
			fov = 58,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CANAL 03 / VARANDA",
			from = v(12, 7, 82),
			to = v(12, 7, 82),
			lookFrom = v(3, 5, 66),
			lookTo = v(0, 5, 66),
			duration = 5,
			fov = 50,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CANAL 03 / PORTÃO",
			from = v(-18, 9, 119),
			to = v(-18, 9, 119),
			lookFrom = v(0, 6, 98),
			lookTo = v(0, 9, 64),
			duration = 5,
			fov = 60,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CANAL 03 / JANELAS",
			from = v(-35, 9, 83),
			to = v(-35, 9, 83),
			lookFrom = v(-10, 16, 64),
			lookTo = v(3, 5, 66),
			duration = 5,
			fov = 55,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
	}),
}) :: Sequence

-- Câmera de segurança: fixa e sem tremor (o controller dá cor de CFTV e 12 quadros/s).
function CinematicShots.isCctv(s: Shot): boolean
	return s.handheld <= 0
end

-- Progresso preso na grade de quadros do CFTV (fps), para a imagem andar "aos saltos".
function CinematicShots.quantize(alpha: number, duration: number, fps: number): number
	local frames = math.max(1, math.floor(duration * fps))
	return math.clamp(math.floor(math.clamp(alpha, 0, 1) * frames) / frames, 0, 1)
end

-- Tempo dentro da volta de uma sequência em laço.
function CinematicShots.wrap(sequence: Sequence, elapsed: number): number
	local total = 0
	for _, s in sequence.shots do
		total += s.duration
	end
	if total <= 0 then
		return 0
	end
	return math.max(0, elapsed) % total
end

-- Legenda da vez: as linhas se dividem igualmente pela duração (nil sem legendas).
function CinematicShots.caption(lines: { string }?, elapsed: number, total: number): string?
	if not lines or #lines == 0 or total <= 0 then
		return nil
	end
	local index = math.floor(math.clamp(elapsed / total, 0, 0.9999) * #lines) + 1
	return lines[index]
end

-- Curvas de suavização (t fora de 0..1 é limitado).
function CinematicShots.ease(kind: Ease, t: number): number
	local x = math.clamp(t, 0, 1)
	if kind == "inOut" then
		return x * x * (3 - 2 * x)
	elseif kind == "out" then
		return 1 - (1 - x) * (1 - x)
	elseif kind == "in" then
		return x * x
	end
	return x
end

function CinematicShots.lerp(a: Vec, b: Vec, t: number): Vec
	return { x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, z = a.z + (b.z - a.z) * t }
end

function CinematicShots.duration(sequence: Sequence): number
	local total = 0
	for _, s in sequence.shots do
		total += s.duration
	end
	return total
end

-- Qual plano está no ar em `elapsed` segundos: (índice, progresso 0..1 dentro dele, terminou?).
function CinematicShots.locate(sequence: Sequence, elapsed: number): (number, number, boolean)
	local shots = sequence.shots
	local start = 0
	for index, s in shots do
		if elapsed < start + s.duration then
			return index, math.max(0, elapsed - start) / s.duration, false
		end
		start += s.duration
	end
	return #shots, 1, true
end

-- Posição da câmera e ponto observado no progresso `alpha` (0..1) do plano.
function CinematicShots.sample(s: Shot, alpha: number): (Vec, Vec)
	local t = CinematicShots.ease(s.ease, alpha)
	return CinematicShots.lerp(s.from, s.to, t), CinematicShots.lerp(s.lookFrom, s.lookTo, t)
end

-- Relógio da fita (HH:MM:SS) a partir de segundos desde a meia-noite.
function CinematicShots.clock(seconds: number): string
	local total = math.max(0, math.floor(seconds)) % 86400
	return string.format("%02d:%02d:%02d", total // 3600, (total // 60) % 60, total % 60)
end

-- A fita começa às 03:12 (a queda de energia da história).
CinematicShots.TAPE_START = 3 * 3600 + 12 * 60

-- O final tem três planos próprios. Abertura e laço do menu usam as definições autorais acima.
CinematicShots.Escape = {
	name = "Escape",
	title = "A ÚLTIMA NOITE",
	subtitle = "THE CURSED HOUSE",
	shots = {
		shot({
			label = "A CASA DESTRUÍDA",
			from = v(-65, 65, 120),
			to = v(-55, 60, 112),
			lookFrom = v(0, 16, -10),
			lookTo = v(0, 12, -10),
			duration = 4,
			fov = 64,
			ease = "inOut",
			handheld = 0,
			cut = "blink",
		}),
		shot({
			label = "VOCÊS QUEIMARAM MINHA CASA...",
			from = v(12, 10, 90),
			to = v(9, 9, 85),
			lookFrom = v(0, 6, 58),
			lookTo = v(0, 6, 58),
			duration = 4,
			fov = 58,
			ease = "inOut",
			handheld = 0,
			cut = "hard",
		}),
		shot({
			label = "MAS NÃO ACABARAM COMIGO.",
			from = v(3, 7, 75),
			to = v(2, 6.5, 73),
			lookFrom = v(0, 5, 58),
			lookTo = v(0, 5, 58),
			duration = 4,
			fov = 50,
			ease = "inOut",
			handheld = 0,
			cut = "hard",
		}),
	},
}
CinematicShots.Escape.captions = {
	"As chamas engoliram a casa. Vocês alcançaram a floresta.",
	"VOCÊS QUEIMARAM MINHA CASA...",
	"MAS NÃO ACABARAM COMIGO.",
}
return table.freeze(CinematicShots)
