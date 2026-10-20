--!strict
--[[
	Interface do jogo, toda construída por código (estética PS1: fonte pixel, poucos tons,
	animações em passos de ~12 quadros por segundo).

	Camadas: mira + prompt, objetivo (com ícones de fusível em 2 quadros), legendas, fôlego,
	ajuda (H), introdução (cartela), bilhete, jumpscare (sprite de 2 quadros) e telas finais.
	Tudo reage ao GameState replicado pelo servidor; reiniciar = remote RequestRestart.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local AdemirPortrait = require("../Creature/AdemirPortrait")
local SettingsController = require("./SettingsController")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local STEP = 1 / 12 -- passo das animações 2D

type Refs = {
	gui: ScreenGui,
	prompt: TextLabel,
	objective: TextLabel,
	objectiveHint: TextLabel,
	fuseIcons: { Frame },
	caption: TextLabel,
	help: Frame,
	helpLines: { TextLabel },
	intro: Frame,
	introTitle: TextLabel,
	introLines: { TextLabel },
	note: Frame,
	noteText: TextLabel,
	scare: Frame,
	faces: { Frame },
	finale: Frame,
	finaleTitle: TextLabel,
	finaleSubtitle: TextLabel,
	finaleStats: TextLabel,
	restart: TextButton,
	continueButton: TextButton,
	inventory: TextLabel,
}

local refs: Refs? = nil
local snapshot: GameState.Snapshot? = nil
local noteOpen = false
local captionToken = 0
local introToken = 0
local endToken = 0
local finaleToken = 0
local objectiveToken = 0
local lastObjective = ""
local blinkOn = false

local function r(): Refs
	assert(refs, "[GameUiController] used before Init")
	return refs
end

local function label(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextSize = Theme.SizeBody,
		TextColor3 = Theme.Text,
		TextStrokeColor3 = Theme.Black,
		TextStrokeTransparency = 0.35,
		TextWrapped = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Create("TextLabel", defaults) :: TextLabel
end

-- Aviso de rodapé: texto branco maior, sem fundo, sem borda (pedido do humano: "só o texto embaixo").
local BOTTOM_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular)
local function bottomText(target: TextLabel, y: number)
	target.AnchorPoint = Vector2.new(0.5, 1)
	target.Position = UDim2.new(0.5, 0, 1, y)
	target.Size = UDim2.new(0.62, 0, 0, 56)
	target.BackgroundTransparency = 1
	target.BorderSizePixel = 0
	target.FontFace = BOTTOM_FONT
	target.TextSize = 21
	target.TextColor3 = Color3.fromRGB(240, 236, 228)
	target.TextStrokeColor3 = Color3.new(0, 0, 0)
	target.TextStrokeTransparency = 0.55
	target.TextYAlignment = Enum.TextYAlignment.Bottom
	for _, child in target:GetChildren() do
		if
			child:IsA("UIStroke")
			or child:IsA("UICorner")
			or child:IsA("UISizeConstraint")
			or child:IsA("UIPadding")
		then
			child:Destroy()
		end
	end
end

local function frame(props: { [string]: any }, children: { any }?): Frame
	local defaults: { [string]: any } = { BorderSizePixel = 0, BackgroundColor3 = Theme.Panel }
	for key, value in props do
		defaults[key] = value
	end
	return Create("Frame", defaults, children) :: Frame
end

local function stroke(color: Color3, thickness: number): Instance
	-- Border: em TextLabel/TextButton o modo padrão contornaria o TEXTO (fica borrado).
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- Rosto do Ademir em 2 quadros; compartilha a textura da cabeça 3D.
local function buildFace(parent: Instance, variant: number): Frame
	local open = variant == 2
	local face = frame({
		Name = `Face{variant}`,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + (if open then 0.012 else 0), 0.52),
		Size = UDim2.fromScale(0.36, 0.78),
		BackgroundColor3 = Theme.Skin,
		Rotation = if open then 5 else -2,
		Visible = false,
		Parent = parent,
	}, { Create("UICorner", { CornerRadius = UDim.new(0.42, 0) }) })
	local aspect = Create("UIAspectRatioConstraint", { AspectRatio = 0.72, Parent = face }) :: UIAspectRatioConstraint
	if AdemirPortrait.createImage({ Parent = face }) then
		face.BackgroundTransparency = 1
		face.Size = UDim2.fromScale(0.8, 0.98)
		aspect.AspectRatio = 1
		return face
	end
	for _, x in { 0.3, 0.7 } do
		frame({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, 0.38),
			Size = UDim2.fromScale(if open then 0.15 else 0.12, if open then 0.06 else 0.035),
			BackgroundColor3 = Color3.fromRGB(255, 244, 214),
			Parent = face,
		})
	end
	frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.58),
		Size = UDim2.fromScale(if open then 0.16 else 0.035, if open then 0.32 else 0.22),
		BackgroundColor3 = Theme.Black,
		Parent = face,
	})
	return face
end

local function build(): Refs
	local gui = Create("ScreenGui", {
		Name = "GameUi",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Mira
	frame({
		Name = "Crosshair",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Text,
		Parent = gui,
	}, { stroke(Theme.Black, 1) })
	local prompt = label({
		Name = "Prompt",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 18),
		Size = UDim2.new(0.8, 0, 0, 60),
		Text = "",
		Visible = false,
		Parent = gui,
	})
	-- Só o texto branco no rodapé (sem caixa nem moldura), no estilo do NoirHud.
	bottomText(prompt, -156)

	-- Objetivo (canto superior esquerdo)
	local objectivePanel = frame({
		Name = "Objective",
		Position = UDim2.fromOffset(20, 20),
		Size = UDim2.fromOffset(380, 74),
		BackgroundTransparency = 0.45,
		Parent = gui,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 10),
		}),
		stroke(Theme.TextDim, 1),
	})
	label({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 14),
		Text = "OBJETIVO",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Hazard,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = objectivePanel,
	})
	local objective = label({
		Name = "Text",
		Position = UDim2.fromOffset(0, 18),
		Size = UDim2.new(1, -96, 0, 34),
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = objectivePanel,
	})
	local objectiveHint = label({
		Name = "Hint",
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 14),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = objectivePanel,
	})
	local fuseIcons: { Frame } = {}
	for i = 1, 3 do
		table.insert(
			fuseIcons,
			frame({
				Name = `Fuse{i}`,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -(3 - i) * 26, 0, 20),
				Size = UDim2.fromOffset(18, 22),
				BackgroundColor3 = Theme.Panel,
				Parent = objectivePanel,
			}, { stroke(Theme.TextDim, 2) })
		)
	end

	-- Legenda (baixo, centro)
	local caption = label({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -100),
		Size = UDim2.new(0.86, 0, 0, 48),
		Text = "",
		TextSize = Theme.SizeBody,
		Visible = false,
		Parent = gui,
	})

	-- Fôlego e bateria são diegéticos (respiração/postura e LEDs da lanterna).
	-- Inventário sob demanda (segurar Tab), canto inferior esquerdo.
	local inventory = label({
		Name = "Inventory",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -20),
		Size = UDim2.fromOffset(420, 84),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Visible = false,
		Parent = gui,
	})
	label({
		Name = "HelpHint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -20),
		Size = UDim2.fromOffset(160, 16),
		Text = Text.HelpHint,
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = gui,
	})

	-- Ajuda (H)
	local help = frame({
		Name = "Help",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		Size = UDim2.fromOffset(330, 20 + #Text.Help * 20),
		BackgroundTransparency = 0.25,
		Visible = false,
		Parent = gui,
	}, {
		stroke(Theme.TextDim, 1),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingTop = UDim.new(0, 10) }),
	})
	local helpLines: { TextLabel } = {}
	for i = 1, #Text.Help do
		table.insert(
			helpLines,
			label({
				Position = UDim2.fromOffset(0, (i - 1) * 20),
				Size = UDim2.new(1, -12, 0, 18),
				TextSize = Theme.SizeSmall,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = help,
			})
		)
	end

	-- Bilhete
	local note = frame({
		Name = "Note",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 330),
		BackgroundColor3 = Theme.Paper,
		Rotation = -1.5,
		Visible = false,
		Parent = gui,
	}, {
		stroke(Theme.Ink, 2),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 26),
			PaddingRight = UDim.new(0, 26),
			PaddingTop = UDim.new(0, 24),
			PaddingBottom = UDim.new(0, 30),
		}),
	})
	local noteScroll = Create("ScrollingFrame", {
		Name = "Reading",
		Parent = note,
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}) :: ScrollingFrame
	local noteText = label({
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		FontFace = Theme.FontNote,
		TextSize = 19,
		TextColor3 = Theme.Ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = noteScroll,
	})
	local noteClose = Create("TextButton", {
		Name = "Close",
		Parent = note,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(120, 44),
		Text = "FECHAR",
		FontFace = Theme.Font,
		TextSize = 16,
		BackgroundColor3 = Theme.Panel,
		TextColor3 = Theme.Text,
		Modal = true,
	}) :: TextButton
	noteClose.Activated:Connect(function()
		note.Visible, noteOpen = false, false
		player:SetAttribute("NoteOpen", false)
	end)
	label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 18),
		Size = UDim2.fromOffset(160, 14),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Ink,
		TextStrokeTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = note,
	})

	-- Introdução (cartela preta)
	local intro = frame({
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Black,
		Visible = false,
		ZIndex = 5,
		Parent = gui,
	})
	local introTitle = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(800, 50),
		Text = Text.Title,
		TextSize = Theme.SizeTitle,
		TextColor3 = Theme.Accent,
		ZIndex = 5,
		Parent = intro,
	})
	local introLines: { TextLabel } = {}
	for i = 1, #Text.Intro do
		table.insert(
			introLines,
			label({
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0.42, (i - 1) * 30),
				Size = UDim2.fromOffset(900, 24),
				Text = "",
				ZIndex = 5,
				Parent = intro,
			})
		)
	end
	label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(900, 18),
		Text = Text.IntroControls,
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.TextDim,
		ZIndex = 5,
		Parent = intro,
	})

	-- Jumpscare
	local scare = frame({
		Name = "Scare",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Black,
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})
	local faces = { buildFace(scare, 1), buildFace(scare, 2) }

	-- Tela final
	local finale = frame({
		Name = "Finale",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Black,
		BackgroundTransparency = 0.15,
		Visible = false,
		ZIndex = 6,
		Parent = gui,
	})
	local finaleTitle = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(900, 50),
		TextSize = Theme.SizeTitle - 4,
		ZIndex = 6,
		Parent = finale,
	})
	local finaleSubtitle = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 46),
		Size = UDim2.fromOffset(900, 20),
		TextColor3 = Theme.TextDim,
		ZIndex = 6,
		Parent = finale,
	})
	local finaleStats = label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 86),
		Size = UDim2.fromOffset(900, 20),
		TextSize = Theme.SizeSmall,
		ZIndex = 6,
		Parent = finale,
	})
	local restart = Create("TextButton", {
		Name = "Restart",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 150),
		Size = UDim2.fromOffset(300, 40),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		FontFace = Theme.Font,
		Text = Text.Restart,
		TextSize = Theme.SizeBody,
		TextColor3 = Theme.Text,
		-- Modal libera o mouse da trava de primeira pessoa enquanto a tela final está aberta.
		Modal = true,
		ZIndex = 6,
		Parent = finale,
	}, { stroke(Theme.Text, 2) }) :: TextButton
	-- Continuar do checkpoint: destaque próprio, para não confundir com "reiniciar tudo".
	local continueButton = Create("TextButton", {
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.36, 150),
		Size = UDim2.fromOffset(380, 44),
		BackgroundColor3 = Theme.Hazard,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		FontFace = Theme.Font,
		Text = Text.Continue,
		TextSize = Theme.SizeBody,
		TextColor3 = Theme.Black,
		Visible = false,
		ZIndex = 6,
		Parent = finale,
	}, { stroke(Theme.Black, 2) }) :: TextButton
	-- Escala da interface pela altura da tela (base 720 px).
	local scale = Create("UIScale", { Parent = gui }) :: UIScale
	local function rescale()
		local current = workspace.CurrentCamera
		local height = if current then current.ViewportSize.Y else 720
		scale.Scale = math.clamp(height / 720, 0.75, 1.5)
	end
	rescale()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	return {
		gui = gui,
		prompt = prompt,
		objective = objective,
		objectiveHint = objectiveHint,
		fuseIcons = fuseIcons,
		caption = caption,
		inventory = inventory,
		help = help,
		helpLines = helpLines,
		intro = intro,
		introTitle = introTitle,
		introLines = introLines,
		note = note,
		noteText = noteText,
		scare = scare,
		faces = faces,
		finale = finale,
		finaleTitle = finaleTitle,
		finaleSubtitle = finaleSubtitle,
		finaleStats = finaleStats,
		restart = restart,
		continueButton = continueButton,
	}
end

local function onOff(value: boolean): string
	return if value then Text.On else Text.Off
end

local function refreshHelp()
	local ui = r()
	for i, line in ui.helpLines do
		local template = Text.Help[i]
		if string.find(template, "%s", 1, true) then
			local value = if i == 6 then SettingsController.get("retro") else SettingsController.motionEnabled()
			line.Text = string.format(template, onOff(value))
		else
			line.Text = template
		end
	end
end

local function refreshObjective(s: GameState.Snapshot)
	local ui = r()
	local key = s.objective :: string
	ui.objective.Text = (Text.Objectives :: any)[key] or ""
	if key == "fuses" then
		ui.objective.Text ..= ` ({s.fusesCollected}/{s.fusesTotal})`
	end
	if key ~= lastObjective then
		lastObjective = key
		objectiveToken += 1
		local token = objectiveToken
		ui.objective.TextColor3 = Theme.Hazard
		task.delay(0.7, function()
			if token == objectiveToken then
				ui.objective.TextColor3 = Theme.Text
			end
		end)
	end
	ui.objectiveHint.Text = if s.fusesHeld > 0 and not s.powerOn
		then string.format(Text.ObjectiveHeld, s.fusesHeld)
		else ""
	for i, icon in ui.fuseIcons do
		local uiStroke = icon:FindFirstChildOfClass("UIStroke")
		if i <= s.fusesInserted then
			icon.BackgroundColor3 = Theme.Good
		elseif i <= s.fusesCollected then
			icon.BackgroundColor3 = Theme.Hazard
		else
			icon.BackgroundColor3 = Theme.Panel
		end
		if uiStroke then
			uiStroke.Color = if i == s.fusesCollected + 1 and blinkOn then Theme.Text else Theme.TextDim
		end
	end
end

-- Escreve o texto em passos (efeito máquina de escrever a 12 quadros/s).
local function typeInto(target: TextLabel, value: string, token: number, current: () -> number)
	target.Text = ""
	local length = utf8.len(value) or #value
	local shown = 0
	while shown < length do
		if current() ~= token then
			return
		end
		shown = math.min(length, shown + 3)
		local cut = utf8.offset(value, shown + 1)
		target.Text = if cut then string.sub(value, 1, cut - 1) else value
		task.wait(STEP)
	end
end

local function playIntro(fromCheckpoint: boolean?)
	local ui = r()
	introToken += 1
	local token = introToken
	ui.intro.Visible = true
	ui.intro.BackgroundTransparency = 0
	ui.introTitle.Visible = false
	for _, line in ui.introLines do
		line.Text = ""
	end
	-- Continuar do checkpoint: cartela curta (uma linha), sem repetir a história.
	local lines = if fromCheckpoint then { Text.IntroCheckpoint } else Text.Intro
	task.spawn(function()
		task.wait(0.4)
		if token ~= introToken then
			return
		end
		ui.introTitle.Visible = true
		for i, line in ui.introLines do
			if lines[i] == nil then
				break
			end
			task.wait(0.9)
			if token ~= introToken then
				return
			end
			typeInto(line, lines[i], token, function()
				return introToken
			end)
		end
	end)
end

local function endIntro()
	local ui = r()
	introToken += 1
	local token = introToken
	task.spawn(function()
		-- Esmaece em 4 passos (stop-motion).
		for i = 1, 4 do
			if token ~= introToken then
				return
			end
			ui.intro.BackgroundTransparency = i / 4
			task.wait(STEP * 1.5)
		end
		if token == introToken then
			ui.intro.Visible = false
		end
	end)
end

local function showFinale(s: GameState.Snapshot)
	local ui = r()
	local won = s.phase == "Won"
	local texts = if won then Text.EndWon else Text.EndLost
	ui.finaleTitle.Text = texts.title
	ui.finaleTitle.TextColor3 = if won then Theme.Text else Theme.Accent
	ui.finaleSubtitle.Text = texts.subtitle
	local duration = if s.roundStartedAt > 0 then s.roundEndedAt - s.roundStartedAt else 0
	local total = math.max(0, math.floor(duration))
	ui.finaleStats.Text = string.format(
		Text.EndStats,
		string.format("%02d:%02d", total // 60, total % 60),
		s.fusesCollected,
		s.fusesTotal
	)
	-- Derrota com checkpoint: duas opções distintas. Senão, só "jogar de novo".
	local canContinue = not won and s.checkpointReady
	ui.continueButton.Visible = canContinue
	ui.restart.Text = if canContinue then Text.RestartAll else Text.Restart
	ui.restart.Position = UDim2.new(0.5, 0, 0.36, if canContinue then 204 else 150)
	ui.finale.Visible = true
	finaleToken += 1
	local token = finaleToken
	if SettingsController.motionEnabled() then
		ui.finaleSubtitle.TextTransparency = 1
		TweenService:Create(ui.finaleSubtitle, TweenInfo.new(0.4), { TextTransparency = 0 }):Play()
		task.spawn(function()
			for i = 1, 8 do
				if token ~= finaleToken or not snapshot or snapshot.phase ~= s.phase then
					return
				end
				local count = math.floor(total * i / 8)
				ui.finaleStats.Text = string.format(
					Text.EndStats,
					string.format("%02d:%02d", count // 60, count % 60),
					s.fusesCollected,
					s.fusesTotal
				)
				task.wait(STEP)
			end
		end)
	else
		ui.finaleSubtitle.TextTransparency = 0
	end
end

local function playScareThenFinale(s: GameState.Snapshot)
	local ui = r()
	endToken += 1
	local token = endToken
	task.spawn(function()
		-- O rosto 2D piscando foi aposentado: o susto de verdade é o jumpscare 3D na hora da pancada
		-- (JumpscareController). Aqui fica só um corte seco para o preto antes da tela final.
		ui.scare.Visible = true
		ui.scare.BackgroundColor3 = Theme.Black
		ui.faces[1].Visible = false
		ui.faces[2].Visible = false
		task.wait(0.8)
		if token ~= endToken then
			return
		end
		ui.scare.Visible = false
		showFinale(snapshot or s) -- snapshot mais recente (o horário de fim chega depois da fase)
	end)
end

-- mode: "full" (do zero) ou "checkpoint" (continuar depois de voltar a energia).
local function requestRestart(mode: "full" | "checkpoint")
	task.spawn(function()
		local ok, err = pcall(function()
			Remotes.clientFunction("RequestRestart", 5):InvokeServer(mode)
		end)
		if not ok then
			warn(`[GameUi] restart failed: {err}`)
		end
	end)
end

-- Legenda temporária, com pequena entrada em 2 quadros.
-- Quando a última legenda apareceu (o aviso da campanha some se uma legenda mais nova chega; veredito 20/10).
local captionShownAt = 0
-- Tela de derrota aberta: nenhuma legenda por cima dela (ContinueController).
local captionsMuted = false

local function showCaption(text: string, duration: number?)
	if text == "" or captionsMuted then
		return
	end
	local ui = r()
	captionToken += 1
	local token = captionToken
	captionShownAt = os.clock()
	task.spawn(function()
		ui.caption.Visible = true
		ui.caption.Text = text
		ui.caption.Position = UDim2.new(0.5, 0, 1, -100)
		if SettingsController.motionEnabled() then
			ui.caption.Position += UDim2.fromOffset(0, 8)
			TweenService:Create(ui.caption, TweenInfo.new(0.16), { Position = UDim2.new(0.5, 0, 1, -100) }):Play()
		end
		ui.caption.TextTransparency = 0.5
		task.wait(STEP)
		ui.caption.TextTransparency = 0
		task.wait(duration or 3)
		if token == captionToken then
			ui.caption.Visible = false
		end
	end)
end

local function onState(s: GameState.Snapshot, changed: string?)
	local previous = snapshot
	snapshot = s
	local ui = r()
	refreshObjective(s)

	local phaseChanged = previous == nil or previous.phase ~= s.phase
	if phaseChanged then
		if s.phase == "Intro" then
			endToken += 1
			ui.finale.Visible = false
			ui.scare.Visible = false
			ui.note.Visible = false
			noteOpen = false
			playIntro(s.fromCheckpoint)
		elseif s.phase == "Playing" then
			endIntro()
		elseif s.phase == "Lost" then
			ui.note.Visible = false
			noteOpen = false
			playScareThenFinale(s)
		elseif s.phase == "Won" then
			ui.note.Visible = false
			noteOpen = false
			endToken += 1
			showFinale(s)
		end
	end

	if previous and s.phase == "Playing" then
		if s.creatureActive and not previous.creatureActive then
			local house = workspace:FindFirstChild("CursedHouse")
			local forest = house and house:FindFirstChild("Forest")
			showCaption(if forest then Text.Captions.awakenForest else Text.Captions.awaken, 4)
		end
		if s.powerOn and not previous.powerOn then
			showCaption(Text.Captions.power, 5)
		end
		if s.gateOpen and not previous.gateOpen then
			showCaption(Text.Captions.gate, 4)
		end
		if s.checkpointReady and not previous.checkpointReady then
			task.delay(5.5, function()
				showCaption(Text.Hints.checkpoint, 3)
			end)
		end
	end
	if changed == "RoundEndedAt" and (s.phase == "Won" or s.phase == "Lost") and ui.finale.Visible then
		showFinale(s)
	end
end

local GameUiController = {
	Name = "GameUiController",
}

function GameUiController.Init()
	local ui = build()
	refs = ui
	-- Interações/avisos também existem no coop, cujo HUD desliga somente o painel solo.
	local shared = Create("ScreenGui", {
		Name = "InteractionUi",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 70,
		Parent = player:WaitForChild("PlayerGui"),
	})
	ui.prompt.Parent = shared
	ui.caption.Parent = shared
	ui.note.Parent = shared
	local safe = Create(
		"Frame",
		{ Name = "SafeArea", Parent = shared, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }
	) :: Frame
	ui.prompt.Parent, ui.caption.Parent, ui.note.Parent = safe, safe, safe
	RunService.RenderStepped:Connect(function()
		local size = safe.AbsoluteSize
		local touch = UserInputService.TouchEnabled
		ui.note.Size = UDim2.fromOffset(math.min(460, size.X - 24), math.min(400, size.Y - 24))
		ui.note.Rotation = if touch then 0 else -1.5
		if ui.note.Visible then
			local reading = ui.note:FindFirstChild("Reading") :: ScrollingFrame
			local bounds = game:GetService("TextService"):GetTextSize(
				ui.noteText.Text,
				19,
				Enum.Font.Gotham,
				Vector2.new(math.max(100, reading.AbsoluteSize.X - 12), 100000)
			)
			ui.noteText.Size, reading.CanvasSize =
				UDim2.new(1, -12, 0, bounds.Y + 32), UDim2.fromOffset(0, bounds.Y + 32)
		end
		if touch then
			-- Celular: acima dos botões de toque, ainda só texto.
			ui.prompt.Position = UDim2.new(0.5, 0, 1, -240)
			ui.prompt.TextSize = 18
		end
	end)
	bottomText(ui.caption, -100)
	local function visibility()
		(shared :: ScreenGui).Enabled = player:GetAttribute("CinematicActive") ~= true
			and player:GetAttribute("ComfortMenuOpen") ~= true
			and player:GetAttribute("FieldGuideOpen") ~= true
			and player:GetAttribute("TouchBackpackOpen") ~= true
	end
	player:GetAttributeChangedSignal("CinematicActive"):Connect(visibility)
	for _, key in { "ComfortMenuOpen", "FieldGuideOpen", "TouchBackpackOpen" } do
		player:GetAttributeChangedSignal(key):Connect(visibility)
	end
	visibility()
	refreshHelp()
end

function GameUiController.Start()
	local ui = r()
	GameState.observe(onState)
	local notePosition = ui.note.Position
	ui.note:GetPropertyChangedSignal("Visible"):Connect(function()
		if not ui.note.Visible then
			ui.note.Position = notePosition
		end
	end)
	local function cinematicChanged()
		local active = player:GetAttribute("CinematicActive") == true
		-- Solo: a cena fica limpa (objetivo/legendas somem). No coop o CampaignController já esconde esta tela.
		if not Config.Campaign.Enabled then
			ui.gui.Enabled = not active
		end
		if active then
			ui.intro.Visible = false
			ui.finale.Visible = false
		elseif snapshot and (snapshot.phase == "Won" or snapshot.phase == "Lost") then
			showFinale(snapshot)
		end
	end
	player:GetAttributeChangedSignal("CinematicActive"):Connect(cinematicChanged)
	cinematicChanged()

	ui.restart.Activated:Connect(function()
		requestRestart("full")
	end)
	ui.continueButton.Activated:Connect(function()
		requestRestart("checkpoint")
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local s = snapshot
		if input.KeyCode == Enum.KeyCode.R and s and (s.phase == "Won" or s.phase == "Lost") then
			requestRestart("full")
		elseif input.KeyCode == Enum.KeyCode.C and s and s.phase == "Lost" and s.checkpointReady then
			requestRestart("checkpoint")
		elseif input.KeyCode == Enum.KeyCode.H then
			ui.help.Visible = not ui.help.Visible
			refreshHelp()
		end
	end)

	SettingsController.onChanged(function(key, value)
		refreshHelp()
		local template = if key == "retro" then Text.SettingRetro else Text.SettingMotion
		showCaption(string.format(template, onOff(value)), 2)
	end)

	-- Atualizações em passos: piscar dos ícones, fôlego, lanterna.
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		accumulator += dt
		if accumulator < STEP then
			return
		end
		accumulator = 0
		blinkOn = (os.clock() * 2) % 2 < 1
		local s = snapshot
		if s then
			refreshObjective(s)
		end
		-- Inventário: só enquanto segura Tab, durante a rodada.
		local showInventory = s ~= nil
			and (s.phase == "Playing" or s.phase == "Intro")
			and UserInputService:IsKeyDown(Enum.KeyCode.Tab)
		ui.inventory.Visible = showInventory
		if showInventory and s then
			local battery = player:GetAttribute("Battery")
			local percent = math.floor((if type(battery) == "number" then battery else 0) * 100 + 0.5)
			ui.inventory.Text = table.concat({
				Text.Inventory.title,
				string.format(Text.Inventory.fuses, s.fusesHeld, s.fusesInserted, s.fusesTotal),
				if s.hasKey then Text.Inventory.key else Text.Inventory.noKey,
				string.format(Text.Inventory.battery, percent),
			}, "\n")
		end
	end)
end

function GameUiController.setPrompt(text: string?)
	local ui = r()
	if text and UserInputService.TouchEnabled then
		if (player:GetAttribute("Hidden") or "") ~= "" then
			text = "Toque SAIR · Segure O AR para prender a respiração"
				.. (if player:GetAttribute("HoldBreath") == true then "\nPRENDENDO O AR..." else "")
		else
			text = text:gsub("%[E%]", "AÇÃO"):gsub("aperte E", "toque AÇÃO")
		end
	end
	ui.prompt.Visible = text ~= nil
	if text then
		ui.prompt.Text = text
	end
end

-- Some com a legenda do rodapé (um aviso mais novo no meio da tela tomou o lugar).
function GameUiController.hideCaption()
	captionToken += 1
	r().caption.Visible = false
end

function GameUiController.muteCaptions(on: boolean)
	captionsMuted = on
	if on then
		GameUiController.hideCaption()
	end
end

function GameUiController.captionShownAt(): number
	return captionShownAt
end

function GameUiController.caption(text: string, duration: number?)
	showCaption(text, duration)
end

function GameUiController.showNote(id: string)
	local ui = r()
	local text = (Text.Notes :: any)[id] or ""
	ui.noteText.Text = if id == "note_breakers" then string.format(text, GameState.snapshot().breakerOrder) else text
	ui.note.Visible = true
	local reading = ui.note:FindFirstChild("Reading") :: ScrollingFrame
	reading.CanvasPosition = Vector2.zero
	if SettingsController.motionEnabled() then
		local target = UDim2.fromScale(0.5, 0.5)
		ui.note.Position = target + UDim2.fromOffset(0, 12)
		TweenService:Create(ui.note, TweenInfo.new(0.18), { Position = target }):Play()
	end
	noteOpen = true
	player:SetAttribute("NoteOpen", true)
end

function GameUiController.isNoteOpen(): boolean
	return noteOpen
end

function GameUiController.closeNote()
	local ui = r()
	ui.note.Visible = false
	noteOpen = false
	player:SetAttribute("NoteOpen", false)
end

return GameUiController
