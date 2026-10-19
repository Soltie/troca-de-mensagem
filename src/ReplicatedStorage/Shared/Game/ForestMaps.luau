--!strict
--[[
	Floresta v2 (docs/FLORESTA_V2.md): um mapa diferente por capítulo, em dados puros (testados no Lune). Todos entram
	pelo sul (0, 580) e saem pelo norte (0, 870); tarefas ficam em |x| < 70 e 600 <= z < 880.
	- trail: pontos da trilha sinuosa (x, z), de largura `TrailWidth`;
	- rooms: lugares das tarefas; hides: abrigos (6 por capítulo);
	- ravine (só no 6): faixa z0..z1 de leste a oeste, atravessada pela ponte em x = 0.
	Capítulos sem mapa novo ainda (7 e 8) devolvem nil e usam o mapa antigo.
]]

export type Point = { x: number, z: number }
export type Room = { id: string, title: string, x: number, y: number, z: number }
export type Map = {
	chapter: number,
	biome: string,
	trail: { Point },
	rooms: { Room },
	hides: { { x: number, y: number, z: number } },
	ravine: { z0: number, z1: number, depth: number, bridgeWidth: number }?,
	camp: Point?,
}

local ForestMaps = {}

ForestMaps.TrailWidth = 14

local MIST: Map = {
	chapter = 6,
	biome = "mist",
	trail = {
		{ x = 0, z = 560 },
		{ x = 0, z = 600 },
		{ x = -26, z = 640 },
		{ x = -42, z = 688 },
		{ x = -22, z = 728 },
		{ x = 0, z = 748 },
		{ x = 0, z = 800 },
		{ x = 26, z = 826 },
		{ x = 0, z = 862 },
		{ x = 0, z = 890 },
	},
	rooms = {
		{ id = "MistTrail", title = "TRILHA DA NEBLINA", x = -14, y = 0, z = 616 },
		{ id = "MistCamp", title = "ACAMPAMENTO ABANDONADO", x = -48, y = 0, z = 694 },
		{ id = "RavineEdge", title = "BEIRA DA RAVINA", x = -8, y = 0, z = 740 },
		{ id = "NorthBank", title = "OUTRO LADO DA PONTE", x = 14, y = 0, z = 812 },
		{ id = "MistRoad", title = "ESTRADA VELHA", x = 0, y = 0, z = 852 },
	},
	hides = {
		{ x = 18, y = 0, z = 618 },
		{ x = -60, y = 0, z = 660 },
		{ x = -26, y = 0, z = 706 },
		{ x = 22, y = 0, z = 736 },
		{ x = -16, y = 0, z = 818 },
		{ x = 24, y = 0, z = 852 },
	},
	ravine = { z0 = 754, z1 = 794, depth = 30, bridgeWidth = 8 },
	camp = { x = -56, z = 696 },
}

local MAPS: { [number]: Map } = { [6] = MIST }

function ForestMaps.get(chapter: number): Map?
	return MAPS[chapter]
end

-- Todos os lugares de todos os mapas novos (ids únicos), para o catálogo e o guia.
function ForestMaps.allRooms(): { Room }
	local out = {}
	for _, map in MAPS do
		for _, room in map.rooms do
			table.insert(out, room)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

-- Distância (no chão) de (x, z) até a trilha.
function ForestMaps.trailDistance(map: Map, x: number, z: number): number
	local best = math.huge
	for i = 2, #map.trail do
		local a, b = map.trail[i - 1], map.trail[i]
		local dx, dz = b.x - a.x, b.z - a.z
		local length2 = dx * dx + dz * dz
		local k = if length2 > 0 then math.clamp(((x - a.x) * dx + (z - a.z) * dz) / length2, 0, 1) else 0
		local px, pz = a.x + dx * k, a.z + dz * k
		best = math.min(best, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))
	end
	return best
end

-- Dentro da ravina (o buraco), fora da ponte?
function ForestMaps.inRavine(map: Map, x: number, z: number): boolean
	local r = map.ravine
	return r ~= nil and z > r.z0 and z < r.z1 and math.abs(x) > r.bridgeWidth / 2
end

-- Lugar livre para árvore: longe da trilha, dos lugares, dos abrigos, do acampamento e fora da ravina (com folga).
function ForestMaps.treeAllowed(map: Map, x: number, z: number): boolean
	if ForestMaps.trailDistance(map, x, z) < ForestMaps.TrailWidth / 2 + 4 then
		return false
	end
	local r = map.ravine
	if r and z > r.z0 - 6 and z < r.z1 + 6 then
		return false
	end
	for _, room in map.rooms do
		if (x - room.x) ^ 2 + (z - room.z) ^ 2 < 15 * 15 then
			return false
		end
	end
	for _, hide in map.hides do
		if (x - hide.x) ^ 2 + (z - hide.z) ^ 2 < 10 * 10 then
			return false
		end
	end
	local camp = map.camp
	if camp and (x - camp.x) ^ 2 + (z - camp.z) ^ 2 < 24 * 24 then
		return false
	end
	return true
end

return table.freeze(ForestMaps)
