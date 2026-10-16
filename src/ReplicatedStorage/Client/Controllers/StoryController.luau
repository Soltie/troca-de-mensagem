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
	local objective = text("NarrativeObjective", 0.17, 0.08)
	local revelation = text("RecoveredRecording", 0.72, 0.13)
	objective.Position = UDim2.fromOffset(330, 126)
	objective.Size = UDim2.new(1, -350, 0, 72)
	revelation.Position = UDim2.new(0, 460, 0.66, 0)
	revelation.Size = UDim2.new(1, -480, 0.24, 0)
	local subtitleGui = Create("ScreenGui", {
		Name = "StorySubtitles",
		Parent = player.PlayerGui,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 122,
		Enabled = false,
	}) :: ScreenGui
	local subtitle = Create("TextLabel", {
		Name = "Caption",
		Parent = subtitleGui,
		Position = UDim2.fromScale(0.04, 0.89),
		Size = UDim2.fromScale(0.71, 0.1),
		BackgroundTransparency = 1,
		TextColor3 = Color3.fromRGB(230, 216, 180),
		Font = Enum.Font.Code,
		TextSize = 18,
		Text = "",
		TextWrapped = true,
	}) :: TextLabel
	local previous = ""
	local lastSolved = 0
	local revealUntil = 0
	local lastLine = 0
	RunService:BindToRenderStep("S9Story", Enum.RenderPriority.Camera.Value - 1, function()
		local active = state:GetAttribute("GameMode") == "Story" and state:GetAttribute("Phase") ~= "Lobby"
		gui.Enabled = active
		subtitleGui.Enabled = false
		if not active then
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
		local start = (state:GetAttribute("StorySceneStartedAt") or 0) :: number
		local key = `{state:GetAttribute("StorySceneSerial")}:{stage}`
		if endsAt > now and key ~= previous then
			previous, lastSolved, lastLine = key, 0, 0
			Cinema.play(Story.Scenes[stage])
			Transition.title(
				string.format("CAPÍTULO %02d", stage),
				string.match(chapter.title, "·%s*(.+)") or chapter.title
			)
			Transition.caption(nil)
		end
		if endsAt > now and player:GetAttribute("CinematicActive") == true then
			subtitleGui.Enabled = true
			local index = math.clamp(math.floor((now - start) / 4) + 1, 1, 3)
			if index ~= lastLine then
				lastLine = index
				subtitle.Text = Story.SceneLines[stage][index]
			end
		end
		local phase = tostring(state:GetAttribute("Phase"))
		local solved = (state:GetAttribute("Solved") or 0) :: number
		if solved > lastSolved then
			revelation.Text = chapter.objectives[solved].revelation
			revealUntil = now + 10
		end
		lastSolved = solved
		local nextObjective = chapter.objectives[math.min(#chapter.objectives, solved + 1)]
		objective.Text = if phase == "Won"
			then "O ÚLTIMO TURNO / CONCLUÍDO"
			elseif phase == "Lost" then "A GRAVAÇÃO FOI INTERROMPIDA / [R] VOTAR VOLTA AO MENU"
			elseif phase == "Extracting" then "CIRCUITO ISOLADO / REÚNAM A EQUIPE NO PORTÃO"
			elseif phase == "Intermission" then "GRAVAÇÃO RECUPERADA / PRÓXIMO CAPÍTULO"
			else `{chapter.title}\n{nextObjective.title}`
		if phase == "Won" then
			revelation.Text = Story.Ending
		end
		revelation.Visible = phase == "Won" or now < revealUntil
		objective.Visible = player:GetAttribute("CinematicActive") ~= true
		if endsAt <= now and phase == "Playing" and string.sub(Cinema.debugState().sequence, 1, 5) == "Story" then
			Cinema.stop()
		end
	end)
end
return Controller
