--!strict
-- Rotas reais em fixture isolada; não muda o mapa da campanha em andamento.
local TestKit = require("../TestKit")
return {
	name = "HouseNavigation",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		local Pathfinding = game:GetService("PathfindingService")
		local Builder = require("@game/ServerScriptService/Server/World/HouseBuilder")
		local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
		local Config = require("@game/ReplicatedStorage/Shared/Config")
		t.it("world exposes house contracts before any creature spawn", function()
			local World = require("@game/ServerScriptService/Server/Services/WorldService")
			t.expect(type(World.setHouseStage)).toBe("function")
			t.expect(type(World.houseEvent)).toBe("function")
		end)
		t.it("player and creature reach all floors rooms hiding exits and forest without jumping", function()
			local fixture = Instance.new("Folder")
			fixture.Name = "HouseNavigationFixture"
			fixture.Parent = workspace
			local ok, failure = pcall(function()
				local world, features = Builder.build(fixture)
				for _, door in world.doors do
					t.expect(math.abs(door.panel.Position.X) > 8).toBe(true)
				end
				local offset = Vector3.new(600, 0, 0)
				for _, part in world.root:GetDescendants() do
					if part:IsA("BasePart") then
						part.CFrame += offset
					end
				end
				local gates = world.root:FindFirstChild("MissionGates")
				assert(gates, "Missing house gates")
				for _, gate in gates:GetChildren() do
					if gate:IsA("BasePart") then
						gate.CanCollide, gate.CanQuery = false, false
					end
				end
				world.gate.model:PivotTo(world.gate.openPivot + offset)
				require("@game/ServerScriptService/Server/World/HouseAccess").refresh(world.root)
				-- Pathfinding não detecta uma casa visualmente aberta: medimos também a geometria física.
				local rays = RaycastParams.new()
				rays.FilterType = Enum.RaycastFilterType.Include
				rays.FilterDescendantsInstances = { world.root.Architecture }
				for _, y in { -16, 0, 16, 32 } do
					for _, x in { -7, 0, 7, 23, 42 } do
						for _, z in { 12.8, 17, 57, 62 } do
							local origin = Vector3.new(x, y + 0.6, z) + offset
							local floor = workspace:Raycast(origin, Vector3.new(0, -1.7, 0), rays)
							assert(floor, `Missing landing floor at {x}/{y}/{z}`)
						end
					end
					for _, z in { 18, 38, 61 } do
						for _, side in { -1, 1 } do
							for _, height in { 6, 15.6 } do
								local wall = workspace:Raycast(
									Vector3.new(side * 55, y + height, z) + offset,
									Vector3.new(-side * 55, 0, 0),
									rays
								)
								assert(wall, `Open stair facade at {y}/{z}/{height}`)
								local boundary = if side < 0 then -24 else 45
								assert(math.abs(wall.Position.X - offset.X - boundary) < 0.8, "Recessed exterior seam")
							end
						end
						local roof = workspace:Raycast(Vector3.new(0, y + 10, z) + offset, Vector3.new(0, 45, 0), rays)
						assert(roof, `Missing stair roof at {y}/{z}`)
					end
				end
				local Plans = require("@game/ServerScriptService/Server/Campaign/HousePlan")
				local overlap = OverlapParams.new()
				overlap.RespectCanCollide = true
				overlap.FilterType = Enum.RaycastFilterType.Include
				overlap.FilterDescendantsInstances = { world.root }
				for seed = 1, 20 do
					for chapter = 1, 5 do
						-- Exteriores têm piso/escada próprios, medidos na fixture HouseLevelNavigation.
						local Levels = require("@game/ServerScriptService/Server/Campaign/HouseLevelPlan")
						if Levels.create(seed, chapter, "Standard").outdoor then
							continue
						end
						local plan = Plans.create(seed, chapter, 1, "Standard")
						for _, spec in plan.activities do
							if spec.kind == "hide" or spec.kind == "breath" or spec.kind == "explore" then
								continue
							end
							local point = Vector3.new(spec.x, (spec.y or 0) + 3, spec.z) + offset
							local hits =
								workspace:GetPartBoundsInBox(CFrame.new(point), Vector3.new(1.4, 1, 1), overlap)
							assert(#hits == 0, `Obstructed item: seed={seed} chapter={chapter} task={spec.id}`)
							local approach = workspace:GetPartBoundsInBox(
								CFrame.new(point + Vector3.new(0, 0, 5)),
								Vector3.new(2.4, 5, 2.4),
								overlap
							)
							assert(#approach == 0, `Obstructed approach: seed={seed} chapter={chapter} task={spec.id}`)
						end
					end
				end
				task.wait(2)
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
					for _, room in House.Rooms do
						local path = Pathfinding:CreatePath(agent)
						path:ComputeAsync(Vector3.new(0, 0, 70) + offset, Vector3.new(room.x, room.y, room.z) + offset)
						assert(
							path.Status == Enum.PathStatus.Success,
							`Blocked room {room.id} agentHeight={agent.AgentHeight}`
						)
					end
					for _, locker in features.lockers do
						local path = Pathfinding:CreatePath(agent)
						path:ComputeAsync(Vector3.new(0, 0, 2) + offset, locker.front + offset)
						assert(path.Status == Enum.PathStatus.Success, `Blocked hide exit {locker.id}`)
					end
					local escape = Pathfinding:CreatePath(agent)
					escape:ComputeAsync(Vector3.new(-26, -16, -68) + offset, Vector3.new(0, 0, 106) + offset)
					assert(escape.Status == Enum.PathStatus.Success, "Ritual to forest route blocked")
				end
				t.expect(#world.root:GetDescendants() < 4000).toBe(true)
			end)
			fixture:Destroy()
			assert(ok, tostring(failure))
		end)
	end,
} :: TestKit.Spec
