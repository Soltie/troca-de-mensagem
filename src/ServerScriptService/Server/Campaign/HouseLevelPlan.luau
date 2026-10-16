--!strict
-- Sorteio privado: a História preserva o percurso; o Desafio visita a propriedade inteira.
local Random = require("./SeededRandom")
export type Spot = { room: string, x: number, y: number, z: number }
export type Passage = { x: number, y: number, z: number, width: number }
export type Level = {
	outdoor: boolean,
	theme: string,
	spots: { Spot },
	passages: { Passage },
	stairSide: number,
	serviceStair: boolean,
}
local Levels = {}

function Levels.create(seed: number, chapter: number, mode: string): Level
	local rng = Random.new(seed + chapter * 104729)
	local outdoor = mode == "Standard" and (chapter == 3 or (chapter == 4 and rng.integer(0, 1) == 1))
	local stairSide = if rng.integer(0, 1) == 0 then -1 else 1
	local spots: { Spot } = {
		{ room = "JARDIM DE INVERNO", x = -76, y = 0, z = 24 },
		{ room = "PAVILHÃO DAS MEMÓRIAS", x = -76, y = 0, z = -44 },
		{ room = "ESTUFA", x = 76, y = 0, z = 24 },
		{ room = "OFICINA DO JARDINEIRO", x = 76, y = 0, z = -44 },
		{ room = "PÁTIO DO RELÓGIO", x = -22, y = 0, z = -101 },
		{ room = "FONTE SELADA", x = 22, y = 0, z = -101 },
	}
	local passages: { Passage } = {}
	spots[2] = { room = "MIRANTE DO JARDIM", x = stairSide * 94, y = 8, z = 36 }
	if mode == "Standard" then
		for _, y in { -16, 0, 16, 32 } do
			for _, side in { -1, 1 } do
				-- Salas unidas viram salões; outras recebem portas de serviço de dez studs.
				for _, z in { -20, -52 } do
					local roll = rng.integer(1, 4)
					local stairAccess = chapter >= 3 and y >= 16 and side == stairSide and z == -52
					if roll == 1 and not stairAccess then
						continue
					end
					table.insert(passages, { x = side * 26, y = y, z = z, width = if roll == 2 then 24 else 10 })
				end
			end
		end
	end
	return {
		outdoor = outdoor,
		theme = if outdoor
			then ({ "O JARDIM DAS LEMBRANÇAS", "OS SEGREDOS DA ESTUFA", "O PÁTIO ESQUECIDO" })[rng.integer(1, 3)]
			else "A CASA POR DENTRO",
		spots = if outdoor then rng.shuffle(spots) else {},
		passages = passages,
		stairSide = stairSide,
		serviceStair = mode == "Standard" and chapter >= 3,
	}
end

function Levels.relocate(level: Level, index: number): Spot?
	return if level.outdoor then level.spots[index] else nil
end

return Levels
