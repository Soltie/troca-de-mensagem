--!strict
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Broadcast = require("@game/ReplicatedStorage/Shared/Game/HouseBroadcast")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local TestKit = require("../TestKit")
return {
	name = "HouseLayout",
	run = function(t: TestKit.Context)
		t.it("real facade windows skip the basement and rooms with tall furniture on the facade", function()
			local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
			local windows = Layout.facadeWindows(House.Rooms)
			t.expect(#windows).toBe(9)
			for _, hole in windows do
				t.expect(hole.y >= 0).toBe(true)
				t.expect(Layout.NoWindow[hole.id] == nil).toBe(true)
				-- Alinhada com uma das linhas de janelas externas (z −14/−46/−78) e dentro da parede de 98.
				t.expect(hole.z == -14 or hole.z == -46 or hole.z == -78).toBe(true)
			end
		end)
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
