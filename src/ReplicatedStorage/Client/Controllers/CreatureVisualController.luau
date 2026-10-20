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

-- Acima disto (studs/s) ele corre mesmo fora da perseguição (caçada com a luz apagada).
local RUN_FROM_SPEED = 12

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
local moving = false
local mode = "Dormant"
local headYaw = 0
local chaseLoop: Sound? = nil
local nextGrowlAt = 0
-- Bastão batendo no chão e rangidos do piso enquanto anda (para dar para saber onde ele está).
local nextCreakAt = 0
local phase: GameState.Phase = "Loading"
local rng = Random.new()
local reaction = ""
local reactionUntil = 0
local lastMiss: any = nil
-- Próxima ação de procura sorteada (espiar debaixo dos móveis ou bater o bastão) quando ele para na busca.
local nextSearchActAt = 0
-- Arrasto pelo pé até a máquina (DragSerial/ThrowSerial na Root, servidor do Desenvolvedor).
local lastDrag: any = nil
local lastThrow: any = nil
local lastWall: any = nil
local draggingUntil = 0
local lastWindup: any = nil

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

-- Sons do Tung Tung chegam longe: o jogador precisa ouvir de que lado ele vem, mesmo atrás de paredes.
local function carry(sound: Sound, near: number, far: number): Sound
	sound.RollOffMinDistance = near
	sound.RollOffMaxDistance = far
	return sound
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

-- Nuvem de serragem (só visual, no cliente): um estouro de lascas e pó marrom que cai devagar.
local function sawdust(position: Vector3, amount: number)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(3, 5, 3)
	part.CFrame = CFrame.new(position)
	local dust = Instance.new("ParticleEmitter")
	dust.Color = ColorSequence.new(Color3.fromRGB(196, 150, 98), Color3.fromRGB(120, 84, 50))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0.9) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.4)
	dust.Speed = NumberRange.new(3, 9)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.Acceleration = Vector3.new(0, -6, 0)
	dust.Drag = 3
	dust.Rate = 0
	dust.Parent = part
	part.Parent = workspace
	dust:Emit(amount)
	task.delay(3, function()
		part:Destroy()
	end)
end

-- Ação inteira (corpo todo) do Tung Tung: segura a troca de clipe até o fim dela.
local function perform(t: TungTungRig.TungRig, name: TungTungRig.ClipName, speed: number, fade: number?)
	local again = TungTungRig.playing(t) == name
	TungTungRig.play(t, name, fade or 0.12, speed)
	if again then
		TungTungRig.restart(t)
	end
	reactionUntil = os.clock() + TungTungRig.duration(name) / speed
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
		-- Perseguição começa com uma pancada no ar (golpe aprovado); a captura é o agarrão com as duas mãos
		-- depois do aviso (WindupSerial). Ouviu barulho: para a cabeça e escuta sem parar de andar.
		if current == "Capture" then
			perform(tung, "grab", 1, 0.15)
		elseif current == "Chase" and previous ~= "Chase" then
			perform(tung, "slash", 1.6, 0.2)
		elseif current == "Investigate" then
			TungTungRig.overlay(tung, "alert", 1)
		elseif current == "Search" then
			nextSearchActAt = os.clock() + rng:NextNumber(1.2, 2.2)
		end
	end
	if current == "Chase" and previous ~= "Chase" then
		carry(AudioController.playAt("Snarl", emitter(), 1.1), 18, 150)
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

-- Passos que informam (ideia E): o som muda com o piso que ele pisa e com o andar. Em outro andar, o passo chega
-- abafado (sem agudos, mais lento) e, se ele está em cima, o teto range junto. O jogador aprende a ler onde ele
-- está só pelo som, como o Mr. X de Resident Evil 2.
local STEP_BY_MATERIAL: { [Enum.Material]: string } = {
	[Enum.Material.Wood] = "StepWood",
	[Enum.Material.WoodPlanks] = "StepWood",
	[Enum.Material.Concrete] = "StepConcrete",
	[Enum.Material.Brick] = "StepConcrete",
	[Enum.Material.Cobblestone] = "StepConcrete",
	[Enum.Material.Slate] = "StepConcrete",
	[Enum.Material.Marble] = "StepConcrete",
	[Enum.Material.Granite] = "StepConcrete",
	[Enum.Material.Basalt] = "StepConcrete",
	[Enum.Material.Pavement] = "StepConcrete",
	[Enum.Material.Metal] = "StepMetal",
	[Enum.Material.DiamondPlate] = "StepMetal",
	[Enum.Material.CorrodedMetal] = "StepMetal",
	[Enum.Material.Carpet] = "StepFallback",
	[Enum.Material.Fabric] = "StepFallback",
	[Enum.Material.Grass] = "StepFallback",
	[Enum.Material.Ground] = "StepFallback",
	[Enum.Material.LeafyGrass] = "StepFallback",
	[Enum.Material.Mud] = "StepWater",
}
local stepRays = RaycastParams.new()
stepRays.FilterType = Enum.RaycastFilterType.Exclude

local function floorUnder(root: BasePart): Enum.Material
	local exclude: { Instance } = { visualModel() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	stepRays.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -(HEIGHT / 2 + 3), 0), stepRays)
	return if hit then hit.Material else Enum.Material.Wood
end

-- Abafa um som que vem de outro andar (parede/piso no meio): corta agudos e, de baixo, engrossa.
local function muffle(sound: Sound, below: boolean)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -22
	eq.MidGain = if below then -10 else -6
	eq.LowGain = if below then 5 else 0
	eq.Parent = sound
	sound.PlaybackSpeed *= 0.88
	sound.Volume *= 0.75
end

local stepParity = false
local function footstep(root: BasePart, camera: Camera?)
	local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
	local dy = if camera then root.Position.Y - camera.CFrame.Position.Y else 0
	local otherFloor = math.abs(dy) > 9
	local volume = if root:GetAttribute("FalseExit") then 0.25 else 1
	local clip = STEP_BY_MATERIAL[floorUnder(root)] or "StepWood"
	local soft = clip == "StepFallback"
	local thud = carry(
		AudioController.playAt(
			"CreatureStep",
			emitter(),
			volume * (if soft then 0.9 else 1.2),
			0.42 + rng:NextNumber(-0.04, 0.04)
		),
		16,
		110
	)
	local surface = carry(
		AudioController.playAt(
			clip,
			emitter(),
			volume * (if soft then 0.9 elseif clip == "StepMetal" then 1.3 else 1.5),
			if clip == "StepConcrete" then rng:NextNumber(0.7, 0.8) else rng:NextNumber(0.5, 0.6)
		),
		14,
		95
	)
	if otherFloor then
		muffle(thud, dy < 0)
		muffle(surface, dy < 0)
		-- Ele em cima: o teto range a cada dois passos, bem acima da sua cabeça.
		stepParity = not stepParity
		if dy > 0 and stepParity and camera and distance < 40 then
			local creak = AudioController.playAtPosition(
				"CreakWood",
				Vector3.new(root.Position.X, camera.CFrame.Position.Y + 6, root.Position.Z),
				0.9,
				rng:NextNumber(0.5, 0.7)
			)
			creak.RollOffMaxDistance = 45
		end
	end
	-- Tremor dos passos pela distância (o compositor respeita a opção de conforto).
	if distance < 30 then
		local k = (30 - distance) / 30
		CameraController.addTrauma(0.22 * k * k * (if otherFloor then 0.5 else 1))
	end
end

local function lookYawAt(base: CFrame, camera: Camera?): number
	if camera and (mode == "Chase" or mode == "Capture" or mode == "Investigate" or mode == "Search") then
		local toCamera = base:PointToObjectSpace(camera.CFrame.Position)
		return math.clamp(math.deg(math.atan2(-toCamera.X, -toCamera.Z)), -50, 50)
	end
	return 0
end

-- TUM: o bastão bate no chão (ou num móvel). Grave, chega longe, treme a câmera de quem está perto.
local function tum(root: BasePart, camera: Camera?)
	carry(AudioController.playAt("StepWood", emitter(), 2.2, rng:NextNumber(0.3, 0.34)), 20, 130)
	carry(AudioController.playAt("CreatureStep", emitter(), 1.4, 0.36), 16, 110)
	local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
	if distance < 26 then
		local k = (26 - distance) / 26
		CameraController.addTrauma(0.3 * k * k)
	end
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

	-- Três posturas que dá para ler de longe pela silhueta: patrulha (alto, bastão pendurado), procura (bastão
	-- no ombro, cabeça varrendo) e perseguição (baixo, bastão erguido atrás da cabeça). Andar e correr tocam na
	-- velocidade da Root para o pé plantado não escorregar.
	local now = os.clock()
	local reacting = now < reactionUntil
	if not reacting then
		local running = moving and (mode == "Chase" or smoothSpeed > RUN_FROM_SPEED)
		if now < draggingUntil then
			-- Arrastando o jogador pelo pé: curvado, puxando com a mão esquerda, na velocidade da Root.
			TungTungRig.play(t, "drag", 0.2, math.clamp(smoothSpeed / TungTungRig.feetSpeed("drag"), 0.5, 1.6))
		elseif mode == "Capture" then
			-- Fica na última pose do agarrão.
			TungTungRig.play(t, "grab", 0.2)
		elseif running then
			TungTungRig.play(t, "run", 0.25, math.clamp(smoothSpeed / TungTungRig.feetSpeed("run"), 0.6, 1.5))
		elseif mode == "Search" and moving then
			local rate = math.clamp(smoothSpeed / TungTungRig.feetSpeed("searchwalk"), 0.6, 1.8)
			TungTungRig.play(t, "searchwalk", 0.25, rate)
		elseif moving then
			TungTungRig.play(t, "walk", 0.25, math.clamp(smoothSpeed / TungTungRig.feetSpeed("walk"), 0.6, 1.8))
		elseif mode == "Search" then
			if now >= nextSearchActAt then
				-- Procura de verdade: espia debaixo dos móveis ou bate o bastão neles (como em Hello Neighbor).
				nextSearchActAt = now + rng:NextNumber(3.5, 6)
				perform(t, if rng:NextNumber() < 0.5 then "peek" else "bash", 1, 0.25)
			else
				TungTungRig.play(t, "search", 0.3)
			end
		elseif mode == "Chase" then
			-- Parado na perseguição (perdeu de vista, recuperando o golpe): para e escuta, respirando.
			TungTungRig.play(t, "listen", 0.25)
		else
			TungTungRig.play(t, "stand", 0.35)
		end
	end

	headYaw += (lookYawAt(base, camera) - headYaw) * math.min(1, dt * 10)
	TungTungRig.step(t, dt, headYaw)

	-- Som no quadro exato da animação: passo quando o pé toca o chão, TUM quando o bastão bate.
	for _, marker in TungTungRig.markers(t) do
		if marker == "step" then
			footstep(root, camera)
		elseif marker == "tap" then
			-- Bastão no chão: TUM (parado, batidas) ou a ponta raspando a cada passo do lado manco (patrulha).
			tum(root, camera)
		elseif marker == "throw" then
			-- O corpo some na boca da máquina neste quadro (o servidor esconde o jogador em 0,55 s).
			carry(AudioController.playAt("WoodSplinter", emitter(), 1.6, 0.8), 14, 90)
		end
	end
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
	-- Golpe que passou raspando (CreatureBrain "miss"): bastão no ar, som e tranco só em quem escapou.
	local miss = tonumber(root:GetAttribute("MissSerial")) or 0
	if lastMiss == nil then
		-- Primeiro quadro (ou entrou no meio da partida): só marca, não toca golpe antigo.
		lastMiss = miss
	end
	if miss ~= lastMiss then
		lastMiss = miss
		do
			reaction, reactionUntil = "Lunge", os.clock() + 0.9
			if tung then
				perform(tung, "slash", 1.5, 0.15)
			end
			carry(AudioController.playAt("SwingMiss", emitter(), 1.8), 10, 90)
			if root:GetAttribute("MissTarget") == Players.LocalPlayer.UserId then
				CameraController.addTrauma(0.55)
				CameraController.punch(1.4)
			end
		end
	end

	-- Aviso antes da pegada (CreatureBrain "windup"): ergue o bastão devagar e rosna; a pegada continua o golpe.
	local windup = tonumber(root:GetAttribute("WindupSerial")) or 0
	if lastWindup == nil then
		lastWindup = windup
	end
	if windup ~= lastWindup then
		lastWindup = windup
		reaction, reactionUntil = "Lunge", os.clock() + Config.Creature.CaptureWindup
		if tung then
			-- Aviso no corpo: trava para trás e abre os braços em "Y" com o bastão no alto (dura o windup todo).
			perform(tung, "warn", TungTungRig.duration("warn") / Config.Creature.CaptureWindup, 0.15)
		end
		carry(AudioController.playAt("Growl", emitter(), 1.8, 0.7), 16, 90)
		if root:GetAttribute("WindupTarget") == Players.LocalPlayer.UserId then
			CameraController.addTrauma(0.25)
		end
	end

	-- Arrasto e arremesso na máquina (só visual; o servidor move a Root e esconde o jogador no impacto).
	local drag = tonumber(root:GetAttribute("DragSerial")) or 0
	local throw = tonumber(root:GetAttribute("ThrowSerial")) or 0
	if lastDrag == nil then
		lastDrag, lastThrow = drag, throw
	end
	if drag ~= lastDrag then
		lastDrag = drag
		draggingUntil = os.clock() + 6
		reactionUntil = 0
	end
	if throw ~= lastThrow then
		lastThrow = throw
		draggingUntil = 0
		if tung then
			perform(tung, "throw", 1, 0.2)
		end
		-- A máquina "come": ronco grave que chega longe, como se ela acordasse lá embaixo.
		task.delay(0.55, function()
			carry(AudioController.playAt("Machinery", emitter(), 3, 0.45), 30, 220)
		end)
	end
	-- Capturas seguintes: arrastado 1,4 s e some dentro da parede numa nuvem de serragem.
	local wall = tonumber(root:GetAttribute("WallSerial")) or 0
	if lastWall == nil then
		lastWall = wall
	end
	if wall ~= lastWall then
		lastWall = wall
		draggingUntil = os.clock() + 1.4
		task.delay(1.4, function()
			sawdust(root.Position, 60)
			carry(AudioController.playAt("WallBurst", emitter(), 1.4, 0.9), 14, 100)
		end)
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
	local awake = mode ~= "Dormant" and (phase == "Playing" or phase == "Intro")
	if tung and awake and moving and mode ~= "Capture" then
		-- Assoalho rangendo sob o peso dele.
		if now >= nextCreakAt then
			nextCreakAt = now + rng:NextNumber(3, 6)
			carry(AudioController.playAt("CreakWood", emitter(), 1.6, rng:NextNumber(0.7, 0.9)), 12, 70)
		end
	end
	if now >= nextGrowlAt and mode ~= "Chase" and mode ~= "Capture" then
		nextGrowlAt = now + rng:NextNumber(5, 9)
		if tung and rng:NextNumber() < 0.6 then
			if not moving and now >= reactionUntil and mode ~= "Search" then
				-- Parado: as três batidas no chão (TUM TUM TUM), cada som no quadro do impacto.
				perform(tung, "knock3", 1, 0.2)
			else
				carry(AudioController.playAt("DoorBang", emitter(), 1, 0.72), 18, 140)
			end
			local distance = if camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge
			if distance < 60 then
				-- Legenda no HUD (CampaignController): perto o bastante para ouvir.
				Players.LocalPlayer:SetAttribute(
					"TungKnockSerial",
					((Players.LocalPlayer:GetAttribute("TungKnockSerial") :: number?) or 0) + 1
				)
			end
		else
			carry(AudioController.playAt("Growl", emitter(), 1, rng:NextNumber(0.75, 0.95)), 16, 130)
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
			perform(tung, "slash", 1.4, 0.2)
		end
	elseif tung and (name == "Stunned" or name == "Knock3") then
		-- Momentos da história (escorregou da van, caiu da ponte, as batidas do final).
		perform(tung, if name == "Stunned" then "stunned" else "knock3", 1, 0.1)
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
