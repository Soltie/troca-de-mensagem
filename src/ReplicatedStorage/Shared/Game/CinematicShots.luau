--!strict
--[[
	Planos de câmera das cenas (abertura, início de etapa, fuga) e a matemática pura deles.

	As cenas mostram só o exterior (estrada, pátio, fachada): o interior muda a cada rodada
	(docs/MAP_RANDOMIZATION.md), mas o núcleo, o spawn e a saída são referências estáveis.
	Coordenadas em studs, as mesmas de Server/World/Layout: fachada em z = 0, portão em z = 44,
	spawn perto de (14, 0, 34), van em (26, 0, 26), guarita em (-28, 0, 37).

	Sem `game`/`task`/CFrame: o CinematicController converte Vec em CFrame.
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

-- Primeira entrada no servidor (lobby da campanha) e cartela da missão solo (~9 s).
-- No solo o controller troca as legendas pelo briefing (Text.Intro).
CinematicShots.Opening = table.freeze({
	name = "Opening",
	title = "SUBESTAÇÃO 9",
	subtitle = "03:12 · O ÚLTIMO TURNO",
	captions = table.freeze({
		"03:12. A Subestação 9 parou de responder.",
		"A equipe anterior entrou pelo portão e não voltou.",
		"O vigia da noite ainda está no turno.",
	}),
	shots = table.freeze({
		shot({
			label = "ESTRADA DE ACESSO",
			from = v(3, 5, 70),
			to = v(1.5, 4.6, 58),
			lookFrom = v(0, 4, 44),
			lookTo = v(0, 3.5, 30),
			duration = 3.2,
			fov = 60,
			ease = "inOut",
			handheld = 0.35,
			cut = "static",
		}),
		shot({
			label = "CÂMERA 2 · PÁTIO",
			from = v(-34, 13, 41),
			to = v(-34, 13, 41),
			lookFrom = v(18, 1, 26),
			lookTo = v(-2, 3, 4),
			duration = 3,
			fov = 62,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "RECEPÇÃO",
			from = v(-1, 4.6, 20),
			to = v(-3.4, 4.3, 8.5),
			lookFrom = v(-4, 4, 0),
			lookTo = v(-4, 3.8, -4),
			duration = 2.8,
			fov = 62,
			ease = "in",
			handheld = 0.5,
			cut = "static",
		}),
	}),
}) :: Sequence

-- Início de cada etapa da campanha: a equipe parada no pátio, vista pelas câmeras (~3,5 s).
CinematicShots.Stage = table.freeze({
	name = "Stage",
	shots = table.freeze({
		shot({
			label = "CÂMERA 3 · PÁTIO",
			from = v(34, 11, 40),
			to = v(34, 11, 40),
			lookFrom = v(15, 2.5, 36),
			lookTo = v(9, 3, 31),
			duration = 1.8,
			fov = 50,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CÂMERA 1 · FACHADA",
			from = v(14, 6, 26),
			to = v(6, 5, 14),
			lookFrom = v(-4, 4, 0),
			lookTo = v(-4, 3.5, -2),
			duration = 1.7,
			fov = 58,
			ease = "out",
			handheld = 0.25,
			cut = "static",
		}),
	}),
}) :: Sequence

-- Vitória: da estrada, olhando a equipe sair pelo portão (~5 s).
CinematicShots.Escape = table.freeze({
	name = "Escape",
	title = "FIM DO TURNO",
	subtitle = "GRAVAÇÃO RECUPERADA",
	captions = table.freeze({
		"O portão ficou para trás.",
		"Lá dentro, alguém continua cumprindo a ordem.",
	}),
	shots = table.freeze({
		shot({
			label = "ESTRADA · FIM DA GRAVAÇÃO",
			from = v(9, 6, 60),
			to = v(12, 10, 74),
			lookFrom = v(0, 3, 50),
			lookTo = v(0, 4, 42),
			duration = 5,
			fov = 58,
			ease = "out",
			handheld = 0.3,
			cut = "hard",
		}),
	}),
}) :: Sequence

-- Lobby: câmeras de segurança em laço atrás do menu de modo (~20 s por volta, sem tremor).
CinematicShots.Attract = table.freeze({
	name = "Attract",
	shots = table.freeze({
		shot({
			label = "CÂMERA 1 · PORTÃO",
			from = v(-6, 13, 68),
			to = v(-6, 13, 68),
			lookFrom = v(3, 1, 36),
			lookTo = v(6, 1, 28),
			duration = 5,
			fov = 62,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CÂMERA 2 · PÁTIO",
			from = v(-34, 13, 41),
			to = v(-34, 13, 41),
			lookFrom = v(16, 1, 24),
			lookTo = v(0, 2, 8),
			duration = 5,
			fov = 64,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CÂMERA 3 · VAN",
			from = v(40, 12, 22),
			to = v(40, 12, 22),
			lookFrom = v(14, 1, 30),
			lookTo = v(2, 2, 38),
			duration = 5,
			fov = 64,
			ease = "inOut",
			handheld = 0,
			cut = "static",
		}),
		shot({
			label = "CÂMERA 4 · RECEPÇÃO",
			from = v(6, 10, 24),
			to = v(6, 10, 24),
			lookFrom = v(-6, 3, 0),
			lookTo = v(-2, 2.5, -2),
			duration = 5,
			fov = 62,
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

local function houseScene(name: string, duration: number, labels: { string }): Sequence
	local list: { Shot } = {}
	for index, label in labels do
		table.insert(
			list,
			shot({
				label = label,
				from = v(-15 + index * 7, 8, 86 - index * 3),
				to = v(-13 + index * 7, 7, 83 - index * 3),
				lookFrom = v(0, 12, 0),
				lookTo = v(0, 10, 0),
				duration = duration / #labels,
				fov = 64,
				ease = "inOut",
				handheld = 0,
				cut = "blink",
			})
		)
	end
	return { name = name, title = "TUNG TUNG SAHUR", subtitle = "THE CURSED HOUSE", shots = list }
end
CinematicShots.Opening = houseScene("Opening", 9, { "CAMINHO DA FLORESTA", "A CASA", "NÃO ACORDE O DONO" })
CinematicShots.Opening.captions = {
	"A floresta terminou diante de uma casa esquecida.",
	"A porta se abriu sozinha.",
	"Lá dentro, alguém ouviu vocês chegarem.",
}
CinematicShots.Attract = houseScene("Attract", 12, { "THE CURSED HOUSE", "CINCO CAPÍTULOS", "UMA ÚLTIMA NOITE" })
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
