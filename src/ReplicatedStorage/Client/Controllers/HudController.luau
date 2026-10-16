--!strict
--[[
	Painel de debug construído por código (F3 alterna; padrão em Config.Debug.ShowHud).
	Mostra FPS médio, fase, estado da criatura e posição. Também expõe métricas para testes
	(HudController.metrics()).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Create = require("../UI/Create")
local CreatureVisualController = require("./CreatureVisualController")
local FearController = require("./FearController")
local TensionController = require("./TensionController")

local GUI_NAME = "DebugHud"

local label: TextLabel? = nil
local gui: ScreenGui? = nil
local frameTimes: { number } = {}
local frameIndex = 0
local SAMPLE = 120
local worstFrame = 0

local function averageFps(): number
	local count = #frameTimes
	if count == 0 then
		return 0
	end
	local total = 0
	for _, dt in frameTimes do
		total += dt
	end
	return count / total
end

local HudController = {
	Name = "HudController",
}

function HudController.Init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screenGui = Create("ScreenGui", {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		Enabled = Config.Debug.ShowHud,
	}) :: ScreenGui
	label = Create("TextLabel", {
		Name = "Info",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = Color3.fromRGB(20, 20, 24),
		BackgroundTransparency = 0.25,
		TextColor3 = Color3.fromRGB(235, 235, 235),
		FontFace = Font.fromEnum(Enum.Font.RobotoMono),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = screenGui,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
	}) :: TextLabel
	screenGui.Parent = playerGui
	gui = screenGui
end

function HudController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.F3 and gui then
			gui.Enabled = not gui.Enabled
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		frameIndex = frameIndex % SAMPLE + 1
		frameTimes[frameIndex] = dt
		worstFrame = math.max(worstFrame * 0.995, dt)
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			if label and gui and gui.Enabled then
				local ok, snapshot = pcall(GameState.snapshot)
				local shown, mode, distance = CreatureVisualController.status()
				local character = Players.LocalPlayer.Character
				local position = if character then character:GetPivot().Position else Vector3.zero
				label.Text = string.format(
					"FPS %.0f (pior %.1f ms)\nfase %s  | fusíveis %s\nvigia %s %s %.0f st\npos %.0f, %.0f, %.0f",
					averageFps(),
					worstFrame * 1000,
					if ok then snapshot.phase else "?",
					if ok then `{snapshot.fusesCollected}/{snapshot.fusesInserted}` else "?",
					if shown then "visível" else "oculto",
					mode,
					if distance < math.huge then distance else -1,
					position.X,
					position.Y,
					position.Z
				)
				local tension = TensionController.debugState()
				local lines: { string } = {}
				for i = math.max(1, #tension.log - 4), #tension.log do
					table.insert(lines, tension.log[i])
				end
				label.Text ..= string.format(
					"\nmedo %.2f | diretor %s\n%s",
					FearController.get(),
					tension.state,
					table.concat(lines, "\n")
				)
			end
		end
	end)
end

-- Métricas para validação de desempenho via MCP.
function HudController.metrics(): { [string]: number }
	local camera = workspace.CurrentCamera
	return {
		fps = averageFps(),
		worstFrameMs = worstFrame * 1000,
		viewportX = if camera then camera.ViewportSize.X else 0,
		viewportY = if camera then camera.ViewportSize.Y else 0,
	}
end

return HudController
