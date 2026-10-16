--!strict
--[[
	"Filtro retrô" (o Roblox não tem shader de tela nem pixelização de render, validado):
	- Gradação de cor (contraste alto, saturação baixa, tom esverdeado) + bloom leve: sempre ligados,
	  fazem parte da direção de arte.
	- Sobreposição 2D (scanlines, vinheta, granulação animada a 12 quadros/s e uma "linha de
	  tracking" ocasional): liga/desliga com V (conforto).
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local SettingsController = require("./SettingsController")
local FearController = require("./FearController")

local E = Config.Effects
local player = Players.LocalPlayer

local overlay: ScreenGui? = nil
local scanlines: Frame? = nil
local grain: { Frame } = {}
local tracking: Frame? = nil
local lastHeight = 0
local rng = Random.new()

local function buildScanlines(container: Frame, height: number)
	container:ClearAllChildren()
	local spacing = E.ScanlineSpacing
	for y = 0, height, spacing do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = Color3.new(0, 0, 0)
		line.BackgroundTransparency = E.ScanlineTransparency
		line.Position = UDim2.fromOffset(0, y)
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Parent = container
	end
end

local function edge(parent: Instance, anchor: Vector2, position: UDim2, size: UDim2, rotation: number)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.AnchorPoint = anchor
	f.Position = position
	f.Size = size
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = rotation
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = f
	f.Parent = parent
end

local function buildOverlay(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "RetroOverlay"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Enabled = SettingsController.get("retro")

	-- Vinheta (4 bordas com gradiente).
	edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.2, 1), 0)
	edge(gui, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.2, 1), 180)
	edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.18), 90)
	edge(gui, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.18), 270)

	local lines = Instance.new("Frame")
	lines.Name = "Scanlines"
	lines.BackgroundTransparency = 1
	lines.Size = UDim2.fromScale(1, 1)
	lines.Parent = gui
	scanlines = lines

	for _ = 1, E.GrainDots do
		local dot = Instance.new("Frame")
		dot.BorderSizePixel = 0
		dot.Size = UDim2.fromOffset(2, 2)
		dot.Parent = gui
		table.insert(grain, dot)
	end

	local track = Instance.new("Frame")
	track.Name = "Tracking"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Color3.new(1, 1, 1)
	track.BackgroundTransparency = 0.93
	track.Size = UDim2.new(1, 0, 0, 3)
	track.Visible = false
	track.Parent = gui
	tracking = track

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function buildPostFx()
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "RetroGrade"
	grade.Contrast = 0.16
	grade.Saturation = -0.32
	grade.Brightness = -0.01
	grade.TintColor = Color3.fromRGB(214, 228, 210)
	grade.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "RetroBloom"
	bloom.Intensity = 0.5
	bloom.Size = 18
	bloom.Threshold = 1.3
	bloom.Parent = Lighting
end

local RetroFxController = {
	Name = "RetroFxController",
}

function RetroFxController.Init()
	buildPostFx()
	overlay = buildOverlay()
end

function RetroFxController.Start()
	SettingsController.onChanged(function(key, value)
		if key == "retro" and overlay then
			overlay.Enabled = value
		end
	end)

	local accumulator = 0
	local trackingY = -10
	RunService.RenderStepped:Connect(function(dt: number)
		local gui = overlay
		local camera = workspace.CurrentCamera
		if not gui or not gui.Enabled or not camera then
			return
		end
		local height = math.floor(camera.ViewportSize.Y)
		if height ~= lastHeight and scanlines then
			lastHeight = height
			buildScanlines(scanlines, height)
		end
		accumulator += dt
		if accumulator < 1 / Config.Visual.FlickerRate then
			return
		end
		accumulator = 0
		-- Granulação em passos (12 quadros/s).
		for _, dot in grain do
			dot.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
			local light = rng:NextNumber() < 0.5
			dot.BackgroundColor3 = if light then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			dot.BackgroundTransparency = math.clamp(rng:NextNumber(0.75, 0.95) - FearController.get() * 0.2, 0.4, 1)
		end
		-- Linha de tracking de VHS descendo de vez em quando.
		local track = tracking
		if track then
			if trackingY < 0 and rng:NextNumber() < 0.01 then
				trackingY = 0
			end
			if trackingY >= 0 then
				trackingY += 0.06
				track.Visible = false -- tracking VHS pertence ao ScreenFxController
				track.Position = UDim2.fromScale(0, trackingY)
				if trackingY > 1 then
					trackingY = -10
				end
			end
		end
	end)
end

return RetroFxController
