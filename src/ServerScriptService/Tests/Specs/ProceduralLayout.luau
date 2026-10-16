--!strict
local Layout = require("@game/ServerScriptService/Server/World/ProceduralLayout")
local Base = require("@game/ServerScriptService/Server/World/Layout")
local Generator = require("@game/ServerScriptService/Server/Campaign/CampaignGenerator")
local TestKit = require("../TestKit")

local function signature(plan: Layout.Plan, geometryOnly: boolean?): string
	local parts = {}
	if not geometryOnly then
		for _, room in plan.rooms do
			table.insert(parts, `{room.kind}:{room.turn}`)
		end
	end
	for _, edge in plan.links do
		table.insert(parts, `{edge.a}-{edge.b}`)
	end
	return table.concat(parts, "/")
end

local spec: TestKit.Spec = {
	name = "ProceduralLayout",
	run = function(t)
		t.it("reproduces geometry, room functions and equipment placement from seed and stage", function()
			t.expect(Layout.create(9182, 2)).toEqual(Layout.create(9182, 2))
		end)
		t.it("keeps 1500 layouts connected with a bounded size and at least one internal loop", function()
			for seed = 1, 500 do
				for stage = 1, 3 do
					local plan = Layout.create(seed, stage)
					local valid, reason = Layout.validate(plan)
					assert(valid, `seed={seed} stage={stage}: {reason}`)
					t.expect(#plan.rooms).toBe(9)
					t.expect(#plan.links >= #plan.rooms).toBe(true)
					for _, room in plan.rooms do
						t.expect(room.x - 14 >= Layout.Bounds.x0 and room.x + 14 <= Layout.Bounds.x1).toBe(true)
						t.expect(room.z - 14 >= Layout.Bounds.z0 and room.z + 14 <= Layout.Bounds.z1).toBe(true)
					end
					local routes = Layout.returnRoutes(plan)
					for _, room in plan.rooms do
						local cell, steps = room.cell, 0
						while cell ~= 0 do
							steps += 1
							assert(steps <= 9 and routes[cell] ~= nil, "Missing or looping return signage")
							local nextCell = routes[cell]
							assert(
								nextCell == 0 or Layout.connected(plan, cell, nextCell),
								"Return sign points through wall"
							)
							cell = nextCell
						end
					end
				end
			end
		end)
		t.it("varies actual door geometry as well as room functions across seeds and stages", function()
			local shapes: { [string]: boolean } = {}
			local maps: { [string]: boolean } = {}
			for seed = 1, 128 do
				local first = Layout.create(seed, 1)
				shapes[signature(first, true)] = true
				maps[signature(first)] = true
				t.expect(signature(first) ~= signature(Layout.create(seed, 2))).toBe(true)
				t.expect(signature(first) ~= signature(Layout.create(seed + 1, 1))).toBe(true)
			end
			local count = 0
			for _ in shapes do
				count += 1
			end
			t.expect(count >= 48).toBe(true)
			count = 0
			for _ in maps do
				count += 1
			end
			t.expect(count).toBe(128)
		end)
		t.it("aligns both entrances with the physical north wall and the existing rooms", function()
			local wall = Base.wallById("annexNorth")
			assert(wall, "North wall missing")
			for _, cell in Layout.Entrances do
				local x = Layout.center(cell)
				local found = false
				for _, opening in wall.openings do
					if opening.center == x and opening.width >= Layout.DoorWidth then
						found = true
					end
				end
				t.expect(found).toBe(true)
				local room = Base.roomAt(x, Layout.Bounds.z1 + 2)
				t.expect(room ~= nil and (room.id == "Control" or room.id == "Archive")).toBe(true)
			end
		end)
		t.it("rejects disconnected, duplicated or non-adjacent routes and invalid rooms", function()
			local plan = Layout.create(8, 1)
			plan.links[1] = { a = 1, b = 9 }
			t.expect((Layout.validate(plan))).toBe(false)
			plan = Layout.create(8, 1)
			plan.links[1] = plan.links[2]
			t.expect((Layout.validate(plan))).toBe(false)
			plan = Layout.create(8, 1)
			plan.rooms[1].kind = plan.rooms[2].kind
			t.expect((Layout.validate(plan))).toBe(false)
			plan = Layout.create(8, 1)
			plan.rooms[1].x += 2
			t.expect((Layout.validate(plan))).toBe(false)
			plan = Layout.create(8, 1)
			plan.rooms[1].turn = 0.5
			t.expect((Layout.validate(plan))).toBe(false)
			plan = Layout.create(8, 1)
			-- Isolar a célula 1 ainda deixa nove arestas: o tamanho sozinho não prova conectividade.
			plan.links = {}
			for _, edge in Layout.edges() do
				if edge.a ~= 1 and edge.b ~= 1 then
					table.insert(plan.links, edge)
				end
			end
			t.expect((Layout.validate(plan))).toBe(false)
		end)
		t.it("places a majority of campaign tasks in generated rooms and validates their actual coordinates", function()
			for players = 3, 8 do
				for stage = 1, 3 do
					local plan = Generator.create(9182, stage, players)
					local count = 0
					for _, activity in plan.activities do
						if activity.slot:sub(1, 7) == "sector_" then
							count += 1
						end
					end
					t.expect(count > #plan.activities / 2).toBe(true)
					t.expect((Generator.validate(plan))).toBe(true)
				end
			end
			local plan = Generator.create(9182, 2, 8)
			plan.sector.stage = 1
			t.expect((Generator.validate(plan))).toBe(false)
		end)
	end,
}

return spec
