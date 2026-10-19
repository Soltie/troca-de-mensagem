--!strict
local LightningRules = require("@game/ReplicatedStorage/Shared/Game/LightningRules")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "LightningRules",
	run = function(t)
		t.it("the escape chapter is much more dangerous", function()
			local normal = LightningRules.chance(3, 8)
			local final = LightningRules.chance(8, 8)
			t.expect(final > normal * 3).toBe(true)
			t.expect(normal > 0 and final < 0.5).toBe(true)
		end)

		t.it("respects start grace and cooldown", function()
			t.expect(LightningRules.canRoll(5, 999)).toBe(false)
			t.expect(LightningRules.canRoll(60, 5)).toBe(false)
			t.expect(LightningRules.canRoll(60, 60)).toBe(true)
		end)

		t.it("moving away from the warning saves you", function()
			t.expect(LightningRules.hits(0, 0, 1, 1)).toBe(true)
			t.expect(LightningRules.hits(0, 0, 6, 0)).toBe(false)
		end)
	end,
}

return spec
