--!strict
local P = require("@game/ReplicatedStorage/Shared/Game/LightingProfile")
local TestKit = require("../TestKit")
return {
	name = "LightingProfile",
	run = function(t)
		t.it("contains decorative fill without dimming clues or mission effects", function()
			local night, reach = P.fixture("NightLight", 0.75, 26)
			t.expect(night > 0 and night < 0.75).toBe(true)
			t.expect(reach).toBe(18)
			local _, short = P.fixture("NightLight", 0.75, 8)
			t.expect(short).toBe(8)
			local clue, clueRange = P.fixture("ObjectiveGlow", 2, 30)
			t.expect(clue).toBe(2)
			t.expect(clueRange).toBe(30)
		end)
		t.it("preserves bounded grade and visibility across interior/power blends", function()
			for i = -1, 11 do
				for j = -1, 11 do
					local grade = P.grade(i / 10, j / 10)
					for _, channel in grade.tint do
						t.expect(channel >= 0 and channel <= 255).toBe(true)
					end
					t.expect(grade.contrast >= 0 and grade.contrast <= 0.12).toBe(true)
					t.expect(P.exposure(i / 10, j / 10) >= 0.08).toBe(true)
				end
			end
		end)
		t.it("fog recovers fully and never extends a shorter existing visibility cap", function()
			t.expect(P.fogEnd(142, 0)).toBe(142)
			t.expect(P.fogEnd(142, 1)).toBe(64)
			t.expect(P.fogEnd(40, 1)).toBe(40)
			t.expect(P.fogEnd(142, -3)).toBe(142)
			t.expect(P.fogEnd(142, 3)).toBe(64)
		end)
		t.it("adaptation does not depend on frame rate or overshoot", function()
			local fast, slow = 0, 0
			for _ = 1, 120 do
				fast = P.approach(fast, 1, 1 / 120)
			end
			for _ = 1, 12 do
				slow = P.approach(slow, 1, 1 / 12)
			end
			t.expect(fast).toBeCloseTo(slow)
			t.expect(P.approach(0.4, 1, -1)).toBe(0.4)
			t.expect(P.approach(0, 1, 100) <= 1).toBe(true)
		end)
		t.it("shadow budget excludes disabled, distant and out-of-range lights", function()
			local chosen = P.selectShadows({
				{ id = "off", enabled = false, distance = 0, range = 20 },
				{ id = "far", enabled = true, distance = 70, range = 80 },
				{ id = "range", enabled = true, distance = 40, range = 5 },
				{ id = "a", enabled = true, distance = 5, range = 20 },
				{ id = "b", enabled = true, distance = 8, range = 20 },
				{ id = "c", enabled = true, distance = 9, range = 20 },
			}, 2)
			t.expect(chosen).toEqual({ a = true, b = true })
			t.expect(P.selectShadows({}, 2)).toEqual({})
			t.expect(P.shadowBudget(2)).toBe(0)
			t.expect(P.shadowBudget(0)).toBe(2)
		end)
		t.it("comfort mode keeps every fixture steady", function()
			for tick = 0, 100 do
				t.expect(P.flicker(tick / 10, 4, true, false)).toBe(1)
				local value = P.flicker(tick / 10, 4, true, true)
				t.expect(value >= 0.48 and value <= 1).toBe(true)
			end
		end)
	end,
} :: TestKit.Spec
