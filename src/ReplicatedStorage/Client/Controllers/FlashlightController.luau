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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BatteryModel = require("@game/ReplicatedStorage/Shared/Game/BatteryModel")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local LightingProfile = require("@game/ReplicatedStorage/Shared/Game/LightingProfile")
local AudioController = require("./AudioController")
local SettingsController = require("./SettingsController")
local CharacterController = require("./CharacterController")

local player = Players.LocalPlayer
local BASE_BRIGHTNESS = LightingProfile.Flashlight.brightness
local WARM = Color3.fromRGB(255, 232, 196)
-- Lâmpada incandescente: o filtro frio da cena deixava o feixe branco-azulado (crítico, 21/10). A luz (não a
-- lente) passa por este filtro quente, em qualquer skin; o tom da skin continua reconhecível.
local function incandescent(color: Color3): Color3
	return Color3.new(color.R, color.G * 0.9, color.B * 0.72)
end

type Viewmodel = {
	model: Model,
	root: BasePart,
	lens: BasePart,
	leds: { BasePart },
	parts: { BasePart },
}

local wanted = true
local phase: GameState.Phase = "Loading"
local raisedAt = 0
local reachAt = -10
local clickAt = -10
local viewmodel: Viewmodel? = nil
local emitter: BasePart? = nil
local spot: SpotLight? = nil
local spill: PointLight? = nil
local halos: { { light: SpotLight, share: number, reach: number } } = {}
local dust: ParticleEmitter? = nil
local smoothed: CFrame? = nil
local fearLevel = 0
local flickerClock = 0
local flickerFactor = 1
-- Escurece o feixe quando bate perto (teto/parede): evita o branco estourado. Raio a 15 Hz, suavizado.
local nearFactor = 1
local nearTarget = 1
local nearClock = 0
local nearParams = RaycastParams.new()
nearParams.FilterType = Enum.RaycastFilterType.Exclude
nearParams.RespectCanCollide = true
local forcedFlickerUntil = 0
local restoreAfterHide = false
local hintCallbacks: { (string) -> () } = {}
-- Cor do feixe e da lente acesa (skin equipada; ver CosmeticController).
local beamColor = WARM
local rng = Random.new()
-- Lanterna que escapou da mão na pancada (rastejando): cai, quica e fica acesa no chão até levantar.
type Drop = { start: CFrame, rest: CFrame, at: number, spin: number, landed: boolean }
local dropped: Drop? = nil
local lastHand: CFrame? = nil
local HAND_PARTS = {
	Hand = true,
	Thumb = true,
	Sleeve = true,
	Cuff = true,
	Finger1 = true,
	Finger2 = true,
	Finger3 = true,
	Finger4 = true,
	Tip1 = true,
	Tip2 = true,
	Tip3 = true,
	Tip4 = true,
	Knuckle1 = true,
	Knuckle2 = true,
	Knuckle3 = true,
	Knuckle4 = true,
	Thumb2 = true,
}
local DROP_FALL = 0.42
local DROP_BOUNCE = 0.34

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

-- Posições locais das peças da lanterna de época (preenchidas ao clonar o modelo; ver `periodFlashlight`).
local PERIOD_OFFSETS: { [string]: CFrame } = {}
-- Quanto o ponteiro sobe em cima da lanterna de época (corpo mais grosso que a de peças).
local dialLift = 0
-- O .glb chega sem textura nas peças de metal (cinza Plastic): cor e material de época por nome da peça.
-- Tons quentes de propósito: o filtro frio da cena puxa para o azul (o níquel neutro lia cinza-azulado).
-- Peça com SurfaceAppearance (o couro) fica como veio.
local PERIOD_FINISH: { [string]: { color: Color3, material: Enum.Material } } = {
	Torch_Nickel = { color = Color3.fromRGB(165, 145, 115), material = Enum.Material.Metal },
	Torch_Brass = { color = Color3.fromRGB(170, 120, 55), material = Enum.Material.Metal },
	Torch_Steel = { color = Color3.fromRGB(70, 70, 74), material = Enum.Material.Metal },
	Torch_Leather = { color = Color3.fromRGB(70, 40, 22), material = Enum.Material.Leather },
	Torch_Reflector = { color = Color3.fromRGB(214, 196, 160), material = Enum.Material.Metal },
}

-- Lanterna de época do Artista 3D (níquel, latão, couro; 2 mil triângulos; frente = -Z; lente "Torch_Lens").
-- Procura em ReplicatedStorage.Assets; sem o asset, a lanterna de peças continua (fallback).
local function periodFlashlight(model: Model, add: (BasePart) -> ()): (BasePart?, BasePart?)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local found = assets and assets:FindFirstChild("PeriodFlashlight", true)
	if not found then
		return nil, nil
	end
	local copy = found:Clone()
	local pieces: { BasePart } = {}
	if copy:IsA("BasePart") then
		table.insert(pieces, copy)
	end
	for _, item in copy:GetDescendants() do
		if item:IsA("BasePart") then
			table.insert(pieces, item)
		elseif item:IsA("Script") or item:IsA("LocalScript") or item:IsA("ModuleScript") then
			item:Destroy() -- asset de arte não traz código
		end
	end
	if #pieces == 0 then
		copy:Destroy()
		return nil, nil
	end
	-- Centro e tamanho de tudo: a frente (-Z) do modelo fica onde ficava a lente antiga.
	local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, piece in pieces do
		low = low:Min(piece.Position - piece.Size / 2)
		high = high:Max(piece.Position + piece.Size / 2)
	end
	local center = CFrame.new((low + high) / 2)
	local front = (high.Z - low.Z) / 2
	local root: BasePart? = nil
	local lens: BasePart? = nil
	for index, piece in pieces do
		local offset = center:ToObjectSpace(piece.CFrame)
		local finish = PERIOD_FINISH[piece.Name]
		if finish and not piece:FindFirstChildOfClass("SurfaceAppearance") then
			piece.Color = finish.color
			piece.Material = finish.material
		end
		local name = if string.find(piece.Name, "Lens") then "Lens" else `Period{index}`
		piece.Name = name
		PERIOD_OFFSETS[name] = CFrame.new(0, 0, -0.63 + front) * offset
		piece.Anchored = true
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.CastShadow = false
		piece.Parent = model
		add(piece)
		if name == "Lens" then
			lens = piece
		elseif not root or piece.Size.Magnitude > root.Size.Magnitude then
			root = piece
		end
	end
	copy:Destroy()
	return root, lens
end

-- Mão fechada no cabo (eixo -Z), com o cabo de raio ~`radius` - 0,035. Os dedos saem da palma (embaixo, lado
-- de fora) e dão a volta pelo lado esquerdo até o topo; cada falange fica tangente ao cabo, o nó na junta.
local function gripOffsets(radius: number): { [string]: CFrame }
	local out: { [string]: CFrame } = {}
	local function at(angle: number, z: number): CFrame
		local a = math.rad(angle)
		-- Cilindro no eixo X: gira para o X ficar tangente ao círculo no ângulo `a`.
		return CFrame.new(radius * math.cos(a), radius * math.sin(a), z) * CFrame.Angles(0, 0, a + math.pi / 2)
	end
	out.Hand = CFrame.new(0.03, -radius - 0.005, 0.07)
	for i = 1, 4 do
		local z = -0.08 + (i - 1) * 0.08
		local k = if i == 4 then 0.8 else 1
		-- Nó em -65°, falange até -122°, ponta até -168° (o mindinho fecha menos).
		out[`Knuckle{i}`] = at(-65, z) * CFrame.new(0, 0.012, 0)
		out[`Finger{i}`] = at(-65 - 57 * k / 2 - 5, z)
		out[`Tip{i}`] = at(-122 - 46 * k / 2 + (1 - k) * 20, z) * CFrame.new(0, -0.004, 0)
	end
	-- Polegar por cima, apontando para a frente, de leve para dentro.
	out.Thumb = CFrame.new(0.05, radius - 0.01, -0.03)
		* CFrame.Angles(0, math.rad(80), 0)
		* CFrame.Angles(0, 0, math.rad(-8))
	out.Thumb2 = CFrame.new(0.035, radius - 0.02, -0.12)
		* CFrame.Angles(0, math.rad(95), 0)
		* CFrame.Angles(0, 0, math.rad(-18))
	return out
end

-- Lanterna + mão + manga (só o jogador vê; peças locais sob a câmera).
local function buildViewmodel(): Viewmodel
	local model = Instance.new("Model")
	model.Name = "Viewmodel"
	local parts: { BasePart } = {}
	local function add(name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		local part = localPart(model, name, size, color, material)
		table.insert(parts, part)
		return part
	end
	-- Peças redondas (cilindro no eixo X, girado para -Z nos OFFSETS): sem cara de bloco.
	local function round(name: string, size: Vector3, color: Color3, material: Enum.Material?): BasePart
		local part = add(name, size, color, material);
		(part :: Part).Shape = Enum.PartType.Cylinder
		return part
	end
	local root, lens = periodFlashlight(model, function(piece: BasePart)
		table.insert(parts, piece)
	end)
	if root and not lens then
		-- Modelo de uma peça só: lente fina na boca, para acender em Neon.
		lens = round("Lens", Vector3.new(0.02, 0.17, 0.17), Color3.fromRGB(90, 88, 80), Enum.Material.SmoothPlastic)
		PERIOD_OFFSETS.Lens = CFrame.new(0, 0, -0.635) * CFrame.Angles(0, math.rad(90), 0)
	end
	if not root then
		root = round("Body", Vector3.new(0.85, 0.17, 0.17), Color3.fromRGB(38, 40, 44), Enum.Material.Metal)
		round("Head", Vector3.new(0.2, 0.27, 0.27), Color3.fromRGB(52, 54, 58), Enum.Material.Metal)
		round("Bezel", Vector3.new(0.04, 0.3, 0.3), Color3.fromRGB(28, 28, 30), Enum.Material.Metal)
		lens = round("Lens", Vector3.new(0.03, 0.22, 0.22), Color3.fromRGB(90, 88, 80), Enum.Material.SmoothPlastic)
		for i = 1, 3 do
			round(`Grip{i}`, Vector3.new(0.035, 0.185, 0.185), Color3.fromRGB(24, 24, 26), Enum.Material.DiamondPlate)
		end
		round("Tail", Vector3.new(0.05, 0.19, 0.19), Color3.fromRGB(28, 28, 30), Enum.Material.Metal)
		add("Switch", Vector3.new(0.06, 0.04, 0.12), Color3.fromRGB(150, 32, 28))
	end
	-- Mão de luva de couro fechada em volta do cabo: palma por baixo, quatro dedos de duas falanges que dão a volta
	-- pelo lado (nó aparente em cada um, mindinho menor) e o polegar de duas partes por cima.
	-- 21/10: luva escura (o crítico leu "bolinhas empilhadas" na pele com pontas em bola); 20/10 (Animador): dedos
	-- articulados no lugar da cápsula única curvada.
	local glove = Color3.fromRGB(46, 34, 27)
	local gloveLight = Color3.fromRGB(52, 39, 31)
	add("Hand", Vector3.new(0.2, 0.15, 0.3), glove, Enum.Material.Fabric)
	for i = 1, 4 do
		local k = if i == 4 then 0.8 else 1
		round(`Finger{i}`, Vector3.new(0.115 * k, 0.07 * k, 0.07 * k), glove, Enum.Material.Fabric)
		round(`Tip{i}`, Vector3.new(0.09 * k, 0.064 * k, 0.064 * k), glove, Enum.Material.Fabric)
		local knuckle = add(`Knuckle{i}`, Vector3.new(0.078, 0.078, 0.078) * k, gloveLight, Enum.Material.Fabric);
		(knuckle :: Part).Shape = Enum.PartType.Ball
	end
	round("Thumb", Vector3.new(0.11, 0.074, 0.074), gloveLight, Enum.Material.Fabric)
	round("Thumb2", Vector3.new(0.085, 0.068, 0.068), gloveLight, Enum.Material.Fabric)
	if next(PERIOD_OFFSETS) then
		-- Lanterna de época é mais grossa: a mão abre para o cabo dela.
		for name, offset in gripOffsets(0.15) do
			PERIOD_OFFSETS[name] = offset
		end
	end
	round("Sleeve", Vector3.new(0.7, 0.34, 0.34), Color3.fromRGB(46, 58, 54), Enum.Material.Fabric)
	round("Cuff", Vector3.new(0.09, 0.37, 0.37), Color3.fromRGB(34, 44, 40), Enum.Material.Fabric)
	local leds: { BasePart } = {}
	for i = 1, BatteryModel.LEDS do
		-- Plástico, não neon: com o brilho da tela o neon virava uma barra ciano por cima da mão.
		local led =
			add(`Led{i}`, Vector3.new(0.03, 0.025, 0.04), Color3.fromRGB(20, 20, 20), Enum.Material.SmoothPlastic)
		table.insert(leds, led)
		if next(PERIOD_OFFSETS) then
			-- Lanterna de época (mais grossa): visores pequenos, rente ao topo do latão, perto do polegar.
			led.Size = Vector3.new(0.02, 0.012, 0.026)
			PERIOD_OFFSETS[`Led{i}`] = CFrame.new(0, 0.128, 0.0 + i * 0.04)
		end
	end
	if next(PERIOD_OFFSETS) then
		dialLift = 0.035
		PERIOD_OFFSETS.GuideDial = CFrame.new(0, 0.092 + dialLift, -0.3) * CFrame.Angles(0, 0, math.rad(90))
	end
	-- Ponteiro em cima da lanterna (única orientação do jogo): haste + ponta, gira para o objetivo.
	local dial = add("GuideDial", Vector3.new(0.012, 0.15, 0.15), Color3.fromRGB(26, 24, 22), Enum.Material.Metal);
	(dial :: Part).Shape = Enum.PartType.Cylinder
	add("GuideNeedle", Vector3.new(0.022, 0.012, 0.1), Color3.fromRGB(200, 140, 60), Enum.Material.Neon)
	add("GuideTip", Vector3.new(0.04, 0.012, 0.04), Color3.fromRGB(200, 140, 60), Enum.Material.Neon)
	model.PrimaryPart = root
	return { model = model, root = root :: BasePart, lens = lens :: BasePart, leds = leds, parts = parts }
end

-- Posições locais (em relação ao corpo da lanterna, -Z = frente).
local ALONG = CFrame.Angles(0, math.rad(90), 0) -- eixo X do cilindro apontando para -Z (frente)
local OFFSETS: { [string]: CFrame } = {
	Body = ALONG,
	Head = CFrame.new(0, 0, -0.5) * ALONG,
	Bezel = CFrame.new(0, 0, -0.6) * ALONG,
	Lens = CFrame.new(0, 0, -0.615) * ALONG,
	Grip1 = CFrame.new(0, 0, -0.26) * ALONG,
	Grip2 = CFrame.new(0, 0, -0.2) * ALONG,
	Grip3 = CFrame.new(0, 0, 0.36) * ALONG,
	Tail = CFrame.new(0, 0, 0.43) * ALONG,
	Switch = CFrame.new(0, 0.1, -0.12),
	Sleeve = CFrame.new(0.05, -0.2, 0.6) * CFrame.Angles(math.rad(-12), 0, 0) * ALONG,
	Cuff = CFrame.new(0.05, -0.18, 0.27) * CFrame.Angles(math.rad(-12), 0, 0) * ALONG,
	Led1 = CFrame.new(0, 0.095, 0.06),
	Led2 = CFrame.new(0, 0.095, 0.12),
	Led3 = CFrame.new(0, 0.095, 0.18),
	Led4 = CFrame.new(0, 0.095, 0.24),
	GuideDial = CFrame.new(0, 0.092, -0.3) * CFrame.Angles(0, 0, math.rad(90)),
}

for name, offset in gripOffsets(0.12) do
	OFFSETS[name] = offset
end

-- Objetivo atual (CampaignController); nil = ponteiro escondido.
local guideTarget: Vector3? = nil
local guideYaw = 0

-- Gira o ponteiro para o objetivo (só no plano da lanterna, com inércia de bússola).
local function aimGuide(hand: CFrame, dt: number)
	local vm = viewmodel
	if not vm then
		return
	end
	local target = guideTarget
	local shown = target ~= nil
	for _, part in vm.parts do
		if part.Name == "GuideNeedle" or part.Name == "GuideTip" then
			part.Transparency = if shown then 0 else 1
		end
	end
	if not target then
		return
	end
	local pivot = hand * CFrame.new(0, 0.105 + dialLift, -0.3)
	local localDir = pivot:PointToObjectSpace(target)
	local yaw = math.atan2(-localDir.X, -localDir.Z)
	local delta = (yaw - guideYaw + math.pi) % (2 * math.pi) - math.pi
	guideYaw += delta * (1 - math.exp(-6 * dt))
	local needle = CFrame.new(0, 0.105 + dialLift, -0.3) * CFrame.Angles(0, guideYaw, 0)
	OFFSETS.GuideNeedle = needle * CFrame.new(0, 0, -0.01)
	OFFSETS.GuideTip = needle * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, math.rad(45), 0)
end

local function placeViewmodel(base: CFrame)
	local vm = viewmodel
	if not vm then
		return
	end
	for _, part in vm.parts do
		part.CFrame = base * (PERIOD_OFFSETS[part.Name] or OFFSETS[part.Name] or CFrame.identity)
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
		-- Tons de lâmpada de época (o verde-ciano lia como brinquedo): âmbar claro, âmbar, vermelho.
		elseif lit >= 3 then
			led.Color = Color3.fromRGB(240, 200, 130)
		elseif lit == 2 then
			led.Color = Color3.fromRGB(235, 150, 60)
		else
			led.Color = Color3.fromRGB(220, 60, 45)
		end
	end
end

local function applyVisible()
	local status = player:GetAttribute("CampaignStatus")
	local on = serverOn()
		and phase ~= "Won"
		and not isHidden()
		and player:GetAttribute("CinematicActive") ~= true
		and (dropped ~= nil or status == nil or status == "Active")
	if spot then
		spot.Enabled = on
	end
	for _, halo in halos do
		halo.light.Enabled = on
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
		vm.lens.Color = if on then beamColor else Color3.fromRGB(90, 88, 80)
	end
end

local function showHand(value: boolean)
	local vm = viewmodel
	if not vm then
		return
	end
	for _, part in vm.parts do
		if HAND_PARTS[part.Name] then
			part.Transparency = if value then 0 else 1
		end
	end
end

-- Ponto de descanso no chão, um pouco à frente; deitada de lado, o feixe varrendo rente ao piso.
local function restPose(from: CFrame): CFrame?
	local camera = workspace.CurrentCamera
	if not camera then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { camera }
	if player.Character then
		table.insert(ignore, player.Character :: Instance)
	end
	params.FilterDescendantsInstances = ignore
	local origin = camera.CFrame.Position
	local floor = workspace:Raycast(origin, Vector3.new(0, -12, 0), params)
	if not floor then
		return nil
	end
	local look = Vector3.new(from.LookVector.X, 0, from.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local ahead = look * 1.5 + Vector3.new(look.Z, 0, -look.X) * 0.35
	local base = floor.Position + Vector3.new(0, 0.3, 0)
	local wall = workspace:Raycast(base, ahead, params)
	local place = if wall then wall.Position - ahead.Unit * 0.4 else base + ahead
	local yaw = math.atan2(-look.X, -look.Z) + rng:NextNumber(-1.1, 1.1)
	return CFrame.new(place.X, floor.Position.Y + 0.14, place.Z)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(math.rad(-3), 0, math.rad(90))
end

local function dropFlashlight()
	if dropped or player:GetAttribute("HasFlashlight") ~= true then
		return
	end
	local camera = workspace.CurrentCamera
	local start = lastHand or (camera and camera.CFrame * CFrame.new(0.42, -0.42, -0.95))
	local rest = start and restPose(start)
	if not start or not rest then
		return
	end
	dropped = {
		start = start,
		rest = rest,
		at = os.clock(),
		spin = math.rad(rng:NextNumber(220, 340)) * (if rng:NextNumber() < 0.5 then -1 else 1),
		landed = false,
	}
	-- Pisca enquanto rola no ar; ao bater no chão engasga mais (ver dropPose).
	forcedFlickerUntil = os.clock() + DROP_FALL
	showHand(false)
	applyVisible()
end

local function pickUpFlashlight()
	if not dropped then
		return
	end
	dropped = nil
	smoothed = nil
	raisedAt = os.clock()
	showHand(true)
	applyVisible()
end

-- Pose da lanterna caindo: queda com gravidade girando no ar, depois um quique curto que balança e para.
local function dropPose(drop: Drop, now: number): CFrame
	local t = now - drop.at
	if t < DROP_FALL then
		local a = t / DROP_FALL
		local position = drop.start.Position:Lerp(drop.rest.Position, a)
		local y = drop.start.Y + (drop.rest.Y - drop.start.Y) * a * a + 0.5 * a * (1 - a)
		local rotation = drop.start.Rotation:Lerp(drop.rest.Rotation, a) * CFrame.Angles(drop.spin * (1 - a), 0, 0)
		return CFrame.new(position.X, y, position.Z) * rotation
	end
	if not drop.landed then
		drop.landed = true
		forcedFlickerUntil = now + 1.1
		AudioController.play("Fall_cans", 0.32, 1.35)
		AudioController.play("Flashlight", 0.5, 0.8)
	end
	local b = math.clamp((t - DROP_FALL) / DROP_BOUNCE, 0, 1)
	local hop = math.sin(b * math.pi) * 0.16 * (1 - b)
	local wobble = math.sin(b * math.pi * 3) * math.rad(14) * (1 - b)
	return drop.rest * CFrame.new(hop, 0, 0) * CFrame.Angles(0, 0, wobble)
end

local function partNamed(name: string): BasePart?
	local vm = viewmodel
	if not vm then
		return nil
	end
	for _, part in vm.parts do
		if part.Name == name then
			return part
		end
	end
	return nil
end

local FlashlightController = {
	Name = "FlashlightController",
}

-- Para onde o ponteiro da lanterna aponta (nil = esconde).
function FlashlightController.setGuide(target: Vector3?)
	guideTarget = target
end

-- Medo 0..1 (vem do FearController): faz as mãos tremerem.
function FlashlightController.setFear(value: number)
	fearLevel = math.clamp(value, 0, 1)
end

function FlashlightController.isOn(): boolean
	local status = player:GetAttribute("CampaignStatus")
	return serverOn() and (status == nil or status == "Active")
end

function FlashlightController.isWanted(): boolean
	return wanted
end

-- Skin da lanterna (cosmético, só o dono vê). O feixe muda de tom, nunca de alcance/brilho.
function FlashlightController.applySkin(body: Color3, head: Color3, beam: Color3, material: Enum.Material)
	beamColor = beam
	local bodyPart = partNamed("Body")
	local headPart = partNamed("Head")
	if bodyPart then
		bodyPart.Color = body
		bodyPart.Material = material
	end
	if headPart then
		headPart.Color = head
		headPart.Material = if material == Enum.Material.Neon then Enum.Material.Neon else Enum.Material.Metal
	end
	if spot then
		spot.Color = incandescent(beam)
	end
	for _, halo in halos do
		halo.light.Color = incandescent(beam)
	end
	if spill then
		spill.Color = incandescent(beam)
	end
	applyVisible()
end

-- Manga do braço com a cor da farda equipada.
function FlashlightController.applySleeve(color: Color3)
	local sleeve = partNamed("Sleeve")
	if sleeve then
		sleeve.Color = color
	end
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
	if not SettingsController.get("flashes") then
		return
	end
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
	light.Angle = LightingProfile.Flashlight.angle
	light.Range = LightingProfile.Flashlight.range
	light.Brightness = BASE_BRIGHTNESS
	light.Color = incandescent(WARM)
	light.Shadows = true
	light.Parent = part

	-- Halo: cones mais abertos e mais fracos em volta do feixe. O SpotLight do Roblox tem borda dura; empilhar
	-- cones faz a luz cair aos poucos para o escuro, sem clarear o cômodo inteiro. Sem sombra (custo).
	for index, ring in LightingProfile.Flashlight.halo do
		local cone = Instance.new("SpotLight")
		cone.Name = `Halo{index}`
		cone.Face = Enum.NormalId.Front
		cone.Angle = ring.angle
		cone.Range = LightingProfile.Flashlight.range * ring.reach
		cone.Brightness = BASE_BRIGHTNESS * ring.share
		cone.Color = incandescent(WARM)
		cone.Shadows = false
		cone.Parent = part
		table.insert(halos, { light = cone, share = ring.share, reach = ring.reach })
	end

	local glow = Instance.new("PointLight")
	glow.Range = LightingProfile.Flashlight.spillRange
	glow.Brightness = LightingProfile.Flashlight.spill
	glow.Color = incandescent(WARM)
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
	player:GetAttributeChangedSignal("CinematicActive"):Connect(function()
		if player:GetAttribute("CinematicActive") ~= true then
			raisedAt = os.clock()
		end
		applyVisible()
	end)
	player:GetAttributeChangedSignal("CampaignStatus"):Connect(applyVisible)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if player:GetAttribute("PvPRole") == "Hunter" then
			return
		end
		if processed then
			return
		end
		if player:GetAttribute("CinematicActive") == true then
			return
		end
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
			reachAt = os.clock()
		end
		if input.KeyCode ~= Enum.KeyCode.F and input.KeyCode ~= Enum.KeyCode.ButtonY then
			return
		end
		local status = player:GetAttribute("CampaignStatus")
		if (phase == "Playing" or phase == "Intro") and not isHidden() and (status == nil or status == "Active") then
			clickAt = os.clock()
			FlashlightController.set(not wanted)
		end
	end)

	player:GetAttributeChangedSignal(Tags.Attr.Flashlight):Connect(function()
		applyVisible()
		-- A carga é publicada em passos de 0,5% e pode chegar depois do apagão: basta estar abaixo do mínimo para ligar.
		if wanted and not serverOn() and charge() <= Config.Battery.MinToTurnOn + 0.01 and phase == "Playing" then
			-- Apagou sozinha: o próximo F liga (antes o primeiro F só "desligava" o pedido antigo).
			wanted = false
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
	-- Pancada do Tung Tung: a lanterna escapa da mão e cai; volta para a mão quando você levanta.
	player:GetAttributeChangedSignal("Crawling"):Connect(function()
		if player:GetAttribute("Crawling") == true then
			dropFlashlight()
		else
			pickUpFlashlight()
		end
	end)
	player.CharacterAdded:Connect(function()
		pickUpFlashlight()
		raisedAt = os.clock()
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
		local budget = SettingsController.visualBudget()
		if spot then
			spot.Shadows = budget.shadows > 0
		end
		if dust then
			dust.Rate = 16 * budget.particles
		end
		local motion = CharacterController.getMotion()

		-- Mão com peso: a rotação segue a câmera com atraso; corrida abaixa a lanterna.
		local lower = if motion.sprinting then math.rad(-14) else 0
		local target = camera.CFrame * CFrame.Angles(lower, 0, 0)
		smoothed = if smoothed then smoothed:Lerp(target, 1 - math.exp(-11 * dt)) else target
		local rotation = (smoothed :: CFrame).Rotation
		-- Balanço no mesmo ritmo dos passos (meia volta por passo, como a câmera).
		local bob = math.sin((motion.steps + motion.stride) * math.pi) * math.min(motion.speed / 16, 1)
		local hand = CFrame.new(camera.CFrame.Position)
			* rotation
			-- 21/10: mais baixa, mais à direita e um pouco mais longe (o crítico achou a lanterna dominante na tela):
			-- metade inferior da mão sai do quadro.
			* CFrame.new(0.47 + bob * 0.02, -0.52 + math.abs(bob) * -0.025, -1.0)
		-- Mãos tremem com o medo (antes e mais que a câmera, que só treme no pânico).
		local fright = math.clamp((fearLevel - 0.35) / 0.65, 0, 1)
		if fright > 0 and SettingsController.get("shake") then
			local t = now * 21
			local angle = math.rad(1.3) * fright * fright
			hand *= CFrame.Angles(
				angle * math.noise(t, 3.1),
				angle * math.noise(t, 7.7),
				angle * 0.5 * math.noise(t, 12.4)
			)
		end
		local raise = math.clamp(1 - (now - raisedAt) / 0.65, 0, 1)
		local reach = math.sin(math.clamp((now - reachAt) / 0.45, 0, 1) * math.pi)
		local click = math.sin(math.clamp((now - clickAt) / 0.2, 0, 1) * math.pi)
		local dip = if motion.stance == "Crouch" then 0.08 else 0
		if SettingsController.motionEnabled() then
			hand *= CFrame.new(-reach * 0.12, -raise * 0.7 - dip, -reach * 0.24 + click * 0.04) * CFrame.Angles(
				math.rad(-raise * 40 + click * 7),
				0,
				math.rad(reach * -8)
			)
		end
		local visible = player:GetAttribute("HasFlashlight") == true
			and not motion.hidden
			and player:GetAttribute("CinematicActive") ~= true
			and (player:GetAttribute("CampaignStatus") == nil or player:GetAttribute("CampaignStatus") == "Active")
			and phase ~= "Won"
			and (phase == "Playing" or phase == "Intro" or phase == "Lost")
		local drop = dropped
		if drop then
			-- Caída no chão: a luz sai da lente, rente ao piso, e fica onde caiu enquanto você rasteja.
			local pose = dropPose(drop, now)
			vm.model.Parent = if player:GetAttribute("HasFlashlight") == true then camera else nil
			placeViewmodel(pose)
			part.CFrame = pose * CFrame.new(0, 0, -0.64)
		else
			lastHand = hand
			vm.model.Parent = if visible then camera else nil
			aimGuide(hand, dt)
			placeViewmodel(hand)
			-- A fonte da luz fica na cabeça (a câmera nunca entra na parede), apontando para onde a mão aponta. Na
			-- ponta da lanterna ela atravessava paredes ao encostar e a luz piscava/vazava em cômodos apertados.
			part.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.UpVector * -0.25) * hand.Rotation
		end
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
			flickerFactor = if SettingsController.get("flashes") and rng:NextNumber() < chance
				then rng:NextNumber(0, 0.4)
				else 1
		end
		nearClock += dt
		if nearClock >= 1 / 15 then
			nearClock = 0
			nearParams.FilterDescendantsInstances = { camera, part, player.Character :: Instance }
			local hit = workspace:Raycast(
				part.Position,
				part.CFrame.LookVector * LightingProfile.FlashlightNear.full,
				nearParams
			)
			nearTarget = (if hit then LightingProfile.nearDim(hit.Distance) else 1)
				* LightingProfile.aimDim(part.CFrame.LookVector.Y)
		end
		nearFactor += (nearTarget - nearFactor) * math.min(1, dt * 10)
		local brightness = BASE_BRIGHTNESS * BatteryModel.brightness(charge()) * flickerFactor * nearFactor
		if spot then
			spot.Brightness = brightness
			spot.Range = LightingProfile.Flashlight.range * (0.6 + 0.4 * BatteryModel.brightness(charge()))
			for _, halo in halos do
				halo.light.Brightness = brightness * halo.share
				halo.light.Range = spot.Range * halo.reach
			end
		end
		if spill then
			spill.Brightness = LightingProfile.Flashlight.spill * flickerFactor
		end
	end)
end

return FlashlightController
