--!strict
local TestKit = require("../TestKit")
return {
	name = "ForestNavigation",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		t.it("forest objectives, shelters and rescue have walkable player and creature routes", function()
			local Builder = require("@game/ServerScriptService/Server/World/ForestBuilder")
			local HouseBuilder = require("@game/ServerScriptService/Server/World/HouseBuilder")
			local Plan = require("@game/ServerScriptService/Server/Campaign/ForestPlan")
			local fixture = Instance.new("Folder")
			fixture.Name, fixture.Parent = "ForestNavigationFixture", workspace
			local ok, failure = pcall(function()
				local world, features = HouseBuilder.build(fixture)
				local forest = Builder.build(world.root, 8, 42, features)
				local offset = Vector3.new(6000, 0, 0)
				for _, part in world.root:GetDescendants() do
					if part:IsA("BasePart") then
						part.CFrame += offset
					end
				end
				task.wait(2)
				local count = 0
				for id in features.lockers do
					if string.sub(id, 1, 12) == "hide_Forest_" then
						count += 1
					end
				end
				t.expect(count).toBe(6)
				for _, radius in { 1.2, 2 } do
					local function route(a: Vector3, b: Vector3)
						local path = game:GetService("PathfindingService")
							:CreatePath({ AgentRadius = radius, AgentHeight = 6, AgentCanJump = false })
						path:ComputeAsync(a + offset, b + offset)
						assert(
							path.Status == Enum.PathStatus.Success,
							`Forest route blocked: {a} -> {b}, radius={radius}`
						)
					end
					for chapter = 6, 8 do
						for _, spec in Plan.create(42, chapter, 2, "Story").activities do
							route(Vector3.new(0, 3, 580), Vector3.new(spec.x, 3, spec.z + 5))
						end
					end
					for id, locker in features.lockers do
						if string.sub(id, 1, 12) == "hide_Forest_" then
							route(Vector3.new(0, 3, 580), locker.front + Vector3.new(0, 3, 0))
						end
					end
					route(Vector3.new(0, 3, 580), Vector3.new(0, 3, 870))
				end
				t.expect(forest:FindFirstChild("RescueVan") ~= nil).toBe(true)
				Builder.clear(world.root, features)
				t.expect(world.root:FindFirstChild("Forest")).toBe(nil)
				t.expect(features.lockers.hide_Forest_1).toBe(nil)
			end)
			fixture:Destroy()
			if not ok then
				error(tostring(failure), 0)
			end
		end)
	end,
} :: TestKit.Spec
