--!strict
local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "TableUtil",
	run = function(t)
		t.describe("deepCopy", function()
			t.it("copies nested tables independently", function()
				local original = { a = 1, nested = { b = 2 } }
				local copy = TableUtil.deepCopy(original)
				copy.nested.b = 3
				t.expect(original.nested.b).toBe(2)
				t.expect(copy.a).toBe(1)
			end)

			t.it("returns non-table values as-is", function()
				t.expect(TableUtil.deepCopy(5)).toBe(5)
				t.expect(TableUtil.deepCopy("x")).toBe("x")
			end)
		end)

		t.describe("reconcile", function()
			local template = { coins = 0, settings = { music = true, volume = 1 } }

			t.it("fills missing keys recursively and keeps existing values", function()
				local result = TableUtil.reconcile({ coins = 10, settings = { volume = 0.5 } }, template)
				t.expect(result).toEqual({ coins = 10, settings = { music = true, volume = 0.5 } })
			end)

			t.it("returns a copy of the template for non-table input", function()
				local result = TableUtil.reconcile(nil, template)
				t.expect(result).toEqual(template)
				result.settings.music = false
				t.expect(template.settings.music).toBe(true)
			end)
		end)

		t.describe("deepFreeze", function()
			t.it("freezes nested tables", function()
				local frozen = TableUtil.deepFreeze({ nested = { value = 1 } })
				t.expect(table.isfrozen(frozen)).toBe(true)
				t.expect(table.isfrozen(frozen.nested)).toBe(true)
				t.expect(function()
					(frozen.nested :: any).value = 2
				end).toThrow()
			end)
		end)

		t.describe("deepEqual", function()
			t.it("compares structurally", function()
				local a: { any } = { 1, { 2 } }
				local b: { any } = { 1, { 2 } }
				t.expect(TableUtil.deepEqual(a, b)).toBe(true)
				t.expect(TableUtil.deepEqual({ a = 1 }, { a = 1, b = 2 })).toBe(false)
				t.expect(TableUtil.deepEqual({ a = 1, b = 2 }, { a = 1 })).toBe(false)
			end)
		end)
	end,
}

return spec
