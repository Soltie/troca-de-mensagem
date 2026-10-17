--!strict
-- Usa a câmera/cenas do outro controller; não cria um segundo compositor de câmera.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Create = require("../UI/Create")
local Cinema = require("./CinematicController")
local Transition = require("./TransitionController")

local Controller = { Name = "StoryController" }
local player = Players.LocalPlayer
function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState")
	local gui = Create("ScreenGui", {
		Name = "StoryUi",
		Parent = player:WaitForChild("PlayerGui"),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 65,
		Enabled = false,
	}) :: ScreenGui
	local function text(name: string, y: number, height: number): TextLabel
		return Create("TextLabel", {
			Name = name,
			Parent = gui,
			Position = UDim2.fromScale(0.17, y),
			Size = UDim2.fromScale(0.66, height),
			BackgroundColor3 = Color3.fromRGB(8, 14, 16),
			BackgroundTransparency = 0.12,
			TextColor3 = Color3.fromRGB(230, 216, 180),
			Font = Enum.Font.Code,
			TextSize = 17,
			Text = "",
			TextWrapped = true,
			BorderSizePixel = 0,
		}) :: TextLabel
	end
	local revelation = text("RecoveredRecording", 0.72, 0.13)
	-- Objetivo unificado no CampaignUi; aqui ficam somente gravações e cenas.
	revelation.AnchorPoint = Vector2.new(0.5, 1)
	revelation.Position = UDim2.new(0.5, 0, 1, -150)
	revelation.Size = UDim2.new(0.78, 0, 0, 84)
	revelation.TextScaled = true
	Create("UITextSizeConstraint", { Parent = revelation, MinTextSize = 14, MaxTextSize = 17 })
	local endingAt = 0
	local ending = text("Continues", 0, 1)
	ending.Position, ending.Size = UDim2.fromScale(0, 0), UDim2.fromScale(1, 1)
	ending.BackgroundColor3, ending.BackgroundTransparency, ending.TextSize = Color3.new(0, 0, 0), 0, 32
	ending.Text, ending.Visible = "FIM\n\nO resgate chegou. Vocês escaparam.", false
	local previous = ""
	local lastSolved = 0
	local revealUntil = 0
	RunService:BindToRenderStep("S9Story", Enum.RenderPriority.Camera.Value - 1, function()
		local active = state:GetAttribute("GameMode") == "Story" and state:GetAttribute("Phase") ~= "Lobby"
		gui.Enabled = active and player:GetAttribute("CinematicActive") ~= true
		ending.Visible = false
		if not active then
			endingAt = 0
			previous, lastSolved = "", 0
			return
		end
		local stage = (state:GetAttribute("Stage") or 0) :: number
		local chapter = Story.Chapters[stage]
		if not chapter then
			return
		end
		local now = workspace:GetServerTimeNow()
		local endsAt = (state:GetAttribute("StorySceneEndsAt") or 0) :: number
		local key = `{state:GetAttribute("StorySceneSerial")}:{stage}`
		if endsAt > now and key ~= previous then
			previous, lastSolved = key, 0
			revealUntil = 0
			Cinema.play(Story.Scenes[stage])
			Transition.caption(nil)
		end
		local phase = tostring(state:GetAttribute("Phase"))
		local solved = (state:GetAttribute("Solved") or 0) :: number
		if solved > lastSolved then
			revelation.Text = chapter.objectives[solved].revelation
			revealUntil = now + 10
		end
		lastSolved = solved
		if phase == "Won" then
			if endingAt == 0 then
				endingAt = now
			end
			ending.Visible = now - endingAt >= 12
			local remaining = math.max(0, math.ceil((tonumber(state:GetAttribute("LobbyReturnAt")) or now) - now))
			ending.Text = `FIM\n\nO resgate chegou. Vocês escaparam.\nVoltando ao lobby com a equipe em {remaining}s`
			ending.TextSize = 24
			revelation.Text = Story.Ending
		end
		revelation.Visible = not ending.Visible
			and (phase == "Won" or ((phase == "Playing" or phase == "Extracting") and now < revealUntil))
			and player:GetAttribute("FieldGuideOpen") ~= true
		if endsAt <= now and phase == "Playing" and string.sub(Cinema.debugState().sequence, 1, 5) == "Story" then
			Cinema.stop()
		end
	end)
end
return Controller
