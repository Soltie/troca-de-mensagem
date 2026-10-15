--!strict
local Retry = require("@game/ReplicatedStorage/Shared/Util/Retry")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "Retry",
	run = function(t)
		t.it("returns the value on first success without waiting", function()
			local waits = 0
			local ok, value, err = Retry.run(function()
				return 42
			end, {
				attempts = 3,
				baseDelay = 1,
				wait = function()
					waits += 1
				end,
			})
			t.expect(ok).toBe(true)
			t.expect(value).toBe(42)
			t.expect(err).toBeNil()
			t.expect(waits).toBe(0)
		end)

		t.it("retries with exponential backoff until success", function()
			local calls = 0
			local delays: { number } = {}
			local ok, value = Retry.run(function()
				calls += 1
				if calls < 3 then
					error("boom")
				end
				return "done"
			end, {
				attempts = 5,
				baseDelay = 1,
				wait = function(seconds: number)
					table.insert(delays, seconds)
				end,
			})
			t.expect(ok).toBe(true)
			t.expect(value).toBe("done")
			t.expect(calls).toBe(3)
			t.expect(delays).toEqual({ 1, 2 })
		end)

		t.it("gives up after the last attempt and returns the last error", function()
			local calls = 0
			local ok, value, err = Retry.run(function(): number
				calls += 1
				error(`fail {calls}`, 0)
			end, { attempts = 3, baseDelay = 0, wait = function() end })
			t.expect(ok).toBe(false)
			t.expect(value).toBeNil()
			t.expect(err).toBe("fail 3")
			t.expect(calls).toBe(3)
		end)

		t.it("caps the delay at maxDelay", function()
			t.expect(Retry.delayFor(1, 1, 5)).toBe(1)
			t.expect(Retry.delayFor(4, 1, 5)).toBe(5)
			t.expect(Retry.delayFor(3, 2, nil)).toBe(8)
		end)
	end,
}

return spec
