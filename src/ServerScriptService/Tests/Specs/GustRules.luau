--!strict
local GustRules = require("@game/ReplicatedStorage/Shared/Game/GustRules")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "GustRules",
	run = function(t)
		t.it("blows in the house chapters except the fire escape", function()
			t.expect(GustRules.allowed(1)).toBe(true)
			t.expect(GustRules.allowed(0)).toBe(false)
			t.expect(GustRules.allowed(2)).toBe(true)
			t.expect(GustRules.allowed(4)).toBe(true)
			t.expect(GustRules.allowed(5)).toBe(false)
			t.expect(GustRules.allowed(7)).toBe(false)
		end)

		t.it("chapter 1 gusts only after the 3rd key, at most twice, away from the visit", function()
			t.expect(GustRules.chapterReady(1, 4, 0, 999)).toBe(false)
			t.expect(GustRules.chapterReady(1, 5, 0, 999)).toBe(true)
			t.expect(GustRules.chapterReady(1, 5, 2, 999)).toBe(false)
			t.expect(GustRules.chapterReady(1, 5, 1, 30)).toBe(false)
			t.expect(GustRules.chapterReady(2, 0, 9, 0)).toBe(true)
		end)

		t.it("respects start grace and cooldown", function()
			t.expect(GustRules.canRoll(10, 999)).toBe(false)
			t.expect(GustRules.canRoll(90, 30)).toBe(false)
			t.expect(GustRules.canRoll(90, 200)).toBe(true)
		end)

		t.it("the front waits for the warning, then moves", function()
			t.expect(GustRules.front(0) < 0).toBe(true)
			t.expect(GustRules.front(GustRules.WarnTime)).toBe(0)
			t.expect(GustRules.front(GustRules.WarnTime + 1)).toBe(GustRules.Speed)
			t.expect(GustRules.duration(38) > GustRules.WarnTime + 1).toBe(true)
		end)

		t.it("a side room or another floor is safe", function()
			t.expect(GustRules.inLane(10, 2, 0, 40)).toBe(true)
			t.expect(GustRules.inLane(10, 7, 0, 40)).toBe(false)
			t.expect(GustRules.inLane(10, 0, 12, 40)).toBe(false)
			t.expect(GustRules.inLane(60, 0, 0, 40)).toBe(false)
		end)

		t.it("hits once when the front passes", function()
			t.expect(GustRules.crossed(10, 8, 12)).toBe(true)
			t.expect(GustRules.crossed(10, 12, 16)).toBe(false)
			t.expect(GustRules.crossed(10, -5, 4)).toBe(false)
		end)
	end,
}

return spec
