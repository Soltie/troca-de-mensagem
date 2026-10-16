--!strict
-- Executa o diretor puro. Eventos são locais, canceláveis e nunca movem colisores do servidor.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Director = require("@game/ReplicatedStorage/Shared/Game/TensionDirector")
local Presentation = require("@game/ReplicatedStorage/Shared/Game/ThreatPresentation")
local Audio = require("./AudioController")
local Fear = require("./FearController")
local Flashlight = require("./FlashlightController")
local Settings = require("./SettingsController")
local WorldFx = require("./WorldFxController")

local player = Players.LocalPlayer
local rng = Random.new()
local director = Director.new(function()
	return rng:NextNumber()
end, os.clock())
local snapshot: GameState.Snapshot? = nil
local generation = 0
local effects: Folder? = nil
local hiddenParts: { [BasePart]: number } = {}
local sounds: { Sound } = {}
local running = false
local eventCounts: { [string]: number } = {}
local lastWarning = 0
local visualsCreated = 0

local function cleanup()
	generation += 1
	for part, previous in hiddenParts do
		if part.Parent then
			part.LocalTransparencyModifier = previous
		end
	end
	table.clear(hiddenParts)
	for _, sound in sounds do
		if sound.Parent then
			sound:Destroy()
		end
	end
	table.clear(sounds)
	if effects then
		effects:Destroy()
		effects = nil
	end
end

local function rootPart(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

local function context(): Director.Context
	local s = snapshot
	local camera = workspace.CurrentCamera
	local root = rootPart()
	local status = player:GetAttribute("CampaignStatus") :: string?
	local mode = Presentation.mode(
		if root then (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant" else "Dormant",
		if root then root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number? else nil,
		player.UserId,
		status
	)
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	local progress = if s then math.min(4, s.fusesCollected + (if s.powerOn then 1 else 0)) else 0
	if campaign then
		local stage = (campaign:GetAttribute("Stage") :: number?) or 0
		local solved = (campaign:GetAttribute("Solved") :: number?) or 0
		progress = math.clamp(stage - 1 + (if solved > 0 then 1 else 0), 0, 4)
	end
	return {
		now = os.clock(),
		playing = s ~= nil and Presentation.playing(s.phase, status),
		creatureActive = root ~= nil and root:GetAttribute(Tags.Attr.CreatureActive) == true,
		creatureMode = mode,
		creatureDistance = if root and camera then (root.Position - camera.CFrame.Position).Magnitude else math.huge,
		fear = Fear.get(),
		darkness = Fear.darkness(),
		zone = Audio.zone(),
		progress = progress,
		hidden = type(player:GetAttribute("Hidden")) == "string" and player:GetAttribute("Hidden") ~= "",
	}
end

local function soundAt(name: string, position: Vector3, volume: number?, speed: number?)
	table.insert(sounds, Audio.playAtPosition(name, position, volume, speed))
end

local function parameters(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, member in Players:GetPlayers() do
		if member.Character then
			table.insert(exclude, member.Character)
		end
	end
	for _, name in { Tags.CreatureModel, "VigiaVisual", "TensionLocal" } do
		local instance = workspace:FindFirstChild(name)
		if instance then
			table.insert(exclude, instance)
		end
	end
	params.FilterDescendantsInstances = exclude
	return params
end

local function apparition(name: string, token: number)
	local camera = workspace.CurrentCamera
	if not camera or not effects then
		return
	end
	local eyes = name == "eyes"
	local angle = math.rad(
		if eyes then rng:NextNumber(-10, 10) else rng:NextNumber(35, 55) * (if rng:NextNumber() < 0.5 then -1 else 1)
	)
	local position = (camera.CFrame * CFrame.Angles(0, angle, 0) * CFrame.new(0, 0, -rng:NextNumber(18, 26))).Position
	if workspace:Raycast(camera.CFrame.Position, position - camera.CFrame.Position, parameters()) then
		return
	end
	local figure = Instance.new("Model")
	figure.Name = name
	figure.Parent = effects
	visualsCreated += 1
	for i = 1, 2 do
		local part = Instance.new("Part")
		part.Name = if eyes then "Eye" else "Silhouette"
		part.Size = if eyes
			then Vector3.new(0.12, 0.12, 0.12)
			else (if i == 1 then Vector3.new(1.5, 4.8, 0.7) else Vector3.new(1, 1.3, 0.8))
		part.Color = if eyes then Color3.fromRGB(140, 155, 100) else Color3.new(0.02, 0.02, 0.02)
		part.Material = if eyes then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.CFrame = CFrame.new(
			position
				+ (
					if eyes
						then Vector3.new((i - 1.5) * 0.55, 0, 0)
						else Vector3.new(0, if i == 1 then -1.3 else 1.7, 0)
				)
		)
		part.Parent = figure
	end
	if not eyes then
		Fear.spike(0.12)
	end
	local untilAt = os.clock() + (if eyes then 2.2 else 0.7)
	while token == generation and os.clock() < untilAt do
		local current = workspace.CurrentCamera
		if not current then
			break
		end
		local direction = position - current.CFrame.Position
		if direction.Magnitude < 0.1 then
			break
		end
		local aligned = current.CFrame.LookVector:Dot(direction.Unit)
		if aligned > math.cos(math.rad(if eyes then 12 else 15)) and (not eyes or Flashlight.isOn()) then
			break
		end
		task.wait(0.05)
	end
	figure:Destroy()
end

local function moveVisual(name: string, token: number)
	local camera = workspace.CurrentCamera
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	local folder = world and world:FindFirstChild(if name == "door_twitch" then "Doors" else "Props")
	if not camera or not folder or not effects then
		return
	end
	local count = 0
	for _, item in folder:GetDescendants() do
		if not item:IsA("BasePart") then
			continue
		end
		local distance = (item.Position - camera.CFrame.Position).Magnitude
		local _, onScreen = camera:WorldToViewportPoint(item.Position)
		local door = name == "door_twitch"
			and string.sub(item.Name, 1, 5) == "door_"
			and item:GetAttribute("DoorState") == "closed"
		local small = name ~= "door_twitch" and item.Size.Magnitude < 3.5 and not item:FindFirstChildWhichIsA("Light")
		if distance > (if door then 20 else 14) or not (door or small) or (name == "object_shift" and onScreen) then
			continue
		end
		local clone = item:Clone()
		clone:ClearAllChildren()
		for _, tag in CollectionService:GetTags(clone) do
			CollectionService:RemoveTag(clone, tag)
		end
		clone.Anchored = true
		clone.CanCollide = false
		clone.CanQuery = false
		clone.CanTouch = false
		clone.LocalTransparencyModifier = 0
		clone.Parent = effects
		visualsCreated += 1
		hiddenParts[item] = item.LocalTransparencyModifier
		item.LocalTransparencyModifier = 1
		local base = item.CFrame
		local started = os.clock()
		while token == generation and os.clock() - started < 1.2 and item.Parent and item.CFrame == base do
			local elapsed = os.clock() - started
			clone.CFrame = if name == "object_shift"
				then base * CFrame.new(0.6, 0, 0) * CFrame.Angles(0, math.rad(15), 0)
				elseif door then base * CFrame.Angles(0, math.sin(elapsed * 8) * math.rad(2), 0)
				else base * CFrame.new(math.sin(elapsed * 40) * 0.035, 0, 0)
			task.wait(1 / 30)
		end
		if item.Parent and hiddenParts[item] ~= nil then
			item.LocalTransparencyModifier = hiddenParts[item]
		end
		hiddenParts[item] = nil
		clone:Destroy()
		count += 1
		if count >= 1 then
			break
		end
	end
	if count > 0 then
		soundAt("DoorRattle", camera.CFrame.Position, 0.25)
	end
end

local function perform(name: string, token: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	eventCounts[name] = (eventCounts[name] or 0) + 1
	local origin = camera.CFrame.Position
	if name == "flicker" or name == "false_alarm" then
		if Settings.get("flashes") then
			WorldFx.surge(1.2, origin, 18)
			Flashlight.flicker(1)
		end
		if name == "false_alarm" then
			soundAt("Snarl", origin - camera.CFrame.LookVector * 30, 0.5)
		end
	elseif name == "distant_steps" then
		local position = origin - camera.CFrame.LookVector * 30
		-- Busca um ponto atrás de obstáculo para não representar o Vigia à vista.
		local hit = workspace:Raycast(origin, position - origin, parameters())
		if not hit then
			return
		end
		for _ = 1, 5 do
			if token ~= generation then
				return
			end
			soundAt("CreatureStep", position, 0.45, 0.55)
			task.wait(0.5)
		end
	elseif name == "radio_static" then
		local world = workspace:FindFirstChild(Tags.WorldFolder)
		local features = world and world:FindFirstChild("Features")
		local radio = features and features:FindFirstChild("GuardRadio")
		local body = radio and radio:FindFirstChild("Radio")
		if body and body:IsA("BasePart") then
			soundAt("RadioStatic", body.Position, 0.65)
		end
		local led = radio and radio:FindFirstChild("Led")
		if led and led:IsA("BasePart") then
			hiddenParts[led] = led.LocalTransparencyModifier
			local untilAt = os.clock() + 1.8
			while token == generation and led.Parent and os.clock() < untilAt do
				led.LocalTransparencyModifier = if math.floor(os.clock() * 8) % 2 == 0 then 0 else 0.85
				task.wait(0.125)
			end
			if led.Parent and hiddenParts[led] ~= nil then
				led.LocalTransparencyModifier = hiddenParts[led]
			end
			hiddenParts[led] = nil
		end
	elseif name == "whisper" then
		table.insert(sounds, Audio.play("Whisper", 0.3))
	elseif name == "silhouette" or name == "eyes" then
		apparition(name, token)
	elseif name == "vibrate" or name == "door_twitch" or name == "object_shift" then
		moveVisual(name, token)
	end
end

local function schedule(name: string, silence: boolean)
	cleanup()
	local token = generation
	local folder = Instance.new("Folder")
	folder.Name = "TensionLocal"
	folder.Parent = workspace
	effects = folder
	if silence then
		Audio.silence(Config.Tension.SilenceBefore)
	end
	task.spawn(function()
		if silence then
			task.wait(Config.Tension.SilenceBefore)
		end
		local ctx = context()
		if
			token ~= generation
			or not ctx.playing
			or ctx.hidden
			or ctx.creatureMode == "Chase"
			or ctx.creatureMode == "Capture"
		then
			if token == generation then
				cleanup()
			end
			return
		end
		perform(name, token)
		task.wait(Director.EVENTS[name].duration)
		if token == generation then
			cleanup()
		end
	end)
end

local Controller = { Name = "TensionController" }

-- Ferramenta local de QA: sem remote e indisponível fora do Studio.
function Controller.preview(name: string): boolean
	local ctx = context()
	if
		not RunService:IsStudio()
		or not Director.EVENTS[name]
		or not ctx.playing
		or ctx.hidden
		or ctx.creatureMode == "Chase"
		or ctx.creatureMode == "Capture"
	then
		return false
	end
	schedule(name, false)
	return true
end

function Controller.debugState(): { [string]: any }
	return {
		state = director.state,
		log = table.clone(director.log),
		events = table.clone(eventCounts),
		generation = generation,
		visualsCreated = visualsCreated,
		active = running,
		localParts = if effects then #effects:GetDescendants() else 0,
	}
end

function Controller.Start()
	GameState.observe(function(next)
		local previous = snapshot
		snapshot = next
		if not previous or next.roundId ~= previous.roundId or next.phase == "Intro" and previous.phase ~= "Intro" then
			cleanup()
			Director.reset(director, os.clock())
		elseif next.creatureActive and not previous.creatureActive then
			Director.notify(director, os.clock(), "awaken", 3)
		end
	end)
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		if accumulator < Config.Tension.TickInterval then
			return
		end
		local step = math.min(accumulator, 1)
		accumulator = 0
		local ctx = context()
		local active = ctx.playing and not ctx.hidden and ctx.creatureMode ~= "Chase" and ctx.creatureMode ~= "Capture"
		if running and not active then
			cleanup()
		end
		running = active
		local decision = Director.step(director, ctx, step)
		local music: Audio.MusicState = if not ctx.playing
			then "none"
			elseif decision.state == "Chase" then "chase"
			elseif decision.state == "Recovery" then "relief"
			elseif decision.state == "Tension" then "tension"
			else "calm"
		Audio.setMusicState(music)
		if decision.event then
			schedule(decision.event, decision.silence)
		end
		if active and ctx.creatureActive and ctx.creatureDistance < 18 and ctx.now - lastWarning > 6 then
			lastWarning = ctx.now
			local camera = workspace.CurrentCamera
			WorldFx.surge(0.3, if camera then camera.CFrame.Position else nil, 18)
		end
	end)
end

return Controller
