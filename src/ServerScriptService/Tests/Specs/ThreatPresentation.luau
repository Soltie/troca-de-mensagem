--!strict
local Presentation = require("@game/ReplicatedStorage/Shared/Game/ThreatPresentation")
local TestKit = require("../TestKit")

local testSpec: TestKit.Spec = {
	name = "ThreatPresentation",
	run = function(t)
		t.it("only active members receive playing effects", function()
			t.expect(Presentation.playing("Playing", "Active")).toBe(true)
			t.expect(Presentation.playing("Playing", nil)).toBe(true)
			for _, status in { "Waiting", "Downed", "Eliminated", "Escaped" } do
				t.expect(Presentation.playing("Playing", status)).toBe(false)
			end
			t.expect(Presentation.playing("Intro", "Active")).toBe(false)
		end)
		t.it("global chase only becomes personal chase for its target, including test IDs", function()
			t.expect(Presentation.mode("Chase", -2, -2, "Active")).toBe("Chase")
			t.expect(Presentation.mode("Chase", -2, -3, "Active")).toBe("Patrol")
			t.expect(Presentation.mode("Capture", 45, 46, "Active")).toBe("Patrol")
			t.expect(Presentation.mode("Chase", 0, 46, "Active")).toBe("Patrol")
			t.expect(Presentation.mode("Search", 0, 46, "Active")).toBe("Search")
		end)
		t.it("preserves solo fallback and silences inactive members", function()
			t.expect(Presentation.mode("Capture", nil, 99, nil)).toBe("Capture")
			t.expect(Presentation.mode("Chase", 99, 99, "Downed")).toBe("Dormant")
		end)
		t.it("capture is an individual edge, not a group defeat", function()
			t.expect(Presentation.captured("Active", "Downed", "Playing", "Playing")).toBe(true)
			t.expect(Presentation.captured("Downed", "Downed", "Playing", "Lost")).toBe(false)
			t.expect(Presentation.captured("Active", "Active", "Playing", "Lost")).toBe(false)
			t.expect(Presentation.captured(nil, "Downed", nil, "Playing")).toBe(false)
			t.expect(Presentation.captured("Downed", "Active", "Playing", "Playing")).toBe(false)
			t.expect(Presentation.captured("Active", "Downed", "Playing", "Playing")).toBe(true)
			t.expect(Presentation.captured(nil, nil, "Playing", "Lost")).toBe(true)
		end)
		t.it("comfort disables all optional screen effects even at maximum fear", function()
			local off = Presentation.effects(1, true, false, false)
			for _, key in { "vignette", "grain", "fog", "blur", "glitch" } do
				t.expect((off :: any)[key]).toBe(0)
			end
			t.expect(Presentation.effects(1, false, true, true).fear).toBe(0)
		end)
		t.it("panic starts above 0.8 and intensity is clamped", function()
			t.expect(Presentation.effects(0.8, true, true, true).blur).toBe(0)
			t.expect(Presentation.effects(2, true, true, true).fear).toBe(1)
			t.expect(Presentation.effects(0.9, true, true, true).blur > 0).toBe(true)
		end)
	end,
}
return testSpec
