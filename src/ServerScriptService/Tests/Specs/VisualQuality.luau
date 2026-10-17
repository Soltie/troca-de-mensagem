--!strict
local Quality = require("@game/ReplicatedStorage/Shared/Game/VisualQuality")
local Preferences = require("@game/ReplicatedStorage/Shared/Game/HousePreferences")
local Schema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local TestKit = require("../TestKit")
return {
	name = "VisualQuality",
	run = function(t)
		t.it("rejects fractional enums, infinity, NaN and unknown preference keys", function()
			for _, value in { -1, 0.1, 0.75, 2, math.huge, 0 / 0 } do
				t.expect(Preferences.valid("quality", value)).toBe(false)
			end
			t.expect(Preferences.valid("shaders", 0.5)).toBe(false)
			t.expect(Preferences.valid("unknown", 1)).toBe(false)
			for _, value in { 0, 0.25, 0.5, 1 } do
				t.expect(Preferences.valid("quality", value)).toBe(true)
			end
			t.expect(Preferences.sanitize({ quality = 0.75, shaders = 0.5, music = 0.75 })).toEqual({ music = 0.75 })
		end)
		t.it("migrates v5 while preserving progress, money, season and comfort", function()
			local data = Schema.migrate({
				schemaVersion = 5,
				wallet = { fichas = 123, creditos = 9 },
				season = { id = "s1", xp = 231, free = { [1] = true }, premium = {} },
				house = { cleared = { Story = 255 }, preferences = { flashes = 0, vhs = 0, master = 0.75 } },
			})
			t.expect(data.wallet.fichas).toBe(123)
			t.expect(data.season.xp).toBe(231)
			t.expect(data.house.cleared.Story).toBe(255)
			t.expect(data.house.preferences).toEqual({ flashes = 0, vhs = 0, master = 0.75, shaders = 1, quality = 0 })
			t.expect(
				Schema.migrate({ house = { preferences = { shaders = 0, quality = 1 } } }).house.preferences.shaders
			)
				.toBe(0)
		end)
		t.it("uses bounded budgets and a stable conservative automatic policy", function()
			t.expect(Quality.resolve(0, true, 0)).toBe(1)
			t.expect(Quality.resolve(0, false, 0)).toBe(2)
			t.expect(Quality.resolve(0, false, 2)).toBe(1)
			t.expect(Quality.resolve(0, true, 9)).toBe(3)
			for level = 1, 3 do
				local off, on = Quality.budget(level, false), Quality.budget(level, true)
				t.expect(off.shadows == 0 and off.particles == 0 and off.bloom == 0 and not off.depth).toBe(true)
				t.expect(on.shadows <= 3 and on.particles <= 1 and on.bloom <= 0.1).toBe(true)
				on.shadows = 99
				t.expect(Quality.budget(level, true).shadows <= 3).toBe(true)
			end
		end)
	end,
} :: TestKit.Spec
