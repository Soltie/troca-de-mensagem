--!strict
local RoomScares = require("@game/ReplicatedStorage/Shared/Game/RoomScares")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "RoomScares",
	run = function(t)
		t.it("finds the ground-floor room and ignores other floors", function()
			t.expect(RoomScares.roomAt(-26, 0, -36)).toBe("Dining")
			t.expect(RoomScares.roomAt(0, 0, 2)).toBe("Hall")
			t.expect(RoomScares.roomAt(-26, 16, -36)).toBeNil()
		end)
		t.it("fires each room scare only once", function()
			local done: { [string]: boolean } = {}
			local first = RoomScares.pick("Kitchen", done)
			t.expect(first ~= nil and first.kind == "pans").toBe(true)
			done.Kitchen = true
			t.expect(RoomScares.pick("Kitchen", done)).toBeNil()
			t.expect(RoomScares.pick("Bath", done)).toBeNil()
		end)
		t.it("has one scare per room with a caption", function()
			local seen: { [string]: boolean } = {}
			for _, scare in RoomScares.Chapter1 do
				t.expect(seen[scare.room]).toBeNil()
				seen[scare.room] = true
				t.expect(#scare.caption > 0).toBe(true)
			end
		end)
	end,
}

return spec
