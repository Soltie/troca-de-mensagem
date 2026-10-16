--!strict
--[[
	Lanterna na mão (cliente). HUD diegético: a carga aparece nos 4 LEDs em cima da lanterna.

	- F pede liga/desliga ao servidor (SetFlashlight); quem decide é a bateria no servidor
	  (atributos "Flashlight" e "Battery" do Player). Sem carga: clique seco e aviso.
	- A luz segue a mão com atraso (balanço/peso) e acompanha o passo; poeira só aparece no feixe.
	- Falhas: em passos perto do Vigia, com bateria fraca e quando o diretor de tensão pede.
	- Animações locais que representam resultados JÁ aprovados pelo servidor:
	  item voando para a mão (pegar) e chave na fechadura (inserir, girar, clique).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BatteryModel = require("@game/ReplicatedStorage/Shared/Game/BatteryModel")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local CharacterController = require("./CharacterController")

local player = Players.LocalPlayer
local BASE_BRIGHTNESS = 2.6
local WARM = Color3.fromRGB(255, 232, 196)

type Viewmodel = {
	model: Model,
	root: BasePart,
	lens: BasePart,
	leds: { BasePart },
	parts: { BasePart },
}

local wanted = true
local phase: GameState.Phase = "Loading"
local viewmodel: Viewmodel? = nil
local emitter: BasePart? = nil
local spot: SpotLight? = nil
local spill: PointLight? = nil
local dust: ParticleEmitter? = nil
local smoothed: CFrame? = nil
local flickerClock = 0
local flickerFactor = 1
local forcedFlickerUntil = 0
local restoreAfterHide = false
local hintCallbacks: { (string) -> () } = {}
local rng = Random.new()

local function charge(): number
	local value = player:GetAttribute("Battery")
	return if type(value) == "number" then value else Config.Battery.StartCharge
end

local function serverOn(): boolean
	return player:GetAttribute(Tags.Attr.Flashlight) == true
end

local function isHidden(): boolean
	local hidden = player:GetAttribute("Hidden")
	return type(hidden) == "string" and hidden ~= ""
end

local function hint(key: string)
	for _, callback in hintCallbacks do
		task.spawn(callback, key)
	end
end

local function creatureDistance(position: Vector3): number
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	if root and root:IsA("BasePart") and root:GetAttribute(Tags.Attr.CreatureActive) then
		return (root.Position - position).Magnitude
	end
	return math.huge
end

local function send(value: boolean)
	task.spawn(function()
		local ok, remote = pcall(Remotes.clientEvent, "SetFlashlight", 10)
		if ok then
			remote:FireServer(value)
		end
	end)
end

local function localPart(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Lanterna low poly + mão + manga (só o jogador vê; peças locais sob a câmera).
local function buildViewmodel(): Viewmodel
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local parts: { BasePart } = {}
	local function add(name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		local part = localPart(model, name, size, color, material)
		table.insert(parts, part)
		return part
	end
	local root = add("Body", Vector3.new(0.17, 0.17, 0.85), Color3.fromRGB(38, 40, 44), Enum.Material.Metal)
	add("Head", Vector3.new(0.27, 0.27, 0.2), Color3.fromRGB(52, 54, 58), Enum.Material.Metal)
	local lens = add("Lens", Vector3.new(0.22, 0.22, 0.03), Color3.fromRGB(90, 88, 80), Enum.Material.SmoothPlastic)
	add("Switch", Vector3.new(0.06, 0.04, 0.12), Color3.fromRGB(150, 32, 28))
	add("Hand", Vector3.new(0.26, 0.24, 0.36), Color3.fromRGB(150, 118, 96))
	add("Thumb", Vector3.new(0.08, 0.08, 0.18), Color3.fromRGB(140, 110, 90))
	add("Sleeve", Vector3.new(0.32, 0.32, 0.7), Color3.fromRGB(46, 58, 54), Enum.Material.Fabric)
	local leds: { BasePart } = {}
	for i = 1, BatteryModel.LEDS do
		local led = add(`Led{i}`, Vector3.new(0.035, 0.03, 0.05), Color3.fromRGB(20, 20, 20), Enum.Material.Neon)
		table.insert(leds, led)
	end
	model.PrimaryPart = root
	return { model = model, root = root, lens = lens, leds = leds, parts = parts }
end

-- Posições locais (em relação ao corpo da lanterna, -Z = frente).
local OFFSETS: { [string]: CFrame } = {
	Body = CFrame.identity,
	Head = CFrame.new(0, 0, -0.5),
	Lens = CFrame.new(0, 0, -0.61),
	Switch = CFrame.new(0, 0.1, -0.12),
	Hand = CFrame.new(0.02, -0.11, 0.08),
	Thumb = CFrame.new(-0.11, 0.02, -0.02),
	Sleeve = CFrame.new(0.05, -0.2, 0.6) * CFrame.Angles(math.rad(-12), 0, 0),
	Led1 = CFrame.new(0, 0.095, 0.06),
	Led2 = CFrame.new(0, 0.095, 0.12),
	Led3 = CFrame.new(0, 0.095, 0.18),
	Led4 = CFrame.new(0, 0.095, 0.24),
}

local function placeViewmodel(base: CFrame)
	local vm = viewmodel
	if not vm then
		return
	end
	for _, part in vm.parts do
		part.CFrame = base * (OFFSETS[part.Name] or CFrame.identity)
	end
end

local function updateLeds(now: number)
	local vm = viewmodel
	if not vm then
		return
	end
	local c = charge()
	local lit = BatteryModel.leds(c)
	local low = BatteryModel.isLow(c)
	local blinkOff = low and (now * 2.5) % 1 < 0.4
	for i, led in vm.leds do
		local on = i <= lit and not (lit == 1 and blinkOff)
		if not on then
			led.Color = Color3.fromRGB(22, 22, 22)
		elseif lit >= 3 then
			led.Color = Color3.fromRGB(70, 255, 110)
		elseif lit == 2 then
			led.Color = Color3.fromRGB(255, 190, 60)
		else
			led.Color = Color3.fromRGB(255, 60, 50)
		end
	end
end

local function applyVisible()
	local on = serverOn() and phase ~= "Won" and not isHidden()
	if spot then
		spot.Enabled = on
	end
	if spill then
		spill.Enabled = on
	end
	if dust then
		dust.Enabled = on
	end
	local vm = viewmodel
	if vm then
		vm.lens.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
		vm.lens.Color = if on then WARM else Color3.fromRGB(90, 88, 80)
	end
end

local FlashlightController = {
	Name = "FlashlightController",
}

function FlashlightController.isOn(): boolean
	return serverOn()
end

function FlashlightController.isWanted(): boolean
	return wanted
end

-- Pede ligar/desligar (o servidor confirma pelo atributo).
function FlashlightController.set(value: boolean, silent: boolean?)
	if value and charge() < Config.Battery.MinToTurnOn then
		AudioController.play("Flashlight", 0.6, 0.7)
		hint("battery_empty")
		return
	end
	wanted = value
	if not silent then
		AudioController.play("Flashlight", 1, 1.15)
	end
	send(value)
end

-- Falha forte por `duration` s (diretor de tensão, susto).
function FlashlightController.flicker(duration: number)
	forcedFlickerUntil = math.max(forcedFlickerUntil, os.clock() + duration)
end

function FlashlightController.onHint(callback: (key: string) -> ())
	table.insert(hintCallbacks, callback)
end

-- Item "voa" até a mão e some (o servidor já aprovou a coleta).
function FlashlightController.showPickup(kind: string, from: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local color = if kind == "Key"
		then Color3.fromRGB(176, 140, 64)
		elseif kind == "Battery" then Color3.fromRGB(186, 150, 40)
		elseif kind == "Note" then Color3.fromRGB(212, 204, 178)
		else Color3.fromRGB(222, 216, 198)
	local size = if kind == "Key" then Vector3.new(0.3, 0.5, 0.08) else Vector3.new(0.5, 0.22, 0.22)
	local item = localPart(camera, "PickupFx", size, color, Enum.Material.SmoothPlastic)
	item.CFrame = CFrame.new(from)
	AudioController.play("Pickup", 0.8, 1.2)
	task.spawn(function()
		local frames = 6
		local start = CFrame.new(from) * item.CFrame.Rotation
		for i = 1, frames do
			local cam = workspace.CurrentCamera
			if not cam then
				break
			end
			local hand = cam.CFrame * CFrame.new(-0.35, -0.5, -1.1) * CFrame.Angles(0.4, 0.6, 0)
			local t = i / frames
			local eased = 1 - (1 - t) ^ 2
			item.CFrame = start:Lerp(hand, eased)
			item.Size = size * (1 - 0.5 * t)
			task.wait(1 / 20)
		end
		item:Destroy()
	end)
end

-- Chave na fechadura: aparece na mão, avança, gira em dois passos com cliques (~UnlockTime).
function FlashlightController.playKeyUnlock()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local model = Instance.new("Model")
	model.Name = "KeyFx"
	model.Parent = camera
	local bow =
		localPart(model, "Bow", Vector3.new(0.16, 0.16, 0.03), Color3.fromRGB(176, 140, 64), Enum.Material.Metal)
	local blade =
		localPart(model, "Blade", Vector3.new(0.04, 0.03, 0.3), Color3.fromRGB(176, 140, 64), Enum.Material.Metal)
	task.spawn(function()
		local steps: { { forward: number, roll: number, wait: number, sound: boolean } } = {
			{ forward = 0, roll = 0, wait = 0.15, sound = false },
			{ forward = 0.15, roll = 0, wait = 0.15, sound = false },
			{ forward = 0.3, roll = 0, wait = 0.25, sound = true },
			{ forward = 0.3, roll = 45, wait = 0.2, sound = true },
			{ forward = 0.3, roll = 90, wait = 0.45, sound = true },
		}
		for _, s in steps do
			local cam = workspace.CurrentCamera
			if not cam then
				break
			end
			local base = cam.CFrame * CFrame.new(-0.1, -0.32, -0.9 - s.forward) * CFrame.Angles(0, 0, math.rad(s.roll))
			blade.CFrame = base * CFrame.new(0, 0, -0.15)
			bow.CFrame = base * CFrame.new(0, 0, 0.03)
			if s.sound then
				AudioController.play("KeyTurn", 0.9, 1.3 + s.roll / 200)
			end
			task.wait(s.wait)
		end
		model:Destroy()
	end)
end

function FlashlightController.Init()
	local part = Instance.new("Part")
	part.Name = "FlashlightRig"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 46
	light.Range = 48
	light.Brightness = BASE_BRIGHTNESS
	light.Color = WARM
	light.Shadows = false
	light.Parent = part

	local glow = Instance.new("PointLight")
	glow.Range = 7
	glow.Brightness = 0.25
	glow.Color = WARM
	glow.Shadows = false
	glow.Parent = part

	-- Poeira: volume à frente da lanterna; partículas só aparecem onde há luz (LightInfluence 1).
	local volume = Instance.new("Part")
	volume.Name = "DustVolume"
	volume.Size = Vector3.new(4, 3, 9)
	volume.Transparency = 1
	volume.Anchored = true
	volume.CanCollide = false
	volume.CanQuery = false
	volume.CanTouch = false
	local particles = Instance.new("ParticleEmitter")
	particles.Shape = Enum.ParticleEmitterShape.Box
	particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	particles.Rate = 16
	particles.Lifetime = NumberRange.new(2.5, 4)
	particles.Speed = NumberRange.new(0.05, 0.25)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Drag = 1.5
	particles.Acceleration = Vector3.new(0, -0.05, 0)
	particles.Size = NumberSequence.new(0.045)
	particles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.45),
		NumberSequenceKeypoint.new(0.8, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	particles.Color = ColorSequence.new(Color3.fromRGB(220, 214, 200))
	particles.LightInfluence = 1
	particles.LightEmission = 0
	particles.Parent = volume
	volume.Parent = part

	part.Parent = workspace
	emitter = part
	spot = light
	spill = glow
	dust = particles
	local vm = buildViewmodel()
	vm.model.Parent = workspace.CurrentCamera
	viewmodel = vm
end

function FlashlightController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.F and input.KeyCode ~= Enum.KeyCode.ButtonY then
			return
		end
		if (phase == "Playing" or phase == "Intro") and not isHidden() then
			FlashlightController.set(not wanted)
		end
	end)

	player:GetAttributeChangedSignal(Tags.Attr.Flashlight):Connect(function()
		applyVisible()
		if wanted and not serverOn() and charge() <= 0.001 and phase == "Playing" then
			hint("battery_dead")
			AudioController.play("Flashlight", 0.7, 0.6)
		end
	end)
	player:GetAttributeChangedSignal("Hidden"):Connect(function()
		-- Dentro do armário a luz vazaria pelas frestas: apaga e volta ao sair.
		if isHidden() then
			restoreAfterHide = wanted
			if wanted then
				FlashlightController.set(false, true)
			end
		elseif restoreAfterHide then
			restoreAfterHide = false
			FlashlightController.set(true, true)
		end
		applyVisible()
	end)
	player.CharacterAdded:Connect(function()
		wanted = true
		restoreAfterHide = false
		applyVisible()
	end)

	GameState.observe(function(snapshot)
		phase = snapshot.phase
		applyVisible()
	end)

	RunService:BindToRenderStep("S9Flashlight", Enum.RenderPriority.Camera.Value + 2, function(dt: number)
		local camera = workspace.CurrentCamera
		local part = emitter
		local vm = viewmodel
		if not camera or not part or not vm then
			return
		end
		if vm.model.Parent ~= camera then
			vm.model.Parent = camera
		end
		local now = os.clock()
		local motion = CharacterController.getMotion()

		-- Mão com peso: a rotação segue a câmera com atraso; corrida abaixa a lanterna.
		local lower = if motion.sprinting then math.rad(-14) else 0
		local target = camera.CFrame * CFrame.Angles(lower, 0, 0)
		smoothed = if smoothed then smoothed:Lerp(target, math.min(1, dt * 11)) else target
		local rotation = (smoothed :: CFrame).Rotation
		local bob = math.sin(now * (if motion.sprinting then 11 else 7)) * math.min(motion.speed / 16, 1)
		local hand = CFrame.new(camera.CFrame.Position)
			* rotation
			* CFrame.new(0.42 + bob * 0.02, -0.42 + math.abs(bob) * -0.025, -0.95)
		local visible = not motion.hidden
			and phase ~= "Won"
			and (phase == "Playing" or phase == "Intro" or phase == "Lost")
		vm.model.Parent = if visible then camera else nil
		placeViewmodel(hand)
		part.CFrame = hand * CFrame.new(0, 0, -0.62)
		local volume = part:FindFirstChild("DustVolume")
		if volume and volume:IsA("BasePart") then
			volume.CFrame = part.CFrame * CFrame.new(0, 0, -5.5)
		end
		updateLeds(now)

		-- Falhas em passos (12 Hz): Vigia perto, bateria fraca ou pedido do diretor.
		flickerClock += dt
		local stepTime = 1 / Config.Visual.FlickerRate
		if flickerClock >= stepTime then
			flickerClock -= stepTime
			local distance = creatureDistance(part.Position)
			local chance = if distance < 22 then (22 - distance) / 22 * 0.35 else 0
			if BatteryModel.isLow(charge()) then
				chance = math.max(chance, 0.12)
			end
			if now < forcedFlickerUntil then
				chance = 0.6
			end
			flickerFactor = if rng:NextNumber() < chance then rng:NextNumber(0, 0.4) else 1
		end
		local brightness = BASE_BRIGHTNESS * BatteryModel.brightness(charge()) * flickerFactor
		if spot then
			spot.Brightness = brightness
			spot.Range = 48 * (0.6 + 0.4 * BatteryModel.brightness(charge()))
		end
		if spill then
			spill.Brightness = 0.25 * flickerFactor
		end
	end)
end

return FlashlightController
