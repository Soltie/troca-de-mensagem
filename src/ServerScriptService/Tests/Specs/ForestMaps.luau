--!strict
local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local Plan = require("@game/ServerScriptService/Server/Campaign/ForestPlan")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "ForestMaps",
	run = function(t)
		t.it("every task, shelter and dock of the new maps is on dry land", function()
			for chapter = 6, 8 do
				local map = ForestMaps.get(chapter)
				if not map then
					continue
				end
				for seed = 1, 10 do
					for _, mode in { "Story", "Standard" } do
						for _, activity in Plan.create(seed, chapter, 2, mode).activities do
							t.expect(ForestMaps.inLake(map, activity.x, activity.z)).toBe(false)
							t.expect(ForestMaps.inRavine(map, activity.x, activity.z)).toBe(false)
						end
					end
				end
				for _, hide in map.hides do
					t.expect(ForestMaps.inLake(map, hide.x, hide.z)).toBe(false)
					t.expect(ForestMaps.inLake(map, hide.x, hide.z + 6)).toBe(false)
				end
			end
		end)

		t.it("the lake is water around a dry island and a dry sandbar to the north", function()
			local map = ForestMaps.get(7)
			assert(map and map.lake, "lake map missing")
			local l = map.lake
			t.expect(ForestMaps.inLake(map, l.cx - 60, l.cz)).toBe(true)
			t.expect(ForestMaps.inLake(map, l.island.x, l.island.z)).toBe(false)
			t.expect(ForestMaps.inLake(map, 39, 773.5)).toBe(false)
			t.expect(ForestMaps.inLake(map, 0, 600)).toBe(false)
			t.expect(ForestMaps.treeAllowed(map, -60, 732)).toBe(false)
		end)
	end,
}

return spec
