--!strict
local TestKit = require("../TestKit")
return {
	name = "ForestNavigation",
	robloxOnly = true,
	run = function(t: TestKit.Context)
		t.it("forest objectives, shelters and rescue have walkable player and creature routes", function()
			-- O mapa novo usa o Terrain de verdade (não dá para deslocar): com uma floresta já montada no jogo, o teste
			-- apagaria o chão dela. Roda no lobby/casa, que é quando o runner normalmente roda.
			local live = workspace:FindFirstChild("CursedHouse")
			if live and live:FindFirstChild("Forest") then
				return
			end
			local Builder = require("@game/ServerScriptService/Server/World/ForestBuilder")
			local HouseBuilder = require("@game/ServerScriptService/Server/World/HouseBuilder")
			local Plan = require("@game/ServerScriptService/Server/Campaign/ForestPlan")
			local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
			local PathfindingService = game:GetService("PathfindingService")
			local fixture = Instance.new("Folder")
			fixture.Name, fixture.Parent = "ForestNavigationFixture", workspace
			local ok, failure = pcall(function()
				local world, features = HouseBuilder.build(fixture)
				for chapter = 6, 8 do
					local forest = Builder.build(world.root, chapter, 42, features)
					local map = assert(ForestMaps.get(chapter), "forest map missing")
					if chapter == 6 then
						Builder.event(forest, "forest_winch")
						task.wait(3)
					end
					Builder.pressure(world.root, 0, chapter, true)
					t.expect(world.root:GetAttribute("ForestBlackout")).toBe(true)
					for _, part in forest:GetChildren() do
						if part.Name == "TrailLantern" then
							local light = part:FindFirstChildWhichIsA("PointLight")
							assert(light and not light.Enabled, "Trail lamp ignores blackout")
						end
					end
					Builder.pressure(world.root, 7, chapter, true)
					t.expect(world.root:GetAttribute("ForestBlackout")).toBe(false)
					task.wait(2)
					local count = 0
					for id in features.lockers do
						if string.sub(id, 1, 12) == "hide_Forest_" then
							count += 1
						end
					end
					t.expect(count).toBe(6)
					local function route(a: Vector3, b: Vector3, radius: number, swim: boolean)
						local path = PathfindingService:CreatePath({
							AgentRadius = radius,
							AgentHeight = 6,
							AgentCanJump = false,
							Costs = if swim then nil else { Water = math.huge },
						})
						-- A malha de navegação demora a absorver um mapa recém-montado (torre, ponte): tenta de novo antes de reprovar.
						for _ = 1, 6 do
							path:ComputeAsync(a, b)
							if path.Status == Enum.PathStatus.Success then
								break
							end
							task.wait(1)
						end
						assert(
							path.Status == Enum.PathStatus.Success,
							`Forest route blocked (chapter {chapter}): {a} -> {b}, radius={radius}`
						)
					end
					local l = map.lake
					local function onIsland(x: number, z: number): boolean
						return l ~= nil and (x - l.island.x) ^ 2 + (z - l.island.z) ^ 2 < (l.island.r + 4) ^ 2
					end
					local start = Vector3.new(0, 4, 580)
					for _, radius in { 1.2, 2 } do
						for _, spec in Plan.create(42, chapter, 2, "Story").activities do
							-- Destino logo acima do piso real (terreno ou plataforma da torre, sob o telhado).
							local floor = workspace:Raycast(
								Vector3.new(spec.x, (spec.y or 0) + 6, spec.z + 3),
								Vector3.new(0, -12, 0)
							)
							local goal =
								Vector3.new(spec.x, (if floor then floor.Position.Y else spec.y or 0) + 1, spec.z + 3)
							-- A ilha do rádio só se alcança pela jangada (do cais da ilha) ou pelo banco de areia (do norte).
							local from = if l and onIsland(spec.x, spec.z)
								then Vector3.new(l.islandDock.x, 4, l.islandDock.z + 4)
								else start
							route(from, goal, radius, false)
						end
						for id, locker in features.lockers do
							if string.sub(id, 1, 12) == "hide_Forest_" then
								route(start, locker.front + Vector3.new(0, 4, 0), radius, false)
							end
						end
						route(start, Vector3.new(0, 4, 870), radius, false)
					end
					if chapter == 8 then
						t.expect(forest:FindFirstChild("RescueVan", true) ~= nil).toBe(true)
					end
				end
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
