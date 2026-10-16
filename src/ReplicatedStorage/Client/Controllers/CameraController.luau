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

local Config = require("@game/ReplicatedStorage/Shared/Config")
local CharacterController = require("./CharacterController")
local SettingsController = require("./SettingsController")

local C = Config.Camera
local P = Config.Player
local player = Players.LocalPlayer

type Mode = "normal" | "hidden" | "capture" | "spectate"

local mode: Mode = "normal"
local applied = CFrame.identity
local appliedCamera: Camera? = nil

-- Estado dos efeitos
local bobPhase = 0
local bobAmplitude = 0
local breathClock = 0
local tilt = 0
local trauma = 0
local fear = 0
local fearSmooth = 0
local punch = 0
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
	bobPhase += motion.speed * dt * C.BobFrequency * math.pi
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
	local accel = -140 * landOffset - 16 * landVelocity
	landVelocity += accel * dt
	landOffset += landVelocity * dt
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
	return offset
end

local function rotationOffset(dt: number, motion: CharacterController.Motion, now: number): CFrame
	local tiltOn = SettingsController.get("tilt")
	local shakeOn = SettingsController.get("shake")

	-- Inclinação lateral (strafe) + balanço de exaustão.
	local targetTilt = if tiltOn then -motion.lateral / P.WalkSpeed * C.StrafeTilt else 0
	tilt = approach(tilt, math.clamp(targetTilt, -C.StrafeTilt * 1.3, C.StrafeTilt * 1.3), 8, dt)
	local sway = if tiltOn then math.sin(now * 1.7) * motion.exhaustion * 1.4 else 0
	local roll = math.rad(tilt + sway)
	local pitch = if tiltOn then math.rad(math.sin(now * 3.4) * motion.exhaustion * 0.6) else 0

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

local function updateHidden(camera: Camera)
	local origin = hiddenOrigin
	if not origin then
		return
	end
	local delta = UserInputService:GetMouseDelta()
	hiddenYaw = math.clamp(hiddenYaw - delta.X * 0.004, math.rad(-32), math.rad(32))
	hiddenPitch = math.clamp(hiddenPitch - delta.Y * 0.004, math.rad(-18), math.rad(14))
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = origin * CFrame.Angles(0, hiddenYaw, 0) * CFrame.Angles(hiddenPitch, 0, 0)
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
	local look = if target then CFrame.lookAt(from.Position, target) else from
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

	if mode == "spectate" then
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
		updateHidden(camera)
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

-- Entra/sai do modo esconderijo. `eye` = posição e direção do olhar pela fresta.
function CameraController.setHidden(eye: CFrame?)
	local camera = workspace.CurrentCamera
	if eye then
		undo()
		hiddenOrigin = eye
		hiddenYaw = 0
		hiddenPitch = 0
		mode = "hidden"
	elseif mode == "hidden" then
		hiddenOrigin = nil
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
	mode = "normal"
	spectateTarget = nil
	hiddenOrigin = nil
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
		spectating = if spectateTarget then spectateTarget.UserId else nil,
		trauma = trauma,
		fear = fearSmooth,
		crouch = crouchAlpha,
		offset = currentOffset,
		fov = if workspace.CurrentCamera then workspace.CurrentCamera.FieldOfView else 0,
	}
end

function CameraController.Start()
	CharacterController.onLanded(function(intensity: number)
		CameraController.land(intensity)
	end)
	RunService:BindToRenderStep("S9CameraUndo", Enum.RenderPriority.Camera.Value - 1, undo)
	RunService:BindToRenderStep("S9CameraApply", Enum.RenderPriority.Camera.Value + 1, apply)
end

return CameraController
