--!strict
--[[
	CreatureService: O Vigia no servidor (autoritativo).

	- O corpo no servidor é só uma peça invisível "Root" (ancorada, sem colisão) movida de forma
	  cinemática ao longo de waypoints do PathfindingService. Simulação e captura acontecem aqui.
	- O visual (modelo low poly em stop-motion) é montado no cliente e segue esta Root.
	- Decisões vêm do CreatureBrain (puro); aqui só calculamos percepção e executamos comandos.
]]

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local CreatureBrain = require("../Game/CreatureBrain")
local HideRules = require("../Game/HideRules")
local Layout = require("../World/Layout")
local WorldService = require("./WorldService")

type Target = {
	player: Player,
	character: Model,
	root: BasePart,
	eye: Vector3,
}

local log = Logger.new("CreatureService")
local C = Config.Creature
local HEIGHT = C.Height
local HIDDEN = CFrame.new(0, -400, 0)
local UP = Vector3.yAxis

local model: Model? = nil
local root: BasePart? = nil
local brain = CreatureBrain.new()
local active = false
local frozen = false
local hunt = false
local token = 0
local captureCallbacks: { (Player) -> () } = {}

-- Percepção auxiliar
local pendingNoise: Vector3? = nil
local lastStalkAt = 0
local lastSeenFlag = false
local lastSeenAt = -math.huge
-- Tempo que ele está perto do armário com o jogador respirando (HideRules.exposure).
local exposure = 0
-- Trégua (checkpoint): parado até este instante.
local holdUntil = 0
local nextBangAt = 0

-- Movimento
local waypoints: { Vector3 } = {}
local waypointIndex = 1
local moveSpeed = 0
local destination: Vector3? = nil
local arrived = true
local pathBusy = false
local lastPathAt = -math.huge
local pauseUntil = 0
local currentMode: CreatureBrain.Mode = "Dormant"
local patrolOrder: { number } = {}
local patrolCursor = 0
local rng = Random.new()

local function getRoot(): BasePart
	assert(root, "[CreatureService] used before Init")
	return root
end

local function feet(): Vector3
	return getRoot().Position - UP * (HEIGHT / 2)
end

local function setAttributes(mode: string)
	local r = getRoot()
	r:SetAttribute(Tags.Attr.CreatureMode, mode)
	r:SetAttribute(Tags.Attr.CreatureActive, active)
end

local function placeAt(position: Vector3, look: Vector3?)
	local center = Vector3.new(position.X, position.Y + HEIGHT / 2, position.Z)
	local direction = look or Vector3.new(0, 0, -1)
	direction = Vector3.new(direction.X, 0, direction.Z)
	if direction.Magnitude < 1e-3 then
		direction = Vector3.new(0, 0, -1)
	end
	getRoot().CFrame = CFrame.lookAt(center, center + direction.Unit)
end

local function vec(p: Layout.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function findTarget(): Target?
	local best: Target? = nil
	local bestDistance = math.huge
	local origin = feet()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		local campaignStatus = player:GetAttribute("CampaignStatus")
		local campaignActive = campaignStatus == nil or campaignStatus == "Active"
		local grace = player:GetAttribute("CampaignGraceUntil")
		local protected = type(grace) == "number" and workspace:GetServerTimeNow() < grace
		if
			campaignActive
			and not protected
			and character
			and humanoid
			and humanoid.Health > 0
			and hrp
			and hrp:IsA("BasePart")
		then
			local head = character:FindFirstChild("Head")
			local eye = if head and head:IsA("BasePart") then head.Position else hrp.Position + UP * 1.5
			local distance = (hrp.Position - origin).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = { player = player, character = character, root = hrp, eye = eye }
			end
		end
	end
	return best
end

local function lineOfSight(target: Target): boolean
	local eye = feet() + UP * (HEIGHT - 0.7)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { target.character }
	if model then
		table.insert(exclude, model)
	end
	params.FilterDescendantsInstances = exclude
	local result = workspace:Raycast(eye, target.eye - eye, params)
	return result == nil
end

-- Jogador escondido num armário: só é "visto" se o Vigia viu entrar ou o ouviu respirar.
local function perceiveHidden(target: Target, now: number): CreatureBrain.Perception
	local player = target.player
	local origin = feet()
	local at = player:GetAttribute("HiddenAt")
	local spot = if typeof(at) == "Vector3" then at else target.root.Position
	local spotFeet = Vector3.new(spot.X, origin.Y, spot.Z)
	local distance = (spotFeet - origin).Magnitude
	-- Lanterna acesa dentro do armário vaza pelas frestas: conta como respirar.
	local quiet = player:GetAttribute("HoldBreath") == true and player:GetAttribute(Tags.Attr.Flashlight) ~= true
	exposure = HideRules.exposure(exposure, distance, quiet, C.BrainInterval)
	local seen = player:GetAttribute("HiddenSeen") == true
	if
		not seen
		and HideRules.found({
			sawEntry = false,
			creatureActive = active,
			distance = distance,
			holdingBreath = quiet,
			exposedTime = exposure,
			captureRange = C.CaptureRange,
		})
	then
		seen = true
		player:SetAttribute("HiddenSeen", true)
		getRoot():SetAttribute("Alert", now)
		log.info("heard %s breathing inside the locker", player.Name)
	end
	local noise = pendingNoise
	pendingNoise = nil
	if seen then
		lastSeenAt = now
		return {
			now = now,
			canSee = true,
			lineOfSight = true,
			distance = distance,
			targetPos = spotFeet,
			noisePos = nil,
			hunt = hunt,
			arrived = arrived,
		}
	end
	-- Não sabe onde ele está: segue o último rastro / barulho (o arquejo atrai até o armário).
	return {
		now = now,
		canSee = false,
		lineOfSight = false,
		distance = distance,
		targetPos = nil,
		noisePos = noise,
		hunt = hunt,
		arrived = arrived,
	}
end

local function perceive(target: Target?, now: number): CreatureBrain.Perception
	if target == nil then
		return { now = now, canSee = false, lineOfSight = false, hunt = false, arrived = arrived }
	end
	local hiddenId = target.player:GetAttribute("Hidden")
	if type(hiddenId) == "string" and hiddenId ~= "" then
		return perceiveHidden(target, now)
	end
	exposure = 0
	local origin = feet()
	local toTarget = target.root.Position - (origin + UP * 3)
	local distance = toTarget.Magnitude
	local los = distance < 80 and lineOfSight(target)

	local flashlight = target.player:GetAttribute(Tags.Attr.Flashlight) == true
	-- Agachado ele enxerga menos (alcance e o "sentido" de perto).
	local crouch = if target.player:GetAttribute("Stance") == "Crouch" then Config.Player.CrouchSightFactor else 1
	local range = (if flashlight then C.SightRangeFlashlight else C.SightRange) * crouch
	local forward = getRoot().CFrame.LookVector
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	local inFov = flat.Magnitude < 1e-3
		or math.deg(math.acos(math.clamp(forward:Dot(flat.Unit), -1, 1))) <= C.SightFov / 2
	local canSee = los and distance <= range and (inFov or distance <= C.CloseSenseRange * crouch)
	if canSee then
		lastSeenAt = now
	end

	local targetFeet = target.root.Position - UP * 3
	local noise = pendingNoise
	pendingNoise = nil
	local velocity = target.root.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	if horizontalSpeed > Config.Player.NoiseSpeed and distance <= Config.Player.NoiseRadius then
		noise = targetFeet
	end
	if brain.fuses >= C.StalkFromFuses and brain.mode == "Patrol" and now - lastStalkAt >= C.StalkInterval then
		lastStalkAt = now
		noise = targetFeet + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6))
	end

	return {
		now = now,
		canSee = canSee,
		lineOfSight = los,
		distance = distance,
		targetPos = targetFeet,
		noisePos = noise,
		hunt = hunt,
		arrived = arrived,
	}
end

local function computePath(target: Vector3)
	if pathBusy then
		return
	end
	pathBusy = true
	local myToken = token
	local start = feet()
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = C.AgentRadius,
			AgentHeight = C.AgentHeight,
			AgentCanJump = false,
			AgentCanClimb = false,
			WaypointSpacing = 4,
			Costs = { Door = 2 },
		})
		local ok, err = pcall(function()
			path:ComputeAsync(start, target)
		end)
		pathBusy = false
		if myToken ~= token then
			return
		end
		lastPathAt = os.clock()
		if ok and path.Status == Enum.PathStatus.Success then
			local points = {}
			for _, waypoint in path:GetWaypoints() do
				table.insert(points, waypoint.Position)
			end
			waypoints = points
			waypointIndex = math.min(2, #points)
			arrived = #points == 0
		else
			if not ok then
				log.debug("path error: %s", tostring(err))
			end
			waypoints = {}
			arrived = true
		end
	end)
end

local function stopMoving()
	waypoints = {}
	destination = nil
	moveSpeed = 0
end

local function nextPatrolNode(): Vector3
	if patrolCursor >= #patrolOrder then
		patrolOrder = {}
		for i = 1, #Layout.PatrolNodes do
			table.insert(patrolOrder, i)
		end
		for i = #patrolOrder, 2, -1 do
			local j = rng:NextInteger(1, i)
			patrolOrder[i], patrolOrder[j] = patrolOrder[j], patrolOrder[i]
		end
		patrolCursor = 0
	end
	patrolCursor += 1
	return vec(Layout.PatrolNodes[patrolOrder[patrolCursor]])
end

-- urgent (perseguição): recalcula a rota a cada RepathInterval; senão só quando o destino muda.
local function goTo(target: Vector3, speed: number, urgent: boolean)
	moveSpeed = speed
	local changed = destination == nil or (destination - target).Magnitude > 2
	destination = target
	if urgent then
		if os.clock() - lastPathAt >= C.RepathInterval then
			arrived = false
			computePath(target)
		end
	elseif changed then
		arrived = false
		computePath(target)
	end
end

local function fireCapture(player: Player)
	for _, callback in captureCallbacks do
		task.spawn(callback, player)
	end
end

local function brainTick()
	if not active or frozen then
		return
	end
	local now = os.clock()
	if now < holdUntil then
		setAttributes("Search")
		return
	end
	local target = findTarget()
	local perception = perceive(target, now)
	local command = CreatureBrain.step(brain, perception)

	if command.event == "capture" and target then
		frozen = true
		stopMoving()
		setAttributes("Capture")
		placeAt(feet(), target.root.Position - feet())
		log.info("captured %s", target.player.Name)
		fireCapture(target.player)
		return
	end
	if command.event then
		log.debug("event %s", command.event)
	end
	lastSeenFlag = perception.canSee

	if command.mode == "Patrol" then
		if currentMode ~= "Patrol" or arrived or destination == nil then
			goTo(nextPatrolNode(), command.speed, false)
		else
			moveSpeed = command.speed
		end
	elseif command.mode == "Chase" and command.target then
		-- Muito perto e à vista: vai direto (sem esperar o pathfinding).
		if perception.lineOfSight and perception.distance and perception.distance < 9 then
			destination = command.target
			waypoints = { command.target }
			waypointIndex = 1
			moveSpeed = command.speed
			arrived = false
		else
			goTo(command.target, command.speed, true)
		end
	elseif command.mode == "Investigate" and command.target then
		goTo(command.target, command.speed, false)
	else
		stopMoving()
	end

	currentMode = command.mode
	setAttributes(command.mode)
end

local function move(dt: number)
	if not active or frozen then
		return
	end
	local now = os.clock()
	local r = getRoot()
	if now < holdUntil then
		return
	end

	-- Porta trancada: bate com força e desiste (o pathfinding já contorna).
	local lockedDoor = WorldService.lockedDoorNear(feet(), C.DoorOpenRange)
	if lockedDoor and (currentMode == "Chase" or currentMode == "Investigate") and now >= nextBangAt then
		nextBangAt = now + 5
		WorldService.bangDoor(lockedDoor)
		pauseUntil = now + 1.2
	end

	-- Arromba portas fechadas no caminho.
	local door = WorldService.closedDoorNear(feet(), C.DoorOpenRange)
	if door and (currentMode == "Chase" or currentMode == "Investigate" or currentMode == "Patrol") then
		WorldService.forceOpenDoor(door)
		pauseUntil = now + C.DoorOpenPause
	end
	if now < pauseUntil then
		return
	end

	if currentMode == "Search" then
		r.CFrame = r.CFrame * CFrame.Angles(0, math.sin(now * 1.3) * dt * 1.6, 0)
		return
	end

	local waypoint: Vector3? = waypoints[waypointIndex]
	if waypoint == nil or moveSpeed <= 0 then
		return
	end
	local position = feet()
	local delta = Vector3.new(waypoint.X - position.X, 0, waypoint.Z - position.Z)
	local distance = delta.Magnitude
	if distance < 0.6 then
		waypointIndex += 1
		if waypointIndex > #waypoints then
			arrived = true
			waypoints = {}
		end
		return
	end
	local step = math.min(distance, moveSpeed * dt)
	local nextPosition = position + delta.Unit * step
	nextPosition =
		Vector3.new(nextPosition.X, position.Y + (waypoint.Y - position.Y) * math.min(1, dt * 8), nextPosition.Z)
	local look = r.CFrame.LookVector:Lerp(delta.Unit, math.min(1, dt * 9))
	placeAt(nextPosition, look)
end

local CreatureService = {
	Name = "CreatureService",
}

function CreatureService.Init()
	local m = Instance.new("Model")
	m.Name = Tags.CreatureModel
	local r = Instance.new("Part")
	r.Name = Tags.CreatureRoot
	r.Size = Vector3.new(2, HEIGHT, 1.4)
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.CanTouch = false
	r.Transparency = 1
	r.CastShadow = false
	r.CFrame = HIDDEN
	r.Parent = m
	m.PrimaryPart = r
	m.Parent = workspace
	model = m
	root = r
	setAttributes("Dormant")
end

function CreatureService.Start()
	task.spawn(function()
		while true do
			task.wait(C.BrainInterval)
			local ok, err = pcall(brainTick :: () -> any)
			if not ok then
				log.error("brain tick failed: %s", tostring(err))
			end
		end
	end)
	RunService.Heartbeat:Connect(move)
end

-- Volta ao estado inicial (escondido e dormente).
function CreatureService.reset()
	token += 1
	brain = CreatureBrain.new()
	active = false
	frozen = false
	hunt = false
	pendingNoise = nil
	lastSeenFlag = false
	lastSeenAt = -math.huge
	exposure = 0
	holdUntil = 0
	nextBangAt = 0
	arrived = true
	pathBusy = false
	pauseUntil = 0
	currentMode = "Dormant"
	stopMoving()
	getRoot().CFrame = HIDDEN
	setAttributes("Dormant")
end

-- Acorda no ponto de surgimento mais distante do jogador (ou em `at`).
function CreatureService.activate(at: Vector3?)
	if active then
		return
	end
	local spawnAt = at
	if spawnAt == nil then
		local target = findTarget()
		local reference = if target then target.root.Position else Vector3.zero
		local best, bestDistance = nil, -1
		for _, p in Layout.CreatureSpawns do
			local position = vec(p)
			local distance = (position - reference).Magnitude
			if distance > bestDistance then
				best, bestDistance = position, distance
			end
		end
		spawnAt = best
	end
	assert(spawnAt, "no spawn point")
	placeAt(spawnAt, nil)
	active = true
	lastStalkAt = os.clock()
	CreatureBrain.activate(brain)
	currentMode = "Patrol"
	setAttributes("Patrol")
	log.info("awakened at (%d, %d)", spawnAt.X, spawnAt.Z)
end

function CreatureService.setFuses(count: number)
	brain.fuses = count
end

function CreatureService.setHunt(on: boolean)
	hunt = on
end

-- Barulho em `position` (ouvido se estiver dentro de `radius`).
function CreatureService.makeNoise(position: Vector3, radius: number)
	if active and not frozen and (position - feet()).Magnitude <= radius then
		pendingNoise = position
	end
end

function CreatureService.freeze()
	frozen = true
	stopMoving()
end

-- Depuração: congela/descongela sem mudar o resto do estado.
function CreatureService.setFrozen(value: boolean)
	frozen = value
	if value then
		stopMoving()
	end
end

-- Trégua: fica parado olhando em volta por `seconds` (continuar do checkpoint).
function CreatureService.holdOff(seconds: number)
	holdUntil = os.clock() + seconds
end

-- Segundos desde a última vez que viu o jogador (esconderijo: "viu entrar?").
function CreatureService.secondsSinceSeen(): number
	return os.clock() - lastSeenAt
end

function CreatureService.isChasing(): boolean
	return active and currentMode == "Chase"
end

function CreatureService.onCapture(callback: (Player) -> ())
	table.insert(captureCallbacks, callback)
end

function CreatureService.isActive(): boolean
	return active
end

function CreatureService.state(): { [string]: any }
	return {
		active = active,
		frozen = frozen,
		hunt = hunt,
		mode = brain.mode,
		fuses = brain.fuses,
		position = feet(),
		waypoints = #waypoints,
		seeing = lastSeenFlag,
		sinceSeen = os.clock() - lastSeenAt,
		exposure = exposure,
		holdOff = math.max(0, holdUntil - os.clock()),
	}
end

-- Teleporte para depuração/testes (não usado no jogo normal).
function CreatureService.debugPlace(position: Vector3)
	placeAt(position, nil)
	stopMoving()
	arrived = true
end

return CreatureService
