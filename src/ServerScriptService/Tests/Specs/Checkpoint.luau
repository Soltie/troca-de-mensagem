--!strict
local Checkpoint = require("@game/ServerScriptService/Server/Game/Checkpoint")
local Objectives = require("@game/ServerScriptService/Server/Game/Objectives")
local TestKit = require("../TestKit")

local function powered(): Objectives.State
	local s = Objectives.new(1)
	s.enteredBuilding = true
	Objectives.takeKey(s)
	Objectives.useKey(s, "door_storage")
	Objectives.collect(s, "fuse")
	Objectives.insert(s)
	Objectives.solveBreakers(s)
	Objectives.powerOn(s)
	return s
end

local function input(objectives: Objectives.State, overrides: { [string]: any }?): Checkpoint.Snapshot
	local i: { [string]: any } = {
		objectives = objectives,
		doors = {},
		locked = {},
		battery = 1,
		breakerOrder = { 1 },
		taken = {},
	}
	if overrides then
		for key, value in overrides do
			i[key] = value
		end
	end
	return i :: any
end

local spec: TestKit.Spec = {
	name = "Checkpoint",
	run = function(t)
		t.it("captures an independent copy of the round", function()
			local s = powered()
			local doors: { [string]: Checkpoint.DoorState } = { door_office = "open", door_storage = "crack" }
			local taken = { battery_1 = true }
			local snap = Checkpoint.capture(input(s, {
				doors = doors,
				locked = { door_storage = false },
				battery = 0.4,
				breakerOrder = { 3, 1, 2 },
				taken = taken,
			}))
			-- O jogo continua mudando depois do checkpoint...
			s.gateOpen = true
			s.collected.extra = true
			doors.door_office = "closed"
			taken.battery_2 = true
			-- ...e o snapshot não muda.
			t.expect(snap.objectives.gateOpen).toBe(false)
			t.expect(snap.objectives.collected.extra).toBeNil()
			t.expect(snap.doors.door_office).toBe("open")
			t.expect(snap.battery).toBe(0.4)
			t.expect(snap.breakerOrder).toEqual({ 3, 1, 2 })
			t.expect(snap.taken.battery_2).toBeNil()
			t.expect(snap.taken.battery_1).toBe(true)
		end)

		t.it("restores progress, inventory and doors as a fresh copy each time", function()
			local snap = Checkpoint.capture(input(powered(), { doors = { door_office = "crack" }, battery = 2 }))
			t.expect(snap.battery).toBe(1)
			local first = Checkpoint.restore(snap)
			first.objectives.gateOpen = true
			local second = Checkpoint.restore(snap)
			t.expect(second.objectives.gateOpen).toBe(false)
			t.expect(second.objectives.powerOn).toBe(true)
			t.expect(second.objectives.inserted).toBe(1)
			t.expect(second.objectives.unlocked.door_storage).toBe(true)
			t.expect(second.doors.door_office).toBe("crack")
		end)

		t.it("is only usable with power on and the gate still closed", function()
			t.expect(Checkpoint.isUsable(nil)).toBe(false)
			t.expect(Checkpoint.isUsable(Checkpoint.capture(input(Objectives.new(1))))).toBe(false)
			t.expect(Checkpoint.isUsable(Checkpoint.capture(input(powered())))).toBe(true)
		end)
	end,
}

return spec
