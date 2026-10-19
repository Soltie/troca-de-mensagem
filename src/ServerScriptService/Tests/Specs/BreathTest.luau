--!strict
local BreathTest = require("@game/ReplicatedStorage/Shared/Game/BreathTest")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "BreathTest",
	run = function(t)
		t.it("beats come in order with a breath before the first", function()
			local times = BreathTest.times(7)
			t.expect(#times).toBe(BreathTest.Beats)
			t.expect(times[1]).toBe(BreathTest.FirstDelay)
			for index = 2, #times do
				t.expect(times[index] > times[index - 1] + 0.8).toBe(true)
			end
		end)

		t.it("pressing on the beat passes", function()
			local times = BreathTest.times(1)
			local results = {}
			for index = 1, BreathTest.Beats do
				local judged, result = BreathTest.press(times, results, times[index] + 0.1)
				t.expect(judged).toBe(index)
				t.expect(result).toBe("hit")
			end
			t.expect(BreathTest.outcome(results)).toBe("pass")
			t.expect(BreathTest.encode(results)).toBe("HHHHH")
		end)

		t.it("three misses open the door", function()
			local times = BreathTest.times(2)
			local results = {}
			BreathTest.press(times, results, times[1] - 0.6)
			t.expect(BreathTest.outcome(results)).toBeNil()
			BreathTest.expire(times, results, times[3] + BreathTest.Window + 0.01)
			t.expect(BreathTest.misses(results)).toBe(3)
			t.expect(BreathTest.outcome(results)).toBe("fail")
		end)

		t.it("two misses still pass", function()
			local times = BreathTest.times(3)
			local results = {}
			BreathTest.expire(times, results, times[2] + BreathTest.Window + 0.01)
			for index = 3, BreathTest.Beats do
				BreathTest.press(times, results, times[index])
			end
			t.expect(BreathTest.encode(results)).toBe("MMHHH")
			t.expect(BreathTest.outcome(results)).toBe("pass")
		end)
	end,
}

return spec
