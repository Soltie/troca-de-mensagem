--!strict
local TungVisit = require("@game/ReplicatedStorage/Shared/Game/TungVisit")
local TestKit = require("../TestKit")

local function sight(overrides: { [string]: any }): TungVisit.Sight
	local base: any = {
		hidden = false,
		flashlight = false,
		speed = 0,
		distance = 5,
		clear = true,
		atCloset = false,
		sinceSpawn = 10,
	}
	for key, value in overrides do
		base[key] = value
	end
	return base
end

local spec: TestKit.Spec = {
	name = "TungVisit",
	run = function(t)
		t.it("picks the room with the most players outside the hall", function()
			local room = TungVisit.pickRoom({ { x = -20, z = -4 }, { x = -22, z = -6 }, { x = 20, z = -4 } }, "Dining")
			t.expect(room).toBe("Living")
			t.expect(TungVisit.pickRoom({ { x = 0, z = 2 } }, "Kitchen")).toBe("Kitchen")
			t.expect(TungVisit.roomOf(-26, -36)).toBe("Dining")
			t.expect(TungVisit.roomOf(26, -4)).toBe("Kitchen")
			t.expect(TungVisit.roomOf(0, 2)).toBeNil()
		end)
		t.it("route goes stairs, hall, room and back", function()
			local route = TungVisit.route("Kitchen")
			t.expect(route[1].kind).toBe("stairs")
			t.expect(route[#route].kind).toBe("leave")
			local pauses = 0
			for _, step in route do
				pauses += step.pause
			end
			t.expect(pauses >= TungVisit.MiddlePause + TungVisit.ClosetPause).toBe(true)
		end)
		t.it("hidden and quiet is safe, exposed is seen", function()
			t.expect(TungVisit.sees(sight({ hidden = true, atCloset = true }))).toBe(false)
			t.expect(TungVisit.sees(sight({ hidden = true, atCloset = true, flashlight = true, distance = 3 })))
				.toBe(true)
			t.expect(TungVisit.sees(sight({ hidden = true, atCloset = false, flashlight = true, distance = 3 })))
				.toBe(false)
			t.expect(TungVisit.sees(sight({}))).toBe(true)
			t.expect(TungVisit.sees(sight({ distance = 15 }))).toBe(false)
			t.expect(TungVisit.sees(sight({ distance = 15, speed = 20 }))).toBe(true)
			t.expect(TungVisit.sees(sight({ distance = 30, flashlight = true }))).toBe(true)
			t.expect(TungVisit.sees(sight({ clear = false }))).toBe(false)
			t.expect(TungVisit.sees(sight({ sinceSpawn = 0.5 }))).toBe(false)
		end)
	end,
}

return spec
