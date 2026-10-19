--!strict
local FootTrail = require("@game/ReplicatedStorage/Shared/Game/FootTrail")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "FootTrail",
	run = function(t)
		t.it("smells a fresh print nearby and points to the newest one", function()
			local trail = FootTrail.new()
			FootTrail.add(trail, 0, 0, 0, 0)
			FootTrail.add(trail, 0, 0, 10, 1)
			FootTrail.add(trail, 0, 0, 20, 2)
			local target = FootTrail.scent(trail, 3, 0, 0, 5, 8, 40)
			t.expect(target ~= nil and target.z == 20).toBe(true)
			t.expect(FootTrail.scent(trail, 60, 0, 0, 5, 8, 40) == nil).toBe(true)
		end)

		t.it("dry prints do not count and are pruned", function()
			local trail = FootTrail.new()
			FootTrail.add(trail, 0, 0, 0, 0)
			t.expect(FootTrail.scent(trail, 0, 0, 0, 50, 8, 40) == nil).toBe(true)
			FootTrail.prune(trail, 50, 40)
			t.expect(#trail.prints).toBe(0)
		end)

		t.it("keeps a bounded number of prints", function()
			local trail = FootTrail.new()
			for i = 1, FootTrail.MaxPrints + 15 do
				FootTrail.add(trail, i, 0, 0, i)
			end
			t.expect(#trail.prints).toBe(FootTrail.MaxPrints)
			t.expect(trail.prints[#trail.prints].x).toBe(FootTrail.MaxPrints + 15)
		end)
	end,
}

return spec
