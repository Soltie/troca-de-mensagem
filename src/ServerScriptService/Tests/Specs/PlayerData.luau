--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config")
local MockDataStore = require("@game/ServerScriptService/Server/Data/MockDataStore")
local PlayerDataSchema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "PlayerData",
	run = function(t)
		t.describe("PlayerDataSchema", function()
			t.it("creates a fresh template for nil or garbage", function()
				local fromNil = PlayerDataSchema.migrate(nil)
				t.expect(fromNil.sessions).toBe(0)
				t.expect(fromNil.schemaVersion).toBe(Config.Data.SchemaVersion)
				t.expect(PlayerDataSchema.migrate("garbage").sessions).toBe(0)
			end)

			t.it("keeps saved values and fills missing fields", function()
				local data = PlayerDataSchema.migrate({ sessions = 7, schemaVersion = 0 })
				t.expect(data.sessions).toBe(7)
				t.expect(data.firstJoin).toBe(0)
				t.expect(data.schemaVersion).toBe(Config.Data.SchemaVersion)
			end)

			t.it("returns independent copies of the template", function()
				local a = PlayerDataSchema.template()
				a.sessions = 99
				t.expect(PlayerDataSchema.template().sessions).toBe(0)
			end)
		end)

		t.describe("MockDataStore", function()
			t.it("returns nil for unknown keys", function()
				t.expect(MockDataStore.new():GetAsync("missing")).toBeNil()
			end)

			t.it("stores copies via UpdateAsync (multi-return transform, like the real API)", function()
				local store = MockDataStore.new()
				local value = { sessions = 1 }
				store:UpdateAsync("k", function(_current: any)
					return value, { 123 }
				end)
				value.sessions = 50
				t.expect(store:GetAsync("k")).toEqual({ sessions = 1 })
			end)

			t.it("passes the current value to the transform and cancels on nil", function()
				local store = MockDataStore.new()
				store:UpdateAsync("k", function()
					return { n = 1 }
				end)
				store:UpdateAsync("k", function(current: any)
					t.expect(current).toEqual({ n = 1 })
					return nil
				end)
				t.expect(store:GetAsync("k")).toEqual({ n = 1 })
				store:RemoveAsync("k")
				t.expect(store:GetAsync("k")).toBeNil()
			end)
		end)
	end,
}

return spec
