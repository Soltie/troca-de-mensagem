--!strict
local RateLimiter = require("@game/ReplicatedStorage/Shared/Net/RateLimiter")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "RateLimiter",
	run = function(t)
		local now = 0
		local function clock(): number
			return now
		end

		t.it("allows a burst up to capacity, then blocks", function()
			now = 0
			local limiter = RateLimiter.new({ capacity = 3, refillPerSecond = 1, clock = clock })
			t.expect(limiter.allow("a")).toBe(true)
			t.expect(limiter.allow("a")).toBe(true)
			t.expect(limiter.allow("a")).toBe(true)
			t.expect(limiter.allow("a")).toBe(false)
		end)

		t.it("refills over time without exceeding capacity", function()
			now = 0
			local limiter = RateLimiter.new({ capacity = 2, refillPerSecond = 1, clock = clock })
			limiter.allow("a")
			limiter.allow("a")
			t.expect(limiter.allow("a")).toBe(false)
			now = 1
			t.expect(limiter.allow("a")).toBe(true)
			t.expect(limiter.allow("a")).toBe(false)
			now = 100
			t.expect(limiter.allow("a")).toBe(true)
			t.expect(limiter.allow("a")).toBe(true)
			t.expect(limiter.allow("a")).toBe(false)
		end)

		t.it("tracks keys independently and frees them on reset", function()
			now = 0
			local limiter = RateLimiter.new({ capacity = 1, refillPerSecond = 0, clock = clock })
			t.expect(limiter.allow(1)).toBe(true)
			t.expect(limiter.allow(2)).toBe(true)
			t.expect(limiter.allow(1)).toBe(false)
			t.expect(limiter.size()).toBe(2)
			limiter.reset(1)
			t.expect(limiter.size()).toBe(1)
			t.expect(limiter.allow(1)).toBe(true)
		end)
	end,
}

return spec
