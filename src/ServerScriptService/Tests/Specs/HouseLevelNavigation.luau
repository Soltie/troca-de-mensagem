--!strict
local TestKit = require("../TestKit")
return {
	name = "HouseLevelNavigation",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		local Levels = require("@game/ServerScriptService/Server/Campaign/HouseLevelPlan")
		local Builder = require("@game/ServerScriptService/Server/World/HouseBuilder")
		local Estate = require("@game/ServerScriptService/Server/World/HouseLevelBuilder")
		local Plans = require("@game/ServerScriptService/Server/Campaign/HousePlan")
		local Activities = require("@game/ServerScriptService/Server/Campaign/HouseActivities")
		local Config = require("@game/ReplicatedStorage/Shared/Config")
		t.it("player and creature reach all outdoor tasks including the elevated lookout without jumping", function()
			local fixture = Instance.new("Folder")
			fixture.Name, fixture.Parent = "EstateNavigationFixture", workspace
			local ok, failure = pcall(function()
				local world = Builder.build(fixture)
				local offset = Vector3.new(1200, 0, 0)
				for _, seed in { 1, 2, 42 } do
					local level = Levels.create(seed, 3, "Standard")
					Estate.build(world.root, level)
					local built = Activities.build(world.root, Plans.create(seed, 3, 2, "Standard"), 8)
					-- Mantém a fixture afastada do mapa real e retorna antes da próxima reconstrução.
					for _, part in world.root:GetDescendants() do
						if part:IsA("BasePart") then
							part.CFrame += offset
						end
					end
					task.wait(1)
					for _, agent in
						{
							{ AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false },
							{
								AgentRadius = Config.Creature.AgentRadius,
								AgentHeight = Config.Creature.AgentHeight,
								AgentCanJump = false,
							},
						}
					do
						local stairsPath = game:GetService("PathfindingService"):CreatePath(agent)
						stairsPath:ComputeAsync(
							Vector3.new(level.stairSide * 26, 16, -80) + offset,
							Vector3.new(level.stairSide * 26, 32, -38) + offset
						)
						assert(stairsPath.Status == Enum.PathStatus.Success, "Blocked internal service stair")
						local usedStair = false
						for _, waypoint in stairsPath:GetWaypoints() do
							if waypoint.Position.Y > 21 and waypoint.Position.Y < 28 and waypoint.Position.Z < -50 then
								usedStair = true
							end
						end
						assert(usedStair, "Internal service stair was not traversed")
						for _, spot in level.spots do
							local path = game:GetService("PathfindingService"):CreatePath(agent)
							path:ComputeAsync(
								Vector3.new(0, 0, 80) + offset,
								Vector3.new(spot.x, spot.y, spot.z + 5) + offset
							)
							assert(
								path.Status == Enum.PathStatus.Success,
								`Blocked estate seed={seed} room={spot.room} height={agent.AgentHeight}`
							)
						end
					end
					local params = RaycastParams.new()
					params.FilterType = Enum.RaycastFilterType.Include
					params.FilterDescendantsInstances = { world.root }
					params.RespectCanCollide = true
					for _, spot in level.spots do
						local p = Vector3.new(spot.x, spot.y + 1, spot.z + 5) + offset
						assert(workspace:Raycast(p, -Vector3.yAxis * 2, params), `Missing estate floor: {spot.room}`)
					end
					for _, target in built.targets do
						t.expect(target.focus.CanQuery).toBe(true)
					end
					for _, part in world.root:GetDescendants() do
						if part:IsA("BasePart") then
							part.CFrame -= offset
						end
					end
				end
				Estate.build(world.root, Levels.create(42, 3, "Story"))
				local architecture = world.root:FindFirstChild("Architecture")
				assert(architecture, "Missing architecture")
				for _, wall in architecture:GetChildren() do
					if
						wall:IsA("BasePart")
						and (wall.Name == "RoomPartition" or wall:GetAttribute("LevelOriginalTransparency") ~= nil)
					then
						t.expect(wall.CanCollide and wall.CanQuery and wall.Transparency == 0).toBe(true)
					end
				end
				t.expect(world.root:GetAttribute("LevelEnvironment")).toBe("Interior")
				t.expect(#world.root:GetDescendants() < 4500).toBe(true)
			end)
			fixture:Destroy()
			assert(ok, tostring(failure))
		end)
	end,
} :: TestKit.Spec
