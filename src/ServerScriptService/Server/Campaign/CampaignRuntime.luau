--!strict
-- Runtime alternativo registrado pelo ponto de entrada RoundService: nunca roda junto com a rodada solo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local ServerNet = require("../Net/ServerNet")
local WorldService = require("../Services/WorldService")
local CreatureService = require("../Services/CreatureService")
local CollectibleService = require("../Services/CollectibleService")
local Builder = require("./ActivityBuilder")
local Build = require("../World/Build")
local Session = require("./CoopSession")

local C = Config.Campaign
local log = Logger.new("Campaign")
local session = Session.new(1, C)
local replicated: Configuration? = nil
local built: Builder.Built? = nil
local version = 0
local startedAt = 0
local nextStageAt = 0
local nextThreatAt = 0
local blackoutUntil = 0
local building = false
local spawning: { [Player]: boolean } = {}
local spawnedVersion: { [Player]: number } = {}
local spawnSlots: { [number]: number } = {}
local playerAdapter: any = nil
local channels: { [number]: { target: number, endsAt: number } } = {}
local nextActionAt: { [number]: number } = {}
local rescueParts: { [number]: BasePart } = {}

local Runtime = { Name = "RoundService" }

local function slotFor(id: number): number
	if spawnSlots[id] then
		return spawnSlots[id]
	end
	local used: { [number]: boolean } = {}
	for _, slot in spawnSlots do
		used[slot] = true
	end
	for slot = 1, C.maxPlayers do
		if not used[slot] then
			spawnSlots[id] = slot
			return slot
		end
	end
	error("[Campaign] no spawn slot available")
end

local function parts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character,
		if root and root:IsA("BasePart") then root else nil,
		character and character:FindFirstChildOfClass("Humanoid")
end

local function feedback(player: Player, message: string)
	player:SetAttribute("CampaignFeedback", message)
	local serial = player:GetAttribute("CampaignFeedbackSerial")
	player:SetAttribute("CampaignFeedbackSerial", (if type(serial) == "number" then serial else 0) + 1)
end

local function freeze(player: Player, value: boolean)
	local _, root = parts(player)
	if root then
		root.Anchored = value
	end
end

local function publish()
	if not replicated then
		return
	end
	local roster = {}
	for _, player in Players:GetPlayers() do
		local member = session.members[player.UserId]
		if member then
			player:SetAttribute("CampaignStatus", member.status)
			player:SetAttribute("CampaignRole", member.role)
			table.insert(roster, {
				id = member.id,
				name = player.DisplayName,
				role = member.role,
				status = member.status,
				contributions = member.contributions,
				downedUntil = member.downedUntil,
			})
		end
	end
	table.sort(roster, function(a, b)
		return a.id < b.id
	end)
	local tasks = {}
	local plan = session.plan
	if plan then
		for _, spec in plan.activities do
			local state = session.tasks[spec.id]
			table.insert(
				tasks,
				{ id = spec.id, room = spec.room, kind = spec.kind, solved = state.solved, progress = state.progress }
			)
		end
	end
	replicated:SetAttribute("Roster", HttpService:JSONEncode(roster))
	replicated:SetAttribute("Tasks", HttpService:JSONEncode(tasks))
	replicated:SetAttribute("Stage", session.stage)
	replicated:SetAttribute("Seed", session.seed)
	replicated:SetAttribute("Title", if plan then plan.title else "REUNINDO A EQUIPE")
	replicated:SetAttribute("Threat", if plan then Catalog.Threats[plan.threat].title else "")
	replicated:SetAttribute("Solved", Session.solvedCount(session))
	replicated:SetAttribute("Total", if plan then #plan.activities else 0)
	replicated:SetAttribute("NextStageAt", nextStageAt)
	replicated:SetAttribute("Phase", session.phase)
	local phase = if session.phase == "Won"
		then "Won"
		elseif session.phase == "Lost" then "Lost"
		elseif session.phase == "Playing" or session.phase == "Extracting" then "Playing"
		else "Intro"
	GameState.set("RoundStartedAt", startedAt)
	if phase == "Won" or phase == "Lost" then
		GameState.set("RoundEndedAt", workspace:GetServerTimeNow())
	end
	GameState.set("Phase", phase)
	GameState.set("PowerOn", WorldService.isPowered())
	GameState.set("CreatureActive", CreatureService.isActive())
	if built then
		Builder.refresh(built, session.tasks)
	end
end

local function clearRescues()
	for _, part in rescueParts do
		part:Destroy()
	end
	rescueParts, channels = {}, {}
end

local function spawnMember(player: Player)
	if spawning[player] then
		task.delay(0.2, spawnMember, player)
		return
	end
	if not player.Parent or not session.members[player.UserId] then
		return
	end
	spawning[player] = true
	local thisVersion = version
	local ok, reason = pcall(function(): any
		player:LoadCharacterAsync()
		if thisVersion ~= version or not player.Parent then
			return nil
		end
		local character = player.Character
		assert(character, "[Campaign] character missing after load")
		local root = character:WaitForChild("HumanoidRootPart", C.SpawnTimeout)
		local humanoid = character:WaitForChild("Humanoid", C.SpawnTimeout)
		assert(
			root and root:IsA("BasePart") and humanoid and humanoid:IsA("Humanoid"),
			"[Campaign] character parts missing"
		)
		if thisVersion ~= version or not player.Parent then
			return nil
		end
		root.Anchored = true
		if character then
			local index = slotFor(player.UserId)
			local offset = Vector3.new(((index - 1) % 4) * 4 - 6, 0, math.floor((index - 1) / 4) * 4)
			local member = session.members[player.UserId]
			if member and member.status == "Waiting" then
				offset += Vector3.new(-28, 0, -8)
			end
			character:PivotTo(WorldService.spawnCFrame() + offset)
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		end
		if humanoid then
			humanoid.WalkSpeed, humanoid.UseJumpPower, humanoid.JumpHeight =
				Config.Player.WalkSpeed, false, Config.Player.JumpHeight
			humanoid.Died:Connect(function()
				if thisVersion == version then
					local member = session.members[player.UserId]
					if member and member.status == "Active" then
						Session.capture(session, player.UserId, workspace:GetServerTimeNow())
						member.status = "Waiting"
						publish()
					end
				end
			end)
		end
		player:SetAttribute(Tags.Attr.Flashlight, true)
		if playerAdapter then
			playerAdapter.resetForSpawn(player)
		end
		player:SetAttribute("CampaignGraceUntil", workspace:GetServerTimeNow() + C.SpawnGrace)
		local member = session.members[player.UserId]
		freeze(player, building or not member or member.status ~= "Active")
		spawnedVersion[player] = thisVersion
		return nil
	end)
	spawning[player] = nil
	if not ok then
		log.error("spawn failed for %s: %s", player.Name, tostring(reason))
	end
end

local function stage()
	if building then
		return
	end
	local ok, reason = Session.beginStage(session)
	if not ok then
		if reason ~= "need_players" then
			log.warn("stage refused: %s", reason or "?")
		end
		return
	end
	building = true
	version += 1
	channels, nextActionAt = {}, {}
	clearRescues()
	CreatureService.reset()
	WorldService.resetRound(Random.new(session.seed + session.stage))
	local world = WorldService.get()
	-- As trancas da missão solo não podem invalidar o grafo da campanha.
	local worldAdapter: any = WorldService
	if type(worldAdapter.doorSnapshot) == "function" and type(worldAdapter.applyDoors) == "function" then
		local states = worldAdapter.doorSnapshot()
		worldAdapter.applyDoors(states, {})
	end
	for _, focus in CollectionService:GetTagged(Tags.Interactable) do
		if focus:IsDescendantOf(world.root) then
			focus:SetAttribute(Tags.Attr.InteractEnabled, false)
		end
	end
	for id in world.interactables do
		WorldService.setInteractEnabled(id, world.interactables[id].kind == "Door")
	end
	local plan = session.plan
	assert(plan, "[Campaign] missing stage plan")
	built = Builder.build(world.root, plan, Config.Game.InteractDistance)
	WorldService.setPower(session.stage >= 2)
	startedAt = if session.stage == 1 then workspace:GetServerTimeNow() else startedAt
	nextStageAt, nextThreatAt, blackoutUntil = 0, workspace:GetServerTimeNow() + C.ThreatInterval, 0
	for _, player in Players:GetPlayers() do
		freeze(player, true)
		task.spawn(spawnMember, player)
	end
	local thisVersion = version
	task.delay(C.StageIntroSeconds, function()
		if thisVersion ~= version then
			return
		end
		local deadline = os.clock() + C.SpawnTimeout
		local function everyoneReady(): boolean
			for _, player in Players:GetPlayers() do
				local member = session.members[player.UserId]
				if member and member.status == "Active" and spawnedVersion[player] ~= thisVersion then
					return false
				end
			end
			return true
		end
		while thisVersion == version and not everyoneReady() and os.clock() < deadline do
			task.wait(0.1)
		end
		if thisVersion ~= version then
			return
		end
		for _, player in Players:GetPlayers() do
			local member = session.members[player.UserId]
			if member and member.status == "Active" and spawnedVersion[player] ~= thisVersion then
				member.status = "Waiting"
				feedback(player, "spawn_failed")
				log.warn("spawn timed out for %s", player.Name)
			end
		end
		building = false
		for _, player in Players:GetPlayers() do
			local member = session.members[player.UserId]
			freeze(player, not member or member.status ~= "Active")
		end
		CreatureService.activate(nil)
		CreatureService.setHunt(session.stage == 3)
		publish()
	end)
	publish()
	log.info("stage=%d seed=%d players=%d tasks=%d", session.stage, session.seed, plan.players, #plan.activities)
end

local function hasSight(player: Player, focus: BasePart, range: number): boolean
	local character, root, humanoid = parts(player)
	if not character or not root or not humanoid or humanoid.Health <= 0 or not focus.Parent then
		return false
	end
	if (root.Position - focus.Position).Magnitude > range then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.yAxis * 1.5
	local hit = workspace:Raycast(origin, focus.Position - origin, params)
	return hit == nil or hit.Instance == focus or (hit.Position - focus.Position).Magnitude < 1.5
end

local function capture(player: Player)
	local now = workspace:GetServerTimeNow()
	if not Session.capture(session, player.UserId, now) then
		return
	end
	freeze(player, true)
	local _, root = parts(player)
	if root then
		local beacon = Build.part(
			WorldService.get().root,
			`Rescue_{player.UserId}`,
			Vector3.new(1, 1, 1),
			CFrame.new(root.Position + Vector3.new(0, 3.3, 0)),
			Color3.fromRGB(90, 220, 160),
			{ transparency = 0.4, collide = false }
		)
		beacon:SetAttribute(Tags.Attr.InteractId, `rescue_{player.UserId}`)
		beacon:SetAttribute(Tags.Attr.InteractPrompt, `RESGATAR {player.DisplayName}`)
		beacon:SetAttribute(Tags.Attr.InteractDistance, Config.Game.InteractDistance)
		beacon:SetAttribute(Tags.Attr.InteractEnabled, true)
		CollectionService:AddTag(beacon, Tags.Interactable)
		rescueParts[player.UserId] = beacon
	end
	publish()
	-- O cérebro legado termina em Capture; recolocar o Vigia permite continuar caçando a equipe.
	local thisVersion = version
	task.delay(C.CaptureRecovery, function()
		if thisVersion == version and (session.phase == "Playing" or session.phase == "Extracting") then
			CreatureService.reset()
			CreatureService.activate(nil)
			CreatureService.setFuses(math.min(2, session.stage - 1))
			CreatureService.setHunt(session.stage == 3)
		end
	end)
end

local function afterActivity(previous: Session.Phase)
	if session.phase ~= previous then
		if session.phase == "Intermission" then
			nextStageAt = workspace:GetServerTimeNow() + C.IntermissionSeconds
			CreatureService.freeze()
			for _, player in Players:GetPlayers() do
				freeze(player, true)
			end
		elseif session.phase == "Extracting" then
			WorldService.setPower(true)
			WorldService.openGate()
		end
	end
	publish()
end

local function interact(player: Player, id: string, _action: string?): { accepted: boolean, message: string }
	-- Fita VHS colecionável (Claude, monetização/progressão): mesma validação nos dois modos.
	if id == CollectibleService.TAPE_ID then
		return CollectibleService.collect(player)
	end
	local member = session.members[player.UserId]
	local now = workspace:GetServerTimeNow()
	local function response(ok: boolean, message: string)
		feedback(player, message)
		return { accepted = ok, message = message }
	end
	if building or not member or member.status ~= "Active" then
		return response(false, "not_active")
	end
	if session.phase ~= "Playing" and session.phase ~= "Extracting" then
		return response(false, "not_playing")
	end
	if now < (nextActionAt[player.UserId] or 0) then
		return response(false, "wait")
	end
	local station = built and built.targets[id]
	local targetId = tonumber(string.match(id, "^rescue_([%-]?%d+)$"))
	local focus = if station then station.focus elseif targetId then rescueParts[targetId] else nil
	if focus then
		if not hasSight(player, focus, Config.Game.InteractDistance + Config.Game.InteractTolerance) then
			return response(false, "too_far")
		end
		nextActionAt[player.UserId] = now + C.ActionCooldown
		if targetId then
			local target = session.members[targetId]
			if not target or target.status ~= "Downed" then
				return response(false, "not_available")
			end
			if channels[player.UserId] then
				return response(false, "rescuing")
			end
			channels[player.UserId] = {
				target = targetId,
				endsAt = now + (if member.role == "medic" then C.MedicReviveSeconds else C.ReviveSeconds),
			}
			return response(true, "rescuing")
		end
		assert(station, "[Campaign] missing activity target")
		local previous: Session.Phase = session.phase
		local ok, message = Session.act(session, player.UserId, station.taskId, station.button, now)
		if message == "wrong_sequence" then
			CreatureService.makeNoise(focus.Position, 45)
		end
		if ok then
			CreatureService.makeNoise(focus.Position, 22)
		end
		afterActivity(previous)
		return response(ok, message)
	end
	local item = WorldService.interactable(id)
	if
		item
		and item.kind == "Door"
		and hasSight(player, item.focus, Config.Game.InteractDistance + Config.Game.InteractTolerance)
	then
		nextActionAt[player.UserId] = now + C.ActionCooldown
		local door = WorldService.door(id)
		if door then
			WorldService.forceOpenDoor(door)
			return response(true, "door_opened")
		end
	end
	return response(false, "not_available")
end

local function restartCampaign()
	version += 1
	building = false
	clearRescues()
	CreatureService.reset()
	local seed = C.Seed or ((os.time() + version * 7919) % 2147483646)
	session = Session.new(seed, C)
	spawnSlots = {}
	for _, player in Players:GetPlayers() do
		Session.join(session, player.UserId)
		slotFor(player.UserId)
		freeze(player, true)
	end
	nextStageAt, startedAt = 0, 0
	GameState.set("RoundId", version)
	GameState.set("RoundEndedAt", 0)
	publish()
end

local function tick()
	local now = workspace:GetServerTimeNow()
	local before = session.phase .. ":" .. Session.count(session, "Downed")
	Session.tick(session, now)
	for helperId, channel in channels do
		local helper = Players:GetPlayerByUserId(helperId)
		local target = Players:GetPlayerByUserId(channel.target)
		local beacon = rescueParts[channel.target]
		local member = session.members[helperId]
		if
			not helper
			or not target
			or not beacon
			or not member
			or member.status ~= "Active"
			or not hasSight(helper, beacon, Config.Game.InteractDistance)
		then
			channels[helperId] = nil
			if helper then
				feedback(helper, "rescue_cancelled")
			end
		elseif now >= channel.endsAt then
			channels[helperId] = nil
			if Session.revive(session, helperId, channel.target, now) then
				target:SetAttribute("CampaignGraceUntil", now + C.ReviveGrace)
				freeze(target, false)
				beacon:Destroy()
				rescueParts[channel.target] = nil
				feedback(helper, "rescued")
				publish()
			end
		end
	end
	for id, beacon in rescueParts do
		local member = session.members[id]
		if not member or member.status ~= "Downed" then
			beacon:Destroy()
			rescueParts[id] = nil
		end
	end
	if session.phase == "Lobby" then
		if Session.count(session) >= C.minPlayers then
			if nextStageAt == 0 then
				nextStageAt = now + C.LobbySeconds
				publish()
			end
			if now >= nextStageAt then
				stage()
			end
		elseif nextStageAt ~= 0 then
			nextStageAt = 0
			publish()
		end
	elseif session.phase == "Intermission" then
		if now >= nextStageAt then
			stage()
		end
	elseif session.phase == "Extracting" then
		for _, player in Players:GetPlayers() do
			local _, root = parts(player)
			if root and WorldService.isInExitZone(root.Position) and Session.escape(session, player.UserId) then
				freeze(player, true)
				publish()
			end
		end
	end
	if session.phase == "Playing" and not building then
		if blackoutUntil > 0 and now >= blackoutUntil then
			WorldService.setPower(true)
			blackoutUntil = 0
			publish()
		end
		if now >= nextThreatAt then
			nextThreatAt = now + C.ThreatInterval
			if session.stage == 2 then
				local plan = session.plan
				if plan then
					local point = plan.activities[(math.floor(now) % #plan.activities) + 1]
					CreatureService.makeNoise(Vector3.new(point.x, 0, point.z), 100)
				end
			elseif session.stage == 3 then
				WorldService.setPower(false)
				blackoutUntil = now + C.BlackoutSeconds
				publish()
			end
		end
	end
	if session.phase == "Won" or session.phase == "Lost" then
		CreatureService.freeze()
		for _, player in Players:GetPlayers() do
			freeze(player, true)
		end
	end
	if before ~= session.phase .. ":" .. Session.count(session, "Downed") then
		publish()
	end
end

function Runtime.Init()
	Players.CharacterAutoLoads = false
	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	StarterPlayer.CameraMaxZoomDistance = 0.5
	StarterPlayer.CameraMinZoomDistance = 0.5
	local gameState = GameState.serverCreate()
	gameState:SetAttribute("CampaignActive", true)
	local state = Instance.new("Configuration")
	state.Name = "CampaignState"
	state.Parent = ReplicatedStorage
	replicated = state
	if not PhysicsService:IsCollisionGroupRegistered("CampaignPlayers") then
		PhysicsService:RegisterCollisionGroup("CampaignPlayers")
	end
	PhysicsService:CollisionGroupSetCollidable("CampaignPlayers", "CampaignPlayers", false)
	CreatureService.onCapture(capture)
	restartCampaign()
end

function Runtime.Start()
	ServerNet.onInvoke("Interact", {
		args = {
			Guard.string({ maxLength = 32, pattern = "^[%w_%-]+$" }),
			Guard.optional(Guard.literal("use", "alt")),
		},
		rateLimit = { capacity = 6, refillPerSecond = 3 },
	}, interact)
	ServerNet.onInvoke("RequestRestart", {
		args = { Guard.optional(Guard.literal("full", "checkpoint")) },
		rateLimit = { capacity = 2, refillPerSecond = 0.5 },
	}, function(player: Player)
		local passed, reason = Session.voteRestart(session, player.UserId)
		if passed then
			restartCampaign()
		end
		feedback(player, if passed then "restarting" else (reason or "vote_recorded"))
		return { accepted = reason == nil, message = reason or "vote_recorded" }
	end)
	-- Compatível com o template anterior e com PlayerStateService (dono da bateria no polish).
	task.defer(function()
		if not ServerNet.isRegistered("SetFlashlight") then
			ServerNet.onEvent(
				"SetFlashlight",
				{ args = { Guard.boolean() }, rateLimit = { capacity = 10, refillPerSecond = 5 } },
				function(player: Player, on: boolean)
					player:SetAttribute(Tags.Attr.Flashlight, on)
				end
			)
		end
	end)
	local function join(player: Player)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMaxZoomDistance, player.CameraMinZoomDistance = 0.5, 0.5
		local ok = session.members[player.UserId] ~= nil or Session.join(session, player.UserId)
		if not ok then
			player:SetAttribute("CampaignStatus", "Waiting")
			feedback(player, "party_full")
			return
		end
		slotFor(player.UserId)
		if session.phase == "Lobby" then
			nextStageAt = workspace:GetServerTimeNow() + C.LobbySeconds
		end
		player.CharacterAdded:Connect(function(character)
			local function assign(instance: Instance)
				if instance:IsA("BasePart") then
					instance.CollisionGroup = "CampaignPlayers"
				end
			end
			for _, descendant in character:GetDescendants() do
				assign(descendant)
			end
			character.DescendantAdded:Connect(assign)
		end)
		task.spawn(spawnMember, player)
		publish()
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		Session.leave(session, player.UserId)
		if Session.count(session) == 0 then
			version += 1
			building = false
			CreatureService.reset()
		end
		channels[player.UserId], nextActionAt[player.UserId], spawning[player] = nil, nil, nil
		spawnedVersion[player] = nil
		spawnSlots[player.UserId] = nil
		if rescueParts[player.UserId] then
			rescueParts[player.UserId]:Destroy()
			rescueParts[player.UserId] = nil
		end
		publish()
	end)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, reason = pcall(tick :: () -> any)
			if not ok then
				log.error("tick failed: %s", tostring(reason))
			end
		end
	end)
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		if ok and type(args) == "table" and args.campaignQA then
			task.spawn(function()
				require("../../Tests/CampaignHarness").run(Runtime, args)
			end)
		end
	end
end

function Runtime.restart()
	restartCampaign()
end

function Runtime.setPlayerAdapter(adapter: any)
	playerAdapter = adapter
end
function Runtime.lose(player: Player)
	capture(player)
end
function Runtime.win(player: Player)
	if Session.escape(session, player.UserId) then
		publish()
	end
end
function Runtime.getPhase(): "Loading" | "Intro" | "Playing" | "Won" | "Lost"
	return GameState.get("Phase")
end
function Runtime.snapshot(): { [string]: any }
	return {
		building = building,
		tasks = session.tasks,
		phase = session.phase,
		stage = session.stage,
		seed = session.seed,
		players = Session.count(session),
		active = Session.count(session, "Active"),
		downed = Session.count(session, "Downed"),
		solved = Session.solvedCount(session),
		plan = session.plan,
		members = session.members,
	}
end

return Runtime
