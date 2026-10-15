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
	end,
}

return spec
