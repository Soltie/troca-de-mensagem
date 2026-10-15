--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config")
local TensionDirector = require("@game/ReplicatedStorage/Shared/Game/TensionDirector")
local TestKit = require("../TestKit")

local T = Config.Tension

local function ctx(overrides: { [string]: any }): TensionDirector.Context
	local c: { [string]: any } = {
		now = 0,
		playing = true,
		creatureActive = true,
		creatureMode = "Patrol",
		creatureDistance = 80,
		fear = 0.45,
		darkness = 1,
		zone = "Corridor",
		progress = 2,
		hidden = false,
	}
	for key, value in overrides do
		c[key] = value
	end
	return c :: any
end

-- Gerador que sempre "sorteia" o primeiro da lista e sempre dispara.
local function always(): number
	return 0
end

-- Roda o diretor de `from` até `to` segundos e devolve os eventos com o tempo.
local function simulate(
	d: TensionDirector.Director,
	from: number,
	to: number,
	base: { [string]: any }
): { { at: number, event: string } }
	local events: { { at: number, event: string } } = {}
	local now = from
	while now < to do
		local c = table.clone(base)
		c.now = now
		local decision = TensionDirector.step(d, ctx(c), T.TickInterval)
		if decision.event then
			table.insert(events, { at = now, event = decision.event })
		end
		now += T.TickInterval
	end
	return events
end

local testSpec: TestKit.Spec = {
	name = "TensionDirector",
	run = function(t)
		t.it("starts in anticipation and enters tension when the creature is near", function()
			local d = TensionDirector.new(always, 0)
			t.expect(d.state).toBe("Anticipation")
			local decision = TensionDirector.step(d, ctx({ now = 1, creatureDistance = 20 }), 0.25)
			t.expect(decision.state).toBe("Tension")
			t.expect(decision.changed).toBe(true)
		end)

		t.it("never fires during a chase and holds a recovery lull afterwards", function()
			local d = TensionDirector.new(always, 0)
			local during = simulate(d, 0, 30, { creatureMode = "Chase", creatureDistance = 10 })
			t.expect(#during).toBe(0)
			t.expect(d.state).toBe("Chase")
			local after = simulate(d, 30, 30 + T.RecoveryTime - 1, { creatureMode = "Patrol", creatureDistance = 90 })
			t.expect(#after).toBe(0)
			t.expect(d.state).toBe("Recovery")
			simulate(d, 30 + T.RecoveryTime, 30 + T.RecoveryTime + 1, { creatureDistance = 90 })
			t.expect(d.state).toBe("Anticipation")
		end)

		t.it("respects the minimum gap between events (no spam)", function()
			local d = TensionDirector.new(always, 0)
			local events = simulate(d, 0, 300, { creatureDistance = 90 })
			t.expect(#events > 0).toBe(true)
			local minGap = TensionDirector.gap(d, 2)
			for i = 2, #events do
				t.expect(events[i].at - events[i - 1].at >= minGap - 1e-6).toBe(true)
			end
		end)

		t.it("respects each event's own cooldown", function()
			local d = TensionDirector.new(always, 0)
			local events = simulate(d, 0, 600, { creatureDistance = 90 })
			local last: { [string]: number } = {}
			for _, e in events do
				local previous = last[e.event]
				if previous then
					t.expect(e.at - previous >= TensionDirector.EVENTS[e.event].cooldown - 1e-6).toBe(true)
				end
				last[e.event] = e.at
			end
		end)

		t.it("filters by zone, fear, darkness and progress", function()
			local d = TensionDirector.new(always, 0)
			-- Recepção iluminada, medo baixo, sem progresso: só eventos sem restrição.
			local c = ctx({ zone = "Lobby", fear = 0, darkness = 0, progress = 0, creatureDistance = 90 })
			t.expect(TensionDirector.eligible(d, "eyes", c)).toBe(false)
			t.expect(TensionDirector.eligible(d, "silhouette", c)).toBe(false)
			t.expect(TensionDirector.eligible(d, "false_alarm", c)).toBe(false)
			t.expect(TensionDirector.eligible(d, "flicker", c)).toBe(true)
			-- "vibrate" exige o Vigia perto (e o estado Tension).
			t.expect(TensionDirector.eligible(d, "vibrate", c)).toBe(false)
			local dark = ctx({ zone = "Storage", fear = 0.6, darkness = 1, progress = 2, creatureDistance = 90 })
			t.expect(TensionDirector.eligible(d, "eyes", dark)).toBe(true)
		end)

		t.it("does nothing while hidden or outside of play", function()
			local d = TensionDirector.new(always, 0)
			t.expect(#simulate(d, 0, 120, { hidden = true, creatureDistance = 90 })).toBe(0)
			t.expect(#simulate(d, 120, 240, { playing = false, creatureDistance = 90 })).toBe(0)
		end)

		t.it("silence-before events block the next one for longer", function()
			local d = TensionDirector.new(always, 0)
			d.cooldowns.flicker = math.huge
			d.cooldowns.distant_steps = math.huge
			d.cooldowns.radio_static = math.huge
			d.cooldowns.whisper = math.huge
			local decision = TensionDirector.step(d, ctx({ now = 100, creatureDistance = 90 }), 0.25)
			t.expect(decision.event).toBe("false_alarm")
			t.expect(decision.silence).toBe(true)
			t.expect(d.busyUntil).toBeCloseTo(100 + TensionDirector.EVENTS["false_alarm"].duration + T.SilenceBefore)
		end)

		t.it("logs state changes and events, bounded", function()
			local d = TensionDirector.new(always, 0)
			simulate(d, 0, 2000, { creatureDistance = 90 })
			t.expect(#d.log > 0).toBe(true)
			t.expect(#d.log <= 40).toBe(true)
			TensionDirector.notify(d, 2000, "awaken", 5)
			t.expect(d.busyUntil >= 2005).toBe(true)
			TensionDirector.reset(d, 2001)
			t.expect(d.state).toBe("Anticipation")
		end)
	end,
}

return testSpec
