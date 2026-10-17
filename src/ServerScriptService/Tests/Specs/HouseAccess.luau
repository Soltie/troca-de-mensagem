--!strict
local TestKit = require("../TestKit")
return {
	name = "HouseAccess",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		t.it("sealed routes cannot be bypassed through rooms, stairs or the garden", function()
			local fixture = Instance.new("Folder")
			fixture.Parent = workspace
			fixture.Name = "AccessFixture"
			local ok, failure = pcall(function()
				local Builder = require("@game/ServerScriptService/Server/World/HouseBuilder")
				local Access = require("@game/ServerScriptService/Server/World/HouseAccess")
				local Estate = require("@game/ServerScriptService/Server/World/HouseLevelBuilder")
				local Level = require("@game/ServerScriptService/Server/Campaign/HouseLevelPlan")
				local world = Builder.build(fixture)
				Estate.build(world.root, Level.create(42, 1, "Standard"))
				local offset = Vector3.new(1800, 0, 0)
				for _, part in world.root:GetDescendants() do
					if part:IsA("BasePart") then
						part.CFrame += offset
					end
				end
				task.wait(1)
				local function route(a: Vector3, b: Vector3): boolean
					local path = game:GetService("PathfindingService")
						:CreatePath({ AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false })
					path:ComputeAsync(a + offset, b + offset)
					return path.Status == Enum.PathStatus.Success
				end
				t.expect(route(Vector3.new(0, 0, 2), Vector3.new(-26, 0, -68))).toBe(false)
				t.expect(route(Vector3.new(0, 0, 2), Vector3.new(0, 16, 2))).toBe(false)
				t.expect(route(Vector3.new(0, 0, 2), Vector3.new(0, -16, 2))).toBe(false)
				t.expect(route(Vector3.new(0, -16, 2), Vector3.new(-26, -16, -68))).toBe(false)
				t.expect(route(Vector3.new(58, 0, 77), Vector3.new(0, 0, 110))).toBe(false)
				local gates = world.root:FindFirstChild("MissionGates")
				assert(gates, "Missing gates")
				for _, gate in gates:GetChildren() do
					if gate:IsA("BasePart") then
						gate.CanCollide, gate.CanQuery = false, false
					end
				end
				Access.refresh(world.root)
				world.gate.model:PivotTo(world.gate.openPivot + offset)
				task.wait(1)
				t.expect(route(Vector3.new(0, 0, 2), Vector3.new(-26, 0, -68))).toBe(true)
				t.expect(route(Vector3.new(0, 0, 2), Vector3.new(0, 16, 2))).toBe(true)
				t.expect(route(Vector3.new(0, 0, 2), Vector3.new(0, -16, 2))).toBe(true)
				t.expect(route(Vector3.new(0, -16, 2), Vector3.new(-26, -16, -68))).toBe(true)
				t.expect(route(Vector3.new(58, 0, 77), Vector3.new(0, 0, 110))).toBe(true)
				local rays = RaycastParams.new()
				rays.FilterType = Enum.RaycastFilterType.Include
				rays.FilterDescendantsInstances = { world.root }
				rays.RespectCanCollide = true
				for _, y in { -12, 4, 20, 36 } do
					for _, z in { -80, -48, -16 } do
						for _, side in { -1, 1 } do
							assert(
								workspace:Raycast(
									Vector3.new(side * 42, y, z) + offset,
									Vector3.new(side * 6, 0, 0),
									rays
								),
								"Missing side wall"
							)
						end
					end
				end
			end)
			fixture:Destroy()
			assert(ok, tostring(failure))
		end)
	end,
} :: TestKit.Spec
