--!strict
--[[
	Túnel de minhoca do Tung Tung (docs/AVALIACAO_20-10-2026.md, opção A). Buracos ao pé das paredes externas da casa,
	ligados por dentro das paredes e por baixo do piso. Regras puras (testadas no Lune); o TunnelService executa.
	- Capítulos 2 e 3: só ele usa. A partir do 2, cinco buracos no térreo e no porão; no 3, mais três em cima.
	- Entrada: o buraco livre mais perto dele no mesmo andar (até ENTRY_RANGE).
	- Saída: o buraco livre mais perto de quem está mais perto, mas nunca colado em alguém (MIN_EXIT_GAP): ele sai
	  perto, não em cima. Avisos antes de sair (arranhado, poeira, olhos) ficam a cargo do serviço.
	- Buraco pregado (tábua) não serve de entrada nem de saída até `boardedUntil`.
]]

export type Hole = { id: string, x: number, y: number, z: number, nx: number, from: number }
export type Point = { x: number, y: number, z: number }

local WormTunnel = {}

WormTunnel.ENTRY_RANGE = 28
WormTunnel.MIN_EXIT_GAP = 12
WormTunnel.BOARD_SECONDS = 90
WormTunnel.WARN_SECONDS = 2.6

-- x na face de dentro da parede externa; nx aponta para dentro do cômodo.
WormTunnel.Holes = table.freeze({
	{ id = "Living", x = -43.5, y = 0, z = 2, nx = 1, from = 2 },
	{ id = "Kitchen", x = 43.5, y = 0, z = 2, nx = -1, from = 2 },
	{ id = "Dining", x = -43.5, y = 0, z = -30, nx = 1, from = 2 },
	{ id = "Bath", x = 43.5, y = 0, z = -30, nx = -1, from = 2 },
	{ id = "Basement", x = -43.5, y = -16, z = 2, nx = 1, from = 2 },
	{ id = "Office", x = -43.5, y = 16, z = -30, nx = 1, from = 3 },
	{ id = "Locked", x = 43.5, y = 16, z = -30, nx = -1, from = 3 },
	{ id = "Symbols", x = 43.5, y = -16, z = 2, nx = -1, from = 3 },
} :: { Hole })

-- Buracos que existem no capítulo (só na casa: 2 a 5).
function WormTunnel.holes(stage: number): { Hole }
	local out = {}
	if stage < 2 or stage > 5 then
		return out
	end
	for _, hole in WormTunnel.Holes do
		if stage >= hole.from then
			table.insert(out, hole)
		end
	end
	return out
end

-- Ponto do piso logo à frente do buraco (onde ele some e de onde sai).
function WormTunnel.mouth(hole: Hole, depth: number?): Point
	return { x = hole.x + hole.nx * (depth or 3), y = hole.y, z = hole.z }
end

local function distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

local function open(hole: Hole, boarded: { [string]: number }, now: number): boolean
	return (boarded[hole.id] or 0) <= now
end

function WormTunnel.entry(holes: { Hole }, tung: Point, boarded: { [string]: number }, now: number): Hole?
	local best, bestDistance = nil, WormTunnel.ENTRY_RANGE
	for _, hole in holes do
		local mouth = WormTunnel.mouth(hole)
		local d = distance(mouth, tung)
		if open(hole, boarded, now) and math.abs(hole.y - tung.y) < 6 and d < bestDistance then
			best, bestDistance = hole, d
		end
	end
	return best
end

function WormTunnel.exit(
	holes: { Hole },
	entry: Hole,
	players: { Point },
	boarded: { [string]: number },
	now: number
): Hole?
	if #players == 0 then
		return nil
	end
	local best, bestScore = nil, math.huge
	for _, hole in holes do
		if hole.id == entry.id or not open(hole, boarded, now) then
			continue
		end
		local mouth = WormTunnel.mouth(hole)
		local nearest = math.huge
		for _, p in players do
			nearest = math.min(nearest, distance(mouth, p))
		end
		if nearest >= WormTunnel.MIN_EXIT_GAP and nearest < bestScore then
			best, bestScore = hole, nearest
		end
	end
	return best
end

-- Tempo dentro do túnel: mais longe, mais demora (dá tempo dos avisos e de fugir).
function WormTunnel.travelSeconds(a: Hole, b: Hole): number
	return math.clamp(distance(a, b) / 14, 4, 8)
end

return table.freeze(WormTunnel)
