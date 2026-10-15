--!strict
--[[
	HUD de debug construído por código (prova o padrão "UI vive no repositório").
	Outros controllers escrevem linhas com HudController.setLine(chave, texto).
	Desligue com Config.Debug.ShowHud = false.
]]

local Players = game:GetService("Players")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Create = require("../UI/Create")

local GUI_NAME = "DebugHud"

local lines: { [string]: string } = {}
local order: { string } = {}
local label: TextLabel? = nil

local function render()
	if label == nil then
		return
	end
	local parts = {}
	for _, key in order do
		table.insert(parts, lines[key])
	end
	label.Text = table.concat(parts, "\n")
end

local HudController = {
	Name = "HudController",
}

function HudController.Init()
	if not Config.Debug.ShowHud then
		return
	end
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Create("ScreenGui", {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		DisplayOrder = 100,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Topo central: o canto superior esquerdo é do chat e o direito da lista de jogadores.
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
		TextYAlignment = Enum.TextYAlignment.Top,
		Text = "",
		Parent = screenGui,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 8),
		}),
		Create("UICorner", { CornerRadius = UDim.new(0, 6) }),
	}) :: TextLabel

	HudController.setLine("title", "DEBUG HUD")
	screenGui.Parent = playerGui
end

function HudController.setLine(key: string, text: string)
	if lines[key] == nil then
		table.insert(order, key)
	end
	lines[key] = text
	render()
end

function HudController.getText(): string
	return if label then label.Text else ""
end

return HudController
