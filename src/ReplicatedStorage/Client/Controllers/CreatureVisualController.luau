--!strict
--[[
	Visual da criatura no cliente, separado da simulação:
	- A "Root" invisível do servidor anda liso (pathfinding, 60 Hz).
	- Com o asset ReplicatedStorage.Assets.TungTung presente, o corpo é o Tung Tung com esqueleto
	  e animações (andar, correr, golpe, passo lateral) misturadas pelo estado e pela velocidade.
	- Sem o asset (place antiga), cai no boneco low poly em stop-motion (Rig + Poses).
	Colisão, captura e controles não são afetados. Também cuida dos sons da criatura.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Poses = require("../Creature/Poses")
local Rig = require("../Creature/Rig")
local TungTungRig = require("../Creature/TungTungRig")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")

local HEIGHT = Config.Creature.Height
local V = Config.Visual

-- Velocidade (studs/s) que os pés percorrem em 1x em cada clipe (medida no bake).
local WALK_FEET_SPEED = 1.55
local RUN_FEET_SPEED = 16.5

local rig: Rig.Rig? = nil
local tung: TungTungRig.TungRig? = nil
local shown = false
local stepClock = 0
local poseClock = 0
local poseIndex = 1
local animation = "Idle"
local displayBase: CFrame? = nil
local lastBasePosition: Vector3? = nil
local smoothSpeed = 0
local lastCycle = 0
local moving = false
local mode = "Dormant"
local headYaw = 0
local chaseLoop: Sound? = nil
local nextGrowlAt = 0
local phase: GameState.Phase = "Loading"
local rng = Random.new()
local reaction = ""
local reactionUntil = 0

local function serverRoot(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

local function visualModel(): Model
	if tung then
		return tung.model
	end
	assert(rig, "[CreatureVisualController] used before Init")
	return rig.model
end

local function emitter(): Attachment
	if tung then
		return tung.emitter
	end
	assert(rig, "[CreatureVisualController] used before Init")
	return rig.emitter
end

local function animationFor(currentMode: string): (string, number)
	if os.clock() < reactionUntil then
		return reaction, 8
	end
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
	visualModel().Parent = if value then workspace else nil
	if not value and chaseLoop then
		chaseLoop:Stop()
	end
end

local function onModeChanged(previous: string, current: string)
	if current == "Chase" and previous ~= "Chase" then
		reaction, reactionUntil = "Notice", os.clock() + 0.38
	elseif current == "Investigate" then
		reaction, reactionUntil = "Sniff", os.clock() + 0.65
	elseif current == "Capture" then
		reaction, reactionUntil = "Lunge", os.clock() + 0.4
	else
		reactionUntil = 0
	end
	if tung then
		-- No Tung Tung as reações viram golpes do bastão (perseguição começa com uma pancada no ar).
		if current == "Capture" then
			TungTungRig.play(tung, "slash", 0.08, 1.15)
			reactionUntil = os.clock() + 1.0
		elseif current == "Chase" and previous ~= "Chase" then
			TungTungRig.play(tung, "slash", 0.1, 1.6)
			reactionUntil = os.clock() + 0.7
		end
	end
	if current == "Chase" and previous ~= "Chase" then
		AudioController.playAt("Snarl", emitter())
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

local function footstep(root: BasePart, camera: Camera?)
	local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
	AudioController.playAt(
		"CreatureStep",
		emitter(),
		if root:GetAttribute("FalseExit") then 0.25 else 1,
		0.42 + rng:NextNumber(-0.04, 0.04)
	)
	-- Tremor dos passos pela distância (o compositor respeita a opção de conforto).
	if distance < 30 then
		local k = (30 - distance) / 30
		CameraController.addTrauma(0.22 * k * k)
	end
end

local function lookYawAt(base: CFrame, camera: Camera?): number
	if camera and (mode == "Chase" or mode == "Capture" or mode == "Investigate" or mode == "Search") then
		local toCamera = base:PointToObjectSpace(camera.CFrame.Position)
		return math.clamp(math.deg(math.atan2(-toCamera.X, -toCamera.Z)), -50, 50)
	end
	return 0
end

-- Tung Tung: segue a Root a cada quadro, escolhe o clipe pela velocidade/estado e emite passos no ciclo.
local function updateTung(t: TungTungRig.TungRig, root: BasePart, dt: number, camera: Camera?)
	local base = root.CFrame * CFrame.new(0, -HEIGHT / 2, 0)
	local previousBase = displayBase
	if previousBase then
		local speed = (base.Position - previousBase.Position).Magnitude / math.max(dt, 1e-3)
		smoothSpeed += (math.min(speed, 40) - smoothSpeed) * math.min(1, dt * 8)
		base = previousBase:Lerp(base, math.min(1, dt * 18))
	end
	displayBase = base
	moving = smoothSpeed > 1.2
	TungTungRig.place(t, base)

	local reacting = os.clock() < reactionUntil
	if not reacting then
		if mode == "Capture" then
			TungTungRig.play(t, "slash", 0.08, 1.15)
		elseif mode == "Search" and not moving then
			TungTungRig.play(t, "strafe", 0.25, 0.55)
		elseif smoothSpeed > 5 then
			TungTungRig.play(t, "run", 0.22, math.clamp(smoothSpeed / RUN_FEET_SPEED, 0.55, 1.35))
		elseif moving then
			TungTungRig.play(t, "walk", 0.25, math.clamp(smoothSpeed / WALK_FEET_SPEED, 0.8, 3.2))
		else
			TungTungRig.play(t, "idle", 0.35)
		end
	end

	headYaw += (lookYawAt(base, camera) - headYaw) * math.min(1, dt * 10)
	TungTungRig.step(t, dt, headYaw)

	-- Passos: dois por ciclo na corrida/lateral, quatro no andar arrastado.
	local playing = TungTungRig.playing(t)
	local steps = if playing == "walk" then 4 elseif playing == "run" or playing == "strafe" then 2 else 0
	local cycle = TungTungRig.cycle(t)
	if steps > 0 and math.floor(cycle * steps) ~= math.floor(lastCycle * steps) then
		footstep(root, camera)
	end
	lastCycle = cycle
	t.eyeLight.Brightness = if mode == "Chase" then 1.8 else 1.1
end

local function updateLegacy(r: Rig.Rig, root: BasePart, dt: number, camera: Camera?)
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
		if pose.step then
			footstep(root, camera)
		end
		-- Cabeça "estala" para olhar o jogador na perseguição (atualiza só no passo).
		headYaw = if displayBase then lookYawAt(displayBase, camera) else 0
		r.eyeLight.Brightness = if rng:NextNumber() < 0.2 then 0.2 else 0.9
	end

	if dirty and displayBase then
		local cframes = Rig.solve(r, displayBase, frames[poseIndex], headYaw)
		workspace:BulkMoveTo(r.order, cframes, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

local function update(dt: number)
	local root = serverRoot()
	local active = root ~= nil and root:GetAttribute(Tags.Attr.CreatureActive) == true and root.Position.Y > -100
	setShown(active and phase ~= "Won")
	if not shown or not root then
		displayBase = nil
		return
	end
	local camera = workspace.CurrentCamera

	local currentMode = (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Patrol"
	if currentMode ~= mode then
		onModeChanged(mode, currentMode)
		mode = currentMode
	end

	if tung then
		updateTung(tung, root, dt, camera)
	elseif rig then
		updateLegacy(rig, root, dt, camera)
	end
	-- Na mata não existe farol/halo denunciando o caçador. A lanterna do jogador ainda o revela.
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	local forest = world ~= nil and world:GetAttribute("ForestActive") == true
	local eye = if tung then tung.eyeLight elseif rig then rig.eyeLight else nil
	if eye then
		eye.Enabled = not forest
	end

	-- Fora da perseguição: rosnados e o "TUM TUM TUM" do bastão (assinatura do Tung Tung).
	local now = os.clock()
	if now >= nextGrowlAt and mode ~= "Chase" and mode ~= "Capture" then
		nextGrowlAt = now + rng:NextNumber(7, 14)
		if tung and rng:NextNumber() < 0.6 then
			AudioController.playAt("DoorBang", emitter(), 0.85, 0.72)
			local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
			if distance < 60 then
				-- Legenda no HUD (CampaignController): perto o bastante para ouvir.
				Players.LocalPlayer:SetAttribute(
					"TungKnockSerial",
					((Players.LocalPlayer:GetAttribute("TungKnockSerial") :: number?) or 0) + 1
				)
			end
		else
			AudioController.playAt("Growl", emitter(), 0.9, rng:NextNumber(0.75, 0.95))
		end
	end
end

local CreatureVisualController = {
	Name = "CreatureVisualController",
}

function CreatureVisualController.react(name: string)
	if name == "DoorBang" then
		reaction, reactionUntil = name, os.clock() + 0.45
		if tung then
			-- Pancada do bastão na porta.
			TungTungRig.play(tung, "slash", 0.08, 1.4)
			reactionUntil = os.clock() + 0.85
		end
	end
end

function CreatureVisualController.Init()
	tung = TungTungRig.build(nil)
	if not tung then
		rig = Rig.build(workspace)
		visualModel().Parent = nil
	end
	chaseLoop = AudioController.loopAt("ChaseLoop", emitter())
end

function CreatureVisualController.Start()
	local function watchDoor(inst: Instance)
		-- Portas do mapa antigo ("door_*") e da casa ("house_door_*").
		if
			not inst:IsA("BasePart")
			or not (string.match(inst.Name, "^door_") or string.match(inst.Name, "^house_door_"))
		then
			return
		end
		-- Forçando porta emperrada (cada E): pancada na madeira, leve empurrão de FOV e um tremorzinho para quem força;
		-- ao arrombar: estrondo mais alto e tremor maior.
		local function nearCamera(): number
			local camera = workspace.CurrentCamera
			local distance = if camera then (camera.CFrame.Position - inst.Position).Magnitude else math.huge
			return math.clamp(1 - distance / 40, 0, 1)
		end
		inst:GetAttributeChangedSignal("MansionPushSerial"):Connect(function()
			local near = nearCamera()
			if near <= 0 then
				return
			end
			AudioController.playAt("DoorBang", inst, 0.5 + 0.3 * near, 0.9 + math.random() * 0.2)
			if near > 0.75 then
				CameraController.punch(0.22)
				CameraController.addTrauma(0.08)
			end
		end)
		inst:GetAttributeChangedSignal("MansionBurstSerial"):Connect(function()
			local near = nearCamera()
			if near <= 0 then
				return
			end
			AudioController.playAt("Fall_box", inst, 1 + near * 0.5, 0.7)
			AudioController.playAt("DoorBang", inst, 1.2, 0.7)
			CameraController.addTrauma(0.2 + 0.35 * near)
		end)
		-- Porta batendo sozinha: estrondo de madeira e trinco (som no lugar da porta) e tremor leve para quem está perto.
		inst:GetAttributeChangedSignal("SlamSerial"):Connect(function()
			task.delay(0.18, function()
				local camera = workspace.CurrentCamera
				local distance = if camera then (camera.CFrame.Position - inst.Position).Magnitude else math.huge
				if distance > 70 then
					return
				end
				local near = math.clamp(1 - distance / 70, 0, 1)
				AudioController.playAt("Fall_box", inst, 0.9 + near * 0.6, 0.75)
				AudioController.playAt("DoorLatch", inst, 1.2, 0.8)
				CameraController.addTrauma(0.18 + 0.32 * near)
			end)
		end)
		inst:GetAttributeChangedSignal("BangSerial"):Connect(function()
			local root = serverRoot()
			if root and (root.Position - inst.Position).Magnitude < 12 then
				CreatureVisualController.react("DoorBang")
			end
		end)
	end
	local world = workspace:WaitForChild(Tags.WorldFolder)
	for _, inst in world:GetDescendants() do
		watchDoor(inst)
	end
	world.DescendantAdded:Connect(watchDoor)
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

-- Clipe atual do Tung Tung (nil no boneco antigo); usado por testes e câmeras.
function CreatureVisualController.clip(): string?
	return if tung then TungTungRig.playing(tung) else nil
end

return CreatureVisualController
