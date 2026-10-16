--!strict
local Rules = require("@game/ReplicatedStorage/Shared/Game/SpectatorRules")
local TestKit = require("../TestKit")
return {
	name = "SpectatorRules",
	run = function(t)
		t.it("only waiting and escaped members spectate a live stage", function()
			for _, phase in { "Playing", "Extracting" } do
				t.expect(Rules.allowed(phase, "Waiting")).toBe(true)
				t.expect(Rules.allowed(phase, "Escaped")).toBe(true)
				for _, status in { "Active", "Downed", "Unknown" } do
					t.expect(Rules.allowed(phase, status)).toBe(false)
				end
			end
			for _, phase in { "Lobby", "Intro", "Lost", "Won", "Intermission" } do
				t.expect(Rules.allowed(phase, "Waiting")).toBe(false)
			end
			t.expect(Rules.allowed("Playing", nil)).toBe(false)
		end)
		t.it("cycles both ways with wraparound without changing the source list", function()
			local ids = { 7, -2, 4 }
			t.expect(Rules.choose(ids, nil, 0)).toBe(-2)
			t.expect(Rules.choose(ids, 7, 1)).toBe(-2)
			t.expect(Rules.choose(ids, -2, -1)).toBe(7)
			t.expect(Rules.choose(ids, 4, 0)).toBe(4)
			t.expect(ids[1]).toBe(7)
		end)
		t.it("recovers from disconnects and an empty or single survivor roster", function()
			t.expect(Rules.choose({}, 4, 1)).toBe(nil)
			t.expect(Rules.choose({ -3 }, 4, -1)).toBe(-3)
			t.expect(Rules.choose({ -3 }, -3, 1)).toBe(-3)
		end)
	end,
} :: TestKit.Spec
