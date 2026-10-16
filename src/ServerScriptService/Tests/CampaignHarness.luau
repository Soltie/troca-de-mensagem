--!strict
-- Harness opt-in do StudioTestService: clientes reais pedem interações pelos remotes normais.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local StudioTestService = game:GetService("StudioTestService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CreatureService = require("../Server/Services/CreatureService")
local PathfindingService = game:GetService("PathfindingService")
local log = Logger.new("CampaignQA")
local Harness = {}

function Harness.run(runtime: any, args: any)
	assert(RunService:IsStudio(), "Campaign harness is Studio-only")
	local expected = args.players
	local checks = {}
	local spawnPositions = {}
	local completed = false
	local commandId = 0
	local previousSector: Instance? = nil
	local previousMap = ""
	local function mapSignature(plan: any): string
		local signature = {}
		for _, room in plan.rooms do
			table.insert(signature, `{room.kind}:{room.turn}`)
		end
		for _, edge in plan.links do
			table.insert(signature, `{edge.a}-{edge.b}`)
		end
		return table.concat(signature, "/")
	end
	local deadline = os.clock() + 220
	task.delay(230, function()
		if not completed then
			StudioTestService:EndTest({ success = false, error = "watchdog timeout", players = expected })
		end
	end)
	task.spawn(function()
		while not completed do
			CreatureService.setFrozen(true)
			task.wait(0.1)
		end
	end)
	local function waitFor(predicate: () -> boolean, label: string, timeout: number?)
		local untilTime = math.min(deadline, os.clock() + (timeout or 12))
		repeat
			if predicate() then
				return
			end
			task.wait(0.1)
		until os.clock() >= untilTime
		error(`timeout: {label}`, 0)
	end
	local function check(value: boolean, label: string)
		assert(value, label)
		table.insert(checks, label)
		log.info("PASS %s", label)
	end
	local function teleport(player: Player, position: Vector3)
		local character = player.Character
		assert(character, "QA character missing")
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Anchored = true
		character:PivotTo(CFrame.new(position))
		task.wait(0.25)
		root.Anchored = false
	end
	local function request(player: Player, id: string)
		commandId += 1
		player:SetAttribute("CampaignQARequest", HttpService:JSONEncode({ serial = commandId, id = id }))
	end
	local ok, reason = pcall(function()
		waitFor(function()
			return #Players:GetPlayers() == expected
		end, "all clients connected", 35)
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			return a.UserId < b.UserId
		end)
		-- O lobby normal inicia com 3+. O setup de carga forma o lote inteiro antes da campanha medida.
		if runtime.snapshot().stage ~= 0 or runtime.snapshot().active ~= expected then
			runtime.restart()
		end
		waitFor(function()
			local s = runtime.snapshot()
			return s.stage == 1 and not s.building and s.phase == "Playing"
		end, "first stage", 60)
		check(#players == expected and runtime.snapshot().players == expected, `{expected} real clients in roster`)
		local firstSeed = runtime.snapshot().seed
		local firstMap = mapSignature(runtime.snapshot().plan.sector)
		runtime.restart()
		waitFor(function()
			local s = runtime.snapshot()
			return s.stage == 1 and not s.building and s.phase == "Playing"
		end, "fresh match rebuild", 60)
		if Config.Campaign.Seed == nil then
			check(runtime.snapshot().seed ~= firstSeed, "new match receives a new seed")
			check(mapSignature(runtime.snapshot().plan.sector) ~= firstMap, "new match changes physical map")
		end
		for _, player in players do
			waitFor(function()
				return player.Character ~= nil
			end, "character spawned")
			local p = (player.Character :: Model):GetPivot().Position
			table.insert(spawnPositions, { id = player.UserId, position = { p.X, p.Y, p.Z } })
		end
		for i, a in players do
			for j = i + 1, #players do
				local b = players[j]
				check(
					((a.Character :: Model):GetPivot().Position - (b.Character :: Model):GetPivot().Position).Magnitude
						> 2,
					`separate spawn {i}-{j}`
				)
			end
		end
		-- Uma captura real na API do runtime deve deixar os outros ativos; resgate passa pelo remote.
		runtime.lose(players[1])
		check(runtime.snapshot().phase == "Playing" and runtime.snapshot().downed == 1, "capture is individual")
		local rescue = workspace.Substation9:FindFirstChild(`Rescue_{players[1].UserId}`) :: BasePart
		assert(rescue, "QA rescue beacon missing")
		teleport(players[2], rescue.Position + Vector3.new(0, -3.2, 3))
		request(players[2], `rescue_{players[1].UserId}`)
		waitFor(function()
			return runtime.snapshot().downed == 0
		end, "remote rescue", 12)
		check(runtime.snapshot().members[players[1].UserId].status == "Active", "teammate rescued by another client")
		local firstTask = runtime.snapshot().plan.activities[1]
		teleport(players[1], Vector3.new(0, 3.2, 30))
		request(players[1], `{firstTask.id}_1`)
		waitFor(function()
			return players[1]:GetAttribute("CampaignFeedback") == "too_far"
		end, "distant request rejected")
		check(
			runtime.snapshot().tasks[firstTask.id].progress == 0,
			"server rejects a valid remote used from too far away"
		)
		local departed = players[#players]
		check(departed.UserId < 0, "disconnect target is a simulated Studio client")
		departed:Kick("Campaign QA: simulated disconnect")
		waitFor(function()
			return runtime.snapshot().players == expected - 1
		end, "disconnect applied")
		check(runtime.snapshot().phase == "Playing", "disconnect preserves the remaining team's stage")
		StudioTestService:AddPlayers(1)
		waitFor(function()
			return #Players:GetPlayers() == expected and runtime.snapshot().players == expected
		end, "late client joins", 40)
		local incoming: Player? = nil
		for _, candidate in Players:GetPlayers() do
			if not table.find(players, candidate) then
				incoming = candidate
			end
		end
		assert(incoming, "Late client missing")
		check(
			runtime.snapshot().members[incoming.UserId].status == "Waiting",
			"late join waits without changing current puzzles"
		)
		for stageIndex = 1, 3 do
			waitFor(function()
				local s = runtime.snapshot()
				return s.stage == stageIndex and not s.building and s.phase == "Playing"
			end, `stage {stageIndex} start`, 20)
			local snapshot = runtime.snapshot()
			check(snapshot.plan.players == expected, `stage {stageIndex} scales to party`)
			players = {}
			for _, candidate in Players:GetPlayers() do
				if snapshot.members[candidate.UserId].status == "Active" then
					table.insert(players, candidate)
				end
			end
			table.sort(players, function(a, b)
				return a.UserId < b.UserId
			end)
			if stageIndex == 2 then
				check(#players == expected, "late join becomes active at the next stage")
			end
			local plan = snapshot.plan
			local sector = workspace.Substation9:FindFirstChild("ProceduralSector")
			assert(sector, "Generated sector missing")
			check(
				sector:GetAttribute("Seed") == plan.seed and sector:GetAttribute("Stage") == stageIndex,
				`stage {stageIndex} builds its seeded physical map`
			)
			if previousSector then
				check(
					previousSector.Parent == nil and previousSector ~= sector,
					`stage {stageIndex} destroys the old sector`
				)
				check(mapSignature(plan.sector) ~= previousMap, `stage {stageIndex} changes rooms and routes`)
			end
			for _, room in plan.sector.rooms do
				local model = sector:FindFirstChild(`Cell_{room.cell}`)
				assert(model and model:GetAttribute("RoomKind") == room.kind, "Physical room differs from plan")
			end
			previousSector, previousMap = sector, mapSignature(plan.sector)
			for _, activity in plan.activities do
				for name, params in
					{
						player = { AgentRadius = 1.2, AgentHeight = 5, AgentCanJump = false, Costs = { Door = 2 } },
						creature = {
							AgentRadius = Config.Creature.AgentRadius,
							AgentHeight = Config.Creature.AgentHeight,
							AgentCanJump = false,
							Costs = { Door = 2 },
						},
					}
				do
					local path = PathfindingService:CreatePath(params)
					path:ComputeAsync(Vector3.new(14, 0, 34), Vector3.new(activity.x, 0, activity.z + 3.2))
					check(path.Status == Enum.PathStatus.Success, `stage {stageIndex} {name} reaches {activity.slot}`)
				end
			end
			for index, activity in plan.activities do
				local owner = players[(index - 1) % #players + 1]
				local function press(player: Player, button: number)
					local before = runtime.snapshot().tasks[activity.id].progress
					local station = workspace.Substation9.CampaignActivities:FindFirstChild(activity.id)
					assert(station, "QA station missing")
					local focus = station:FindFirstChild(`{activity.id}_{button}`) :: BasePart
					assert(focus, "QA station button missing")
					teleport(player, Vector3.new(focus.Position.X, 3.2, focus.Position.Z + 3.2))
					task.wait(Config.Campaign.ActionCooldown + 0.1)
					request(player, `{activity.id}_{button}`)
					waitFor(function()
						local s = runtime.snapshot()
						return s.tasks[activity.id].progress ~= before or s.tasks[activity.id].solved
					end, `remote {activity.id}/{button}`, 6)
				end
				if activity.kind == "sequence" then
					for _, button in activity.order do
						press(owner, button)
					end
				elseif activity.kind == "relay" then
					press(owner, 1)
					local helper = players[index % #players + 1]
					press(helper, 1)
				else
					for _ = 1, 3 do
						if runtime.snapshot().tasks[activity.id].solved then
							break
						end
						press(owner, 1)
					end
				end
				check(
					runtime.snapshot().tasks[activity.id].solved,
					`stage {stageIndex} task {index} solved through client remote`
				)
			end
			check(
				runtime.snapshot().phase == (if stageIndex == 3 then "Extracting" else "Intermission"),
				`stage {stageIndex} completes`
			)
		end
		teleport(players[1], Vector3.new(0, 3.2, 52))
		waitFor(function()
			return runtime.snapshot().members[players[1].UserId].status == "Escaped"
		end, "first survivor exits")
		check(runtime.snapshot().phase == "Extracting", "first survivor does not end others' game")
		for index = 2, #players do
			teleport(players[index], Vector3.new(0, 3.2, 52))
		end
		waitFor(function()
			return runtime.snapshot().phase == "Won"
		end, "team extraction")
		check(runtime.snapshot().phase == "Won", "team wins after all survivors extract")
	end)
	completed = true
	local result = {
		success = ok,
		error = if ok then nil else tostring(reason),
		players = expected,
		spawnPositions = spawnPositions,
		checks = checks,
		stage = runtime.snapshot().stage,
		phase = runtime.snapshot().phase,
		seed = runtime.snapshot().seed,
	}
	log.info("RESULT %s", HttpService:JSONEncode(result))
	StudioTestService:EndTest(result)
end

return Harness
