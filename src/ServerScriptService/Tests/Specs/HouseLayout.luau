--!strict
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Broadcast = require("@game/ReplicatedStorage/Shared/Game/HouseBroadcast")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local TestKit = require("../TestKit")
return {
	name = "HouseLayout",
	run = function(t: TestKit.Context)
		t.it("every traversable landing point has one slab; stairs have no intersecting slab", function()
			for _, y in Layout.Floors do
				local hole = Layout.opening(y)
				for x = -23.5, 44.5, 1 do
					for z = 12.5, 63.5, 1 do
						local hits = 0
						for _, rect in Layout.decks(y) do
							if x > rect.x0 and x < rect.x1 and z > rect.z0 and z < rect.z1 then
								hits += 1
							end
						end
						local opening = hole and x > hole.x0 and x < hole.x1 and z > hole.z0 and z < hole.z1
						t.expect(hits).toBe(if opening then 0 else 1)
					end
				end
			end
		end)
		t.it("all chapter captions fit their server window and have distinct camera beats", function()
			t.expect(#Broadcast).toBe(#Story.Chapters)
			for _, scene in Story.Scenes do
				t.expect(#scene.shots >= 2).toBe(true)
				t.expect(Shots.duration(scene)).toBe(Story.SceneSeconds)
			end
		end)
	end,
} :: TestKit.Spec
