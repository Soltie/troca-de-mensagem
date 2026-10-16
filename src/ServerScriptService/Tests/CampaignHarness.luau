--!strict
-- QA opt-in: clientes reais usam remotes normais; teleporte/congelamento só preparam o cenário.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StudioTestService = game:GetService("StudioTestService")
local Creature = require("../Server/Services/CreatureService")
local Body = require("../Server/Services/PlayerStateService")
local World = require("../Server/Services/WorldService")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local log = Logger.new("HouseQA")
local Harness = {}
function Harness.run(runtime: any, args: any)
	assert(RunService:IsStudio(), "Studio-only QA")
	local done = false
	local checks: { string } = {}
	local serial = 0
	local function check(value: boolean, name: string)
		assert(value, name)
		table.insert(checks, name)
		log.info("PASS %s", name)
	end
	local function waitFor(predicate: () -> boolean, name: string, timeout: number?)
		local deadline = os.clock() + (timeout or 15)
		repeat
			if predicate() then
				return
			end
			task.wait(0.1)
		until os.clock() > deadline
		error(`Timeout: {name}`)
	end
	local function move(player: Player, position: Vector3)
		assert(player.Character, "Missing QA character")
		player.Character:PivotTo(CFrame.new(position))
		Body.markTeleported(player)
		task.wait(0.25)
	end
	local function request(player: Player, command: any): any
		serial += 1
		command.serial = serial
		local before = tonumber(player:GetAttribute("CampaignFeedbackSerial")) or 0
		player:SetAttribute("CampaignQARequest", HttpService:JSONEncode(command))
		waitFor(function()
			if command.breath ~= nil then
				return player:GetAttribute("HoldBreath") == command.breath
			end
			return (tonumber(player:GetAttribute("CampaignFeedbackSerial")) or 0) > before
		end, "client remote response")
		task.wait(0.6)
		return {
			ok = true,
			data = {
				accepted = player:GetAttribute("CampaignAccepted") == true,
				message = tostring(player:GetAttribute("CampaignFeedback")),
			},
		}
	end

	task.delay(330, function()
		if not done then
			done = true
			StudioTestService:EndTest({ success = false, error = "House QA watchdog" })
		end
	end)
	task.spawn(function()
		while not done do
			Creature.setFrozen(true)
			task.wait(0.1)
		end
	end)
	local ok, failure = pcall(function()
		waitFor(function()
			return #Players:GetPlayers() == args.players
		end, "all clients", 40)
		local players = Players:GetPlayers()
		table.sort(players, function(a, b)
			return a.UserId < b.UserId
		end)
		runtime.restart()
		waitFor(function()
			local s = runtime.snapshot()
			return s.stage == 1 and not s.building and s.active == args.players
		end, "chapter 1", 60)
		local actor = players[1]
		check(
			actor:GetAttribute("HasFlashlight") == false and actor:GetAttribute("Flashlight") == false,
			"no flashlight before collection"
		)
		local distant = request(actor, { id = "task_2_1" })
		check(distant.ok and not distant.data.accepted, "reject remote collection from forest")
		if #players >= 2 then
			runtime.lose(players[2])
			check(runtime.snapshot().downed == 1 and runtime.snapshot().phase == "Playing", "capture is individual")
			local beacon = World.get().root:FindFirstChild(`Rescue_{players[2].UserId}`) :: BasePart
			assert(beacon, "Rescue beacon missing")
			move(actor, beacon.Position + Vector3.new(0, -3, 4))
			request(actor, { id = `rescue_{players[2].UserId}` })
			waitFor(function()
				return runtime.snapshot().downed == 0
			end, "rescue", 20)
			check(players[2]:GetAttribute("CampaignStatus") == "Active", "rescue returns teammate")
		end
		for chapter = 1, 5 do
			waitFor(function()
				local s = runtime.snapshot()
				return s.stage == chapter and not s.building and s.phase == "Playing"
			end, `chapter {chapter}`, 50)
			local snapshot = runtime.snapshot()
			for _, spec in snapshot.plan.activities do
				if spec.kind == "explore" then
					move(actor, Vector3.new(spec.x, (spec.y or 0) + 3.2, spec.z))
				elseif spec.kind == "hide" then
					local locker = World.locker("hide_Library")
					assert(locker, "Tutorial hide missing")
					move(actor, locker.front + Vector3.new(0, 3, 0))
					local result = request(actor, { id = "hide_Library" })
					check(result.ok and result.data.accepted, "enter physical hide through remote")
				elseif spec.kind == "breath" then
					request(actor, { breath = true })
				else
					for _, button in (if spec.kind == "puzzle" then spec.order else { 1 }) do
						local model = (World.get().root:FindFirstChild("CampaignActivities") :: Folder):FindFirstChild(
							spec.id
						)
						local target = model and model:FindFirstChild(`{spec.id}_{button}`) :: BasePart
						assert(target, "Objective target missing")
						move(actor, target.Position + Vector3.new(0, 1.4, 5))
						local result = request(actor, { id = target.Name })
						check(
							result.ok and result.data.accepted,
							`chapter {chapter} {spec.id} button {button}: {result.data.message}`
						)
					end
				end
				waitFor(function()
					return runtime.snapshot().tasks[spec.id].solved
				end, `solve {spec.id}`)
				if spec.kind == "breath" then
					request(actor, { breath = false })
					check((tonumber(actor:GetAttribute("Oxygen")) or 100) < 100, "tutorial consumes real oxygen")
					request(actor, { id = "hide_Library" })
					check(actor:GetAttribute("Hidden") == "", "exit restores hide state")
				end
				if spec.kind == "collect" and runtime.snapshot().phase == "Playing" then
					local duplicate = request(actor, { id = `{spec.id}_1` })
					check(duplicate.ok and not duplicate.data.accepted, `no duplicate {spec.item}`)
				end
				if spec.item == "flashlight" then
					for _, teammate in players do
						check(teammate:GetAttribute("HasFlashlight") == true, "shared flashlight")
					end
				end
			end
			check(
				runtime.snapshot().phase == (if chapter == 5 then "Extracting" else "Intermission"),
				`chapter {chapter} transition`
			)
		end
		check(runtime.snapshot().stage == 5, "all five chapters")
		for _, player in players do
			move(player, Vector3.new(0, 3.2, 106))
		end
		waitFor(function()
			return runtime.snapshot().phase == "Won"
		end, "forest extraction")
		check(runtime.snapshot().phase == "Won", "main ending after real exit zone")
	end)
	done = true
	local result = {
		success = ok,
		error = if ok then nil else tostring(failure),
		checks = #checks,
		players = args.players,
		stage = runtime.snapshot().stage,
		phase = runtime.snapshot().phase,
	}
	log.info("RESULT %s", HttpService:JSONEncode(result))
	StudioTestService:EndTest(result)
end
return Harness
