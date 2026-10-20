--!strict
local WormTunnel = require("@game/ReplicatedStorage/Shared/Game/WormTunnel")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "WormTunnel",
	run = function(t)
		t.it("holes exist only in the house chapters, more of them from chapter 3", function()
			t.expect(#WormTunnel.holes(1)).toBe(0)
			t.expect(#WormTunnel.holes(2)).toBe(5)
			t.expect(#WormTunnel.holes(3)).toBe(8)
			t.expect(#WormTunnel.holes(5)).toBe(8)
			t.expect(#WormTunnel.holes(6)).toBe(0)
		end)

		t.it("he enters the nearest open hole on his floor and never another floor's", function()
			local holes = WormTunnel.holes(3)
			local entry = WormTunnel.entry(holes, { x = -36, y = 0, z = 0 }, {}, 0)
			t.expect(entry and entry.id).toBe("Living")
			t.expect(WormTunnel.entry(holes, { x = -36, y = 8, z = 0 }, {}, 0)).toBe(nil)
			t.expect(WormTunnel.entry(holes, { x = 0, y = 0, z = 2 }, {}, 0)).toBe(nil)
			-- Pregado: usa o próximo do mesmo andar.
			local other = WormTunnel.entry(holes, { x = -36, y = 0, z = -12 }, { Living = 100 }, 10)
			t.expect(other and other.id).toBe("Dining")
		end)

		t.it("he comes out near the closest player but never on top of anyone", function()
			local holes = WormTunnel.holes(3)
			local entry = holes[1]
			local exit = WormTunnel.exit(holes, entry, { { x = 20, y = 0, z = 2 } }, {}, 0)
			t.expect(exit and exit.id).toBe("Kitchen")
			-- Colado no buraco da cozinha: ele escolhe outro.
			local away = WormTunnel.exit(holes, entry, { { x = 40, y = 0, z = 2 } }, {}, 0)
			t.expect(away and away.id ~= "Kitchen").toBe(true)
			t.expect(WormTunnel.exit(holes, entry, {}, {}, 0)).toBe(nil)
			local boarded = WormTunnel.exit(holes, entry, { { x = 20, y = 0, z = 2 } }, { Kitchen = 50 }, 0)
			t.expect(boarded and boarded.id ~= "Kitchen").toBe(true)
		end)

		t.it("far from every hole he burrows into the floor and still comes out near you", function()
			local holes = WormTunnel.holes(3)
			local tung = { x = 0, y = 0, z = -60 }
			t.expect(WormTunnel.entry(holes, tung, {}, 0)).toBe(nil)
			local floor = WormTunnel.burrow(tung)
			t.expect(floor.id).toBe(WormTunnel.BURROW_ID)
			t.expect(WormTunnel.mouth(floor).x).toBe(0)
			local exit = WormTunnel.exit(holes, floor, { { x = 20, y = 0, z = 2 } }, {}, 0)
			t.expect(exit and exit.id).toBe("Kitchen")
			local s = WormTunnel.travelSeconds(floor, exit :: any)
			t.expect(s >= 4 and s <= 8).toBe(true)
		end)

		t.it("a scripted exit picks the open hole nearest to one player, not on top of them", function()
			local holes = WormTunnel.holes(3)
			local near = WormTunnel.nearestTo(holes, { x = 20, y = 0, z = 2 }, {}, 0)
			t.expect(near and near.id).toBe("Kitchen")
			local away = WormTunnel.nearestTo(holes, { x = 40, y = 0, z = 2 }, {}, 0)
			t.expect(away and away.id ~= "Kitchen").toBe(true)
			local boarded = WormTunnel.nearestTo(holes, { x = 20, y = 0, z = 2 }, { Kitchen = 50 }, 0)
			t.expect(boarded and boarded.id ~= "Kitchen").toBe(true)
		end)

		t.it("the trip lasts long enough to warn and to run", function()
			local holes = WormTunnel.holes(3)
			for _, a in holes do
				for _, b in holes do
					local s = WormTunnel.travelSeconds(a, b)
					t.expect(s >= 4 and s <= 8).toBe(true)
				end
			end
		end)
	end,
}

return spec
