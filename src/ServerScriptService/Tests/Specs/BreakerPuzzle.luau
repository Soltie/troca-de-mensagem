--!strict
local BreakerPuzzle = require("@game/ServerScriptService/Server/Game/BreakerPuzzle")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "BreakerPuzzle",
	run = function(t)
		t.it("solves only in the diagram order", function()
			local s = BreakerPuzzle.new({ 2, 3, 1 })
			t.expect(BreakerPuzzle.press(s, 2)).toBe("progress")
			t.expect(BreakerPuzzle.isUp(s, 2)).toBe(true)
			t.expect(BreakerPuzzle.press(s, 2)).toBe("already")
			t.expect(BreakerPuzzle.press(s, 3)).toBe("progress")
			t.expect(BreakerPuzzle.press(s, 1)).toBe("solved")
			t.expect(s.solved).toBe(true)
			t.expect(BreakerPuzzle.press(s, 1)).toBe("already")
		end)

		t.it("a wrong lever drops all of them", function()
			local s = BreakerPuzzle.new({ 2, 3, 1 })
			BreakerPuzzle.press(s, 2)
			t.expect(BreakerPuzzle.press(s, 1)).toBe("wrong")
			t.expect(s.progress).toBe(0)
			t.expect(BreakerPuzzle.isUp(s, 2)).toBe(false)
		end)

		t.it("shuffles a permutation and describes it", function()
			local calls = 0
			local order = BreakerPuzzle.shuffle(3, function(a: number, _b: number): number
				calls += 1
				return a
			end)
			t.expect(calls).toBe(2)
			table.sort(order)
			t.expect(order).toEqual({ 1, 2, 3 })
			t.expect(BreakerPuzzle.describe({ 2, 3, 1 })).toBe("B - C - A")
		end)

		t.it("rejects invalid orders", function()
			t.expect(function()
				BreakerPuzzle.new({})
			end).toThrow("empty")
			t.expect(function()
				BreakerPuzzle.new({ 1, 1 })
			end).toThrow("repeated")
		end)
	end,
}

return spec
