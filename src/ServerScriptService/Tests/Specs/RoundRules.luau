--!strict
local RoundRules = require("@game/ServerScriptService/Server/Game/RoundRules")
local TestKit = require("../TestKit")

local function context(overrides: { [string]: any }): RoundRules.InteractionContext
	local ctx: { [string]: any } = {
		phase = "Playing",
		exists = true,
		enabled = true,
		alive = true,
		distance = 4,
		maxDistance = 8,
		tolerance = 2.5,
		lineOfSight = true,
	}
	for key, value in overrides do
		ctx[key] = value
	end
	return ctx :: any
end

local spec: TestKit.Spec = {
	name = "RoundRules",
	run = function(t)
		t.describe("phases", function()
			t.it("follows Loading -> Intro -> Playing -> Won/Lost -> Intro", function()
				t.expect(RoundRules.canTransition("Loading", "Intro")).toBe(true)
				t.expect(RoundRules.canTransition("Intro", "Playing")).toBe(true)
				t.expect(RoundRules.canTransition("Playing", "Won")).toBe(true)
				t.expect(RoundRules.canTransition("Playing", "Lost")).toBe(true)
				t.expect(RoundRules.canTransition("Lost", "Intro")).toBe(true)
				t.expect(RoundRules.canTransition("Won", "Intro")).toBe(true)
			end)

			t.it("blocks double endings and skipping phases", function()
				t.expect(RoundRules.canTransition("Lost", "Won")).toBe(false)
				t.expect(RoundRules.canTransition("Won", "Lost")).toBe(false)
				t.expect(RoundRules.canTransition("Lost", "Lost")).toBe(false)
				t.expect(RoundRules.canTransition("Intro", "Won")).toBe(false)
				t.expect(RoundRules.canTransition("Loading", "Playing")).toBe(false)
			end)

			t.it("only restarts from end screens", function()
				t.expect(RoundRules.canRestart("Won")).toBe(true)
				t.expect(RoundRules.canRestart("Lost")).toBe(true)
				t.expect(RoundRules.canRestart("Playing")).toBe(false)
				t.expect(RoundRules.canRestart("Intro")).toBe(false)
			end)
		end)

		t.describe("validateInteraction", function()
			t.it("accepts a valid interaction", function()
				t.expect((RoundRules.validateInteraction(context({})))).toBe(true)
			end)

			t.it("rejects outside of Playing", function()
				local ok, reason = RoundRules.validateInteraction(context({ phase = "Intro" }))
				t.expect(ok).toBe(false)
				t.expect(reason).toBe("not_playing")
			end)

			t.it("rejects missing, disabled, dead, far and blocked", function()
				t.expect(select(2, RoundRules.validateInteraction(context({ exists = false })))).toBe("unknown")
				t.expect(select(2, RoundRules.validateInteraction(context({ enabled = false })))).toBe("not_available")
				t.expect(select(2, RoundRules.validateInteraction(context({ alive = false })))).toBe("dead")
				t.expect(select(2, RoundRules.validateInteraction(context({ distance = 11 })))).toBe("too_far")
				t.expect(select(2, RoundRules.validateInteraction(context({ lineOfSight = false })))).toBe("blocked")
			end)

			t.it("accepts within tolerance and rejects NaN distance", function()
				t.expect((RoundRules.validateInteraction(context({ distance = 10.4 })))).toBe(true)
				t.expect((RoundRules.validateInteraction(context({ distance = 0 / 0 })))).toBe(false)
			end)
		end)

		t.it("formats round time as MM:SS", function()
			t.expect(RoundRules.formatTime(0)).toBe("00:00")
			t.expect(RoundRules.formatTime(402.7)).toBe("06:42")
		end)
	end,
}

return spec
