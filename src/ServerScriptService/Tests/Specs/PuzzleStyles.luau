--!strict
local PuzzleStyles = require("@game/ReplicatedStorage/Shared/Game/PuzzleStyles")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "PuzzleStyles",
	run = function(t)
		t.it("each house puzzle becomes a real object", function()
			t.expect(PuzzleStyles.forTask(3, 5, 1).id).toBe("clock")
			t.expect(PuzzleStyles.forTask(4, 2, 1).id).toBe("piano")
			t.expect(PuzzleStyles.forTask(4, 4, 1).id).toBe("safe")
			t.expect(PuzzleStyles.forTask(7, 9, 1).id).toBe("radio")
			t.expect(PuzzleStyles.forTask(2, 3, 1).id).toBe("symbols")
		end)

		t.it("the clock answer is always 03:12", function()
			local clock = PuzzleStyles.CLOCK
			t.expect(table.concat(PuzzleStyles.answer(clock, clock.fixed :: { number }), "")).toBe("0312")
			t.expect(PuzzleStyles.progress(clock, clock.fixed :: { number }, 2):sub(1, 5)).toBe("03:__")
			t.expect(PuzzleStyles.progress(clock, clock.fixed :: { number }, 4):sub(1, 5)).toBe("03:12")
		end)

		t.it("safe digits are four different digits, the same for the same seed", function()
			for _, seed in { 0, 1, 42, 99991, 123456789 } do
				local digits = PuzzleStyles.safeDigits(seed)
				t.expect(#digits).toBe(4)
				local seen = {}
				for _, d in digits do
					t.expect(seen[d]).toBeNil()
					seen[d] = true
					local n = tonumber(d) :: number
					t.expect(n >= 1 and n <= 9).toBe(true)
				end
				t.expect(table.concat(PuzzleStyles.safeDigits(seed))).toBe(table.concat(digits))
			end
		end)

		t.it("the safe code is split between the catacomb and the basement panel", function()
			local safe = PuzzleStyles.forTask(4, 4, 7)
			local order = { 3, 1, 4, 2 }
			local answer = PuzzleStyles.answer(safe, order)
			local catacomb = PuzzleStyles.clue(safe, order)
			t.expect(string.find(catacomb, `{answer[1]} {answer[2]} _ _`, 1, true) ~= nil).toBe(true)
			local panel = PuzzleStyles.clue(PuzzleStyles.PIANO, { 1, 2, 3, 4 }, answer)
			t.expect(string.find(panel, `_ _ {answer[3]} {answer[4]}`, 1, true) ~= nil).toBe(true)
			t.expect(string.find(panel, "LUA - SOL - BASTÃO - ESTRELA", 1, true) ~= nil).toBe(true)
			for _, label in PuzzleStyles.PIANO.labels do
				t.expect(PuzzleStyles.MARK_COLORS[label] ~= nil).toBe(true)
			end
		end)

		t.it("piano keys get the four drawings in a seeded order and forgive mistakes", function()
			for seed = 1, 30 do
				local marks = PuzzleStyles.pianoMarks(seed)
				local seen: { [string]: boolean } = {}
				for _, mark in marks do
					seen[mark] = true
				end
				t.expect(#marks).toBe(4)
				for _, label in PuzzleStyles.PIANO.labels do
					t.expect(seen[label]).toBe(true)
				end
				local style = PuzzleStyles.forTask(4, 2, seed)
				t.expect(table.concat(style.labels, ",")).toBe(table.concat(marks, ","))
				t.expect(style.forgiving).toBe(true)
			end
			t.expect(PuzzleStyles.CLOCK.forgiving).toBe(true)
			t.expect(PuzzleStyles.forTask(4, 4, 1).forgiving).toBeNil()
		end)

		t.it("piano pitches rise", function()
			for i = 2, 4 do
				t.expect(PuzzleStyles.PIANO_PITCH[i] > PuzzleStyles.PIANO_PITCH[i - 1]).toBe(true)
			end
		end)
	end,
}

return spec
