--!strict
-- Efeitos locais limitados; HUD de campanha fica acima (DisplayOrder 60).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Presentation = require("@game/ReplicatedStorage/Shared/Game/ThreatPresentation")
local Create = require("../UI/Create")
local FearController = require("./FearController")
local SettingsController = require("./SettingsController")

local player = Players.LocalPlayer
local snapshot: GameState.Snapshot? = nil
local edges: { Frame } = {}
local bands: { Frame } = {}
local overlay: ScreenGui? = nil
local impact: Frame? = nil
local stamp: TextLabel? = nil
local tracking: Frame? = nil
local blur: BlurEffect? = nil
local baseFog = Lighting.FogEnd
local captureAt = -math.huge
local clock = 0
local lastEffects: { [string]: number } = {}
local rng = Random.new()

local ScreenFxController = { Name = "ScreenFxController" }

function ScreenFxController.capture()
	captureAt = os.clock()
end

function ScreenFxController.reset()
	captureAt = -math.huge
	Lighting.FogEnd = baseFog
	if blur then
		blur.Size = 0
	end
end

function ScreenFxController.debugState(): { [string]: any }
	return {
		effects = table.clone(lastEffects),
		blur = if blur then blur.Size else 0,
		fog = Lighting.FogEnd,
		baseFog = baseFog,
		impact = if impact then impact.Visible else false,
		vhs = if stamp then stamp.Visible else false,
		bands = #bands,
	}
end

function ScreenFxController.Init()
	local initialFog = Lighting:GetAttribute("BaseFogEnd")
	baseFog = if type(initialFog) == "number" then initialFog else Lighting.FogEnd
	local gui = Create("ScreenGui", {
		Name = "FearOverlay",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 55,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	overlay = gui
	local definitions: { { anchor: Vector2, position: UDim2, size: UDim2, rotation: number } } = {
		{ anchor = Vector2.new(0, 0), position = UDim2.fromScale(0, 0), size = UDim2.fromScale(0.22, 1), rotation = 0 },
		{
			anchor = Vector2.new(1, 0),
			position = UDim2.fromScale(1, 0),
			size = UDim2.fromScale(0.22, 1),
			rotation = 180,
		},
		{
			anchor = Vector2.new(0, 0),
			position = UDim2.fromScale(0, 0),
			size = UDim2.fromScale(1, 0.22),
			rotation = 90,
		},
		{
			anchor = Vector2.new(0, 1),
			position = UDim2.fromScale(0, 1),
			size = UDim2.fromScale(1, 0.22),
			rotation = 270,
		},
	}
	for i, definition in definitions do
		local edge = Create("Frame", {
			Name = `FearEdge{i}`,
			AnchorPoint = definition.anchor,
			Position = definition.position,
			Size = definition.size,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 1,
			Parent = gui,
		}, { Create("UIGradient", { Rotation = definition.rotation, Transparency = NumberSequence.new(0, 1) }) }) :: Frame
		table.insert(edges, edge)
	end
	-- Faixas translúcidas aproximam deslocamento/chroma; não são um shader de tela.
	for i = 1, 6 do
		local band = Create("Frame", {
			Name = `Glitch{i}`,
			BorderSizePixel = 0,
			BackgroundTransparency = 0.92,
			Visible = false,
			BackgroundColor3 = if i % 2 == 0 then Color3.fromRGB(160, 30, 30) else Color3.fromRGB(30, 160, 180),
			Size = UDim2.new(1, 4, 0, 3),
			Parent = gui,
		}) :: Frame
		table.insert(bands, band)
	end
	stamp = Create("TextLabel", {
		Name = "VHS",
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 20, 1, -30),
		Size = UDim2.fromOffset(330, 20),
		TextSize = 15,
		Font = Enum.Font.Code,
		TextColor3 = Color3.fromRGB(180, 190, 175),
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Visible = false,
		Parent = gui,
	}) :: TextLabel
	tracking = Create("Frame", {
		Name = "Tracking",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.96,
		Size = UDim2.new(1, 0, 0, 2),
		Visible = false,
		Parent = gui,
	}) :: Frame
	impact = Create("Frame", {
		Name = "CaptureImpact",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	}) :: Frame
	blur = Create("BlurEffect", { Name = "PanicBlur", Size = 0, Parent = Lighting }) :: BlurEffect
end

function ScreenFxController.Start()
	GameState.observe(function(next)
		local previous = snapshot
		snapshot = next
		if previous and next.roundId ~= previous.roundId then
			ScreenFxController.reset()
		end
	end)
	Lighting:GetAttributeChangedSignal("BaseFogEnd"):Connect(function()
		local value = Lighting:GetAttribute("BaseFogEnd")
		if type(value) == "number" then
			baseFog = value
		end
	end)
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		accumulator += dt
		clock += dt
		if accumulator < 1 / 12 then
			return
		end
		accumulator = 0
		local s = snapshot
		if not s or not overlay then
			return
		end
		local playing = Presentation.playing(s.phase, player:GetAttribute("CampaignStatus") :: string?)
		local flashes = SettingsController.get("flashes")
		local fx = Presentation.effects(FearController.get(), playing, flashes, SettingsController.get("retro"))
		lastEffects = fx
		for _, edge in edges do
			edge.BackgroundTransparency = 1 - fx.vignette
		end
		if blur then
			blur.Size = fx.blur
		end
		Lighting.FogEnd = baseFog + (math.min(baseFog, Config.Effects.DangerFogEnd) - baseFog) * fx.fog
		local elapsed = os.clock() - captureAt
		local captured = flashes and elapsed < 0.15
		local glitch = math.max(fx.glitch, if flashes and elapsed < 0.8 then 1 - elapsed / 0.8 else 0)
		for _, band in bands do
			band.Visible = glitch > 0 and rng:NextNumber() < glitch * 0.45
			band.Position = UDim2.new(0, rng:NextInteger(-3, 3), rng:NextNumber(), 0)
		end
		if impact then
			impact.Visible = captured
			impact.BackgroundTransparency = if captured then 0.45 + elapsed / 0.15 * 0.55 else 1
			impact.BackgroundColor3 = if elapsed < 0.05 then Color3.new(1, 1, 1) else Color3.fromRGB(150, 15, 15)
		end
		local vhs = SettingsController.get("vhs") and playing
		if stamp then
			stamp.Visible = vhs
			local seconds = math.max(0, math.floor(workspace:GetServerTimeNow() - s.roundStartedAt))
			stamp.Text = PixelText.normalize(
				string.format("> PLAY %02d:%02d 15 OUT 1999", math.floor(seconds / 60), seconds % 60)
			)
		end
		if tracking then
			tracking.Visible = vhs and clock % 11 < 1
			tracking.Position = UDim2.fromScale(0, clock % 1)
		end
	end)
end

return ScreenFxController
