--!strict
local Loader = require("@game/ReplicatedStorage/Shared/Loader")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "Loader",
	run = function(t)
		t.it("runs every Init before any Start, in list order", function()
			local calls: { string } = {}
			local function module(name: string)
				return {
					Name = name,
					Init = function()
						table.insert(calls, name .. ".Init")
					end,
					Start = function()
						table.insert(calls, name .. ".Start")
					end,
				}
			end
			local count = Loader.boot({ module("A"), module("B"), { Name = "C" } }, { label = "Test" })
			t.expect(count).toBe(3)
			t.expect(calls).toEqual({ "A.Init", "B.Init", "A.Start", "B.Start" })
		end)

		t.it("fails with a clear message naming the phase and module", function()
			t.expect(function()
				Loader.boot({
					{
						Name = "Broken",
						Init = function()
							error("kaboom")
						end,
					},
				}, { label = "Test" })
			end).toThrow("[Test] Init failed in Broken")
		end)

		t.it("does not Start anything if an Init fails", function()
			local started = false
			local modules: { any } = {
				{
					Name = "Ok",
					Start = function()
						started = true
					end,
				},
				{
					Name = "Bad",
					Init = function()
						error("nope")
					end,
				},
			}
			pcall(Loader.boot, modules, { label = "Test" })
			t.expect(started).toBe(false)
		end)

		t.it("validates names and hooks", function()
			t.expect(function()
				Loader.boot({ { Init = function() end } }, { label = "Test" })
			end).toThrow('missing a non-empty string "Name"')
			t.expect(function()
				Loader.boot({ { Name = "X" }, { Name = "X" } }, { label = "Test" })
			end).toThrow('duplicate module name "X"')
			t.expect(function()
				Loader.boot({ { Name = "X", Start = 1 } }, { label = "Test" })
			end).toThrow("X.Start must be a function")
		end)
	end,
}

return spec
