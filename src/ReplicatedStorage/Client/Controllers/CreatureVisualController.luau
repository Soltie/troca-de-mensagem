--!strict
--[[
	Visual do Vigia no cliente, separado da simulação:
	- A "Root" invisível do servidor anda liso (pathfinding, 60 Hz).
	- O corpo visível só acompanha essa Root em passos de 12 Hz e troca de pose a 3–12 poses/s
	  conforme o modo (stop-motion). Colisão, captura e controles não são afetados.
	Também cuida dos sons da criatura (passos, rosnados, perseguição).
]]

local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Poses = require("../Creature/Poses")
local Rig = require("../Creature/Rig")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")

local HEIGHT = Config.Creature.Height
local V = Config.Visual

local rig: Rig.Rig? = nil
local shown = false
local stepClock = 0
local poseClock = 0
local poseIndex = 1
local animation = "Idle"
local displayBase: CFrame? = nil
local lastBasePosition: Vector3? = nil
local moving = false
local mode = "Dormant"
local headYaw = 0
local chaseLoop: Sound? = nil
local nextGrowlAt = 0
local phase: GameState.Phase = "Loading"
local rng = Random.new()

local function serverRoot(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

local function getRig(): Rig.Rig
	assert(rig, "[CreatureVisualController] used before Init")
	return rig
end

local function animationFor(currentMode: string): (string, number)
	if currentMode == "Chase" then
		return "Chase", V.PoseRate.Chase
	elseif currentMode == "Capture" then
		return "Capture", V.PoseRate.Capture
	elseif currentMode == "Search" then
		return "Search", V.PoseRate.Search
	elseif (currentMode == "Patrol" or currentMode == "Investigate") and moving then
		return "Walk", if currentMode == "Investigate" then V.PoseRate.Investigate else V.PoseRate.Patrol
	end
	return "Idle", V.PoseRate.Idle
end

local function setShown(value: boolean)
	if shown == value then
		return
	end
	shown = value
	getRig().model.Parent = if value then workspace else nil
	if not value and chaseLoop then
		chaseLoop:Stop()
	end
end

local function onModeChanged(previous: string, current: string)
	local r = getRig()
	if current == "Chase" and previous ~= "Chase" then
		AudioController.playAt("Snarl", r.emitter)
		if chaseLoop then
			chaseLoop:Play()
		end
	elseif previous == "Chase" and current ~= "Chase" and chaseLoop then
		chaseLoop:Stop()
	end
	if current == "Capture" and chaseLoop then
		chaseLoop:Stop()
	end
end

local function solve(pose: Poses.Pose)
	local base = displayBase
	if not base then
		return
	end
	local r = getRig()
	local cframes = Rig.solve(r, base, pose, headYaw)
	workspace:BulkMoveTo(r.order, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

local function update(dt: number)
	local root = serverRoot()
	local active = root ~= nil and root:GetAttribute(Tags.Attr.CreatureActive) == true and root.Position.Y > -100
	setShown(active and phase ~= "Won")
	if not shown or not root then
		return
	end
	local r = getRig()
	local camera = workspace.CurrentCamera

	local currentMode = (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Patrol"
	if currentMode ~= mode then
		onModeChanged(mode, currentMode)
		mode = currentMode
	end

	local dirty = false
	-- Posição em passos (12 Hz).
	stepClock += dt
	if displayBase == nil or stepClock >= 1 / V.CreatureStepRate then
		stepClock = 0
		local base = root.CFrame * CFrame.new(0, -HEIGHT / 2, 0)
		if lastBasePosition then
			moving = (base.Position - lastBasePosition).Magnitude > 0.08
		end
		lastBasePosition = base.Position
		displayBase = base
		dirty = true
	end

	-- Pose em passos (taxa conforme o modo).
	local name, rate = animationFor(mode)
	if name ~= animation then
		animation = name
		poseIndex = 1
		poseClock = 0
		dirty = true
	end
	poseClock += dt
	local frames = Poses[animation]
	if poseClock >= 1 / rate then
		poseClock = 0
		poseIndex = poseIndex % #frames + 1
		dirty = true
		local pose = frames[poseIndex]
		local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
		if pose.step then
			AudioController.playAt("CreatureStep", r.emitter, 1, 0.42 + rng:NextNumber(-0.04, 0.04))
			-- Tremor dos passos pela distância (o compositor respeita a opção de conforto).
			if distance < 30 then
				local k = (30 - distance) / 30
				CameraController.addTrauma(0.22 * k * k)
			end
		end
		-- Cabeça "estala" para olhar o jogador na perseguição (atualiza só no passo).
		if
			camera
			and (mode == "Chase" or mode == "Capture" or mode == "Investigate" or mode == "Search")
			and displayBase
		then
			local toCamera = displayBase:PointToObjectSpace(camera.CFrame.Position)
			headYaw = math.clamp(math.deg(math.atan2(-toCamera.X, -toCamera.Z)), -50, 50)
		else
			headYaw = 0
		end
		r.eyeLight.Brightness = if rng:NextNumber() < 0.2 then 0.2 else 0.9
	end

	if dirty then
		solve(frames[poseIndex])
	end

	-- Rosnados ocasionais fora da perseguição.
	local now = os.clock()
	if now >= nextGrowlAt and mode ~= "Chase" and mode ~= "Capture" then
		nextGrowlAt = now + rng:NextNumber(7, 14)
		AudioController.playAt("Growl", r.emitter, 0.9, rng:NextNumber(0.75, 0.95))
	end
end

local CreatureVisualController = {
	Name = "CreatureVisualController",
}

function CreatureVisualController.Init()
	rig = Rig.build(workspace)
	local r = getRig()
	r.model.Parent = nil
	chaseLoop = AudioController.loopAt("ChaseLoop", r.emitter)
end

function CreatureVisualController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)
	RunService.RenderStepped:Connect(update)
end

-- Distância e modo atuais (para efeitos e testes).
function CreatureVisualController.status(): (boolean, string, number)
	local root = serverRoot()
	local camera = workspace.CurrentCamera
	local distance = if root and camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
	return shown, mode, distance
end

return CreatureVisualController
