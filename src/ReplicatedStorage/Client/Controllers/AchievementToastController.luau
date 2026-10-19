--!strict
--[[
	Aviso de conquista (DifficultyService publica AchievementToast = "id:serial"): faixa no topo da tela por alguns
	segundos, com som de moeda. Respeita a opção de movimento (sem deslizar se estiver desligada).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Achievements = require("@game/ReplicatedStorage/Shared/Game/Achievements")
local Components = require("../UI/Components")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local AudioController = require("./AudioController")
local SettingsController = require("./SettingsController")

local Controller = {
	Name = "AchievementToastController",
}

local SHOW = 3.6

function Controller.Start()
	local player = Players.LocalPlayer
	local gui = Create("ScreenGui", {
		Name = "AchievementToast",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 40,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local banner = Create("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -90),
		Size = UDim2.fromOffset(420, 64),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}) :: Frame
	Components.corner(banner, Theme.CornerLarge)
	Components.stroke(banner, Theme.Gold, 2, 0.1)
	Components.text({
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 18),
		FontFace = Theme.FontBody,
		TextSize = 12,
		TextColor3 = Theme.Gold,
		Text = "★ CONQUISTA DESBLOQUEADA",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})
	local title = Components.text({
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 0, 30),
		FontFace = Theme.Font,
		TextSize = 22,
		TextColor3 = Theme.TextPrimary,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})
	local serial = 0
	player:GetAttributeChangedSignal("AchievementToast"):Connect(function()
		local raw = player:GetAttribute("AchievementToast")
		local id = if type(raw) == "string" then string.match(raw, "^([%w_]+):") else nil
		local achievement = id and Achievements.get(id)
		if not achievement then
			return
		end
		serial += 1
		local mine = serial
		title.Text = achievement.title
		banner.Visible = true
		pcall(AudioController.play, "Coin", 0.9, 0.9, true)
		local shown = UDim2.new(0.5, 0, 0, 18)
		local hidden = UDim2.new(0.5, 0, 0, -90)
		if SettingsController.motionEnabled() then
			banner.Position = hidden
			TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Position = shown }):Play()
		else
			banner.Position = shown
		end
		task.delay(SHOW, function()
			if mine ~= serial then
				return
			end
			if SettingsController.motionEnabled() then
				TweenService:Create(banner, TweenInfo.new(0.3), { Position = hidden }):Play()
				task.wait(0.32)
			end
			if mine == serial then
				banner.Visible = false
			end
		end)
	end)
end

return Controller
