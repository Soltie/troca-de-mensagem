--!strict
local ChapterMoments = require("@game/ReplicatedStorage/Shared/Game/ChapterMoments")
local HouseCatalog = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "ChapterMoments",
	run = function(t)
		t.it("each house chapter 1 to 4 has exactly one scripted moment on the right task", function()
			local expected = { [1] = "key_dining", [2] = "power", [3] = "mask", [4] = "artifact" }
			for stage = 1, 4 do
				local found = 0
				for index, objective in HouseCatalog.Chapters[stage].objectives do
					local moment = ChapterMoments.forTask(stage, index)
					if moment then
						found += 1
						t.expect(objective.item == expected[stage] or objective.event == expected[stage]).toBe(true)
						t.expect(ChapterMoments.Caption[moment] ~= nil).toBe(true)
						t.expect(ChapterMoments.Duration[moment] > 0).toBe(true)
					end
				end
				t.expect(found).toBe(1)
			end
			t.expect(ChapterMoments.forTask(5, 1)).toBeNil()
			t.expect(ChapterMoments.forTask(7, 2)).toBeNil()
		end)
		t.it("presence moments have a duration and are not tied to a task", function()
			for _, name in ChapterMoments.Presence do
				t.expect(ChapterMoments.isPresence(name)).toBe(true)
				t.expect(ChapterMoments.Duration[name] > 0).toBe(true)
			end
			t.expect(ChapterMoments.isPresence("blackout")).toBe(false)
		end)
	end,
}

return spec
