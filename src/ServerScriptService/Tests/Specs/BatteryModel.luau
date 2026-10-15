--!strict
local BatteryModel = require("@game/ReplicatedStorage/Shared/Game/BatteryModel")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local TestKit = require("../TestKit")

local B = Config.Battery

local function run(state: BatteryModel.State, seconds: number): boolean
	local died = false
	local dt = 0.2
	for _ = 1, math.floor(seconds / dt + 0.5) do
		died = BatteryModel.step(state, dt) or died
	end
	return died
end

local spec: TestKit.Spec = {
	name = "BatteryModel",
	run = function(t)
		t.it("drains while on and turns itself off at zero", function()
			local s = BatteryModel.new(1)
			BatteryModel.setOn(s, true)
			run(s, 10)
			t.expect(s.charge).toBeCloseTo(1 - 10 * B.DrainPerSecond, 1e-4)
			local died = false
			for _ = 1, 100000 do
				died = BatteryModel.step(s, 0.2)
				if died then
					break
				end
			end
			t.expect(died).toBe(true)
			t.expect(s.charge).toBe(0)
			t.expect(s.on).toBe(false)
			-- Apagada, volta a descansar (recupera aos poucos).
			BatteryModel.step(s, 1)
			t.expect(s.charge > 0).toBe(true)
		end)

		t.it("refuses to turn on when empty", function()
			local s = BatteryModel.new(0)
			t.expect(BatteryModel.setOn(s, true)).toBe(false)
			t.expect(s.on).toBe(false)
		end)

		t.it("never blocks the mission: resting recovers to the cap", function()
			local s = BatteryModel.new(0)
			local seconds = BatteryModel.secondsToRecover(0)
			t.expect(seconds < 30).toBe(true)
			run(s, seconds + 1)
			t.expect(s.charge).toBeCloseTo(B.RechargeCap, 1e-6)
			t.expect(BatteryModel.setOn(s, true)).toBe(true)
			-- Descanso não passa do teto.
			local full = BatteryModel.new(0.9)
			run(full, 60)
			t.expect(full.charge).toBeCloseTo(0.9, 1e-6)
		end)

		t.it("pickups add charge up to 100%", function()
			local s = BatteryModel.new(0.2)
			BatteryModel.addPickup(s)
			t.expect(s.charge).toBeCloseTo(0.2 + B.PickupAmount, 1e-6)
			BatteryModel.addPickup(s)
			t.expect(s.charge).toBe(1)
		end)

		t.it("maps charge to LEDs and dims when low", function()
			t.expect(BatteryModel.leds(0)).toBe(0)
			t.expect(BatteryModel.leds(0.01)).toBe(1)
			t.expect(BatteryModel.leds(0.5)).toBe(2)
			t.expect(BatteryModel.leds(0.51)).toBe(3)
			t.expect(BatteryModel.leds(1)).toBe(4)
			t.expect(BatteryModel.brightness(1)).toBe(1)
			t.expect(BatteryModel.brightness(0) < BatteryModel.brightness(B.LowLevel * 0.5)).toBe(true)
			t.expect(BatteryModel.isLow(B.LowLevel)).toBe(true)
		end)
	end,
}

return spec
