--!strict
local CaptureRules = require("@game/ServerScriptService/Server/Game/CaptureRules")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "CaptureRules",
	run = function(t)
		t.it("only captures for real from chapter 2, in Story mode", function()
			t.expect(CaptureRules.kind(true, 1, true)).toBe("none")
			t.expect(CaptureRules.kind(false, 3, true)).toBe("none")
			t.expect(CaptureRules.kind(true, 2, true)).toBe("machine")
		end)

		t.it("plays the machine scene only on the first capture of the run", function()
			t.expect(CaptureRules.kind(true, 3, true)).toBe("machine")
			t.expect(CaptureRules.kind(true, 3, false)).toBe("wall")
			t.expect(CaptureRules.kind(true, 5, false)).toBe("wall")
		end)

		t.it("turns into a stump in the forest", function()
			t.expect(CaptureRules.kind(true, 6, true)).toBe("stump")
			t.expect(CaptureRules.kind(true, 8, false)).toBe("stump")
			t.expect(CaptureRules.furniture("stump", 0)).toBe("stump")
			t.expect(CaptureRules.furniture("stump", 0.99)).toBe("twig")
		end)

		t.it("picks chair, stool or lamp in the house", function()
			t.expect(CaptureRules.furniture("machine", 0)).toBe("chair")
			t.expect(CaptureRules.furniture("wall", 0.5)).toBe("stool")
			t.expect(CaptureRules.furniture("wall", 0.999)).toBe("lamp")
			t.expect(CaptureRules.furniture("wall", 1)).toBe("lamp")
		end)

		t.it("caps the drag and stops at the wall or the machine", function()
			t.expect(CaptureRules.dragSeconds(100, 100)).toBe(CaptureRules.DragMax)
			t.expect(CaptureRules.dragSeconds(6, 100)).toBeCloseTo(1)
			t.expect(CaptureRules.dragSeconds(100, 3)).toBeCloseTo(0.5)
			t.expect(CaptureRules.dragSeconds(-1, 10)).toBe(0)
		end)

		t.it("times the whole scene (solo defeat waits for it)", function()
			local machine = CaptureRules.duration("machine", 2)
			t.expect(machine).toBeCloseTo(CaptureRules.PreDrag + 2 + CaptureRules.Cut + CaptureRules.ThrowEnd)
			t.expect(CaptureRules.duration("machine", 99))
				.toBeCloseTo(CaptureRules.PreDrag + CaptureRules.DragMax + CaptureRules.Cut + CaptureRules.ThrowEnd)
			t.expect(CaptureRules.duration("none")).toBe(0)
			t.expect(CaptureRules.duration("wall") > CaptureRules.PreDrag).toBe(true)
		end)

		t.it("hardens after 60 s only with friends around", function()
			t.expect(CaptureRules.hardens(1, 999)).toBe(false)
			t.expect(CaptureRules.hardens(2, 59)).toBe(false)
			t.expect(CaptureRules.hardens(2, 60)).toBe(true)
		end)
	end,
}

return spec
