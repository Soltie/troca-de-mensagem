--!strict
-- Rotas reais (PathfindingService) no mapa construído: o jogador e O Vigia alcançam todas as áreas.
-- Só roda no Studio, com o mapa no Workspace (servidor, durante o Play).
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "Navigation",
	robloxOnly = true,
	run = function(t)
		local PathfindingService = game:GetService("PathfindingService")
		local Config = require("@game/ReplicatedStorage/Shared/Config")
		local Layout = require("@game/ServerScriptService/Server/World/Layout")

		if workspace:FindFirstChild("Substation9") == nil then
			t.it("needs the built map (run during Play)", function() end)
			return
		end

		local function point(p: Layout.Point): Vector3
			return Vector3.new(p.x, 0, p.z)
		end

		local agents: { [string]: { [string]: any } } = {
			creature = {
				AgentRadius = Config.Creature.AgentRadius,
				AgentHeight = Config.Creature.AgentHeight,
				AgentCanJump = false,
				Costs = { Door = 2 },
			},
			player = { AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false, Costs = { Door = 2 } },
		}

		-- Uma nova tentativa após 1 s: logo após o build a malha de navegação pode estar incompleta.
		local function reachable(params: { [string]: any }, from: Vector3, to: Vector3): boolean
			for attempt = 1, 2 do
				local path = PathfindingService:CreatePath(params)
				local ok = pcall(function()
					path:ComputeAsync(from, to)
				end)
				if ok and path.Status == Enum.PathStatus.Success then
					return true
				end
				if attempt == 1 then
					task.wait(1)
				end
			end
			return false
		end

		local spawn = point(Layout.Spawn.position)

		for name, params in agents do
			t.it(`{name}: spawn reaches every room, fuse spot, note, panel and gate`, function()
				local targets: { [string]: Vector3 } = {}
				for index, node in Layout.PatrolNodes do
					local room = Layout.roomAt(node.x, node.z)
					targets[`{if room then room.id else "?"}#{index}`] = point(node)
				end
				for id, stands in Layout.FuseStands do
					for index, stand in stands do
						targets[`{id}#{index}`] = point(stand)
					end
				end
				for id, stand in Layout.Stands do
					targets[id] = point(stand)
				end
				local failed = {}
				for label, target in targets do
					if not reachable(params, spawn, target) then
						table.insert(failed, label)
					end
				end
				table.sort(failed)
				if #failed > 0 then
					error(`unreachable: {table.concat(failed, ", ")}`)
				end
			end)
		end

		-- Pontos do polish (World/Features): armários, chave, pilhas, disjuntores e procedimento.
		t.it("player: spawn reaches every polish feature stand", function()
			local Features = require("@game/ServerScriptService/Server/World/Features")
			local targets: { [string]: Vector3 } = {
				breakers = point(Features.Breakers.stand),
				note_breakers = point(Features.BreakerNote.stand),
			}
			for _, locker in Features.Lockers do
				targets[locker.id] = point(locker.stand)
			end
			for _, list in { Features.KeySpots, Features.BatterySpots } do
				for _, spot in list do
					targets[spot.id] = point(spot.stand)
				end
			end
			local failed = {}
			for label, target in targets do
				if not reachable(agents.player, spawn, target) then
					table.insert(failed, label)
				end
			end
			table.sort(failed)
			if #failed > 0 then
				error(`unreachable: {table.concat(failed, ", ")}`)
			end
		end)

		-- Duto de cabos. No R15 deste jogo só raiz e torso colidem (a cabeça não), então o teste usa
		-- as caixas de colisão reais do corpo: agachado (HipHeight baixo) cabe; de pé bate no lintel.
		-- O pathfinding não serve para o agachado (grade de 4 studs fecha um vão de 3,4).
		t.it("crawl duct: crouched body fits, standing body is blocked, creature goes around", function()
			local Features = require("@game/ServerScriptService/Server/World/Features")
			local crawl = Features.Crawl
			local params = OverlapParams.new()
			params.RespectCanCollide = true
			local exclude: { Instance } = {}
			for _, player in game:GetService("Players"):GetPlayers() do
				if player.Character then
					table.insert(exclude, player.Character)
				end
			end
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = exclude
			-- Extensão vertical do corpo que colide (base da raiz até o topo do torso).
			local standing = { bottom = 1.75, top = 3.7 }
			local crouched = { bottom = 0.25, top = 2.15 }
			local function clear(body: { bottom: number, top: number }): boolean
				local height = body.top - body.bottom
				for x = crawl.wallX - 2, crawl.wallX + 2, 0.5 do
					local center = Vector3.new(x, body.bottom + height / 2, crawl.centerZ)
					if #workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(1, height, 2), params) > 0 then
						return false
					end
				end
				return true
			end
			t.expect(clear(crouched)).toBe(true)
			t.expect(clear(standing)).toBe(false)
			t.expect(crawl.top > crouched.top + 0.4).toBe(true) -- folga para a câmera agachada

			local path = PathfindingService:CreatePath(agents.creature)
			local ok = pcall(function()
				path:ComputeAsync(point(crawl.standGenerator), point(crawl.standStorage))
			end)
			t.expect(ok and path.Status == Enum.PathStatus.Success).toBe(true) -- contorna pelas portas
			for _, waypoint in path:GetWaypoints() do
				local p = waypoint.Position
				local inside = math.abs(p.X - crawl.wallX) < 1 and math.abs(p.Z - crawl.centerZ) < crawl.width / 2
				t.expect(inside).toBe(false)
			end
		end)

		t.it("creature: patrol route is fully connected", function()
			local nodes = Layout.PatrolNodes
			local failed = {}
			for i = 1, #nodes do
				local a = point(nodes[i])
				local b = point(nodes[i % #nodes + 1])
				if not reachable(agents.creature, a, b) then
					table.insert(failed, `{i}->{i % #nodes + 1}`)
				end
			end
			if #failed > 0 then
				error(`broken legs: {table.concat(failed, ", ")}`)
			end
		end)

		t.it("player and creature can circle the annexes with the original building blocked", function()
			-- Bloqueio temporário prova que a rota alternativa não depende de cortar pelo núcleo.
			local b = Layout.Building
			local blocker = Instance.new("Part")
			blocker.Name = "NavigationTest_CoreBlocker"
			blocker.Anchored = true
			blocker.Transparency = 1
			blocker.Size = Vector3.new(b.x1 - b.x0, Layout.CEILING, b.z1 - b.z0)
			blocker.Position = Vector3.new((b.x0 + b.x1) / 2, Layout.CEILING / 2, (b.z0 + b.z1) / 2)
			blocker.Parent = workspace
			local ok, message = pcall(function()
				task.wait(1)
				local route = {
					Vector3.new(-54, 0, 12),
					Vector3.new(-54, 0, -22),
					Vector3.new(-54, 0, -64),
					Vector3.new(-20, 0, -64),
					Vector3.new(24, 0, -64),
					Vector3.new(56, 0, -64),
					Vector3.new(56, 0, -22),
					Vector3.new(56, 0, 12),
				}
				for name, params in agents do
					for i, from in route do
						if not reachable(params, from, route[i % #route + 1]) then
							error(`{name}: annex bypass blocked at leg {i}`)
						end
					end
				end
			end)
			blocker:Destroy()
			if not ok then
				error(tostring(message))
			end
		end)

		t.it("closed gate prevents escape around the expanded perimeter", function()
			local gate = workspace.Substation9.Exterior.Gate.Mesh :: BasePart
			local saved = gate.CFrame
			gate.CFrame = CFrame.new(Layout.Gate.x, Layout.Gate.height / 2, Layout.Gate.z - 0.6)
			local ok, message = pcall(function()
				task.wait(1)
				for _, x in { -54, 0, 56 } do
					if reachable(agents.player, Vector3.new(x, 0, 12), Vector3.new(0, 0, 56)) then
						error(`escape bypasses closed gate from x={x}`)
					end
				end
			end)
			gate.CFrame = saved
			if not ok then
				error(tostring(message))
			end
		end)
	end,
}

return spec
