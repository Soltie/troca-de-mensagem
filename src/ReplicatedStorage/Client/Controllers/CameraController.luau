--!strict
--[[
	Compositor ÚNICO da câmera. Todos os efeitos passam por aqui e são somados uma vez por
	quadro, para nunca brigarem entre si nem acumularem:

	  posição (Humanoid.CameraOffset): balanço ao andar, respiração parada, altura agachado
	    (compensa o "pulo" físico do HipHeight), mergulho do pouso;
	  rotação: inclinação lateral, balanço de exaustão, tremor (trauma), coice do pouso.
	    É aplicada DEPOIS do módulo de câmera do Roblox e desfeita ANTES dele no quadro seguinte,
	    então o mouse e a câmera padrão nunca "herdam" o efeito;
	  FOV: base + corrida - medo + pancada (detecção) + zoom (captura).

	Modos especiais (câmera Scriptable, só enquanto durar):
	  hidden   dentro do armário: olhar limitado às frestas;
	  capture  captura: hit-stop curto (sem travar a thread), vira para o Vigia, zoom, tremor.
	reset() volta tudo ao normal (nova rodada / checkpoint).

	Conforto (SettingsController): bob, tilt, shake e fov desligam cada parte.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local AudioController = require("./AudioController")
local CharacterController = require("./CharacterController")
local SettingsController = require("./SettingsController")

local C = Config.Camera
local P = Config.Player
local player = Players.LocalPlayer

type Mode = "normal" | "hidden" | "capture" | "spectate" | "cinema"
local cinemaFrame = CFrame.identity
local cinemaFov = 60
local cinemaFocus = Vector3.zero
local cinemaReturnFrame: CFrame? = nil

local mode: Mode = "normal"
local windowFocused = true
local modalButtons: { [GuiButton]: boolean } = {}
local applied = CFrame.identity
local appliedCamera: Camera? = nil

-- Estado dos efeitos
local bobAmplitude = 0
local breathClock = 0
local tilt = 0
local trauma = 0
local fear = 0
local fearSmooth = 0
local punch = 0
-- Pancada do Tung Tung: solavanco forte e curto (bem maior que o trauma), além do tremor que fica depois.
local hitAt = -10
local sprintAlpha = 0
local crouchAlpha = 0
local landOffset = 0
local landVelocity = 0
local noiseSeed = math.random() * 1000
local currentOffset = Vector3.zero

-- Esconderijo
local hiddenOrigin: CFrame? = nil
local hiddenYaw = 0
local hiddenPitch = 0
local spectateTarget: Player? = nil

-- Captura
local captureStarted = 0
local captureFrom: CFrame? = nil
local captureTarget: (() -> Vector3?)? = nil
local captureZoom = 0
local HIT_STOP = 0.1

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Recupera o mouse depois do lobby, de cenas e de painéis. Botões modais visíveis
-- continuam liberando o cursor; um botão dentro de um painel fechado não interfere.
local function updatePointer()
	if not UserInputService.MouseEnabled or not windowFocused then
		return
	end
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	local free = mode == "cinema"
		or mode == "capture"
		or mode == "spectate"
		or player:GetAttribute("ModeMenuOpen") == true
		or (campaign ~= nil and campaign:GetAttribute("Phase") == "Lost")
		or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() ~= nil
	if not free then
		for button in modalButtons do
			if not button.Modal then
				continue
			end
			local visible = true
			local ancestor: Instance? = button
			while ancestor and ancestor ~= player.PlayerGui do
				if
					(ancestor:IsA("GuiObject") and not ancestor.Visible)
					or (ancestor:IsA("ScreenGui") and not ancestor.Enabled)
				then
					visible = false
					break
				end
				ancestor = ancestor.Parent
			end
			if visible and ancestor == player.PlayerGui then
				free = true
				break
			end
		end
	end
	UserInputService.MouseBehavior = if free then Enum.MouseBehavior.Default else Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = free
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-rate * dt))
end

-- Desfaz a rotação extra do quadro anterior antes do módulo de câmera do Roblox rodar.
local function undo()
	local camera = workspace.CurrentCamera
	if camera and appliedCamera == camera and applied ~= CFrame.identity then
		camera.CFrame = camera.CFrame * applied:Inverse()
	end
	applied = CFrame.identity
end

-- Queda do armário (fresta segurada demais): o olhar desaba de lado até o chão, fica caído e levanta devagar.
local FALL_DOWN, FALL_HOLD, FALL_UP = 0.35, 0.9, 0.9
local fallStart = -math.huge
local crawlAlpha = 0
local crawlClock = 0
local function fallAmount(now: number): number
	local t = now - fallStart
	if t < 0 or t > FALL_DOWN + FALL_HOLD + FALL_UP then
		return 0
	elseif t < FALL_DOWN then
		local x = t / FALL_DOWN
		return x * x
	elseif t < FALL_DOWN + FALL_HOLD then
		return 1
	end
	local x = (t - FALL_DOWN - FALL_HOLD) / FALL_UP
	return 1 - x * x * (3 - 2 * x)
end

local function positionOffset(dt: number, motion: CharacterController.Motion, root: BasePart): Vector3
	local bobOn = SettingsController.get("bob")
	local shakeOn = SettingsController.get("shake")

	-- Balanço ao andar: fase pela distância percorrida, amplitude pela postura/corrida.
	local targetAmplitude = 0
	if motion.grounded and motion.speed > 0.5 then
		local base = if motion.stance == "Crouch"
			then C.BobCrouchAmplitude
			elseif motion.sprinting then C.BobSprintAmplitude
			else C.BobAmplitude
		targetAmplitude = base * math.clamp(motion.speed / P.WalkSpeed, 0.3, 1.4)
	end
	bobAmplitude = approach(bobAmplitude, targetAmplitude, 10, dt)
	-- Fase pela passada do CharacterController: o ponto mais baixo coincide com o som do pé.
	local bobPhase = (motion.steps + motion.stride) * math.pi
	local offset = Vector3.zero
	if bobOn then
		offset += Vector3.new(math.sin(bobPhase) * bobAmplitude * 0.55, -math.abs(math.cos(bobPhase)) * bobAmplitude, 0)
		-- Respiração parada (mais forte e rápida exausto ou com medo).
		local rate = C.IdleBreathRate * (1 + motion.exhaustion * 1.6 + fearSmooth * 0.8)
		breathClock += dt * rate * math.pi * 2
		local amplitude = C.IdleBreathAmplitude * (1 + motion.exhaustion * 2.2 + fearSmooth)
		offset += Vector3.new(0, math.sin(breathClock) * amplitude, 0)
	end

	-- Pouso: mola amortecida.
	-- Subpassos de no máximo 1/120 s: a mola se comporta igual a 30 ou 240 FPS.
	local steps = math.max(1, math.ceil(dt * 120))
	local h = dt / steps
	for _ = 1, steps do
		local accel = -140 * landOffset - 16 * landVelocity
		landVelocity += accel * h
		landOffset += landVelocity * h
	end
	if shakeOn then
		offset += Vector3.new(0, math.clamp(landOffset, -0.9, 0.3), 0)
	end

	-- Agachar: altura do olho suave, compensando a mudança física do HipHeight.
	crouchAlpha = approach(crouchAlpha, if motion.stance == "Crouch" then 1 else 0, C.CrouchSpeed, dt)
	local floorY = motion.floorY
	if crouchAlpha > 0.002 and motion.grounded and floorY then
		local standEye = floorY + motion.standHipHeight + root.Size.Y / 2 + 1.5
		local desiredEye = standEye - C.CrouchEyeDrop * crouchAlpha
		local actualEye = root.Position.Y + 1.5
		offset += Vector3.new(0, math.clamp(desiredEye - actualEye, -3, 1.5), 0)
	end
	local fall = fallAmount(os.clock())
	if fall > 0 then
		offset += Vector3.new(0.6 * fall, -3.7 * fall, 0)
	end
	-- Derrubado pelo Tung Tung: olhar rente ao chão enquanto rasteja, balançando a cada puxada de braço.
	crawlAlpha = approach(crawlAlpha, if player:GetAttribute("Crawling") == true then 1 else 0, 5, dt)
	if crawlAlpha > 0.001 then
		crawlClock += dt * (0.6 + motion.speed * 1.6)
		offset += Vector3.new(math.sin(crawlClock) * 0.12, -3.9 + math.abs(math.cos(crawlClock)) * 0.12, 0) * crawlAlpha
	end
	return offset
end

local function rotationOffset(dt: number, motion: CharacterController.Motion, now: number): CFrame
	local tiltOn = SettingsController.get("tilt")
	local shakeOn = SettingsController.get("shake")

	-- Inclinação lateral (strafe) + balanço de exaustão.
	local targetTilt = if tiltOn then -motion.lateral / P.WalkSpeed * C.StrafeTilt else 0
	tilt = approach(tilt, math.clamp(targetTilt, -C.StrafeTilt, C.StrafeTilt), 8, dt)
	local sway = if tiltOn then math.sin(now * 1.7) * motion.exhaustion * 0.6 else 0
	local roll = math.rad(math.clamp(tilt + sway, -C.MaxRoll, C.MaxRoll))
	local pitch = if tiltOn then math.rad(math.sin(now * 3.4) * motion.exhaustion * 0.6) else 0
	-- Corrida: o olhar inclina um pouco para frente (entra e sai junto com o FOV).
	if tiltOn then
		pitch -= math.rad(C.SprintLean) * sprintAlpha
	end

	-- Caído no chão: cabeça de lado e olhando um pouco para baixo (vale mesmo com o conforto de inclinação).
	local fall = fallAmount(now)
	if fall > 0 then
		roll += math.rad(76) * fall
		pitch -= math.rad(14) * fall
	end

	-- Solavanco da pancada: a cabeça chicoteia para o lado e treme forte, morrendo em ~1 s.
	local sinceHit = now - hitAt
	if shakeOn and sinceHit < 1.2 then
		local jolt = math.exp(-sinceHit * 4.2)
		local t = now * 26
		pitch += math.rad(8) * jolt * math.noise(noiseSeed + 120, t) - math.rad(6) * jolt
		roll += math.rad(12) * jolt * math.noise(noiseSeed + 160, t) + math.rad(16) * jolt
	end

	-- Tremor por trauma (quadrático) + leve tremor de pânico.
	trauma = math.max(0, trauma - C.TraumaDecay * dt)
	local panic = if fearSmooth > 0.8 then (fearSmooth - 0.8) * 0.6 else 0
	local amount = math.max(trauma, panic)
	if shakeOn and amount > 0 then
		local angle = math.rad(C.ShakeMaxAngle) * amount * amount
		local t = now * 18
		pitch += angle * math.noise(noiseSeed, t)
		roll += angle * math.noise(noiseSeed + 40, t)
		local yaw = angle * math.noise(noiseSeed + 80, t)
		-- Coice do pouso inclina para baixo junto com o mergulho.
		pitch += math.rad(math.clamp(landOffset, -0.9, 0) * 4)
		return CFrame.Angles(pitch, yaw, roll)
	end
	if shakeOn then
		pitch += math.rad(math.clamp(landOffset, -0.9, 0) * 4)
	end
	return CFrame.Angles(pitch, 0, roll)
end

local function fieldOfView(dt: number, motion: CharacterController.Motion): number
	sprintAlpha = approach(sprintAlpha, if motion.sprinting and motion.speed > P.WalkSpeed then 1 else 0, 4, dt)
	punch = approach(punch, 0, 3.2, dt)
	if not SettingsController.get("fov") then
		return P.FieldOfView
	end
	local fov = P.FieldOfView
		+ C.SprintFov * sprintAlpha
		- C.FearFovNarrow * fearSmooth ^ 1.5
		+ C.PunchFov * punch
		- captureZoom
	return math.clamp(fov, 40, 95)
end

--[[
	Guarda-roupa de duas portas: escondido, a câmera fica atrás das portas fechadas (só o escuro e o vão entre as
	folhas). Espiando (Espaço), a câmera chega perto do vão e as folhas abrem um pouco só no cliente. Esconderijos
	sem guarda-roupa (cama, baú) mantêm o olhar antigo.
]]
type PeekLeaf = { part: BasePart, rest: CFrame, hinge: Vector3, sign: number }
local peekTarget = 0
local peekAmount = 0
local peekLeaves: { PeekLeaf }? = nil
local PEEK_BACK_CLOSED = 1.5
local peekGlow: SpotLight? = nil
local PEEK_BACK_OPEN = 0.7
local PEEK_ANGLE = math.rad(20)

local function findWardrobe(eye: CFrame): { PeekLeaf }?
	local best: Model? = nil
	local bestDistance = 3
	for _, model in workspace:GetDescendants() do
		if model:IsA("Model") and model.Name == "WardrobeDouble" then
			-- Há um guarda-roupa por andar na mesma coluna: o do andar certo tem o pivô (chão) logo abaixo do olho.
			local offset = model:GetPivot().Position - eye.Position
			local distance = offset * Vector3.new(1, 0, 1)
			if distance.Magnitude < bestDistance and offset.Y < 0 and offset.Y > -9 then
				best, bestDistance = model, distance.Magnitude
			end
		end
	end
	if not best then
		return nil
	end
	local center = best:GetPivot().Position
	local out = eye.LookVector
	local leaves: { PeekLeaf } = {}
	for _, name in { "LeafA", "LeafB" } do
		local part = best:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			-- Dobradiça na borda da folha mais longe do centro do guarda-roupa.
			local half = part.CFrame.RightVector * part.Size.X / 2
			local a, b = part.Position + half, part.Position - half
			local hinge = if (a - center).Magnitude > (b - center).Magnitude then a else b
			-- Sentido do giro que leva a folha para fora (para onde o olhar aponta).
			local probe = CFrame.new(hinge) * CFrame.Angles(0, 0.2, 0) * CFrame.new(part.Position - hinge)
			local sign = if (probe.Position - part.Position):Dot(out) > 0 then 1 else -1
			table.insert(leaves, { part = part, rest = part.CFrame, hinge = hinge, sign = sign })
		end
	end
	return if #leaves > 0 then leaves else nil
end

local function poseLeaves(amount: number)
	local leaves = peekLeaves
	if not leaves then
		return
	end
	for _, leaf in leaves do
		local turn = CFrame.Angles(0, leaf.sign * PEEK_ANGLE * amount, 0)
		leaf.part.CFrame = CFrame.new(leaf.hinge) * turn * (CFrame.new(-leaf.hinge) * leaf.rest)
	end
end

local function updateHidden(camera: Camera, dt: number)
	local origin = hiddenOrigin
	if not origin then
		return
	end
	local delta = UserInputService:GetMouseDelta()
	hiddenYaw = math.clamp(hiddenYaw - delta.X * 0.004, math.rad(-32), math.rad(32))
	hiddenPitch = math.clamp(hiddenPitch - delta.Y * 0.004, math.rad(-18), math.rad(14))
	-- Mola curta: abre em ~0,25 s e fecha em ~0,2 s, sem depender do FPS.
	dt = math.min(dt, 1 / 15)
	peekAmount += (peekTarget - peekAmount) * (1 - math.exp(-14 * dt))
	poseLeaves(peekAmount)
	local back = if peekLeaves then PEEK_BACK_CLOSED + (PEEK_BACK_OPEN - PEEK_BACK_CLOSED) * peekAmount else 0
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = origin * CFrame.new(0, 0, back) * CFrame.Angles(0, hiddenYaw, 0) * CFrame.Angles(hiddenPitch, 0, 0)
	-- Luz fraca da fresta (só no cliente): fechado, um fio de luz no vão; espiando, clareia o cômodo à frente o
	-- bastante para ver os vultos (sem virar lanterna).
	local glow: SpotLight
	local existing = peekGlow
	if existing and existing.Parent then
		glow = existing
	else
		local holder = Instance.new("Attachment")
		holder.Name = "PeekGlow"
		holder.Parent = workspace.Terrain
		glow = Instance.new("SpotLight")
		glow.Face = Enum.NormalId.Front
		glow.Angle = 90
		glow.Shadows = false
		glow.Color = Color3.fromRGB(196, 206, 226)
		glow.Parent = holder
		peekGlow = glow
	end
	local holder = glow.Parent :: Attachment
	holder.WorldCFrame = origin * CFrame.new(0, -0.6, -0.4)
	glow.Enabled = true
	glow.Brightness = 0.3 + 3.2 * peekAmount
	glow.Range = 8 + 22 * peekAmount
end

-- De onde a captura olha o Tung: um pouco recuado e acima da cabeça dele, sem atravessar parede. Antes era o olho
-- de quem caiu (no chão): colada no tapete/parede, a tela de derrota mostrava um "quadrado verde" na cintura dele.
local function captureSpot(from: Vector3, target: Vector3): Vector3
	local away = (from - target) * Vector3.new(1, 0, 1)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.zAxis
	local want = target + away * 6.5 + Vector3.new(0, 0.8, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	for _, item in { player.Character, workspace:FindFirstChild("VigiaVisual"), workspace:FindFirstChild("Vigia") } do
		if item then
			table.insert(ignore, item)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(target, want - target, params)
	if hit then
		want = target + (want - target).Unit * math.max(1.5, (hit.Position - target).Magnitude - 1)
	end
	return want
end

local function updateCapture(camera: Camera, now: number, dt: number)
	camera.CameraType = Enum.CameraType.Scriptable
	local from = captureFrom or camera.CFrame
	captureFrom = from
	local elapsed = now - captureStarted
	-- Hit-stop: segura a imagem por HIT_STOP segundos (a thread segue livre).
	if elapsed < HIT_STOP then
		camera.CFrame = from
		return
	end
	local targetFn = captureTarget
	local target = if targetFn then targetFn() else nil
	local look = if target then CFrame.lookAt(captureSpot(from.Position, target), target) else from
	local t = math.clamp((elapsed - HIT_STOP) / 0.22, 0, 1)
	local eased = 1 - (1 - t) ^ 3
	local base = from:Lerp(look, eased)
	if SettingsController.get("fov") then
		captureZoom = approach(captureZoom, 22, 6, dt)
	end
	local shake = CFrame.identity
	if SettingsController.get("shake") then
		local angle = math.rad(3.2) * math.max(0, 1 - elapsed / 1.6)
		shake = CFrame.Angles(angle * math.noise(noiseSeed, now * 30), angle * math.noise(noiseSeed + 9, now * 30), 0)
	end
	camera.CFrame = base * shake
end

local function apply(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local now = os.clock()
	local motion = CharacterController.getMotion()
	fearSmooth = approach(fearSmooth, fear, 3, dt)

	if mode == "cinema" then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cinemaFrame
		camera.Focus = CFrame.new(cinemaFocus)
		camera.FieldOfView = if SettingsController.get("fov") then cinemaFov else P.FieldOfView
		return
	elseif mode == "spectate" then
		local character = spectateTarget and spectateTarget.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			-- Olho do colega, sem câmera livre, zoom ou visão através de paredes.
			local forward = head.CFrame.LookVector
			local offset = forward * (head.Size.Z / 2 + 0.05)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local exclude: { Instance } = { character :: Model }
			if player.Character then
				table.insert(exclude, player.Character)
			end
			params.FilterDescendantsInstances = exclude
			local hit = workspace:Raycast(head.Position, offset, params)
			local eye = if hit then hit.Position - forward * 0.1 else head.Position + offset
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.new(eye) * head.CFrame.Rotation
			camera.FieldOfView = P.FieldOfView
		end
		return
	elseif mode == "hidden" then
		updateHidden(camera, dt)
		camera.FieldOfView = fieldOfView(dt, motion)
		return
	elseif mode == "capture" then
		updateCapture(camera, now, dt)
		camera.FieldOfView = fieldOfView(dt, motion)
		return
	end

	local h = humanoid()
	local root = rootPart()
	if h and root then
		local offset = positionOffset(dt, motion, root)
		currentOffset = offset
		h.CameraOffset = offset
	end
	local rotation = rotationOffset(dt, motion, now)
	camera.CFrame = camera.CFrame * rotation
	applied = rotation
	appliedCamera = camera
	camera.FieldOfView = fieldOfView(dt, motion)
end

local CameraController = {
	Name = "CameraController",
}

function CameraController.setCinema(frame: CFrame, fov: number, focus: Vector3?): boolean
	if mode == "capture" or mode == "hidden" or mode == "spectate" then
		return false
	end
	undo()
	if mode ~= "cinema" and workspace.CurrentCamera then
		cinemaReturnFrame = workspace.CurrentCamera.CFrame
	end
	mode = "cinema"
	cinemaFrame = frame
	cinemaFov = fov
	cinemaFocus = focus or (frame.Position + frame.LookVector * 20)
	return true
end

function CameraController.endCinema()
	if mode == "cinema" then
		CameraController.reset()
	end
end

function CameraController.setSpectator(target: Player?)
	if target then
		if mode == "capture" then
			return
		end
		undo()
		spectateTarget = target
		mode = "spectate"
	elseif mode == "spectate" then
		CameraController.reset()
	end
end

-- Tremor: soma trauma (0..1). O efeito é quadrático (pequenos valores quase não aparecem).
function CameraController.addTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

-- Compatível com a API antiga: amplitude ~ trauma (a duração vem do decaimento).
function CameraController.shake(amount: number, _duration: number?)
	CameraController.addTrauma(math.clamp(amount * 4, 0, 1))
end

-- Pancada forte (Tung Tung derrubou): solavanco + tremor no máximo + FOV + mergulho.
function CameraController.hit()
	hitAt = os.clock()
	CameraController.addTrauma(1)
	CameraController.punch(1.3)
	CameraController.land(1)
end

-- Pancada de FOV (ex.: o Vigia te viu). 1 = PunchFov graus.
function CameraController.punch(amount: number?)
	punch = math.max(punch, amount or 1)
end

-- Medo 0..1 (FearController empurra a cada quadro).
function CameraController.setFear(value: number)
	fear = math.clamp(value, 0, 1)
end

-- Pouso (0..1): mergulho + coice.
function CameraController.land(intensity: number)
	landVelocity -= 6 * math.clamp(intensity, 0, 1)
	CameraController.addTrauma(0.25 * intensity)
end

-- Espiar pela fresta (InteractionController): abre as folhas um pouco e aproxima o olhar do vão.
function CameraController.setPeek(value: boolean)
	peekTarget = if value then 1 else 0
end

-- Entra/sai do modo esconderijo. `eye` = posição e direção do olhar pela fresta.
function CameraController.setHidden(eye: CFrame?)
	local camera = workspace.CurrentCamera
	if eye then
		undo()
		hiddenOrigin = eye
		hiddenYaw = 0
		hiddenPitch = 0
		peekTarget, peekAmount = 0, 0
		peekLeaves = findWardrobe(eye)
		mode = "hidden"
	elseif mode == "hidden" then
		-- Devolve as folhas ao lugar (o servidor também gira na saída).
		poseLeaves(0)
		peekLeaves = nil
		peekTarget, peekAmount = 0, 0
		hiddenOrigin = nil
		if peekGlow then
			peekGlow.Enabled = false
		end
		mode = "normal"
		if camera then
			camera.CameraType = Enum.CameraType.Custom
		end
	end
end

-- Captura: hit-stop, vira para `target()` (cabeça do Vigia), zoom e tremor.
function CameraController.capture(target: () -> Vector3?)
	if mode == "capture" then
		return
	end
	undo()
	mode = "capture"
	captureStarted = os.clock()
	captureFrom = nil
	captureTarget = target
end

function CameraController.isCapturing(): boolean
	return mode == "capture"
end

-- Volta tudo ao normal (nova rodada, checkpoint, saída de cena).
function CameraController.reset()
	undo()
	local returnFrame = if mode == "cinema" then cinemaReturnFrame else nil
	cinemaReturnFrame = nil
	mode = "normal"
	spectateTarget = nil
	hiddenOrigin = nil
	if peekGlow then
		peekGlow.Enabled = false
	end
	captureTarget = nil
	captureFrom = nil
	captureZoom = 0
	trauma = 0
	punch = 0
	tilt = 0
	landOffset = 0
	landVelocity = 0
	fear = 0
	fearSmooth = 0
	applied = CFrame.identity
	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.CameraSubject = humanoid()
		if returnFrame then
			camera.CFrame = returnFrame
		end
		local root = rootPart()
		if root then
			camera.Focus = CFrame.new(root.Position + Vector3.new(0, 1.5, 0))
		end
		camera.FieldOfView = P.FieldOfView
	end
	local h = humanoid()
	if h then
		h.CameraOffset = Vector3.zero
	end
end

-- Para testes/depuração.
function CameraController.debugState(): { [string]: any }
	return {
		mode = mode,
		mouseBehavior = UserInputService.MouseBehavior.Name,
		spectating = if spectateTarget then spectateTarget.UserId else nil,
		trauma = trauma,
		fear = fearSmooth,
		crouch = crouchAlpha,
		offset = currentOffset,
		fov = if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView else 0,
	}
end

-- Cai no chão (queda do armário): trava o andar enquanto isso, baque e tremor no impacto.
function CameraController.fall()
	fallStart = os.clock()
	CharacterController.stun(FALL_DOWN + FALL_HOLD + FALL_UP * 0.6)
	task.delay(FALL_DOWN, function()
		CameraController.addTrauma(0.55)
		AudioController.play("Fall_box", 0.8, 0.85)
		AudioController.play("Land", 1, 0.8)
	end)
end

function CameraController.Start()
	-- Pancada do Tung Tung derruba: baque no chão e tremor; daí em diante rasteja (crawlAlpha).
	player:GetAttributeChangedSignal("Crawling"):Connect(function()
		if player:GetAttribute("Crawling") == true then
			CameraController.hit()
			AudioController.play("Land", 1, 0.75)
			AudioController.play("Fall_box", 0.6, 0.8)
		end
	end)
	player:GetAttributeChangedSignal("HideFellAt"):Connect(function()
		local at = player:GetAttribute("HideFellAt")
		if type(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) < 2 then
			CameraController.fall()
		end
	end)
	local playerGui = player:WaitForChild("PlayerGui")
	local function track(instance: Instance)
		if instance:IsA("GuiButton") then
			modalButtons[instance] = true
		end
	end
	for _, instance in playerGui:GetDescendants() do
		track(instance)
	end
	playerGui.DescendantAdded:Connect(track)
	playerGui.DescendantRemoving:Connect(function(instance: Instance)
		if instance:IsA("GuiButton") then
			modalButtons[instance] = nil
		end
	end)
	UserInputService.WindowFocused:Connect(function()
		windowFocused = true
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		windowFocused = false
	end)
	CharacterController.onLanded(function(intensity: number)
		CameraController.land(intensity)
	end)
	RunService:BindToRenderStep("S9CameraUndo", Enum.RenderPriority.Camera.Value - 1, undo)
	RunService:BindToRenderStep("S9CameraApply", Enum.RenderPriority.Camera.Value + 1, apply)
	RunService:BindToRenderStep("S9CameraPointer", Enum.RenderPriority.Last.Value + 1, updatePointer)
end

return CameraController
