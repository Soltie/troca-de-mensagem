--!strict
-- Texturas compartilhadas e animação ambiente local; não altera colisão, pistas ou estado do jogo.
local AssetService = game:GetService("AssetService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Patterns = require("@game/ReplicatedStorage/Shared/Game/SurfacePatterns")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Create = require("../UI/Create")
local Settings = require("./SettingsController")

local log = Logger.new("ArtController")
local images: { [string]: EditableImage } = {}
local textures = 0
local snapshot: GameState.Snapshot? = nil
local indicators: { BasePart } = {}
local screens: { { part: BasePart, gui: SurfaceGui, label: TextLabel } } = {}
local dust: { { part: BasePart, emitter: ParticleEmitter } } = {}
local spark: ParticleEmitter? = nil
local clock = 0
local peakStep = 0
local Controller = { Name = "ArtController" }

local function makeImages()
	for index, kind in Patterns.Kinds do
		local created: EditableImage? = nil
		local ok = pcall(function()
			created = AssetService:CreateEditableImage({ Size = Vector2.new(Patterns.Size, Patterns.Size) })
			assert(created, "editable image budget unavailable")
			created:WritePixelsBuffer(
				Vector2.zero,
				Vector2.new(Patterns.Size, Patterns.Size),
				Patterns.pixels(kind, index)
			)
		end)
		if ok and created then
			images[kind] = created
		elseif created then
			created:Destroy()
		end
	end
	local count = 0
	for _ in images do
		count += 1
	end
	log.info("surface atlas ready (%d/%d); native materials remain as fallback", count, #Patterns.Kinds)
end

local function surface(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("ArtTexture") then
		return
	end
	local kind = part:GetAttribute("SurfaceStyle")
	local image = images[kind :: string]
	if not image then
		return
	end
	local faces: { Enum.NormalId }
	if part.Size.Y <= 1.1 and part.Size.X > 3 and part.Size.Z > 3 then
		faces = { Enum.NormalId.Top }
	elseif part.Name:sub(1, 5) == "Wall_" then
		faces = if part.Size.X > part.Size.Z
			then { Enum.NormalId.Front, Enum.NormalId.Back }
			else { Enum.NormalId.Left, Enum.NormalId.Right }
	else
		faces = { Enum.NormalId.Front, Enum.NormalId.Right, Enum.NormalId.Top }
	end
	for _, face in faces do
		if textures >= Config.Art.TextureLimit then
			return
		end
		local texture = Instance.new("Texture")
		texture.Name = "ArtTexture"
		texture.Face = face
		texture.StudsPerTileU = Config.Art.TextureStuds
		texture.StudsPerTileV = Config.Art.TextureStuds
		texture.OffsetStudsU = (part.Position.X % 5) * 0.3
		texture.OffsetStudsV = (part.Position.Z % 5) * 0.3
		local ok = pcall(function()
			texture.ColorMapContent = Content.fromObject(image)
		end)
		if ok then
			texture.Parent = part
			textures += 1
		else
			texture:Destroy()
		end
	end
end

local function screen(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("ArtCRT") then
		return
	end
	local gui = Create("SurfaceGui", {
		Name = "ArtCRT",
		Face = if part.Name == "DeadMonitor" then Enum.NormalId.Back else Enum.NormalId.Front,
		CanvasSize = Vector2.new(128, 96),
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		LightInfluence = 0.35,
		Brightness = 0.75,
		AlwaysOnTop = false,
		MaxDistance = Config.Art.ScreenRange,
		Active = false,
		Parent = part,
	}) :: SurfaceGui
	local label = Create("TextLabel", {
		Name = "Readout",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(9, 19, 16),
		TextColor3 = Color3.fromRGB(117, 162, 125),
		Font = Enum.Font.Code,
		TextSize = 11,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = gui,
	}) :: TextLabel
	for y = 0, 90, 6 do
		Create("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			Position = UDim2.fromOffset(0, y),
			BackgroundColor3 = Color3.new(),
			BackgroundTransparency = 0.6,
			BorderSizePixel = 0,
			Parent = gui,
		})
	end
	table.insert(screens, { part = part, gui = gui, label = label })
end

local function mote(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("ArtDust") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ArtDust"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(168, 165, 144))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.4, 0.87),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Size = NumberSequence.new(0.085)
	emitter.Rate = 1.5
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(0.1, 0.3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightInfluence = 1
	emitter.Enabled = false
	emitter.Parent = part
	table.insert(dust, { part = part, emitter = emitter })
end

local function setupSparks()
	local world = workspace:FindFirstChild("Substation9")
	local features = world and world:FindFirstChild("Features")
	local breakers = features and features:FindFirstChild("Breakers")
	local box = breakers and breakers:FindFirstChild("Box")
	if not box or not box:IsA("BasePart") then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ArtSparks"
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90))
	emitter.LightEmission = 0.6
	emitter.Size = NumberSequence.new(0.055)
	emitter.Lifetime = NumberRange.new(0.12, 0.25)
	emitter.Speed = NumberRange.new(4, 7)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Rate = 0
	emitter.Parent = box
	spark = emitter
	box:GetAttributeChangedSignal("Spark"):Connect(function()
		if box:GetAttribute("Spark") and Settings.get("flashes") and snapshot and snapshot.phase == "Playing" then
			emitter:Emit(6)
		end
	end)
	Settings.onChanged(function(key, value)
		if key == "flashes" and not value then
			emitter:Clear()
		end
	end)
end

local function step()
	local camera = workspace.CurrentCamera
	local state = snapshot
	if not camera or not state then
		return
	end
	local power = state.powerOn
	for _, part in indicators do
		if not part.Parent then
			continue
		end
		local kind = part:GetAttribute("Indicator")
		if kind == "GaugeGenerator" or kind == "GaugePump" then
			local pivot = part:GetAttribute("Pivot")
			if typeof(pivot) == "CFrame" then
				local angle = if power then -0.5 + math.sin(clock * 1.8) * 0.07 else 1.05
				part.CFrame = pivot * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.15, 0)
			end
		elseif kind == "PanelLed" then
			part.Color = if power then Color3.fromRGB(70, 175, 100) else Color3.fromRGB(125, 32, 24)
			part.Material = if power
					or not Settings.get("flashes")
					or math.floor(clock) % 2 == 0
				then Enum.Material.Neon
				else Enum.Material.SmoothPlastic
		end
	end
	for _, entry in screens do
		local near = entry.part.Parent ~= nil
			and (entry.part.Position - camera.CFrame.Position).Magnitude < Config.Art.ScreenRange
		entry.gui.Enabled = near and power
		if near and power then
			local text = " S9 / REDE LOCAL\n\n  50 Hz / 220 V\n\n  SETOR ONLINE\n  > MONITORAMENTO"
			if entry.label.Text ~= text then
				entry.label.Text = text
			end
		end
	end
	for _, entry in dust do
		entry.emitter.Enabled = entry.part.Parent ~= nil
			and (entry.part.Position - camera.CFrame.Position).Magnitude < Config.Art.DustRange
	end
end

function Controller.debugState(): { [string]: any }
	local count = 0
	for _ in images do
		count += 1
	end
	return {
		images = count,
		textureBytes = count * Patterns.Size ^ 2 * 4,
		textures = textures,
		screens = #screens,
		dust = #dust,
		indicators = #indicators,
		spark = spark ~= nil,
		peakStepMs = peakStep * 1000,
	}
end

function Controller.Start()
	GameState.observe(function(state)
		snapshot = state
	end)
	makeImages()
	for _, part in CollectionService:GetTagged("ArtSurface") do
		surface(part)
	end
	for _, part in CollectionService:GetTagged("ArtScreen") do
		screen(part)
	end
	for _, part in CollectionService:GetTagged("ArtDust") do
		mote(part)
	end
	for _, part in CollectionService:GetTagged("Indicator") do
		if part:IsA("BasePart") then
			table.insert(indicators, part)
		end
	end
	CollectionService:GetInstanceAddedSignal("ArtSurface"):Connect(surface)
	CollectionService:GetInstanceAddedSignal("ArtScreen"):Connect(screen)
	CollectionService:GetInstanceAddedSignal("ArtDust"):Connect(mote)
	setupSparks()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		clock += dt
		elapsed += dt
		if elapsed < 1 / 12 then
			return
		end
		elapsed = 0
		local started = os.clock()
		step()
		peakStep = math.max(peakStep, os.clock() - started)
	end)
end

return Controller
