--!strict
local TestKit = require("../TestKit")
return {
	name = "EstateGround",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		t.it("the entire garden and foyer recess have solid ground before and after seeded estate rebuilds", function()
			local House = require("@game/ServerScriptService/Server/World/HouseBuilder")
			local Estate = require("@game/ServerScriptService/Server/World/HouseLevelBuilder")
			local Level = require("@game/ServerScriptService/Server/Campaign/HouseLevelPlan")
			local fixture = Instance.new("Folder")
			fixture.Name, fixture.Parent = "EstateGroundFixture", workspace
			local ok, reason = pcall(function()
				local world = House.build(fixture)
				local offset = Vector3.new(-6000, 0, 0)
				local rays = RaycastParams.new()
				rays.FilterType, rays.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { world.root }
				rays.RespectCanCollide = true
				for seed = 0, 3 do
					if seed > 0 then
						-- Reposiciona a fixture só depois da construção que usa coordenadas locais.
						for _, part in world.root:GetDescendants() do
							if part:IsA("BasePart") then
								part.CFrame -= offset
							end
						end
						Estate.build(world.root, Level.create(seed * 79, 3, "Standard"))
					end
					for _, part in world.root:GetDescendants() do
						if part:IsA("BasePart") then
							part.CFrame += offset
						end
					end
					for x = -107, 107, 2 do
						for z = -117, 131, 2 do
							local exterior = x < -44.5 or x > 45.5 or z < -85.5 or z > 64.5 or (x < -24.5 and z > 12.5)
							if exterior then
								local hit =
									workspace:Raycast(Vector3.new(x, 0.6, z) + offset, Vector3.new(0, -1.2, 0), rays)
								assert(hit, `Garden void at {x}/{z}, seed={seed}`)
							end
						end
						if x % 17 == 0 then
							task.wait()
						end
					end
					for _, p in { Vector3.new(-45.2, 0.6, -30), Vector3.new(45.8, 0.6, 8), Vector3.new(-34, 0.6, 38) } do
						assert(workspace:Raycast(p + offset, Vector3.new(0, -1.2, 0), rays), "Foundation seam is open")
					end
					-- O conserto não preenche o volume dos cômodos subterrâneos.
					local soil = world.root.ProgressionBarriers
					local filter = RaycastParams.new()
					filter.FilterType, filter.FilterDescendantsInstances = Enum.RaycastFilterType.Include, { soil }
					t.expect(workspace:Raycast(Vector3.new(-26, -12, -4) + offset, Vector3.new(0, 5, 0), filter))
						.toBe(nil)
				end
			end)
			fixture:Destroy()
			assert(ok, tostring(reason))
		end)
	end,
} :: TestKit.Spec
