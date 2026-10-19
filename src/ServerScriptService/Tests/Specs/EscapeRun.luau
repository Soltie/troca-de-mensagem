--!strict
local EscapeRun = require("@game/ReplicatedStorage/Shared/Game/EscapeRun")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "EscapeRun",
	run = function(t)
		t.it("projects the basement corridor onto the route", function()
			local s, off = EscapeRun.project(0, -16, -44)
			t.expect(math.abs(s - 50) < 0.01).toBe(true)
			t.expect(off < 0.01).toBe(true)
			local x, y, z = EscapeRun.point(50)
			t.expect(math.abs(x) + math.abs(y + 16) + math.abs(z + 44) < 0.01).toBe(true)
		end)

		t.it("beams fall ahead of whoever triggers them", function()
			for _, beam in EscapeRun.Beams do
				t.expect(beam.at - beam.trigger >= 12).toBe(true)
			end
		end)

		t.it("the collapse is slower than sprinting and faster than walking", function()
			local c = EscapeRun.Collapse
			t.expect(c.speed > 14 and c.speed < 21).toBe(true)
			t.expect(EscapeRun.collapseFront(0)).toBe(c.from)
			t.expect(EscapeRun.collapseFront(100)).toBe(c.to)
		end)

		t.it("catches only who is behind it in the corridor", function()
			t.expect(EscapeRun.caught(60, 50, 2)).toBe(true)
			t.expect(EscapeRun.caught(60, 70, 2)).toBe(false)
			t.expect(EscapeRun.caught(60, 50, 20)).toBe(false)
			t.expect(EscapeRun.caught(106, 150, 1)).toBe(false)
		end)

		t.it("slams side doors behind, never the door on the path", function()
			t.expect(EscapeRun.shouldSlam(40, 7.5, 46)).toBe(true)
			t.expect(EscapeRun.shouldSlam(40, 7.5, 42)).toBe(false)
			t.expect(EscapeRun.shouldSlam(40, 1, 60)).toBe(false)
			t.expect(EscapeRun.shouldSlam(40, 30, 60)).toBe(false)
		end)
	end,
}

return spec
