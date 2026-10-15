--!strict
-- Sanidade da planta: pontos importantes dentro das salas, portas batendo com aberturas, saída além do portão.
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Layout = require("@game/ServerScriptService/Server/World/Layout")
local TestKit = require("../TestKit")
local WallMath = require("@game/ServerScriptService/Server/World/WallMath")

local function inside(p: Layout.Point): boolean
	return Layout.roomAt(p.x, p.z) ~= nil
end

local spec: TestKit.Spec = {
	name = "Layout",
	run = function(t)
		t.it("puts every fuse spot, note, patrol node and spawn inside a room", function()
			for id, spots in Layout.FuseSpots do
				t.expect(#spots >= 1).toBe(true)
				for index, p in spots do
					if not inside(p) then
						error(`fuse spot {id}#{index} is outside the building`)
					end
				end
			end
			for id, p in Layout.Notes do
				if not inside(p) then
					error(`note {id} is outside the building`)
				end
			end
			for index, p in Layout.PatrolNodes do
				if not inside(p) then
					error(`patrol node #{index} is outside the building`)
				end
			end
			for index, p in Layout.CreatureSpawns do
				if not inside(p) then
					error(`creature spawn #{index} is outside the building`)
				end
			end
		end)

		t.it("has a reachable standing point for every fuse spot, within interaction range", function()
			for id, spots in Layout.FuseSpots do
				local stands = Layout.FuseStands[id]
				t.expect(stands ~= nil and #stands == #spots).toBe(true)
				for index, spot in spots do
					local stand = stands[index]
					local dx, dz = spot.x - stand.x, spot.z - stand.z
					local eyeDy = spot.y - 4.5
					local distance = math.sqrt(dx * dx + dz * dz + eyeDy * eyeDy)
					if distance > Config.Game.InteractDistance or not inside(stand) then
						error(`stand {id}#{index} is {distance} studs away or outside`)
					end
				end
			end
			for id, stand in Layout.Stands do
				if id ~= "gate" and not inside(stand) then
					error(`stand {id} is outside the building`)
				end
			end
		end)

		t.it("has one fuse spot list per fuse (3 fuses)", function()
			local count = 0
			for _ in Layout.FuseSpots do
				count += 1
			end
			t.expect(count).toBe(3)
		end)

		t.it("keeps wall openings within the wall", function()
			for _, wall in Layout.Walls do
				for _, opening in wall.openings do
					local a = opening.center - opening.width / 2
					local b = opening.center + opening.width / 2
					if a < wall.from or b > wall.to then
						error(`opening at {opening.center} leaves wall {wall.id}`)
					end
				end
			end
		end)

		t.it("matches every door to a full-height opening on its wall", function()
			for _, door in Layout.Doors do
				local wall = Layout.wallById(door.wall)
				t.expect(wall).toBeTruthy()
				local found = false
				for _, opening in (wall :: Layout.Wall).openings do
					if opening.center == door.center and opening.bottom == 0 and opening.width == door.width then
						found = true
					end
				end
				if not found then
					error(`door {door.id} has no matching opening`)
				end
			end
		end)

		t.it("starts in the courtyard and exits beyond the gate", function()
			local s = Layout.Spawn.position
			t.expect(Layout.inRect(Layout.Courtyard, s.x, s.z)).toBe(true)
			t.expect(Layout.ExitZone.z0 > Layout.Gate.z).toBe(true)
			t.expect(Layout.ExitZone.x0 >= Layout.Gate.x - Layout.Gate.width / 2).toBe(true)
			t.expect(Layout.ExitZone.x1 <= Layout.Gate.x + Layout.Gate.width / 2).toBe(true)
		end)

		t.describe("WallMath", function()
			local openings = {
				{ center = 0, width = 6, bottom = 0, top = 9 },
				{ center = 10, width = 4, bottom = 3, top = 7 },
			}

			t.it("solid area + openings = whole wall", function()
				local segments = WallMath.solidSegments(-20, 20, 0, 11, openings)
				local holes = 6 * 9 + 4 * 4
				t.expect(WallMath.area(segments) + holes).toBeCloseTo(40 * 11)
			end)

			t.it("splitting into bands keeps the area", function()
				local segments = WallMath.solidSegments(-20, 20, 0, 11, openings)
				local lower, upper = WallMath.splitBands(segments, 3.2)
				t.expect(WallMath.area(lower) + WallMath.area(upper)).toBeCloseTo(WallMath.area(segments))
				for _, s in lower do
					t.expect(s.y1 <= 3.2 + 1e-6).toBe(true)
				end
			end)
		end)
	end,
}

return spec
