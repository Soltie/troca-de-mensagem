--!strict
local W = require("@game/ReplicatedStorage/Shared/Game/Weather")
local TestKit = require("../TestKit")
return {
	name = "Weather",
	run = function(t)
		t.it("rain stops under a roof and never vanishes outdoors on low quality", function()
			t.expect(W.rate(W.RainRate, 1, 0, 1)).toBe(0)
			t.expect(W.rate(W.RainRate, 0, 1, 1) > 0).toBe(true)
			t.expect(W.rate(W.RainRate, 1, 1, 1) > W.rate(W.RainRate, 0.45, 1, 1)).toBe(true)
			t.expect(W.rate(W.RainRate, 5, 3, 9)).toBe(math.floor(W.RainRate * 1.2 + 0.5))
		end)
		t.it("gusts stay in a gentle band", function()
			for i = 0, 2000 do
				local g = W.gust(i * 0.37)
				t.expect(g >= 0.74 and g <= 1.16).toBe(true)
			end
		end)
		t.it("indoor rain is quieter but still audible", function()
			t.expect(W.volume(0)).toBe(W.IndoorVolume)
			t.expect(W.volume(1)).toBe(1)
			t.expect(W.volume(-2) > 0).toBe(true)
		end)
		t.it("lightning is rare, thunder follows, flash is short and bounded", function()
			t.expect(W.strikeInterval(0) >= 35).toBe(true)
			t.expect(W.strikeInterval(1) <= 80).toBe(true)
			t.expect(W.thunderDelay(0.5) > 1).toBe(true)
			for i = -10, 100 do
				local f = W.flash(i / 100)
				t.expect(f >= 0 and f <= 1).toBe(true)
			end
			t.expect(W.flash(0.7)).toBe(0)
			t.expect(W.flash(0.01)).toBe(1)
		end)
	end,
} :: TestKit.Spec
