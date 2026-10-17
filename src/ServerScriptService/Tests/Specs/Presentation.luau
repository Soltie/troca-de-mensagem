--!strict
local Presentation = require("@game/ReplicatedStorage/Shared/Game/Presentation")
local TestKit = require("../TestKit")
return {
	name = "Presentation",
	run = function(t)
		t.it("scene masks both camera handoffs without holding the middle", function()
			t.expect(Presentation.shade(0, 8)).toBe(1)
			t.expect(Presentation.shade(4, 8)).toBe(0)
			t.expect(Presentation.shade(8, 8)).toBe(1)
			t.expect(Presentation.shade(0, 0)).toBe(0)
			for i = 0, 80 do
				local value = Presentation.shade(i / 10, 8)
				t.expect(value >= 0 and value <= 1).toBe(true)
			end
		end)
		t.it("cut mask meets at the boundary and leaves static cuts alone", function()
			t.expect(Presentation.cut(0, 4, true, false)).toBe(1)
			t.expect(Presentation.cut(1, 4, false, true)).toBe(1)
			t.expect(Presentation.cut(0.5, 4, true, true)).toBe(0)
			t.expect(Presentation.cut(0, 4, false, false)).toBe(0)
			t.expect(Presentation.cut(1, 4, false, false)).toBe(0)
		end)
		t.it("very short scenes keep a visible middle and clamp overrun", function()
			t.expect(Presentation.shade(0.03, 0.06)).toBe(0)
			t.expect(Presentation.shade(1, 0.06)).toBe(1)
			t.expect(Presentation.ease(-2)).toBe(0)
			t.expect(Presentation.ease(2)).toBe(1)
		end)
	end,
} :: TestKit.Spec
