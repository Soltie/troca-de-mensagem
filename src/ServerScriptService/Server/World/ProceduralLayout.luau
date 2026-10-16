--!strict
-- Planta pura da ala norte: Kruskal sorteado garante circulação e atalhos criam circuitos.
local Random = require("../Campaign/SeededRandom")

export type Room = { cell: number, kind: string, x: number, z: number, turn: number }
export type Link = { a: number, b: number }
export type Plan = { seed: number, stage: number, rooms: { Room }, links: { Link } }

local Layout = {}
Layout.Columns = 3
Layout.Rows = 3
Layout.CellSize = 28
Layout.Bounds = table.freeze({ x0 = -48, x1 = 36, z0 = -162, z1 = -78 })
Layout.Entrances = table.freeze({ 2, 3 }) -- linha sul: controle e arquivo
Layout.DoorWidth = 10
Layout.SurfaceBudget = 16
Layout.Kinds = table.freeze({
	"RelayHall",
	"Cooling",
	"BatteryBank",
	"Radio",
	"MachineShop",
	"Inspection",
	"CableDepot",
	"Turbine",
	"WaterTreatment",
})

function Layout.center(cell: number): (number, number)
	local column = (cell - 1) % Layout.Columns
	local row = math.floor((cell - 1) / Layout.Columns)
	return Layout.Bounds.x0 + (column + 0.5) * Layout.CellSize, Layout.Bounds.z1 - (row + 0.5) * Layout.CellSize
end

function Layout.edges(): { Link }
	local edges: { Link } = {}
	for cell = 1, Layout.Columns * Layout.Rows do
		if cell % Layout.Columns ~= 0 then
			table.insert(edges, { a = cell, b = cell + 1 })
		end
		if cell <= Layout.Columns * (Layout.Rows - 1) then
			table.insert(edges, { a = cell, b = cell + Layout.Columns })
		end
	end
	return edges
end

function Layout.create(seed: number, stage: number): Plan
	assert(stage % 1 == 0 and stage >= 1 and stage <= 3, "Invalid map stage")
	local rng = Random.new(seed + stage * 104729)
	local kinds = rng.shuffle(Layout.Kinds)
	local rooms: { Room } = {}
	for cell, kind in kinds do
		local x, z = Layout.center(cell)
		table.insert(rooms, { cell = cell, kind = kind, x = x, z = z, turn = rng.integer(0, 3) })
	end
	local parents: { number } = {}
	for cell = 1, #rooms do
		parents[cell] = cell
	end
	local function root(cell: number): number
		while parents[cell] ~= cell do
			cell = parents[cell]
		end
		return cell
	end
	local links: { Link } = {}
	local spare: { Link } = {}
	for _, edge in rng.shuffle(Layout.edges()) do
		local a, b = root(edge.a), root(edge.b)
		if a ~= b then
			parents[b] = a
			table.insert(links, edge)
		else
			table.insert(spare, edge)
		end
	end
	-- Uma a três conexões adicionais: nunca gera um labirinto de becos sem alternativa.
	for index = 1, rng.integer(1, 3) do
		table.insert(links, spare[index])
	end
	table.sort(links, function(a, b)
		return a.a < b.a or (a.a == b.a and a.b < b.b)
	end)
	return { seed = seed, stage = stage, rooms = rooms, links = links }
end

function Layout.connected(plan: Plan, a: number, b: number): boolean
	for _, link in plan.links do
		if (link.a == a and link.b == b) or (link.b == a and link.a == b) then
			return true
		end
	end
	return false
end

function Layout.validate(plan: Plan): (boolean, string?)
	if #plan.rooms ~= #Layout.Kinds or #plan.links < 9 or #plan.links > 11 then
		return false, "invalid_map_size"
	end
	local seen: { [string]: boolean } = {}
	for cell, room in plan.rooms do
		local x, z = Layout.center(cell)
		if room.cell ~= cell or room.x ~= x or room.z ~= z then
			return false, "invalid_cell"
		end
		if not table.find(Layout.Kinds, room.kind) or seen[room.kind] then
			return false, "invalid_room_kind"
		end
		if room.turn % 1 ~= 0 or room.turn < 0 or room.turn > 3 then
			return false, "invalid_dressing"
		end
		seen[room.kind] = true
	end
	local allowed: { [string]: boolean } = {}
	for _, edge in Layout.edges() do
		allowed[`{edge.a}:{edge.b}`] = true
	end
	table.clear(seen)
	for _, link in plan.links do
		local key = `{link.a}:{link.b}`
		if not allowed[key] or seen[key] then
			return false, "invalid_map_link"
		end
		seen[key] = true
	end
	local reached: { [number]: boolean } = { [Layout.Entrances[1]] = true }
	local changed = true
	while changed do
		changed = false
		for _, link in plan.links do
			if reached[link.a] ~= reached[link.b] and (reached[link.a] or reached[link.b]) then
				reached[link.a], reached[link.b], changed = true, true, true
			end
		end
	end
	for cell = 1, #plan.rooms do
		if not reached[cell] then
			return false, "unreachable_map_room"
		end
	end
	return true, nil
end

function Layout.slots(plan: Plan): { { id: string, room: string, x: number, z: number } }
	local slots = {}
	for _, room in plan.rooms do
		-- Quadrante sudeste reservado ao terminal e à dupla do relé; nunca recebe props.
		table.insert(slots, { id = `sector_{room.cell}`, room = room.kind, x = room.x + 7, z = room.z + 7 })
	end
	return slots
end

-- Próxima sala em direção à entrada mais próxima; 0 significa saída para o núcleo antigo.
function Layout.returnRoutes(plan: Plan): { [number]: number }
	local routes: { [number]: number } = {}
	local queue = table.clone(Layout.Entrances)
	for _, cell in queue do
		routes[cell] = 0
	end
	local cursor = 1
	while cursor <= #queue do
		local cell = queue[cursor]
		cursor += 1
		for _, edge in plan.links do
			local other = if edge.a == cell then edge.b elseif edge.b == cell then edge.a else nil
			if other and routes[other] == nil then
				routes[other] = cell
				table.insert(queue, other)
			end
		end
	end
	return routes
end

return Layout
