--!strict
local Layout = require("@game/ReplicatedStorage/Shared/Game/CatacombLayout")
local Plan = require("@game/ServerScriptService/Server/Campaign/HousePlan")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "CatacombLayout",
	run = function(t)
		t.it("opens the catacomb in chapters 4 and 5 and the chapel only in 5", function()
			for stage = 1, 8 do
				t.expect(Layout.openCatacomb(stage)).toBe(stage == 4 or stage == 5)
				t.expect(Layout.openChapel(stage)).toBe(stage == 5)
			end
		end)

		t.it("spaces chain from the house wall to the chapel and stay inside the estate", function()
			t.expect(Layout.Mouth.x1 >= Layout.Corridor.x0).toBe(true)
			t.expect(Layout.Corridor.x1 >= Layout.Catacomb.x0).toBe(true)
			t.expect(Layout.Passage.z0 <= Layout.Catacomb.z1).toBe(true)
			t.expect(Layout.Passage.z1 >= Layout.Chapel.z0).toBe(true)
			for _, box in { Layout.Corridor, Layout.Catacomb, Layout.Passage, Layout.Chapel } do
				t.expect(box.x1 < 107).toBe(true)
				-- O Tung (agente de 7,6) cabe em pé.
				t.expect(box.y1 - box.y0 >= 9.5).toBe(true)
				t.expect(box.y1 < -1).toBe(true)
			end
		end)

		t.it("the safe clue goes down to the catacomb and the altar to the chapel, in every seed and mode", function()
			for seed = 1, 15 do
				for _, mode in { "Story", "Standard" } do
					local four = Plan.create(seed, 4, 2, mode)
					t.expect((Plan.validate(four))).toBe(true)
					for _, activity in four.activities do
						if activity.item == "safe_clue" and activity.room == "Tunnel" then
							local p = { x = activity.x, y = activity.y or 0, z = activity.z }
							t.expect(Layout.inside(Layout.Catacomb, p, 2)).toBe(true)
						end
					end
					local five = Plan.create(seed, 5, 2, mode)
					t.expect((Plan.validate(five))).toBe(true)
					local first = five.activities[1]
					local p = { x = first.x, y = first.y or 0, z = first.z }
					t.expect(Layout.inside(Layout.Chapel, p, 2)).toBe(true)
				end
			end
		end)
	end,
}

return spec
