--!strict
--[[
	Avisos antes do perigo (estilo DOORS): o Tung Tung nunca chega "do nada".
	- No mesmo andar, conforme ele se aproxima: as luzes em volta falham forte (apagam e estouram), a tela treme cada
	  vez mais, a lanterna engasga e o "TUM" do bastão ecoa mais rápido. Perto demais = hora de se esconder.
	- Em outro andar, logo acima ou abaixo de você: o teto/piso range, cai poeira e a câmera dá um tranco leve.
	- Quando ele vai embora depois de um aviso forte: as luzes voltam e você solta o ar.
	Tudo só no cliente; respeita as opções de conforto (flashes e tremor).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local FlashlightController = require("./FlashlightController")

local WorldFxController = require("./WorldFxController")

local player = Players.LocalPlayer

local ThreatWarningController = {
	Name = "ThreatWarningController",
}

local NEAR = 48 -- começa a avisar
local CLOSE = 12 -- aviso no máximo
local LIGHT_RADIUS = 45

local level = 0
local peak = 0
local lastDistance: number? = nil
local closing = 0
local nextKnockAt = 0
local nextFlickerAt = 0
local nextDustAt = 0
local phase: GameState.Phase = "Loading"
local rng = Random.new()

local function creatureRoot(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

-- Poeira caindo do teto logo acima da câmera (ele está no andar de cima).
local function dust(camera: Camera)
	local part = Instance.new("Part")
	part.Name = "CeilingDust"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(6, 0.2, 6)
	part.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 3 + Vector3.new(0, 5, 0))
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(150, 140, 125))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.4) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(1.2, 2)
	emitter.Speed = NumberRange.new(0.5, 1.5)
	emitter.Acceleration = Vector3.new(0, -4, 0)
	emitter.SpreadAngle = Vector2.new(20, 20)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(45)
	task.delay(3, function()
		part:Destroy()
	end)
end

-- Vinheta vermelha escura pulsando a cada batida do coração (sincronizada com o laço Heartbeat do AudioController).
local edges: { Frame } = {}
local edgeGui: ScreenGui? = nil
local beatPhase = 0

local function buildEdges()
	local gui = Instance.new("ScreenGui")
	gui.Name = "ThreatPulse"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -3
	gui.Enabled = false
	for _, spec in
		{
			{ size = UDim2.fromScale(1, 0.28), pos = UDim2.fromScale(0, 0), rot = 90 },
			{ size = UDim2.fromScale(1, 0.28), pos = UDim2.fromScale(0, 0.72), rot = -90 },
			{ size = UDim2.fromScale(0.22, 1), pos = UDim2.fromScale(0, 0), rot = 0 },
			{ size = UDim2.fromScale(0.22, 1), pos = UDim2.fromScale(0.78, 0), rot = 180 },
		}
	do
		local frame = Instance.new("Frame")
		frame.Size, frame.Position = spec.size, spec.pos
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.fromRGB(120, 8, 10)
		frame.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rot
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(edges, frame)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	edgeGui = gui
end

-- 96 bpm × velocidade do laço; a borda acende na batida e apaga rápido.
local function pulse(dt: number)
	local gui = edgeGui
	if not gui then
		return
	end
	if level <= 0.05 then
		gui.Enabled = false
		return
	end
	local bps = 96 / 60 * AudioController.heartbeatSpeed()
	beatPhase = (beatPhase + dt * bps) % 1
	local hit = (1 - beatPhase) ^ 4
	gui.Enabled = true
	for _, frame in edges do
		frame.BackgroundTransparency = 1 - level * (0.12 + 0.45 * hit)
	end
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local tung = creatureRoot()
	local active = phase == "Playing"
		and player:GetAttribute("CinematicActive") ~= true
		and player:GetAttribute("CampaignStatus") == "Active"
	local target = 0
	local mode = tung and tung:GetAttribute("Mode")
	if active and camera and body and body:IsA("BasePart") and tung and mode ~= "Dormant" and mode ~= nil then
		local offset = tung.Position - body.Position
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local distance = offset.Magnitude
		if lastDistance then
			closing += (((lastDistance - distance) / math.max(dt, 1e-3)) - closing) * math.min(1, dt * 4)
		end
		lastDistance = distance
		local now = os.clock()
		if math.abs(offset.Y) < 9 then
			target = math.clamp((NEAR - distance) / (NEAR - CLOSE), 0, 1)
			if mode == "Chase" then
				target = math.max(target, math.clamp((70 - distance) / 50, 0, 1))
			end
			if closing > 3 and distance < NEAR + 10 then
				target = math.min(1, target + 0.15)
			end
		elseif flat < 22 and math.abs(offset.Y) < 26 and now >= nextDustAt then
			-- Logo acima/abaixo: o teto range e cai poeira.
			nextDustAt = now + rng:NextNumber(2.2, 3.5)
			AudioController.play("CreakWood", 1, rng:NextNumber(0.55, 0.75))
			if offset.Y > 0 then
				dust(camera)
			end
			CameraController.addTrauma(0.08)
		end
	else
		lastDistance = nil
		closing = 0
	end

	-- Sobe rápido e desce devagar.
	local rate = if target > level then 2.5 else 0.7
	level += (target - level) * math.min(1, dt * rate)
	if level < 0.01 then
		level = 0
	end
	peak = math.max(peak, level)

	if body and body:IsA("BasePart") then
		WorldFxController.threat(level, body.Position, LIGHT_RADIUS)
		AudioController.setThreat(level)
	else
		WorldFxController.threat(0, Vector3.zero, 0)
		AudioController.setThreat(0)
	end
	if level <= 0.05 then
		if peak > 0.6 and level == 0 then
			-- Ele foi embora: solta o ar.
			peak = 0
			AudioController.play("Breath3", 0.8, 0.85)
		end
		return
	end

	local now = os.clock()
	local hidden = player:GetAttribute("Hidden")
	local inside = type(hidden) == "string" and hidden ~= ""
	-- Tela tremendo cada vez mais forte (escondido treme menos: o armário abafa).
	if level > 0.15 then
		CameraController.addTrauma(dt * level * (if inside then 0.3 else 0.85))
	end
	-- Lanterna engasgando.
	if level > 0.4 and now >= nextFlickerAt then
		nextFlickerAt = now + rng:NextNumber(1.6, 2.8) * (1.3 - level)
		FlashlightController.flicker(0.15 + 0.25 * level)
	end
	-- "TUM" do bastão ecoando, mais rápido quanto mais perto.
	local source = creatureRoot()
	if source and level > 0.2 and now >= nextKnockAt then
		nextKnockAt = now + 3.2 - 1.6 * level
		local sound =
			AudioController.playAtPosition("DoorBang", source.Position, 0.3 + 0.3 * level, rng:NextNumber(0.6, 0.72))
		sound.RollOffMinDistance = 18
		sound.RollOffMaxDistance = 120
	end
end

function ThreatWarningController.Start()
	buildEdges()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		update(dt)
		pulse(dt)
	end)
end

-- Depuração (Studio).
function ThreatWarningController.debugState(): { [string]: any }
	return { level = level, closing = closing }
end

return ThreatWarningController
