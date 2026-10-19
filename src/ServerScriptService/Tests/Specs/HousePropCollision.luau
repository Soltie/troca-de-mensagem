--!strict
local TestKit = require("../TestKit")

return {
	name = "HousePropCollision",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		local Props = require("@game/ServerScriptService/Server/World/HouseProps")
		local Builder = require("@game/ServerScriptService/Server/World/HouseBuilder")
		local Furniture = require("@game/ServerScriptService/Server/World/HouseFurniture")
		local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
		local Plans = require("@game/ServerScriptService/Server/Campaign/HousePlan")
		local Levels = require("@game/ServerScriptService/Server/Campaign/HouseLevelPlan")
		local Config = require("@game/ReplicatedStorage/Shared/Config")

		t.it("solid furniture stops a moving physics body without changing the visual mesh", function()
			local fixture = Instance.new("Folder")
			fixture.Name, fixture.Parent = "FurniturePhysicsFixture", workspace
			local ok, failure = pcall(function()
				local position = Vector3.new(3600, 0, 0)
				local floor = Instance.new("Part")
				floor.Anchored, floor.Size = true, Vector3.new(40, 1, 40)
				floor.Position, floor.Parent = position - Vector3.yAxis * 0.5, fixture
				local sofa = Props.place(fixture, "Sofa", position, Vector3.zAxis, 1, "floor")
				assert(sofa, "Missing sofa asset")
				local collider = sofa:FindFirstChild("FurnitureCollider") :: Part?
				assert(collider and collider.CanCollide and collider.Anchored, "Missing solid collider")
				t.expect(collider.CanTouch).toBe(false)
				for _, part in sofa:GetDescendants() do
					if part:IsA("MeshPart") then
						t.expect(part.CanCollide or part.CanTouch or part.CanQuery).toBe(false)
					end
				end
				local body = Instance.new("Part")
				body.Size = Vector3.new(2, 4, 2)
				local forward = collider.CFrame.LookVector
				local start = collider.Position + forward * (collider.Size.Z / 2 + 3)
				body.Position = Vector3.new(start.X, 2.1, start.Z)
				body.Parent = fixture
				body:SetNetworkOwner(nil)
				for _ = 1, 12 do
					body.AssemblyLinearVelocity = -forward * 12 + Vector3.yAxis * body.AssemblyLinearVelocity.Y
					task.wait(0.1)
				end
				local distance = (body.Position - collider.Position):Dot(forward)
				assert(distance > collider.Size.Z / 2 + 0.7, "Physics body passed through sofa")
				assert((start - body.Position):Dot(forward) > 0.7, "Physics body never approached sofa")
			end)
			fixture:Destroy()
			assert(ok, tostring(failure))
		end)

		t.it("furnished rooms keep objectives hiding exits and player/creature routes accessible", function()
			local fixture = Instance.new("Folder")
			fixture.Name, fixture.Parent = "FurnishedNavigationFixture", workspace
			local ok, failure = pcall(function()
				local world, features = Builder.build(fixture)
				Furniture.build(world.root)
				Props.build(world.root)
				local offset = Vector3.new(2400, 0, 0)
				for _, part in world.root:GetDescendants() do
					if part:IsA("BasePart") then
						part.CFrame += offset
					end
				end
				local gates = world.root:FindFirstChild("MissionGates")
				assert(gates, "Missing mission gates")
				for _, part in gates:GetChildren() do
					if part:IsA("BasePart") then
						part.CanCollide, part.CanQuery = false, false
					end
				end
				require("@game/ServerScriptService/Server/World/HouseAccess").refresh(world.root)
				local params = OverlapParams.new()
				params.FilterType = Enum.RaycastFilterType.Include
				params.FilterDescendantsInstances = { world.root.Props }
				params.RespectCanCollide = true
				for _, seed in { 1, 2, 42 } do
					for chapter = 1, 5 do
						if Levels.create(seed, chapter, "Standard").outdoor then
							continue
						end
						for _, spec in Plans.create(seed, chapter, 1, "Standard").activities do
							if spec.kind == "hide" or spec.kind == "breath" or spec.kind == "explore" then
								continue
							end
							local point = Vector3.new(spec.x, (spec.y or 0) + 3, spec.z) + offset
							for _, delta in { Vector3.zero, Vector3.new(0, 0, 5) } do
								local hits = workspace:GetPartBoundsInBox(
									CFrame.new(point + delta),
									Vector3.new(2.4, 5, 2.4),
									params
								)
								assert(#hits == 0, `Furniture obstructs task {spec.id} seed={seed} chapter={chapter}`)
							end
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
						local path = game:GetService("PathfindingService"):CreatePath(agent)
						path:ComputeAsync(Vector3.new(0, 0, 70) + offset, Vector3.new(room.x, room.y, room.z) + offset)
						assert(path.Status == Enum.PathStatus.Success, `Furniture blocks room {room.id}`)
					end
					for _, locker in features.lockers do
						local path = game:GetService("PathfindingService"):CreatePath(agent)
						path:ComputeAsync(Vector3.new(0, 0, 2) + offset, locker.front + offset)
						assert(path.Status == Enum.PathStatus.Success, `Furniture blocks hiding exit {locker.id}`)
					end
				end
			end)
			fixture:Destroy()
			assert(ok, tostring(failure))
		end)
	end,
} :: TestKit.Spec
