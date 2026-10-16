--!strict
-- Pavilhões separados por galerias; pátios e anel externo fazem parte da circulação real.
local Random = require("../Campaign/SeededRandom")

export type Room = { cell: number, kind: string, x: number, z: number, turn: number }
export type Link = { a: number, b: number }
export type Plan = { seed: number, stage: number, rooms: { Room }, links: { Link } }
export type Passage = { id: string, x0: number, x1: number, z0: number, z1: number, covered: boolean }

local Layout = {}
Layout.Columns = 3
Layout.Rows = 3
Layout.CellSize = 44
Layout.RoomSize = 28
Layout.Bounds = table.freeze({ x0 = -96, x1 = 72, z0 = -232, z1 = -78 })
Layout.Entrances = table.freeze({ 2, 3 }) -- linha sul: controle e arquivo
Layout.DoorWidth = 10
Layout.SurfaceBudget = 16
Layout.ExteriorZones = table.freeze({
	{ id = "ServiceYard", x0 = -96, x1 = -64, z0 = -232, z1 = -78, covered = false },
	{ id = "LoadingYard", x0 = -64, x1 = 72, z0 = -232, z1 = -212, covered = false },
	{ id = "UtilityWalk", x0 = 52, x1 = 72, z0 = -212, z1 = -78, covered = false },
})
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
	return -50 + column * Layout.CellSize, -110 - row * Layout.CellSize
end

-- Os vãos antigos continuam no controle e no arquivo; a galeria distribui o acesso aos pavilhões.
function Layout.entranceX(cell: number): number
	assert(table.find(Layout.Entrances, cell), "Invalid sector entrance")
	return if cell == 2 then -6 else 22
end

function Layout.isOutdoorRoom(room: Room): boolean
	return room.kind == "Cooling" or room.kind == "WaterTreatment"
end

function Layout.passages(plan: Plan): { Passage }
	local passages: { Passage } = {
		{ id = "AccessGallery", x0 = -64, x1 = 52, z0 = -96, z1 = -78, covered = true },
	}
	local half, width = Layout.RoomSize / 2, Layout.DoorWidth / 2
	for _, link in plan.links do
		local a, b = plan.rooms[link.a], plan.rooms[link.b]
		local horizontal = a.z == b.z
		table.insert(passages, {
			id = `Passage_{link.a}_{link.b}`,
			x0 = if horizontal then math.min(a.x, b.x) + half else a.x - width,
			x1 = if horizontal then math.max(a.x, b.x) - half else a.x + width,
			z0 = if horizontal then a.z - width else math.min(a.z, b.z) + half,
			z1 = if horizontal then a.z + width else math.max(a.z, b.z) - half,
			covered = not Layout.isOutdoorRoom(a) and not Layout.isOutdoorRoom(b),
		})
	end
	return passages
end

function Layout.isIndoor(plan: Plan, x: number, z: number): boolean
	local half = Layout.RoomSize / 2
	for _, room in plan.rooms do
		if math.abs(x - room.x) <= half and math.abs(z - room.z) <= half then
			return not Layout.isOutdoorRoom(room)
		end
	end
	for _, passage in Layout.passages(plan) do
		if passage.covered and x >= passage.x0 and x <= passage.x1 and z >= passage.z0 and z <= passage.z1 then
			return true
		end
	end
	return false
end

function Layout.patrolPoints(plan: Plan): { { x: number, y: number, z: number } }
	local points = {}
	for _, room in plan.rooms do
		table.insert(points, { x = room.x, y = 0, z = room.z })
	end
	for _, passage in Layout.passages(plan) do
		table.insert(points, { x = (passage.x0 + passage.x1) / 2, y = 0, z = (passage.z0 + passage.z1) / 2 })
	end
	for _, z in { -110, -154, -198 } do
		table.insert(points, { x = -82, y = 0, z = z })
		table.insert(points, { x = 62, y = 0, z = z })
	end
	for _, x in { -82, -50, -6, 38, 62 } do
		table.insert(points, { x = x, y = 0, z = -222 })
	end
	return points
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
