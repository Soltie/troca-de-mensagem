--!strict
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local TestKit = require("../TestKit")

local function accepts(validator: Guard.Validator, value: any): boolean
	local ok = validator(value)
	return ok
end

local spec: TestKit.Spec = {
	name = "Guard",
	run = function(t)
		t.describe("number", function()
			t.it("accepts finite numbers", function()
				t.expect(accepts(Guard.number(), 1.5)).toBe(true)
			end)

			t.it("rejects non-numbers, NaN and infinity", function()
				t.expect(accepts(Guard.number(), "1")).toBe(false)
				t.expect(accepts(Guard.number(), 0 / 0)).toBe(false)
				t.expect(accepts(Guard.number(), math.huge)).toBe(false)
				t.expect(accepts(Guard.number(), -math.huge)).toBe(false)
			end)

			t.it("enforces min, max and integer", function()
				local validator = Guard.integer({ min = 1, max = 10 })
				t.expect(accepts(validator, 5)).toBe(true)
				t.expect(accepts(validator, 0)).toBe(false)
				t.expect(accepts(validator, 11)).toBe(false)
				t.expect(accepts(validator, 2.5)).toBe(false)
			end)
		end)

		t.describe("string", function()
			t.it("rejects invalid UTF-8", function()
				t.expect(accepts(Guard.string(), "\255")).toBe(false)
			end)

			t.it("applies a default max length", function()
				t.expect(accepts(Guard.string(), string.rep("a", 200))).toBe(true)
				t.expect(accepts(Guard.string(), string.rep("a", 201))).toBe(false)
			end)

			t.it("counts characters, not bytes", function()
				t.expect(accepts(Guard.string({ maxLength = 3 }), "ção")).toBe(true)
			end)

			t.it("enforces minLength and pattern", function()
				local validator = Guard.string({ minLength = 2, pattern = "%a+" })
				t.expect(accepts(validator, "ab")).toBe(true)
				t.expect(accepts(validator, "a")).toBe(false)
				t.expect(accepts(validator, "ab1")).toBe(false)
			end)
		end)

		t.describe("literal / optional / boolean", function()
			t.it("accepts only listed literals", function()
				local validator = Guard.literal("red", "blue")
				t.expect(accepts(validator, "red")).toBe(true)
				t.expect(accepts(validator, "green")).toBe(false)
			end)

			t.it("optional accepts nil", function()
				local validator = Guard.optional(Guard.boolean())
				t.expect(accepts(validator, nil)).toBe(true)
				t.expect(accepts(validator, true)).toBe(true)
				t.expect(accepts(validator, 1)).toBe(false)
			end)
		end)

		t.describe("array", function()
			t.it("accepts dense arrays of valid items", function()
				t.expect(accepts(Guard.array(Guard.number()), { 1, 2, 3 })).toBe(true)
			end)

			t.it("rejects holes, string keys, metatables, bad items and long arrays", function()
				local validator = Guard.array(Guard.number(), 2)
				local withHole: { any } = {}
				withHole[1] = 1
				withHole[3] = 3
				local mixed: { any } = { 1, "x" }
				t.expect(accepts(validator, withHole)).toBe(false)
				t.expect(accepts(validator, { a = 1 })).toBe(false)
				t.expect(accepts(validator, setmetatable({ 1 }, {}))).toBe(false)
				t.expect(accepts(validator, mixed)).toBe(false)
				t.expect(accepts(validator, { 1, 2, 3 })).toBe(false)
			end)
		end)

		t.describe("args", function()
			local validate = Guard.args({ Guard.string(), Guard.optional(Guard.number()) })

			t.it("accepts valid argument lists", function()
				t.expect((validate(table.pack("hi")))).toBe(true)
				t.expect((validate(table.pack("hi", 2)))).toBe(true)
			end)

			t.it("rejects extra arguments", function()
				local ok, reason = validate(table.pack("hi", 2, "extra"))
				t.expect(ok).toBe(false)
				t.expect(string.find(reason or "", "too many arguments", 1, true) ~= nil).toBe(true)
			end)

			t.it("reports which argument failed", function()
				local ok, reason = validate(table.pack(123))
				t.expect(ok).toBe(false)
				t.expect(string.find(reason or "", "arg #1", 1, true) ~= nil).toBe(true)
			end)
		end)
	end,
}

return spec
