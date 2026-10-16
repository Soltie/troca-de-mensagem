--!strict
--[[
	Trailer de ~40 s do jogo, montado e tocado DENTRO do Roblox (só no Studio; nunca para jogadores).
	Gravado com OBS (janela do Studio + áudio do Studio): docs/TRAILER.md.

	Roteiro (segundos):
	   0.0  preto, drone, chiado; data e "a Subestação 9 parou de responder"
	   3.6  LOGO (impacto)
	   5.2  estrada -> portão; a equipe chega com lanternas
	  12.0  "ELES ENTRARAM JUNTOS."
	  13.2  corredor escuro: o Vigia no fundo; a luz falha e ele está mais perto
	  16.6  close do Vigia, rugido -> "O VIGIA"
	  18.5  montagem: RELIGUE A ENERGIA (painel, faíscas/explosão), ESCONDA-SE (armário),
	        perseguição, SALVE SUA EQUIPE, mapa novo, "ELE SEGUE A LUZ", FUJA (portão)
	  29.0  o Vigia avança na câmera -> corte seco com o maior impacto
	  30.0  silêncio, um batimento
	  31.6  LOGO final + modos + "EM BREVE NO ROBLOX"
	  40.0  fim

	Tudo é local (atores, luzes, UI e sons); a ponte "TrailerBridge" (PlayerGui, só Studio) prepara,
	toca, para e mostra um instante (seek) para conferir enquadramentos.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Actors = require("../Trailer/TrailerActors")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local Camera = require("./CameraController")

local player = Players.LocalPlayer
local DURATION = 40
local LETTERBOX = (1 - (16 / 9) / 2.39) / 2

type Title = { t: number, d: number, text: string, sub: string?, color: Color3?, size: number? }
type Caption = { t: number, d: number, text: string }
type SoundCue = { t: number, key: string, volume: number?, speed: number?, stop: number? }
type Shot = {
	t: number,
	d: number,
	name: string,
	-- Câmera no progresso alpha (0..1) e tempo local (s).
	camera: (alpha: number, time: number) -> (CFrame, number),
	-- Atores e efeitos do plano (chamado a cada quadro com o tempo local).
	act: ((alpha: number, time: number, dt: number) -> ())?,
	shake: number?,
}

local Controller = { Name = "TrailerController" }

local enabled = false
local playing = false
local startedAt = 0
local armedAt: number? = nil
local seekTime: number? = nil
local lastTime = 0
local lastShot = ""
local gui: ScreenGui? = nil
local ui: { [string]: any } = {}
local team: { Actors.Member } = {}
local vigia: Actors.Creature? = nil
local props: Folder? = nil
local grade: ColorCorrectionEffect? = nil
local sounds: { [number]: Sound } = {}
local fired: { [number]: boolean } = {}
local hitShakeUntil = 0
local rng = Random.new(9)
local savedCharacterPivot: CFrame? = nil
local savedAnchored = false
local savedAudioVolumes: { [SoundGroup]: number } = {}
local savedCoreGui: { [Enum.CoreGuiType]: boolean } = {}
local trailerMix: SoundGroup? = nil

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function ease(t: number): number
	local x = math.clamp(t, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerp(a: Vector3, b: Vector3, t: number): Vector3
	return a:Lerp(b, t)
end

-- Câmera de a -> b olhando de la -> lb.
local function dolly(a: Vector3, b: Vector3, la: Vector3, lb: Vector3, fov: number, smooth: boolean?)
	return function(alpha: number): (CFrame, number)
		local t = if smooth == false then alpha else ease(alpha)
		return CFrame.lookAt(lerp(a, b, t), lerp(la, lb, t)), fov
	end
end

-- ===================== Luzes e efeitos locais =====================

local function light(name: string, position: Vector3, color: Color3, range: number, brightness: number): PointLight
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Position = position
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = true
	l.Enabled = false
	l.Parent = part
	part.Parent = props
	return l
end

local function spot(name: string, from: Vector3, at: Vector3, brightness: number, angle: number): SpotLight
	local part = Instance.new("Part")
	part.Name = name
	part.Size = Vector3.one * 0.2
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CFrame = CFrame.lookAt(from, at)
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Front
	l.Color = Color3.fromRGB(255, 232, 196)
	l.Range = 40
	l.Angle = angle
	l.Brightness = brightness
	l.Shadows = true
	l.Enabled = false
	l.Parent = part
	part.Parent = props
	return l
end

local fx: { [string]: any } = {}

local function buildProps()
	local folder = Instance.new("Folder")
	folder.Name = "TrailerProps"
	folder.Parent = workspace
	props = folder
	-- Luz de cena: lua fria no pátio, luz de corredor, lâmpadas que acendem com os disjuntores.
	fx.moon = light("Moon", v(-6, 26, 30), Color3.fromRGB(130, 150, 200), 80, 1.6)
	fx.backlight = light("Backlight", v(22, 8, -22), Color3.fromRGB(140, 170, 230), 20, 1.4)
	fx.lockerSpot = spot("LockerSpot", v(-33, 9.5, -36), v(-29, 3, -36), 3.5, 60)
	fx.cameraLamp = spot("CameraLamp", v(0, -50, 0), v(0, -50, 10), 8, 46)
	fx.panelFill = light("PanelFill", v(-14, 7, -44), Color3.fromRGB(255, 214, 160), 16, 0.8)
	fx.burst = light("Burst", v(-9.5, 4, -48), Color3.fromRGB(255, 240, 210), 30, 0)
	fx.roomOn = light("RoomOn", v(-20, 9, -38), Color3.fromRGB(255, 226, 180), 40, 0)
	fx.sector = light("SectorFill", v(0, 9, -100), Color3.fromRGB(150, 175, 215), 40, 1.6)
	fx.storage = light("RescueFill", v(9, 9, 22), Color3.fromRGB(180, 200, 255), 22, 1.2)
	fx.faceSpot = spot("FaceSpot", v(-6, 4, -21.5), v(0, 7, -22), 4, 50)
	fx.graffitiSpot = spot("GraffitiSpot", v(30, 5.2, -37), v(30, 5, -27), 5, 34)
	fx.gateLamp = light("GateLamp", v(8, 9, 46), Color3.fromRGB(255, 180, 90), 30, 0.7)
	local sparks = Instance.new("Part")
	sparks.Name = "Sparks"
	sparks.Size = Vector3.new(2.5, 1.5, 0.5)
	sparks.Transparency = 1
	sparks.Anchored = true
	sparks.CanCollide = false
	sparks.CanQuery = false
	sparks.Position = v(-9.5, 3.8, -48.4)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 140), Color3.fromRGB(255, 120, 40))
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new(0.35, 0)
	emitter.Lifetime = NumberRange.new(0.3, 0.8)
	emitter.Speed = NumberRange.new(12, 26)
	emitter.SpreadAngle = Vector2.new(70, 70)
	emitter.Acceleration = v(0, -40, 0)
	emitter.Rate = 0
	emitter.Parent = sparks
	sparks.Parent = folder
	fx.sparks = emitter
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "S9TrailerGrade"
	tint.Contrast = 0.12
	tint.Saturation = -0.15
	tint.Brightness = 0.03
	tint.TintColor = Color3.fromRGB(235, 240, 255)
	tint.Enabled = false
	tint.Parent = Lighting
	grade = tint
	local mix = Instance.new("SoundGroup")
	mix.Name = "TrailerMix"
	mix.Volume = 0.8
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -8
	compressor.Ratio = 6
	compressor.Attack = 0.003
	compressor.Release = 0.18
	compressor.Parent = mix
	mix.Parent = SoundService
	trailerMix = mix
end

local graffitiLabel: TextLabel? = nil
local graffitiColor: Color3? = nil

local function glowGraffiti(on: boolean)
	if not graffitiLabel then
		for _, d in workspace:GetDescendants() do
			if d:IsA("TextLabel") and string.find(string.upper(d.Text), "SEGUE A LUZ", 1, true) then
				graffitiLabel = d
				graffitiColor = d.TextColor3
				break
			end
		end
	end
	local label = graffitiLabel
	if not label then
		return
	end
	label.TextColor3 = if on then Color3.fromRGB(230, 30, 24) else graffitiColor or label.TextColor3
	local surface = label:FindFirstAncestorWhichIsA("SurfaceGui")
	if surface then
		surface.LightInfluence = if on then 0 else 1
		surface.Brightness = if on then 2.5 else 1
	end
end

local function allLightsOff()
	for _, value in fx do
		if typeof(value) == "Instance" and value:IsA("Light") then
			(value :: Light).Enabled = false
		end
	end
end

-- ===================== Atores =====================

local SHIRTS = { Color3.fromRGB(70, 84, 110), Color3.fromRGB(150, 90, 40), Color3.fromRGB(60, 74, 60) }

local function buildActors()
	team = {}
	for i = 1, 3 do
		local member = Actors.member(props :: Folder, SHIRTS[i])
		if member then
			table.insert(team, member)
		end
	end
	vigia = Actors.creature(props :: Folder)
end

local function hideAll()
	for _, member in team do
		Actors.hide(member)
	end
	if vigia then
		Actors.hideCreature(vigia)
	end
end

-- Membro i andando de a até b (pés no chão), com passo pela distância.
local function walk(i: number, a: Vector3, b: Vector3, alpha: number, kind: Actors.PoseName, pitch: number?)
	local member = team[i]
	if not member then
		return
	end
	local position = a:Lerp(b, alpha)
	local stride = if kind == "run" then 1.1 else 0.75
	local phase = (position - a).Magnitude / stride * math.pi * 0.5 + i
	Actors.pose(member, position, b + (b - a).Unit * 5, kind, phase, pitch)
	Actors.placeLamp(member, pitch)
end

local function stand(i: number, at: Vector3, look: Vector3, kind: Actors.PoseName, pitch: number?, time: number?)
	local member = team[i]
	if not member then
		return
	end
	Actors.pose(member, at, look, kind, (time or 0) * 2, pitch)
	Actors.placeLamp(member, pitch)
end

local function creature(at: Vector3, look: Vector3, animation: string, dt: number, rate: number, yaw: number?)
	if vigia then
		Actors.creaturePose(vigia, at, look, animation, dt, rate, yaw)
	end
end

-- ===================== Roteiro =====================

local TITLES: { Title } = {
	{ t = 12.0, d = 1.2, text = "ELES ENTRARAM JUNTOS." },
	{ t = 17.35, d = 1.15, text = "O VIGIA", color = Theme.Accent, size = 1.35 },
	{ t = 18.5, d = 1.0, text = "RELIGUE A ENERGIA." },
	{ t = 21.3, d = 1.1, text = "ESCONDA-SE." },
	{ t = 23.8, d = 1.2, text = "SALVE SUA EQUIPE." },
	{ t = 25.0, d = 1.3, text = "UM MAPA NOVO", sub = "A CADA NOITE" },
	{ t = 27.5, d = 1.2, text = "FUJA." },
}

local CAPTIONS: { Caption } = {
	{ t = 0.7, d = 1.4, text = "16 DE OUTUBRO · 03:12" },
	{ t = 1.9, d = 1.7, text = "A Subestação 9 parou de responder." },
	{ t = 5.6, d = 2.8, text = "Uma equipe foi mandada para religar a energia." },
	{ t = 13.5, d = 2.0, text = "Mas eles não estavam sozinhos." },
}

-- Preto total (sem cena) nestes intervalos.
local BLACK: { { number } } = {
	{ 0, 3.6 },
	{ 3.6, 5.2 },
	{ 12.0, 13.2 },
	{ 30.0, 31.6 },
	{ 38.9, 40.5 },
}

-- Clarões brancos (impactos).
local FLASHES = { 3.6, 17.35, 20.45, 29.95, 31.6 }
-- Estática de fita entre planos.
local STATIC = { 8.4, 18.5, 19.75, 21.3, 22.6, 23.8, 25.0, 26.3, 27.5, 28.8, 38.6 }

local SOUNDS: { SoundCue } = {
	{ t = 0.0, key = "MusicTension", volume = 0.55, stop = 18.5 },
	{ t = 0.25, key = "RadioStatic", volume = 0.35 },
	{ t = 3.6, key = "StingerAwaken", volume = 1 },
	{ t = 3.6, key = "Fall_bucket", volume = 0.9, speed = 0.55 },
	{ t = 5.2, key = "AmbExterior", volume = 0.6, stop = 12.0 },
	{ t = 12.0, key = "DoorLatch", volume = 1, speed = 0.7 },
	{ t = 12.0, key = "Fall_box", volume = 0.7, speed = 0.6 },
	{ t = 13.2, key = "Heartbeat", volume = 0.9, stop = 16.9 },
	{ t = 13.2, key = "AmbInterior", volume = 0.6, stop = 18.5 },
	{ t = 15.25, key = "Flashlight", volume = 0.9 },
	{ t = 15.55, key = "Flashlight", volume = 0.9, speed = 1.1 },
	{ t = 16.6, key = "Whisper", volume = 0.6 },
	{ t = 16.95, key = "Snarl", volume = 1 },
	{ t = 17.35, key = "Roar", volume = 1, speed = 0.9 },
	{ t = 17.35, key = "StingerAwaken", volume = 0.8, speed = 0.8 },
	{ t = 18.5, key = "MusicChase", volume = 0.75, stop = 29.95 },
	{ t = 18.5, key = "Switch", volume = 0.9 },
	{ t = 19.8, key = "KeyTurn", volume = 0.9, speed = 0.8 },
	{ t = 20.45, key = "BreakerFail", volume = 1 },
	{ t = 20.45, key = "Fall_pipes", volume = 1, speed = 0.8 },
	{ t = 21.3, key = "LockerLatch", volume = 1 },
	{ t = 22.0, key = "Growl", volume = 0.9 },
	{ t = 22.6, key = "Snarl", volume = 1, speed = 1.1 },
	{ t = 23.8, key = "Gasp", volume = 0.9 },
	{ t = 25.0, key = "RadioStatic", volume = 0.5 },
	{ t = 26.3, key = "Whisper", volume = 0.8 },
	{ t = 27.5, key = "DoorBang", volume = 1 },
	{ t = 28.8, key = "Snarl", volume = 1, speed = 0.9 },
	{ t = 29.95, key = "Roar", volume = 1, speed = 0.75 },
	{ t = 29.95, key = "StingerCapture", volume = 1 },
	{ t = 29.95, key = "BreakerFail", volume = 1, speed = 0.7 },
	{ t = 29.95, key = "Fall_bucket", volume = 1, speed = 0.45 },
	{ t = 31.0, key = "Heartbeat", volume = 1, stop = 31.75 },
	{ t = 31.6, key = "StingerAwaken", volume = 1, speed = 0.75 },
	{ t = 31.6, key = "MusicRelief", volume = 0.6, stop = 40 },
	{ t = 35.8, key = "Whisper", volume = 0.5 },
	{ t = 38.6, key = "RadioStatic", volume = 0.6 },
}

local function sectorCenter(): Vector3
	local world = workspace:FindFirstChild("CursedHouse")
	local sector = world and world:FindFirstChild("ProceduralSector")
	local cell = sector and sector:FindFirstChild("Cell_5")
	if cell and cell:IsA("Model") then
		return cell:GetPivot().Position
	end
	return v(-6, 0, -106)
end

local SHOTS: { Shot } = {
	{
		t = 5.2,
		d = 3.2,
		name = "road",
		camera = dolly(v(3, 5, 70), v(1.5, 4.6, 57), v(0, 4, 44), v(0, 3.5, 30), 58),
		act = function()
			fx.moon.Enabled = true
			fx.gateLamp.Enabled = true
			fx.cameraLamp.Enabled = true
			fx.cameraLamp.Brightness = 3
		end,
		shake = 0.15,
	},
	{
		t = 8.4,
		d = 3.6,
		name = "arrival",
		camera = dolly(v(-2.5, 4.6, 30), v(-3.2, 4.3, 24.5), v(-4, 3.6, 0), v(-4, 3.4, 0), 56),
		act = function(alpha)
			fx.moon.Enabled = true
			fx.cameraLamp.Enabled = true
			fx.cameraLamp.Brightness = 3
			walk(1, v(-4, 0, 21), v(-4, 0, 10), alpha, "walk", -6)
			walk(2, v(-7.2, 0, 19), v(-7, 0, 8.5), alpha, "walk", -4)
			walk(3, v(-0.8, 0, 18.5), v(-1.4, 0, 8), alpha, "walk", -8)
		end,
		shake = 0.12,
	},
	{
		t = 13.2,
		d = 3.4,
		name = "corridor",
		camera = dolly(v(-38.5, 5.6, -21), v(-37.5, 5.5, -21.2), v(10, 3.6, -22), v(10, 3.6, -22), 48),
		act = function(alpha, time, dt)
			fx.backlight.Enabled = true
			walk(1, v(-33, 0, -23.6), v(-27, 0, -23.4), alpha, "walk", -2)
			-- A luz falha (15,25–15,55 s do trailer) e o Vigia aparece bem mais perto.
			local off = time >= 2.05 and time < 2.35
			local member = team[1]
			if member then
				member.light.Enabled = not off
			end
			local near = time >= 2.35
			creature(if near then v(-14, 0, -22) else v(16, 0, -22), v(-40, 0, -22), "Idle", dt, 2)
			if vigia then
				vigia.rig.eyeLight.Brightness = 3
			end
		end,
		shake = 0.1,
	},
	{
		t = 16.6,
		d = 1.9,
		name = "faceReveal",
		camera = dolly(v(-6.4, 3.4, -21.2), v(-5.4, 3.7, -21.4), v(0, 7.1, -22), v(0, 7.3, -22), 46),
		act = function(_alpha, time, dt)
			fx.faceSpot.Enabled = true
			creature(
				v(0, 0, -22),
				v(-6, 0, -22),
				if time < 0.6 then "Idle" else "Notice",
				dt,
				6,
				if time < 0.4 then 35 else 0
			)
		end,
		shake = 0.2,
	},
	{
		t = 18.5,
		d = 1.3,
		name = "panel",
		camera = dolly(v(-14.2, 5.2, -43.6), v(-15.2, 4.9, -45.2), v(-16, 4.2, -49), v(-16, 4.3, -49), 52),
		act = function(_alpha, time)
			fx.panelFill.Enabled = true
			stand(1, v(-16.6, 0, -46.6), v(-16.6, 0, -52), "reach", -10, time)
		end,
		shake = 0.15,
	},
	{
		t = 19.8,
		d = 1.5,
		name = "breakers",
		camera = dolly(v(-10.8, 4.6, -44.2), v(-10.2, 4.3, -45.4), v(-9.5, 3.6, -49), v(-9.5, 3.7, -49), 52),
		act = function(_alpha, time)
			fx.panelFill.Enabled = true
			local burst = time - 0.65
			if burst >= 0 and burst < 0.05 then
				fx.sparks:Emit(120)
			end
			fx.burst.Enabled = burst >= 0
			fx.burst.Brightness = if burst >= 0 then math.max(0, 30 * (1 - burst / 0.6)) else 0
			fx.roomOn.Enabled = burst > 0.35
			fx.roomOn.Brightness = if burst > 0.35 then (if rng:NextNumber() < 0.3 then 0.4 else 1.6) else 0
			stand(2, v(-6.2, 0, -46.8), v(-8.5, 0, -50), "reach", -6, time)
		end,
		shake = 0.15,
	},
	{
		t = 21.3,
		d = 1.3,
		name = "locker",
		camera = dolly(v(-37.2, 5.1, -36), v(-37.2, 5.1, -36), v(-25, 4.6, -37), v(-25, 4.4, -35), 56, false),
		act = function(alpha, _time, dt)
			fx.roomOn.Enabled = true
			fx.roomOn.Brightness = 0.6
			fx.lockerSpot.Enabled = true
			local position = v(-29, 0, -43):Lerp(v(-29, 0, -30), alpha)
			creature(position, position + v(0, 0, 10), "Walk", dt, 6)
		end,
		shake = 0.05,
	},
	{
		t = 22.6,
		d = 1.2,
		name = "chase",
		camera = dolly(v(-12, 3.1, -22), v(-17, 3.3, -22), v(4, 5, -22), v(-6, 5.4, -22), 60, false),
		act = function(alpha, _time, dt)
			local position = v(6, 0, -22):Lerp(v(-8, 0, -22), alpha)
			creature(position, v(-40, 0, -22), "Chase", dt, 12)
			fx.cameraLamp.Enabled = true
			fx.cameraLamp.Brightness = 8
		end,
		shake = 0.6,
	},
	{
		t = 23.8,
		d = 1.2,
		name = "rescue",
		camera = function(alpha: number): (CFrame, number)
			local angle = math.rad(20 + 50 * ease(alpha))
			local center = v(6.8, 1.4, 18.3)
			return CFrame.lookAt(center + v(math.cos(angle) * 8, 3, math.sin(angle) * 8), center), 50
		end,
		act = function(_alpha, time)
			fx.storage.Enabled = true
			fx.moon.Enabled = true
			stand(1, v(6, 0, 18), v(6, 0, 12), "downed", 0, time)
			stand(2, v(8.6, 0, 18.8), v(5, 0, 18), "kneel", -40, time)
		end,
		shake = 0.1,
	},
	{
		t = 25.0,
		d = 1.3,
		name = "sector",
		camera = function(alpha: number): (CFrame, number)
			local c = sectorCenter()
			local t = ease(alpha)
			return CFrame.lookAt(v(c.X + 10 - 3 * t, 6.2, c.Z + 10), v(c.X - 6, 3, c.Z - 6)), 64
		end,
		act = function()
			local c = sectorCenter()
			fx.sector.Parent.Position = v(c.X, 8, c.Z)
			fx.sector.Enabled = true
		end,
		shake = 0.08,
	},
	{
		t = 26.3,
		d = 1.2,
		name = "graffiti",
		camera = dolly(v(29.4, 5.4, -37.4), v(29.9, 5.2, -35.6), v(30, 5, -27), v(30, 5, -27), 52),
		act = function(_alpha, time)
			fx.graffitiSpot.Enabled = rng:NextNumber() > 0.08 or time < 0.2
			glowGraffiti(true)
		end,
		shake = 0.15,
	},
	{
		t = 27.5,
		d = 1.3,
		name = "gate",
		camera = dolly(v(-4.8, 3.2, 41), v(-4.4, 3.1, 41.8), v(1, 3.2, 20), v(1, 3.4, 22), 58),
		act = function(alpha)
			fx.moon.Enabled = true
			fx.gateLamp.Enabled = true
			fx.storage.Enabled = true
			walk(1, v(-0.5, 0, 16), v(-1, 0, 33), alpha, "run", -4)
			walk(2, v(2.6, 0, 13), v(2.2, 0, 30.5), alpha, "run", -2)
			walk(3, v(-3.4, 0, 11), v(-3, 0, 28), alpha, "run", -6)
		end,
		shake = 0.35,
	},
	{
		t = 28.8,
		d = 1.2,
		name = "lunge",
		camera = dolly(v(0.4, 3.6, 41.5), v(0.4, 3.5, 42.2), v(0, 4.5, 24), v(0, 6.2, 34), 58),
		act = function(alpha, _time, dt)
			fx.moon.Enabled = true
			fx.gateLamp.Enabled = true
			local t = alpha ^ 1.6
			local position = v(0, 0, 22):Lerp(v(0, 0, 38.8), t)
			creature(position, v(0, 0, 60), if alpha < 0.65 then "Chase" else "Lunge", dt, 12)
		end,
		shake = 0.7,
	},
}

-- ===================== Interface =====================

local function px(value: string): string
	return PixelText.normalize(value)
end

local function buildUi()
	local screen = Create("ScreenGui", {
		Name = "TrailerUi",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 500,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	local function black(name: string, fields: { [string]: any }): Frame
		local base: { [string]: any } = { Name = name, BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }
		for key, value in fields do
			base[key] = value
		end
		return Create("Frame", base) :: Frame
	end
	ui.top = black("BarTop", { Size = UDim2.fromScale(1, LETTERBOX), ZIndex = 5, Parent = screen })
	ui.bottom = black("BarBottom", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, LETTERBOX),
		ZIndex = 5,
		Parent = screen,
	})
	-- Vinheta de cinema (escurece as bordas).
	ui.vignette = Create("Frame", {
		Name = "Vignette",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = screen,
	}, {
		Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.35),
				NumberSequenceKeypoint.new(0.22, 1),
				NumberSequenceKeypoint.new(0.78, 1),
				NumberSequenceKeypoint.new(1, 0.35),
			}),
		}),
	})
	-- Frestas do armário.
	ui.slits = Create("Frame", {
		Name = "Slits",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 3,
		Parent = screen,
	})
	for i = 0, 7 do
		black(`Slat{i}`, {
			Position = UDim2.fromScale(0, i / 8),
			Size = UDim2.fromScale(1, 1 / 8 - 0.045),
			BackgroundTransparency = 0.04,
			ZIndex = 3,
			Parent = ui.slits,
		})
	end
	ui.static = Create("Frame", {
		Name = "Static",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = screen,
	})
	ui.bars = {}
	for _ = 1, 26 do
		table.insert(ui.bars, Create("Frame", { BorderSizePixel = 0, ZIndex = 6, Parent = ui.static }))
	end
	ui.black = black("Black", { Size = UDim2.fromScale(1, 1), ZIndex = 7, Parent = screen })
	ui.flash = Create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = screen,
	})
	-- Cartela grande.
	ui.titleHolder = Create("Frame", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.22),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
		Parent = screen,
	})
	ui.titleScale = Create("UIScale", { Parent = ui.titleHolder })
	ui.title = Create("TextLabel", {
		Size = UDim2.fromScale(1, 0.7),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Text,
		TextStrokeTransparency = 0.2,
		ZIndex = 9,
		Parent = ui.titleHolder,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 120 }) })
	ui.titleSub = Create("TextLabel", {
		Position = UDim2.fromScale(0, 0.72),
		Size = UDim2.fromScale(1, 0.28),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		TextColor3 = Theme.Hazard,
		ZIndex = 9,
		Parent = ui.titleHolder,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 44 }) })
	-- Legenda (máquina de escrever) na faixa de baixo.
	ui.caption = Create("TextLabel", {
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1 - LETTERBOX / 2),
		Size = UDim2.fromScale(0.86, LETTERBOX * 0.5),
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		TextScaled = true,
		TextColor3 = Color3.fromRGB(226, 220, 198),
		Visible = false,
		ZIndex = 9,
		Parent = screen,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 34 }) })
	-- Logo.
	ui.logo = Create("Frame", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.47),
		Size = UDim2.fromScale(0.8, 0.5),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 9,
		Parent = screen,
	})
	ui.logoScale = Create("UIScale", { Parent = ui.logo })
	ui.logoRec = Create("TextLabel", {
		Size = UDim2.fromScale(1, 0.1),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		Text = px("● REC · ARQUIVO 009 · TURNO DA NOITE"),
		TextColor3 = Theme.Accent,
		ZIndex = 9,
		Parent = ui.logo,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 24 }) })
	ui.logoName = Create("TextLabel", {
		Position = UDim2.fromScale(0, 0.14),
		Size = UDim2.fromScale(1, 0.42),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		Text = px("SUBESTAÇÃO 9"),
		TextColor3 = Theme.Text,
		TextStrokeColor3 = Theme.Accent,
		TextStrokeTransparency = 0.4,
		ZIndex = 9,
		Parent = ui.logo,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 150 }) })
	ui.logoTag = Create("TextLabel", {
		Position = UDim2.fromScale(0, 0.58),
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		Text = px("O VIGIA AINDA ESTÁ NO TURNO"),
		TextColor3 = Theme.Hazard,
		ZIndex = 9,
		Parent = ui.logo,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 36 }) })
	ui.logoModes = Create("TextLabel", {
		Position = UDim2.fromScale(0, 0.74),
		Size = UDim2.fromScale(1, 0.1),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		Text = px("MODO HISTÓRIA · CO-OP DE 2 A 8 JOGADORES"),
		TextColor3 = Theme.Text,
		ZIndex = 9,
		Visible = false,
		Parent = ui.logo,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 28 }) })
	ui.logoSoon = Create("TextLabel", {
		Position = UDim2.fromScale(0, 0.88),
		Size = UDim2.fromScale(1, 0.12),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextScaled = true,
		Text = px("EM BREVE NO ROBLOX"),
		TextColor3 = Color3.fromRGB(120, 200, 140),
		ZIndex = 9,
		Visible = false,
		Parent = ui.logo,
	}, { Create("UITextSizeConstraint", { MaxTextSize = 34 }) })
	screen.Parent = player:WaitForChild("PlayerGui")
	gui = screen
end

-- Entrada "pancada": cresce, encolhe para o tamanho e treme; sai em 0,15 s.
local function slam(holder: GuiObject, scale: UIScale, local_t: number, d: number)
	local inT = math.clamp(local_t / 0.14, 0, 1)
	scale.Scale = 1.35 - 0.35 * (1 - (1 - inT) ^ 3)
	local shake = if local_t < 0.3 then (0.3 - local_t) * 30 else 0
	holder.Position = UDim2.new(0.5, rng:NextNumber(-shake, shake), 0.5, rng:NextNumber(-shake, shake))
	local out = math.clamp((d - local_t) / 0.15, 0, 1)
	return out
end

local function renderUi(time: number)
	local now = os.clock()
	-- Preto.
	local isBlack = time >= DURATION
	for _, span in BLACK do
		if time >= span[1] and time < span[2] then
			isBlack = true
		end
	end
	ui.black.Visible = isBlack
	-- Clarão.
	local flash = 0
	for _, at in FLASHES do
		local since = time - at
		if since >= 0 and since < 0.35 then
			flash = math.max(flash, 1 - since / 0.35)
		end
	end
	ui.flash.BackgroundTransparency = 1 - flash * 0.9
	-- Estática.
	local static = false
	for _, at in STATIC do
		if time >= at - 0.06 and time < at + 0.14 then
			static = true
		end
	end
	ui.static.Visible = static
	if static then
		for _, bar in ui.bars do
			local gray = rng:NextInteger(30, 240)
			bar.BackgroundColor3 = Color3.fromRGB(gray, gray, gray)
			bar.BackgroundTransparency = rng:NextNumber(0, 0.5)
			bar.Position = UDim2.fromScale(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 1))
			bar.Size = UDim2.new(rng:NextNumber(0.5, 1.4), 0, 0, rng:NextInteger(2, 30))
		end
	end
	-- Frestas (plano do armário).
	ui.slits.Visible = lastShot == "locker" and not isBlack
	-- Cartelas grandes.
	local shownTitle = false
	for _, title in TITLES do
		local local_t = time - title.t
		if local_t >= 0 and local_t < title.d then
			shownTitle = true
			ui.titleHolder.Visible = true
			ui.title.Text = px(title.text)
			ui.title.TextColor3 = title.color or Theme.Text
			ui.titleHolder.Size = UDim2.fromScale(0.9, 0.22 * (title.size or 1))
			ui.titleSub.Text = if title.sub then px(title.sub) else ""
			local out = slam(ui.titleHolder, ui.titleScale, local_t, title.d)
			ui.title.TextTransparency = 1 - out
			ui.titleSub.TextTransparency = 1 - out
			ui.title.TextStrokeTransparency = 1 - out * 0.8
		end
	end
	if not shownTitle then
		ui.titleHolder.Visible = false
	end
	-- Legenda datilografada.
	local caption: Caption? = nil
	for _, c in CAPTIONS do
		if time >= c.t and time < c.t + c.d then
			caption = c
		end
	end
	if caption then
		local chars = math.floor((time - caption.t) * 38)
		ui.caption.Visible = true
		local cut = utf8.offset(caption.text, chars + 1)
		ui.caption.Text = if cut then string.sub(caption.text, 1, cut - 1) else caption.text
		ui.caption.ZIndex = 9
	else
		ui.caption.Visible = false
	end
	-- Logos (abertura 3,6–5,2; final 31,6–38,9).
	local openLogo = time >= 3.6 and time < 5.2
	local endLogo = time >= 31.6 and time < 38.9
	ui.logo.Visible = openLogo or endLogo
	if openLogo or endLogo then
		local local_t = time - (if openLogo then 3.6 else 31.6)
		local d = if openLogo then 1.6 else 7.3
		local out = slam(ui.logo, ui.logoScale, local_t, d)
		ui.logo.Position = UDim2.new(0.5, ui.logo.Position.X.Offset, 0.47, ui.logo.Position.Y.Offset)
		-- Falha de luz no logo.
		local flicker = (local_t > 0.5 and rng:NextNumber() < 0.06) and 0.6 or 0
		ui.logoName.TextTransparency = math.clamp(1 - out + flicker, 0, 1)
		ui.logoRec.TextTransparency = if (now * 1.6) % 1 < 0.6 then 1 - out else 1
		ui.logoTag.TextTransparency = 1 - out
		ui.logoModes.Visible = endLogo and local_t > 1.0
		ui.logoSoon.Visible = endLogo and local_t > 2.0
		ui.logoModes.TextTransparency = 1 - out
		ui.logoSoon.TextTransparency = 1 - out
	end
end

-- ===================== Sons =====================

local function playCue(index: number, cue: SoundCue)
	local clip = (Audio :: any)[cue.key]
	if not clip then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = `Trailer_{cue.key}`
	sound.SoundId = clip.id
	sound.Volume = cue.volume or clip.volume
	sound.PlaybackSpeed = cue.speed or clip.speed or 1
	sound.Looped = cue.stop ~= nil and cue.stop - cue.t > 4
	sound.SoundGroup = trailerMix
	if clip.region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(clip.region[1], clip.region[2])
	end
	sound.Parent = SoundService
	sound:Play()
	sounds[index] = sound
end

local function updateSounds(time: number)
	for index, cue in SOUNDS do
		if not fired[index] and time >= cue.t then
			fired[index] = true
			playCue(index, cue)
		end
		local sound = sounds[index]
		if sound and cue.stop and time >= cue.stop then
			sound:Stop()
			sound:Destroy()
			sounds[index] = nil
		end
	end
end

local function stopSounds(keepFired: boolean?)
	for index, sound in sounds do
		sound:Stop()
		sound:Destroy()
		sounds[index] = nil
	end
	if not keepFired then
		fired = {}
	end
end

-- ===================== Execução =====================

local function shotAt(time: number): Shot?
	for _, shot in SHOTS do
		if time >= shot.t and time < shot.t + shot.d then
			return shot
		end
	end
	return nil
end

local function frame(time: number, dt: number)
	renderUi(time)
	local shot = shotAt(time)
	allLightsOff()
	if not shot then
		lastShot = ""
		hideAll()
		-- Câmera parada (a tela está preta ou no logo).
		Camera.setCinema(CFrame.lookAt(v(0, 300, 0), v(0, 300, -10)), 50, v(0, 300, -10))
		return
	end
	if shot.name ~= lastShot then
		lastShot = shot.name
		hideAll()
	end
	local local_t = time - shot.t
	local alpha = math.clamp(local_t / shot.d, 0, 1)
	if shot.act then
		shot.act(alpha, local_t, dt)
	end
	if shot.name ~= "graffiti" then
		glowGraffiti(false)
	end
	local cf, fov = shot.camera(alpha, local_t)
	local lampPart = fx.cameraLamp.Parent :: BasePart
	lampPart.CFrame = cf * CFrame.new(0.6, -0.8, 0)
	local shake = shot.shake or 0
	if time < hitShakeUntil then
		shake += 1
	end
	if shake > 0 then
		local k = shake * 0.012
		cf *= CFrame.Angles(
			math.noise(time * 2.1, 3.3) * k + rng:NextNumber(-k, k) * 0.15,
			math.noise(time * 1.7, 9.1) * k,
			math.noise(time * 1.3, 5.7) * k * 0.6
		)
	end
	Camera.setCinema(cf, fov, cf.Position + cf.LookVector * 20)
	-- Sem esperar o próximo quadro do compositor.
	local camera = workspace.CurrentCamera
	if camera then
		camera.CFrame = cf
		camera.FieldOfView = fov
	end
end

local function setActive(on: boolean)
	if on == enabled then
		return
	end
	enabled = on
	if gui then
		gui.Enabled = on
	end
	if grade then
		grade.Enabled = on
	end
	player:SetAttribute("CinematicActive", on)
	if on then
		for _, group in SoundService:GetChildren() do
			if group:IsA("SoundGroup") and group ~= trailerMix then
				savedAudioVolumes[group] = group.Volume
				group.Volume = 0
			end
		end
		for _, kind in Enum.CoreGuiType:GetEnumItems() do
			if kind ~= Enum.CoreGuiType.All then
				pcall(function()
					savedCoreGui[kind] = StarterGui:GetCoreGuiEnabled(kind)
					StarterGui:SetCoreGuiEnabled(kind, false)
				end)
			end
		end
	else
		for group, volume in savedAudioVolumes do
			if group.Parent then
				group.Volume = volume
			end
		end
		savedAudioVolumes = {}
		for kind, visible in savedCoreGui do
			pcall(function()
				StarterGui:SetCoreGuiEnabled(kind, visible)
			end)
		end
		savedCoreGui = {}
	end
	-- Esconde as outras telas durante o trailer.
	for _, other in player.PlayerGui:GetChildren() do
		if other:IsA("ScreenGui") and other ~= gui then
			if on then
				other:SetAttribute("TrailerWasEnabled", other.Enabled)
				other.Enabled = false
			elseif other:GetAttribute("TrailerWasEnabled") ~= nil then
				other.Enabled = other:GetAttribute("TrailerWasEnabled") == true
				other:SetAttribute("TrailerWasEnabled", nil)
			end
		end
	end
	-- O próprio personagem sai de cena (fica parado longe).
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		if on then
			savedCharacterPivot = character:GetPivot()
			savedAnchored = root.Anchored
			root.Anchored = true
			character:PivotTo(CFrame.new(-150, 4, 110))
		else
			if savedCharacterPivot then
				character:PivotTo(savedCharacterPivot)
			end
			root.Anchored = savedAnchored
			savedCharacterPivot = nil
		end
	end
	if not on then
		Camera.endCinema()
		allLightsOff()
		hideAll()
		glowGraffiti(false)
	end
end

function Controller.prepare()
	if not props then
		buildProps()
		buildActors()
	end
	setActive(true)
	frame(0, 0)
end

function Controller.play()
	Controller.prepare()
	stopSounds()
	armedAt = nil
	playing = true
	seekTime = nil
	startedAt = os.clock()
	lastTime = 0
end

function Controller.arm(delay: number): number
	Controller.prepare()
	stopSounds()
	playing = false
	seekTime = 0
	armedAt = DateTime.now().UnixTimestampMillis + math.clamp(delay, 0, 30) * 1000
	return armedAt :: number
end

function Controller.seek(time: number)
	Controller.prepare()
	playing = false
	armedAt = nil
	stopSounds()
	seekTime = time
end

function Controller.stop()
	playing = false
	armedAt = nil
	seekTime = nil
	stopSounds()
	setActive(false)
end

function Controller.Start()
	if not RunService:IsStudio() then
		return
	end
	buildUi()
	local bridge = Instance.new("BindableFunction")
	bridge.Name = "TrailerBridge"
	bridge.OnInvoke = function(command: string, value: any): any
		if command == "play" then
			Controller.play()
		elseif command == "arm" then
			return Controller.arm(tonumber(value) or 4)
		elseif command == "seek" then
			Controller.seek(tonumber(value) or 0)
		elseif command == "stop" then
			Controller.stop()
		end
		return {
			playing = playing,
			armedAt = armedAt,
			time = if playing then os.clock() - startedAt else seekTime,
			shot = lastShot,
			duration = DURATION,
		}
	end
	bridge.Parent = gui
	-- Depois da câmera do Roblox e do compositor (o trailer manda na imagem).
	RunService:BindToRenderStep("S9Trailer", Enum.RenderPriority.Camera.Value + 4, function(dt)
		if not enabled then
			return
		end
		if armedAt then
			if DateTime.now().UnixTimestampMillis < armedAt then
				frame(0, dt)
				return
			end
			Controller.play()
		end
		local time = if playing then os.clock() - startedAt else (seekTime or 0)
		if playing then
			updateSounds(time)
			-- Corte de som deliberado após o bote, antes do batimento e do logo final.
			if time >= 30.2 and lastTime < 30.2 then
				stopSounds(true)
			end
			if trailerMix then
				trailerMix.Volume = 0.8 * math.clamp((DURATION + 0.5 - time) / 1.2, 0, 1)
			end
			if time >= 29.95 and lastTime < 29.95 then
				hitShakeUntil = time + 0.3
			end
			if time >= DURATION + 0.5 then
				playing = false
				seekTime = DURATION + 0.5
				stopSounds()
			end
		end
		lastTime = time
		frame(time, dt)
	end)
end

return Controller
