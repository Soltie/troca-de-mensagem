--!strict
local Patterns = require("@game/ReplicatedStorage/Shared/Game/SurfacePatterns")
local TestKit = require("../TestKit")
return {
	name = "SurfacePatterns",
	run = function(t)
		t.it("all surfaces produce bounded RGBA tiles with visible and transparent wear", function()
			for _, kind in Patterns.Kinds do
				local pixels = Patterns.pixels(kind, 7)
				t.expect(buffer.len(pixels)).toBe(Patterns.Size ^ 2 * 4)
				local minAlpha, maxAlpha = 255, 0
				for i = 3, buffer.len(pixels) - 1, 4 do
					minAlpha = math.min(minAlpha, buffer.readu8(pixels, i))
					maxAlpha = math.max(maxAlpha, buffer.readu8(pixels, i))
				end
				t.expect(minAlpha < maxAlpha).toBe(true)
				t.expect(maxAlpha < 200).toBe(true)
			end
		end)
		t.it("same seed is reproducible and different seeds change wear", function()
			local a = buffer.tostring(Patterns.pixels("paint", 4))
			t.expect(a).toBe(buffer.tostring(Patterns.pixels("paint", 4)))
			t.expect(a == buffer.tostring(Patterns.pixels("paint", 5))).toBe(false)
		end)
		t.it("rejects unknown texture kinds", function()
			local ok = pcall(Patterns.pixels, "unknown", 1)
			t.expect(ok).toBe(false)
		end)
	end,
} :: TestKit.Spec
