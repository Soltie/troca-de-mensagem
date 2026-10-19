--!strict
--[[
	Chuva só no cliente (não toca em regra de jogo nem replica nada):
	- gotas em volta da câmera, iluminadas pelas luzes do cenário, que param sob qualquer telhado;
	- respingos no chão logo abaixo da câmera;
	- som de chuva (abafado dentro de casa) e trovões distantes;
	- relâmpago raro, só com a opção de flashes ligada (conforto visual).
	A quantidade de gotas segue a qualidade visual escolhida; em Baixa ainda chove, com menos gotas.
]]
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Weather = require("@game/ReplicatedStorage/Shared/Game/Weather")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local Settings = require("./SettingsController")

local STREAK = "rbxassetid://90203797622509"
local SPLASH = "rbxassetid://131263262987295"

local controller = { Name = "RainController" }

-- Grade 3 × 2 de células de 24 studs, centrada um pouco à frente do olhar e 30 studs acima.
local CELL = 24
local CELLS = {
	Vector3.new(-24, 0, -12),
	Vector3.new(0, 0, -12),
	Vector3.new(24, 0, -12),
	Vector3.new(-24, 0, 12),
	Vector3.new(0, 0, 12),
	Vector3.new(24, 0, 12),
}
type Cell = { part: BasePart, emitter: ParticleEmitter, offset: Vector3 }
local cells: { Cell } = {}
local splashes: ParticleEmitter? = nil
local floor: BasePart? = nil
local sound: Sound? = nil
local muffle: EqualizerSoundEffect? = nil
local flashFx: ColorCorrectionEffect? = nil
local outdoor = 1
local outdoorTarget = 1
local groundY = 0
local nextStrike = 0
local strikeAt = -100
local rng = Random.new()

--[[
	Gotinhas na tela ao ar livre (pedido do humano): no máximo DROPLETS molduras redondas e quase transparentes que
	aparecem, escorrem um pouco e somem. Só em qualidade Média/Alta, abaixo do HUD e da vinheta; custo desprezível.
]]
local DROPLETS = 10
type Droplet = { frame: Frame, born: number, life: number, from: UDim2, fall: number, alive: boolean }
local droplets: { Droplet } = {}
local dropClock = 0

local function buildLens(parent: Instance)
	local gui = Instance.new("ScreenGui")
	gui.Name = "RainLens"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 39
	for _ = 1, DROPLETS do
		local frame = Instance.new("Frame")
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.fromRGB(205, 214, 228)
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		local rim = Instance.new("UIStroke")
		rim.Color = Color3.fromRGB(235, 240, 248)
		rim.Thickness = 1
		rim.Transparency = 1
		rim.Parent = frame
		-- Brilho em cima, sombra embaixo: lê como gota na lente, não como bolinha chapada.
		local shade = Instance.new("UIGradient")
		shade.Rotation = 90
		shade.Transparency = NumberSequence.new(0.2, 0.85)
		shade.Parent = frame
		frame.Parent = gui
		table.insert(droplets, { frame = frame, born = 0, life = 0, from = UDim2.new(), fall = 0, alive = false })
	end
	gui.Parent = parent
end

local function updateLens(now: number, dt: number, wet: boolean, budget: number)
	dropClock += dt
	-- ~2,5 gotas novas por segundo na chuva aberta (qualidade Alta).
	if wet and budget > 0.2 and dropClock > 0.4 / budget then
		dropClock = 0
		for _, drop in droplets do
			if not drop.alive then
				local size = rng:NextInteger(5, 13)
				drop.alive, drop.born, drop.life = true, now, rng:NextNumber(1.4, 3.2)
				drop.from = UDim2.fromScale(rng:NextNumber(0.06, 0.94), rng:NextNumber(0.05, 0.8))
				drop.fall = rng:NextNumber(0.01, 0.06)
				drop.frame.Size = UDim2.fromOffset(size, math.floor(size * rng:NextNumber(1.05, 1.35)))
				drop.frame.Visible = true
				break
			end
		end
	end
	for _, drop in droplets do
		if drop.alive then
			local t = (now - drop.born) / drop.life
			if t >= 1 then
				drop.alive, drop.frame.Visible = false, false
			else
				-- Entra rápido, escorre devagar, some no fim.
				local alpha = math.min(1, t * 6) * (1 - math.max(0, t - 0.7) / 0.3)
				drop.frame.Position = drop.from + UDim2.fromScale(0, drop.fall * t * t)
				drop.frame.BackgroundTransparency = 1 - 0.2 * alpha
				local rim = drop.frame:FindFirstChildOfClass("UIStroke")
				if rim then
					rim.Transparency = 1 - 0.32 * alpha
				end
			end
		end
	end
end

local function holder(name: string, size: Vector3): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = size
	part.CastShadow = false
	return part
end

-- Telhado acima da câmera (casa, varanda, pavilhões) e chão abaixo dela.
local function probe(position: Vector3)
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = if world then { world } else {}
	params.RespectCanCollide = true
	local roof = workspace:Raycast(position, Vector3.new(0, 80, 0), params)
	outdoorTarget = if roof then 0 else 1
	local below = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -40, 0), params)
	groundY = if below then below.Position.Y else position.Y - 5
end

local function strike(now: number)
	strikeAt = now
	nextStrike = now + Weather.strikeInterval(rng:NextNumber())
	task.delay(Weather.thunderDelay(rng:NextNumber()), function()
		local thunder = AudioController.play("AmbThunder", 0.55 + outdoor * 0.45)
		-- Tremor leve quando o trovão chega (mais forte ao ar livre); o CameraController respeita o conforto.
		CameraController.addTrauma(0.28 + 0.17 * outdoor)
		task.delay(0.35, function()
			CameraController.addTrauma(0.12 + 0.08 * outdoor)
		end)
		-- O arquivo tem vários estrondos: cada trovão começa num trecho diferente e some em 9 s.
		thunder.TimePosition = rng:NextNumber(0, 90)
		task.delay(9, function()
			if thunder.Parent then
				thunder:Stop()
				thunder:Destroy()
			end
		end)
	end)
end

function controller.debugState(): { [string]: any }
	return {
		outdoor = outdoor,
		rate = if cells[1] then cells[1].emitter.Rate * #cells else 0,
		splash = splashes and splashes.Rate,
		volume = sound and sound.Volume,
		nextStrike = nextStrike,
	}
end

-- Ponte de QA no Studio: força um relâmpago agora.
function controller.strikeNow()
	strike(os.clock())
end

function controller.Init()
	local folder = Instance.new("Folder")
	folder.Name = "ClientWeather"
	folder.Parent = workspace
	-- Várias células pequenas: um emissor só, numa área grande, fica ralo (o motor limita partículas por emissor).
	for index, offset in CELLS do
		local cell = holder("RainCell" .. index, Vector3.new(CELL, 1, CELL))
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Drops"
		emitter.Texture = STREAK
		emitter.EmissionDirection = Enum.NormalId.Bottom
		emitter.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
		emitter.Speed = NumberRange.new(75, 90)
		emitter.Lifetime = NumberRange.new(0.55, 0.65)
		emitter.SpreadAngle = Vector2.new(3, 3)
		emitter.Acceleration = Vector3.new(4, 0, 1.5) -- vento leve inclina as gotas
		-- Gotas finas, curtas e sem brilho próprio: aparecem onde há luz (lanterna, lâmpadas, relâmpago),
		-- não como riscos brancos longos no escuro (pedido do humano, referência The Mimic).
		emitter.Size = NumberSequence.new(0.48, 0.12)
		emitter.Squash = NumberSequence.new(1.6) -- positivo = gota alta e fina
		emitter.Transparency = NumberSequence.new(0.74, 0.38)
		emitter.Color = ColorSequence.new(Color3.fromRGB(186, 196, 212))
		emitter.LightInfluence = 0.7
		emitter.LightEmission = 0.18
		emitter.Rate = 0
		emitter.Parent = cell
		cell.Parent = folder
		table.insert(cells, { part = cell, emitter = emitter, offset = offset })
	end
	local bottom = holder("RainFloor", Vector3.new(44, 0.2, 44))
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splashes"
	splash.Texture = SPLASH
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	splash.Speed = NumberRange.new(0.05)
	splash.Lifetime = NumberRange.new(0.22, 0.32)
	splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 0.85) })
	splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	splash.Color = ColorSequence.new(Color3.fromRGB(205, 214, 230))
	splash.LightInfluence = 1
	splash.Rate = 0
	splash.Parent = bottom
	bottom.Parent = folder
	splashes, floor = splash, bottom
	local fx = Instance.new("ColorCorrectionEffect")
	fx.Name = "RainLightning"
	fx.TintColor = Color3.fromRGB(214, 226, 255)
	fx.Enabled = false
	fx.Parent = Lighting
	flashFx = fx
end

function controller.Start()
	local rain = AudioController.loopAt("AmbRain", SoundService)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "RainMuffle"
	eq.LowGain, eq.MidGain, eq.HighGain = 0, 0, 0
	eq.Parent = rain
	rain:Play()
	sound, muffle = rain, eq
	local base = rain.Volume
	buildLens(Players.LocalPlayer:WaitForChild("PlayerGui"))
	nextStrike = os.clock() + Weather.strikeInterval(rng:NextNumber())
	local probeClock = 1
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local now = os.clock()
		local eye = camera.CFrame.Position
		probeClock += dt
		if probeClock >= 0.25 then
			probeClock = 0
			probe(eye)
		end
		outdoor += (outdoorTarget - outdoor) * math.min(1, dt * 4)
		-- A nuvem anda com a câmera e um pouco à frente: a maioria das gotas cai onde se olha.
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		local ahead = if flat.Magnitude > 0.01 then flat.Unit * 14 else Vector3.zero
		local budget = Settings.visualBudget().particles
		local gust = Weather.gust(now)
		local open = if outdoorTarget > 0.5 then 1 else 0
		local perCell = Weather.rate(Weather.RainRate, budget, open, gust) / #CELLS
		for _, cell in cells do
			cell.part.CFrame = CFrame.new(eye + ahead + Vector3.new(0, 30, 0) + cell.offset)
			cell.emitter.Rate = perCell
		end
		if floor then
			floor.CFrame = CFrame.new(eye.X + ahead.X, groundY + 0.15, eye.Z + ahead.Z)
		end
		if splashes then
			splashes.Rate = Weather.rate(Weather.SplashRate, budget, open, gust)
		end
		-- Olhando para o chão a lente não molha; sob telhado as gotas que já estão só terminam de escorrer.
		updateLens(now, dt, outdoor > 0.8 and look.Y > -0.55, budget)
		if sound then
			sound.Volume = base * Weather.volume(outdoor) * (0.85 + 0.15 * gust)
		end
		if muffle then
			muffle.HighGain = -28 * (1 - outdoor)
			muffle.MidGain = -8 * (1 - outdoor)
		end
		if now >= nextStrike then
			strike(now)
		end
		local fx = flashFx
		if fx then
			local amount = if Settings.get("flashes") then Weather.flash(now - strikeAt) else 0
			fx.Enabled = amount > 0
			fx.Brightness = amount * Weather.FlashPeak * (0.3 + 0.7 * outdoor)
		end
	end)
end

return controller
