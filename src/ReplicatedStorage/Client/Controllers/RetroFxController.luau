--!strict
--[[
	"Filtro retrô" (o Roblox não tem shader de tela nem pixelização de render, validado):
	- Gradação, bloom e exposição são compostos somente pelo LightingController.
	- Sobreposição 2D (scanlines, vinheta, granulação animada a 12 quadros/s e uma "linha de
	  tracking" ocasional): liga/desliga com V (conforto).
]]

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

local function edge(
	parent: Instance,
	anchor: Vector2,
	position: UDim2,
	size: UDim2,
	rotation: number,
	transparency: number?
)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BackgroundTransparency = transparency or 0.36
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
	edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.16, 1), 0)
	edge(gui, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.16, 1), 180)
	edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.14), 90)
	edge(gui, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.14), 270)

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

-- Vinheta suave sempre ligada (item 13 do ambiente): bordas e cantos escurecem de leve, o centro fica limpo para
-- objetivos e lanterna. Fica abaixo do HUD e do filtro retrô; com o retrô ligado, a vinheta dele substitui esta.
local cinema: ScreenGui? = nil
local function buildCinema(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "CinemaVignette"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Enabled = not SettingsController.get("retro")
	edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(0.24, 1), 0, 0.5)
	edge(gui, Vector2.new(1, 0), UDim2.fromScale(1, 0), UDim2.fromScale(0.24, 1), 180, 0.5)
	edge(gui, Vector2.new(0, 0), UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), 90, 0.55)
	edge(gui, Vector2.new(0, 1), UDim2.fromScale(0, 1), UDim2.fromScale(1, 0.2), 270, 0.55)
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local RetroFxController = {
	Name = "RetroFxController",
}

function RetroFxController.Init()
	overlay = buildOverlay()
	cinema = buildCinema()
end

function RetroFxController.Start()
	SettingsController.onChanged(function(key, value)
		if key == "retro" and overlay then
			overlay.Enabled = value
		end
		if key == "retro" and cinema then
			cinema.Enabled = not value
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
		local budget = SettingsController.visualBudget()
		for index, dot in grain do
			dot.Visible = index <= math.floor(#grain * budget.grain)
			if not dot.Visible then
				continue
			end
			dot.Position = UDim2.fromScale(rng:NextNumber(), rng:NextNumber())
			local light = rng:NextNumber() < 0.5
			dot.BackgroundColor3 = if light then Color3.new(1, 1, 1) else Color3.new(0, 0, 0)
			dot.BackgroundTransparency = math.clamp(rng:NextNumber(0.88, 0.98) - FearController.get() * 0.06, 0.8, 1)
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
