--!strict
-- Geometria real em nove sorteios; fixture isolada nunca substitui a ala da partida em andamento.
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "ProceduralNavigation",
	robloxOnly = true,
	run = function(t)
		local PathfindingService = game:GetService("PathfindingService")
		local Config = require("@game/ReplicatedStorage/Shared/Config")
		local Layout = require("@game/ServerScriptService/Server/World/ProceduralLayout")
		local Builder = require("@game/ServerScriptService/Server/World/SectorBuilder")
		local agents = {
			player = { AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false },
			creature = {
				AgentRadius = Config.Creature.AgentRadius,
				AgentHeight = Config.Creature.AgentHeight,
				AgentCanJump = false,
			},
		}
		for _, seed in { 1, 42, 9182 } do
			for stage = 1, 3 do
				t.it(
					`seed {seed} stage {stage}: all rooms reachable, walls match graph, circulation stays clear`,
					function()
						local fixture = Instance.new("Folder")
						fixture.Name = "ProceduralNavigationFixture"
						fixture.Parent = workspace
						local ok, reason = pcall(function()
							local plan = Layout.create(seed, stage)
							local root = Builder.build(fixture, plan)
							local parts = 0
							local shift = Vector3.new(400, 0, 0)
							for _, part in root:GetDescendants() do
								if part:IsA("BasePart") then
									parts += 1
									part.CFrame += shift
								end
							end
							t.expect(parts < 650).toBe(true)
							-- Fechar o lado sul da fixture: provas de acesso não podem contornar paredes pelo exterior.
							local seal = Instance.new("Part")
							seal.Anchored = true
							seal.Size = Vector3.new(84, 11, 1)
							seal.Position = Vector3.new(-6, 5.5, -78) + shift
							seal.Parent = fixture
							local rayParams = RaycastParams.new()
							rayParams.FilterType = Enum.RaycastFilterType.Include
							rayParams.FilterDescendantsInstances = { fixture }
							for _, edge in Layout.edges() do
								local a, b = plan.rooms[edge.a], plan.rooms[edge.b]
								local origin = Vector3.new(a.x, 4, a.z) + shift
								local hit = workspace:Raycast(origin, Vector3.new(b.x - a.x, 0, b.z - a.z), rayParams)
								t.expect(hit == nil).toBe(Layout.connected(plan, edge.a, edge.b))
							end
							for _, room in plan.rooms do
								local model = root:FindFirstChild(`Cell_{room.cell}`)
								assert(model, "Missing room model")
								local equipment = model:FindFirstChild("Equipment")
								assert(equipment, "Missing room equipment")
								for _, part in equipment:GetDescendants() do
									if part:IsA("BasePart") and part.CanCollide then
										local cf, size = part.CFrame, part.Size / 2
										local hx = math.abs(cf.RightVector.X) * size.X
											+ math.abs(cf.UpVector.X) * size.Y
											+ math.abs(cf.LookVector.X) * size.Z
										local hz = math.abs(cf.RightVector.Z) * size.X
											+ math.abs(cf.UpVector.Z) * size.Y
											+ math.abs(cf.LookVector.Z) * size.Z
										local dx, dz = cf.Position.X - shift.X - room.x, cf.Position.Z - room.z
										assert(
											math.abs(dx) - hx >= 4.9 and math.abs(dz) - hz >= 4.9,
											`{room.kind}/{part.Name} invades circulation`
										)
										assert(
											math.abs(dx) + hx <= 13.5 and math.abs(dz) + hz <= 13.5,
											"Equipment crosses wall"
										)
									end
								end
							end
							-- A malha do Studio precisa de um frame de física após trocar toda a fixture.
							task.wait(1)
							local x, z = Layout.center(Layout.Entrances[1])
							for name, params in agents do
								for _, room in plan.rooms do
									local path = PathfindingService:CreatePath(params)
									path:ComputeAsync(
										Vector3.new(x, 0, z) + shift,
										Vector3.new(room.x + 7, 0, room.z + 10.2) + shift
									)
									assert(
										path.Status == Enum.PathStatus.Success,
										`{name}: unreachable cell {room.cell} seed={seed} stage={stage}`
									)
								end
							end
						end)
						fixture:Destroy()
						assert(ok, tostring(reason))
					end
				)
			end
		end
		t.it("player and creature enter the built sector through both original rooms", function()
			local world = workspace:FindFirstChild("Substation9")
			assert(world, "Run during Play with world built")
			local sector = world:FindFirstChild("ProceduralSector")
			assert(sector, "Missing sector")
			for name, params in agents do
				for _, cell in Layout.Entrances do
					local x, z = Layout.center(cell)
					local path = PathfindingService:CreatePath(params)
					path:ComputeAsync(Vector3.new(x, 0, -68), Vector3.new(x, 0, z))
					assert(path.Status == Enum.PathStatus.Success, `{name}: entry {cell} blocked`)
				end
			end
		end)
	end,
}

return spec
