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
