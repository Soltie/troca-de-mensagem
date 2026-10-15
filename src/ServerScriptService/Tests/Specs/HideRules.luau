--!strict
local Config = require("@game/ReplicatedStorage/Shared/Config")
local HideRules = require("@game/ServerScriptService/Server/Game/HideRules")
local TestKit = require("../TestKit")

local H = Config.Hide

local function enter(overrides: { [string]: any }): HideRules.EnterContext
	local c: { [string]: any } = {
		playing = true,
		alive = true,
		occupied = false,
		alreadyHidden = false,
		sinceExit = math.huge,
	}
	for key, value in overrides do
		c[key] = value
	end
	return c :: any
end

local function found(overrides: { [string]: any }): HideRules.FoundContext
	local c: { [string]: any } = {
		sawEntry = false,
		creatureActive = true,
		distance = 30,
		holdingBreath = false,
		exposedTime = 0,
		captureRange = Config.Creature.CaptureRange,
	}
	for key, value in overrides do
		c[key] = value
	end
	return c :: any
end

local spec: TestKit.Spec = {
	name = "HideRules",
	run = function(t)
		t.it("validates entering", function()
			t.expect((HideRules.canEnter(enter({})))).toBe(true)
			local _, a = HideRules.canEnter(enter({ playing = false }))
			t.expect(a).toBe("not_playing")
			local _, b = HideRules.canEnter(enter({ occupied = true }))
			t.expect(b).toBe("hide_occupied")
			local _, c = HideRules.canEnter(enter({ alreadyHidden = true }))
			t.expect(c).toBe("not_available")
			local _, d = HideRules.canEnter(enter({ sinceExit = H.ExitCooldown * 0.5 }))
			t.expect(d).toBe("not_available")
		end)

		t.it("knows when the creature saw you enter", function()
			t.expect(HideRules.sawEntry(0.2, true)).toBe(true)
			t.expect(HideRules.sawEntry(H.SawEntryWindow + 0.1, true)).toBe(false)
			t.expect(HideRules.sawEntry(0, false)).toBe(false)
		end)

		t.it("seen entering = caught when it reaches the locker", function()
			t.expect(HideRules.found(found({ sawEntry = true, distance = 20 }))).toBe(false)
			t.expect(HideRules.found(found({ sawEntry = true, distance = 3 }))).toBe(true)
		end)

		t.it("not seen: safe while holding breath, found if breathing near for too long", function()
			t.expect(HideRules.found(found({ distance = 3, exposedTime = 0.5 }))).toBe(false)
			t.expect(HideRules.found(found({ distance = 3, exposedTime = H.NoticeTime }))).toBe(true)
			t.expect(HideRules.found(found({ distance = 3, exposedTime = 99, holdingBreath = true }))).toBe(false)
			t.expect(HideRules.found(found({ distance = 3, exposedTime = 99, creatureActive = false }))).toBe(false)
		end)

		t.it("exposure accumulates only when near and breathing", function()
			t.expect(HideRules.exposure(1, 3, false, 0.5)).toBe(1.5)
			t.expect(HideRules.exposure(1, 3, true, 0.5)).toBe(1)
			t.expect(HideRules.exposure(1, H.NoticeRange + 1, false, 0.5)).toBe(0)
		end)
	end,
}

return spec
