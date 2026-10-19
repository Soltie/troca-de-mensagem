--!strict
--[[
	Incêndio da fuga final (capítulo 5). Regras puras: a partir de uma semente monta os focos de fogo e o segundo
	(desde o início da fuga) em que cada um acende. O servidor usa para o calor que derruba; o cliente monta a mesma
	lista com a mesma semente para desenhar chamas, fumaça, luz e som.

	- Frente: nasce no mecanismo do porão e corre pelo caminho de fuga atrás de quem foge (FrontSpeed studs/s depois
	  de HeadStart s). O meio do caminho pega fogo: quem fica para trás queima.
	- Laterais: chamas rente às paredes do caminho, acendendo um pouco antes da frente chegar.
	- Cômodos e hall: tudo vai pegando fogo pela distância até o mecanismo; o hall arde quando você chega nele.
	- Fachada: a frente da casa e o telhado ardem quando você sai (sem calor, só de fora).
]]

local HouseCatalog = require("./HouseCatalog")

local FireSpread = {}

export type Kind = "front" | "side" | "room" | "hall" | "facade" | "gas"
export type Node = {
	x: number,
	y: number,
	z: number,
	at: number,
	radius: number,
	size: number,
	kind: Kind,
}

FireSpread.HeadStart = 7
FireSpread.FrontSpeed = 10.5
FireSpread.SideLead = 4
FireSpread.HallLead = 6
FireSpread.RoomSpeed = 6
FireSpread.Step = 6
FireSpread.GrowSeconds = 1.5
-- Gasolina: o primeiro foco (o que o isqueiro acendeu) estoura em GasStart s; os outros a cada GasStep s.
FireSpread.GasStart = 2.5
FireSpread.GasStep = 1.6
-- Calor por segundo dentro do fogo (1 = derruba) e quanto esfria por segundo fora dele.
FireSpread.HeatRate = 0.65
FireSpread.CoolRate = 0.5

-- Caminho de fuga: mecanismo -> corredor do porão -> escada do porão -> hall -> porta da frente.
FireSpread.Route = {
	{ 26, -16, -68 },
	{ 0, -16, -68 },
	{ 0, -16, 12 },
	{ -16, -16, 20 },
	{ -16, 0, 56 },
	{ 0, 0, 58 },
	{ 0, 0, 63 },
} :: { { number } }

-- Cantos do hall (térreo e andares de cima) e as escadas pegando fogo.
local HALL = {
	{ -20, 0, 18 },
	{ -20, 0, 40 },
	{ 6, 0, 30 },
	{ 30, 0, 18 },
	{ 40, 0, 40 },
	{ 30, 0, 60 },
	{ -20, 0, 60 },
	{ 16, 6, 34 },
	{ 16, 12, 48 },
	{ -20, 16, 30 },
	{ 40, 16, 58 },
	{ 32, 22, 40 },
} :: { { number } }

local function routeLength(): number
	local total = 0
	for i = 2, #FireSpread.Route do
		local a, b = FireSpread.Route[i - 1], FireSpread.Route[i]
		total += math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2 + (b[3] - a[3]) ^ 2)
	end
	return total
end

-- Hora em que a frente passa a `s` studs do mecanismo.
function FireSpread.frontTime(s: number): number
	return FireSpread.HeadStart + s / FireSpread.FrontSpeed
end

-- Distância ao longo do caminho do ponto da rota mais próximo de (x, y, z).
local function nearestRouteDistance(x: number, y: number, z: number): number
	local best, bestS, walked = math.huge, 0, 0
	for i = 2, #FireSpread.Route do
		local a, b = FireSpread.Route[i - 1], FireSpread.Route[i]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		local k = math.clamp(((x - a[1]) * dx + (y - a[2]) * dy + (z - a[3]) * dz) / (length * length), 0, 1)
		local px, py, pz = a[1] + dx * k, a[2] + dy * k, a[3] + dz * k
		local d = (x - px) ^ 2 + (y - py) ^ 2 * 4 + (z - pz) ^ 2
		if d < best then
			best, bestS = d, walked + length * k
		end
		walked += length
	end
	return bestS
end

-- Gerador próprio (o cliente não alcança o SeededRandom do servidor e o Lune não tem Random).
local function generator(seed: number): (number, number) -> number
	local state = math.floor(math.abs(seed)) % 2147483647
	if state == 0 then
		state = 1
	end
	return function(lo: number, hi: number): number
		state = (state * 48271) % 2147483647
		return lo + (hi - lo) * (state / 2147483647)
	end
end

function FireSpread.build(seed: number, fuel: { { number } }?): { Node }
	local rng = generator(seed)
	local nodes: { Node } = {}
	local origin = FireSpread.Route[1]

	-- Frente e laterais ao longo do caminho.
	local side = 1
	local walked = 0
	for i = 2, #FireSpread.Route do
		local a, b = FireSpread.Route[i - 1], FireSpread.Route[i]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		local flat = math.max(math.sqrt(dx * dx + dz * dz), 1e-3)
		local px, pz = -dz / flat, dx / flat
		local steps = math.max(1, math.floor(length / FireSpread.Step))
		for step = 0, steps - 1 do
			local k = step / steps
			local x, y, z = a[1] + dx * k, a[2] + dy * k, a[3] + dz * k
			local s = walked + length * k
			local at = FireSpread.frontTime(s)
			table.insert(nodes, { x = x, y = y, z = z, at = at, radius = 3.4, size = 7, kind = "front" })
			table.insert(nodes, {
				x = x + px * 3 * side,
				y = y,
				z = z + pz * 3 * side,
				at = math.max(FireSpread.HeadStart * 0.5, at - FireSpread.SideLead),
				radius = 1.4,
				size = 5,
				kind = "side",
			})
			side = -side
		end
		walked += length
	end

	-- Gasolina espalhada pelos jogadores: estoura logo depois de acender, em sequência pelo rastro (do mais perto do
	-- isqueiro para o mais longe). A casa já está em chamas à frente de quem foge.
	if fuel then
		local order = table.clone(fuel)
		table.sort(order, function(a, b)
			local da = (a[1] - origin[1]) ^ 2 + (a[2] - origin[2]) ^ 2 + (a[3] - origin[3]) ^ 2
			local db = (b[1] - origin[1]) ^ 2 + (b[2] - origin[2]) ^ 2 + (b[3] - origin[3]) ^ 2
			return da < db
		end)
		for index, spot in order do
			table.insert(nodes, {
				x = spot[1],
				y = spot[2],
				z = spot[3],
				at = FireSpread.GasStart + (index - 1) * FireSpread.GasStep,
				radius = 3,
				size = 11,
				kind = "gas",
			})
		end
	end

	-- Hall: arde quando a frente vai chegando (dá tempo de passar, mas assusta).
	for _, spot in HALL do
		local s = nearestRouteDistance(spot[1], spot[2], spot[3])
		table.insert(nodes, {
			x = spot[1],
			y = spot[2],
			z = spot[3],
			at = math.max(FireSpread.HeadStart, FireSpread.frontTime(s) - FireSpread.HallLead + rng(-2, 2)),
			radius = 2.6,
			size = 9,
			kind = "hall",
		})
	end

	-- Cômodos: três focos cada, pela distância até o mecanismo.
	for _, room in HouseCatalog.Rooms do
		if room.id == "Exterior" then
			continue
		end
		local distance = math.sqrt((room.x - origin[1]) ^ 2 + (room.y - origin[2]) ^ 2 + (room.z - origin[3]) ^ 2)
		for _ = 1, 3 do
			table.insert(nodes, {
				x = room.x + rng(-7, 7),
				y = room.y,
				z = room.z + rng(-7, 7),
				at = FireSpread.HeadStart + distance / FireSpread.RoomSpeed + rng(0, 6),
				radius = 2.6,
				size = 8,
				kind = "room",
			})
		end
	end

	-- Fachada e telhado: a casa inteira em chamas vista do quintal.
	local exit = FireSpread.frontTime(routeLength())
	for _ = 1, 16 do
		table.insert(nodes, {
			x = rng(-22, 43),
			y = rng(2, 30),
			z = 64.6,
			at = exit - 10 + rng(0, 30),
			radius = 0,
			size = 14,
			kind = "facade",
		})
	end
	return nodes
end

-- Poças de gasolina viajam como texto num atributo do mundo ("x,y,z;x,y,z").
function FireSpread.encodeFuel(spots: { { number } }): string
	local parts = {}
	for _, spot in spots do
		table.insert(parts, string.format("%.1f,%.1f,%.1f", spot[1], spot[2], spot[3]))
	end
	return table.concat(parts, ";")
end

function FireSpread.decodeFuel(text: any): { { number } }?
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local spots = {}
	for entry in string.gmatch(text, "[^;]+") do
		local x, y, z = string.match(entry, "^(-?[%d%.]+),(-?[%d%.]+),(-?[%d%.]+)$")
		if x and y and z then
			table.insert(spots, { tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number })
		end
	end
	return if #spots > 0 then spots else nil
end

-- 0..1: quanto o foco já cresceu no instante t.
function FireSpread.intensity(node: Node, t: number): number
	return math.clamp((t - node.at) / FireSpread.GrowSeconds, 0, 1)
end

-- 0..1: o quanto (x, y, z) está dentro de algum foco aceso.
function FireSpread.exposure(nodes: { Node }, t: number, x: number, y: number, z: number): number
	local best = 0
	for _, node in nodes do
		if node.radius <= 0 or t < node.at or math.abs(y - node.y) > 6 then
			continue
		end
		local d = math.sqrt((x - node.x) ^ 2 + (z - node.z) ^ 2)
		if d < node.radius then
			best = math.max(best, (1 - d / node.radius) * FireSpread.intensity(node, t))
		end
	end
	return best
end

-- Novo calor acumulado depois de dt segundos com esta exposição.
function FireSpread.heat(current: number, exposure: number, dt: number): number
	if exposure > 0.05 then
		return math.clamp(current + (0.35 + exposure) * FireSpread.HeatRate * dt, 0, 1)
	end
	return math.clamp(current - FireSpread.CoolRate * dt, 0, 1)
end

return table.freeze(FireSpread)
