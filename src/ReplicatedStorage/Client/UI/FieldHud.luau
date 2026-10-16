--!strict
--[[
	HUD da casa, pensado para crianças: cartão de objetivo grande no topo, barras coloridas com ícones,
	inventário em quadradinhos, moedas e nível sempre à vista. Tudo arredondado e com contorno.
	O CampaignController preenche os campos; esta tela só monta e expõe as peças.
]]
local Create = require("./Create")
local Theme = require("./Theme")
local Hud = {}

export type Bar = { frame: Frame, fill: Frame, label: TextLabel }
export type Slot = { frame: Frame, icon: TextLabel, count: TextLabel }

local function corner(radius: UDim?): Instance
	return Create("UICorner", { CornerRadius = radius or Theme.Corner })
end

local function stroke(color: Color3?, thickness: number?, transparency: number?): Instance
	return Create("UIStroke", {
		Color = color or Theme.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0.15,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}) :: UIStroke
end

local function card(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2?): Frame
	return Create("Frame", {
		Name = name,
		Parent = parent,
		AnchorPoint = anchor or Vector2.zero,
		Position = position,
		Size = size,
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
	}, {
		corner(),
		stroke(),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.PanelLight, Theme.Panel),
		}),
	}) :: Frame
end

local function label(
	parent: Instance,
	name: string,
	font: Font,
	size: number,
	color: Color3,
	position: UDim2,
	dimension: UDim2,
	align: Enum.TextXAlignment?
): TextLabel
	return Create("TextLabel", {
		Name = name,
		Parent = parent,
		Position = position,
		Size = dimension,
		BackgroundTransparency = 1,
		FontFace = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = align or Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = true,
		Text = "",
	}) :: TextLabel
end

local function bar(parent: Instance, name: string, icon: string, color: Color3, y: number): Bar
	local frame = Create("Frame", {
		Name = name,
		Parent = parent,
		Position = UDim2.fromOffset(14, y),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1,
	}) :: Frame
	local iconLabel = label(frame, "Icon", Theme.Font, 18, Theme.Text, UDim2.new(), UDim2.fromOffset(26, 24))
	iconLabel.Text = icon
	local track = Create("Frame", {
		Name = "Track",
		Parent = frame,
		Position = UDim2.fromOffset(32, 4),
		Size = UDim2.new(1, -32, 0, 16),
		BackgroundColor3 = Color3.fromRGB(14, 8, 28),
		BorderSizePixel = 0,
	}, { corner(UDim.new(1, 0)) }) :: Frame
	local fill = Create("Frame", {
		Name = "Fill",
		Parent = track,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, {
		corner(UDim.new(1, 0)),
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color),
		}),
	}) :: Frame
	local text = label(track, "Value", Theme.Font, 12, Theme.Text, UDim2.new(), UDim2.fromScale(1, 1))
	text.TextStrokeTransparency = 0.4
	return { frame = frame, fill = fill, label = text }
end

local function slot(parent: Instance, name: string, icon: string, order: number, key: string?): Slot
	local frame = Create("Frame", {
		Name = name,
		Parent = parent,
		LayoutOrder = order,
		Size = UDim2.fromOffset(58, 58),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	}, { corner(Theme.CornerSmall), stroke(Theme.TextDim, 2, 0.4) }) :: Frame
	local iconLabel = label(frame, "Icon", Theme.Font, 28, Theme.Text, UDim2.fromOffset(0, -2), UDim2.fromScale(1, 1))
	iconLabel.Text = icon
	local count = label(
		frame,
		"Count",
		Theme.Font,
		15,
		Theme.Hazard,
		UDim2.new(1, -40, 1, -20),
		UDim2.fromOffset(38, 18),
		Enum.TextXAlignment.Right
	)
	count.TextStrokeTransparency = 0.2
	if key then
		local hint =
			label(frame, "Key", Theme.Font, 12, Theme.TextDim, UDim2.fromOffset(4, 2), UDim2.fromOffset(14, 14))
		hint.Text = key
	end
	return { frame = frame, icon = iconLabel, count = count }
end

function Hud.build(parent: Instance)
	local gui = Create("ScreenGui", {
		Name = "CampaignUi",
		Parent = parent,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
	}) :: ScreenGui
	local canvas = Create(
		"Frame",
		{ Name = "Canvas", Parent = gui, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }
	) :: Frame
	local scale = Create("UIScale", { Parent = canvas }) :: UIScale

	-- Cartão do objetivo (topo, centro).
	local objective = card(canvas, "Order", UDim2.fromOffset(470, 132), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	local objectiveStroke = objective:FindFirstChildOfClass("UIStroke") :: UIStroke
	objectiveStroke.Thickness = 3
	local chapter = label(
		objective,
		"Chapter",
		Theme.Font,
		14,
		Theme.Hazard,
		UDim2.fromOffset(16, 8),
		UDim2.new(1, -32, 0, 18),
		Enum.TextXAlignment.Left
	)
	local destination = label(
		objective,
		"Destination",
		Theme.Font,
		14,
		Theme.Info,
		UDim2.new(0.5, 0, 0, 8),
		UDim2.new(0.5, -16, 0, 18),
		Enum.TextXAlignment.Right
	)
	local title =
		label(objective, "Title", Theme.Font, 26, Theme.Text, UDim2.fromOffset(14, 28), UDim2.new(1, -28, 0, 34))
	title.TextScaled = true
	Create("UITextSizeConstraint", { Parent = title, MaxTextSize = 28, MinTextSize = 16 })
	title.TextStrokeTransparency = 0.6
	local action = label(
		objective,
		"Action",
		Theme.FontNote,
		15,
		Theme.TextDim,
		UDim2.fromOffset(18, 62),
		UDim2.new(1, -36, 0, 40)
	)
	local progressTrack = Create("Frame", {
		Name = "ProgressTrack",
		Parent = objective,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -120, 0, 12),
		BackgroundColor3 = Color3.fromRGB(14, 8, 28),
		BorderSizePixel = 0,
	}, { corner(UDim.new(1, 0)) }) :: Frame
	local progressFill = Create("Frame", {
		Name = "Fill",
		Parent = progressTrack,
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Good,
		BorderSizePixel = 0,
	}, { corner(UDim.new(1, 0)) }) :: Frame
	local progress = label(
		objective,
		"Progress",
		Theme.Font,
		13,
		Theme.Good,
		UDim2.new(1, -56, 1, -24),
		UDim2.fromOffset(48, 16),
		Enum.TextXAlignment.Right
	)

	-- Dica (balão à esquerda).
	local tipPanel = card(canvas, "FieldTip", UDim2.fromOffset(270, 92), UDim2.fromOffset(16, 170))
	local tipTitle = label(
		tipPanel,
		"Heading",
		Theme.Font,
		14,
		Theme.Hazard,
		UDim2.fromOffset(14, 8),
		UDim2.new(1, -28, 0, 18),
		Enum.TextXAlignment.Left
	)
	tipTitle.Text = "💡 DICA"
	local tip = label(
		tipPanel,
		"Tip",
		Theme.FontNote,
		14,
		Theme.Text,
		UDim2.fromOffset(14, 28),
		UDim2.new(1, -28, 1, -36),
		Enum.TextXAlignment.Left
	)
	tip.TextYAlignment = Enum.TextYAlignment.Top

	-- Status (canto inferior esquerdo): fôlego, lanterna e ar.
	local footer = card(canvas, "Equipment", UDim2.fromOffset(260, 118), UDim2.new(0, 16, 1, -16), Vector2.new(0, 1))
	local bars = {
		stamina = bar(footer, "Stamina", "⚡", Theme.Hazard, 10),
		battery = bar(footer, "Battery", "🔦", Theme.Info, 38),
		oxygen = bar(footer, "Oxygen", "💨", Color3.fromRGB(140, 220, 255), 66),
	}
	local equipment = label(
		footer,
		"Readout",
		Theme.Font,
		13,
		Theme.TextDim,
		UDim2.fromOffset(16, 92),
		UDim2.new(1, -32, 0, 18),
		Enum.TextXAlignment.Left
	)

	-- Inventário (baixo, centro).
	local tray = Create("Frame", {
		Name = "Inventory",
		Parent = canvas,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(470, 62),
		BackgroundTransparency = 1,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	local slots = {
		keys = slot(tray, "Keys", "🔑", 1),
		fuses = slot(tray, "Fuses", "🔌", 2),
		artifact = slot(tray, "Artifact", "🔮", 3),
		battery = slot(tray, "Battery", "🔋", 4, "1"),
		oxygen = slot(tray, "Oxygen", "🎈", 5, "2"),
		decoy = slot(tray, "Decoy", "🥁", 6, "3"),
	}
	-- Texto legado (lido por testes antigos); fica invisível atrás dos slots.
	local inventory = label(tray, "Readout", Theme.Font, 1, Theme.Text, UDim2.new(), UDim2.fromOffset(0, 0))
	inventory.Visible = false

	-- Moedas e nível (canto superior direito).
	local wallet = card(canvas, "Wallet", UDim2.fromOffset(170, 46), UDim2.new(1, -16, 0, 14), Vector2.new(1, 0))
	local coins = label(
		wallet,
		"Coins",
		Theme.Font,
		22,
		Theme.Coin,
		UDim2.fromOffset(12, 0),
		UDim2.new(1, -24, 1, 0),
		Enum.TextXAlignment.Left
	)
	coins.Text = "💰 0"
	local levelBadge = card(canvas, "Level", UDim2.fromOffset(170, 34), UDim2.new(1, -16, 0, 66), Vector2.new(1, 0))
	local level = label(
		levelBadge,
		"Value",
		Theme.Font,
		16,
		Theme.Text,
		UDim2.fromOffset(12, 0),
		UDim2.new(1, -24, 1, 0),
		Enum.TextXAlignment.Left
	)
	level.Text = "⭐ NÍVEL 1"

	local controls = label(
		canvas,
		"Controls",
		Theme.Font,
		13,
		Theme.TextDim,
		UDim2.new(1, -16, 1, -16),
		UDim2.fromOffset(250, 40),
		Enum.TextXAlignment.Right
	)
	controls.AnchorPoint = Vector2.new(1, 1)
	controls.TextYAlignment = Enum.TextYAlignment.Bottom
	controls.Text = "E usar · F lanterna · Shift correr\nZ prender o ar · H guia · TAB time"
	controls.TextStrokeTransparency = 0.5

	-- Guia (H): cartão central com rolagem.
	local dossier = card(canvas, "Dossier", UDim2.fromOffset(420, 380), UDim2.new(0.5, 0, 0, 14), Vector2.new(0.5, 0))
	dossier.Visible = false
	local heading = label(
		dossier,
		"Heading",
		Theme.Font,
		22,
		Theme.Hazard,
		UDim2.fromOffset(18, 10),
		UDim2.new(1, -150, 0, 30),
		Enum.TextXAlignment.Left
	)
	heading.Text = "📖 GUIA DA CASA"
	local close = Create("TextButton", {
		Name = "Close",
		Parent = dossier,
		Position = UDim2.new(1, -118, 0, 10),
		Size = UDim2.fromOffset(104, 32),
		BackgroundColor3 = Theme.Accent,
		Text = "FECHAR [H]",
		FontFace = Theme.Font,
		TextSize = 15,
		TextColor3 = Theme.Text,
		AutoButtonColor = true,
		Modal = true,
	}, { corner(Theme.CornerSmall) }) :: TextButton
	local scroll = Create("ScrollingFrame", {
		Name = "Pages",
		Parent = dossier,
		Position = UDim2.fromOffset(14, 50),
		Size = UDim2.new(1, -28, 1, -62),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Hazard,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}) :: ScrollingFrame
	local pages = label(
		scroll,
		"Text",
		Theme.FontNote,
		15,
		Theme.Text,
		UDim2.fromOffset(4, 0),
		UDim2.new(1, -16, 0, 0),
		Enum.TextXAlignment.Left
	)
	pages.TextYAlignment = Enum.TextYAlignment.Top
	-- Altura calculada pelo controller: AutomaticSize dentro do ScrollingFrame pode limitar o texto ao viewport.

	-- Aviso grande no meio de baixo (resultado de ações).
	local feedback =
		label(canvas, "Feedback", Theme.Font, 22, Theme.Hazard, UDim2.new(0.5, 0, 1, -96), UDim2.new(0.7, 0, 0, 56))
	feedback.AnchorPoint = Vector2.new(0.5, 1)
	feedback.TextStrokeTransparency = 0
	feedback.TextStrokeColor3 = Theme.Ink

	Create("Frame", {
		Name = "Crosshair",
		Parent = canvas,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(6, 6),
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Text,
		BackgroundTransparency = 0.2,
	}, { corner(UDim.new(1, 0)) })

	-- Marcador do objetivo: losango amarelo com nome e distância.
	local waypoint =
		label(canvas, "DestinationMarker", Theme.Font, 16, Theme.Hazard, UDim2.new(), UDim2.fromOffset(240, 52))
	waypoint.AnchorPoint = Vector2.new(0.5, 0.5)
	waypoint.TextStrokeTransparency = 0
	waypoint.TextStrokeColor3 = Theme.Ink

	local function resize(viewport: Vector2)
		local factor = math.clamp(math.min(viewport.X / 820, viewport.Y / 640), 0.6, 1.25)
		scale.Scale = factor
		canvas.Size = UDim2.fromOffset(viewport.X / factor, viewport.Y / factor)
		dossier.Size = UDim2.fromOffset(420, math.max(200, viewport.Y / factor - 120))
		return factor
	end

	local function setBar(which: Bar, value: number, text: string, warn: boolean?)
		local clamped = math.clamp(value, 0, 1)
		which.fill.Size = UDim2.fromScale(clamped, 1)
		which.label.Text = text
		which.fill.BackgroundTransparency = if warn and os.clock() % 0.5 < 0.25 then 0.5 else 0
	end

	return {
		gui = gui,
		canvas = canvas,
		order = objective,
		orderStroke = objectiveStroke,
		chapter = chapter,
		title = title,
		destination = destination,
		action = action,
		progress = progress,
		progressFill = progressFill,
		tipPanel = tipPanel,
		tip = tip,
		footer = footer,
		equipment = equipment,
		bars = bars,
		setBar = setBar,
		inventory = inventory,
		tray = tray,
		slots = slots,
		wallet = wallet,
		coins = coins,
		level = level,
		controls = controls,
		dossier = dossier,
		pages = pages,
		close = close,
		feedback = feedback,
		waypoint = waypoint,
		resize = resize,
	}
end

return Hud
