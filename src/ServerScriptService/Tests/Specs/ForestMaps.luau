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

		t.it("no tree grows on a task, in front of a shelter or on the trail", function()
			for chapter = 6, 8 do
				local map = ForestMaps.get(chapter)
				if not map then
					continue
				end
				for _, mode in { "Story", "Standard" } do
					for _, activity in Plan.create(3, chapter, 2, mode).activities do
						t.expect(ForestMaps.treeAllowed(map, activity.x, activity.z)).toBe(false)
					end
				end
				for _, hide in map.hides do
					t.expect(ForestMaps.treeAllowed(map, hide.x, hide.z + 6)).toBe(false)
				end
				for _, point in map.trail do
					t.expect(ForestMaps.treeAllowed(map, point.x, point.z)).toBe(false)
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

		t.it("hill tasks and shelters stand on the ground, the tower top on its floor", function()
			local map = ForestMaps.get(8)
			assert(map and map.hill and map.tower, "tower map missing")
			local tower = map.tower
			for seed = 1, 10 do
				for _, mode in { "Story", "Standard" } do
					for _, activity in Plan.create(seed, 8, 2, mode).activities do
						if activity.room == "TowerTop" then
							t.expect(activity.y).toBe(tower.floor)
							t.expect(math.abs(activity.x - tower.x) < tower.size / 2 - 1).toBe(true)
							t.expect(math.abs(activity.z - tower.z) < tower.size / 2 - 1).toBe(true)
						else
							t.expect(
								math.abs((activity.y or 0) - ForestMaps.groundHeight(map, activity.x, activity.z)) < 0.6
							)
								.toBe(true)
						end
					end
				end
			end
			for _, hide in map.hides do
				t.expect(math.abs(hide.y - ForestMaps.groundHeight(map, hide.x, hide.z)) < 0.6).toBe(true)
			end
			-- A estrada da van (onde a cena final filma) é plana; a encosta não tem degrau.
			t.expect(ForestMaps.groundHeight(map, 0, 850)).toBe(0)
			-- Câmeras da cena final (ForestCinema) livres de árvore.
			for _, spot in { { -20, 850 }, { -14, 859 }, { 13, 846 }, { 0, 853 }, { -7, 830 }, { 7, 830 } } do
				t.expect(ForestMaps.treeAllowed(map, spot[1], spot[2])).toBe(false)
			end
			t.expect(ForestMaps.groundHeight(map, map.hill.x, map.hill.z)).toBe(map.hill.top)
			local steepest = 0
			for d = map.hill.r0, map.hill.r1, 1 do
				local a = ForestMaps.groundHeight(map, map.hill.x + d, map.hill.z)
				local b = ForestMaps.groundHeight(map, map.hill.x + d + 1, map.hill.z)
				steepest = math.max(steepest, a - b)
			end
			t.expect(steepest < 0.7).toBe(true)
		end)
	end,
}

return spec
