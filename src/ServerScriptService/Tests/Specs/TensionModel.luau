--!strict
local TensionModel = require("@game/ReplicatedStorage/Shared/Game/TensionModel")
local TestKit = require("../TestKit")

local function input(now: number, distance: number, chasing: boolean?, hits: number?, events: number?)
	return { now = now, distance = distance, chasing = chasing == true, hits = hits or 0, events = events or 0 }
end

local spec: TestKit.Spec = {
	name = "TensionModel",
	run = function(t)
		t.it("a chase builds up to the peak", function()
			local s = TensionModel.new(0)
			local entered = nil
			for i = 1, 60 do
				local out = TensionModel.step(s, 0.5, input(i * 0.5, 10, true))
				entered = entered or out.entered
			end
			t.expect(entered).toBe("Peak")
			t.expect(TensionModel.allowsEvents(s)).toBe(false)
		end)

		t.it("a hit at the peak gives a break, and the break ends", function()
			local s = TensionModel.new(0)
			s.tension, s.phase = 0.9, "Peak"
			t.expect(TensionModel.step(s, 0.5, input(1, 10, true, 1)).entered).toBe("Relax")
			t.expect(TensionModel.step(s, 0.5, input(1 + TensionModel.RelaxTime, 60)).entered).toBe("Build")
			t.expect(TensionModel.allowsEvents(s)).toBe(true)
		end)

		t.it("a hit while building also gives a break", function()
			local s = TensionModel.new(0)
			t.expect(TensionModel.step(s, 0.5, input(1, 10, true, 1)).entered).toBe("Relax")
		end)

		t.it("the peak ends when he loses the group", function()
			local s = TensionModel.new(0)
			s.tension, s.phase = 0.9, "Peak"
			local entered = nil
			for i = 1, 40 do
				entered = entered or TensionModel.step(s, 0.5, input(1 + i * 0.5, math.huge)).entered
			end
			t.expect(entered).toBe("Relax")
		end)

		t.it("a peak that drags on also gives a break", function()
			local s = TensionModel.new(0)
			s.tension, s.phase = 0.9, "Peak"
			t.expect(TensionModel.step(s, 0.5, input(TensionModel.PeakMax + 1, 10, true)).entered).toBe("Relax")
		end)

		t.it("too quiet for too long asks for a provocation, with cooldown", function()
			local s = TensionModel.new(0)
			local provokes = 0
			for i = 1, 400 do
				if TensionModel.step(s, 0.5, input(i * 0.5, math.huge)).provoke then
					provokes += 1
				end
			end
			-- 200 s quietos: provoca em ~70 s e ~140 s (QuietMax entre uma e outra).
			t.expect(provokes).toBe(2)
		end)

		t.it("proximity fades with distance", function()
			t.expect(TensionModel.proximity(8)).toBe(1)
			t.expect(TensionModel.proximity(40)).toBe(0)
			t.expect(TensionModel.proximity(math.huge)).toBe(0)
		end)
	end,
}

return spec
