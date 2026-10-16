--!strict
-- Ordem de serviço do HUD: papel quente, carvão e sinalização âmbar da subestação.
local Create = require("./Create")
local Theme = require("./Theme")
local Hud = {}

local function text(parent: Instance, name: string, y: number, height: number, size: number): TextLabel
	return Create("TextLabel", {
		Name = name,
		Parent = parent,
		Position = UDim2.fromOffset(16, y),
		Size = UDim2.new(1, -32, 0, height),
		BackgroundTransparency = 1,
		Font = Enum.Font.Code,
		TextSize = size,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
	}) :: TextLabel
end

local function panel(parent: Instance, name: string, y: number, height: number): Frame
	return Create("Frame", {
		Name = name,
		Parent = parent,
		Position = UDim2.fromOffset(20, y),
		Size = UDim2.fromOffset(344, height),
		BackgroundColor3 = Color3.fromRGB(13, 17, 17),
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, {
		Create("UIStroke", { Color = Color3.fromRGB(66, 70, 60), Thickness = 1 }),
		Create(
			"Frame",
			{ Name = "Rule", Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, BackgroundColor3 = Theme.Hazard }
		),
	}) :: Frame
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
	local objective = panel(canvas, "Order", 58, 218)
	local chapter = text(objective, "Chapter", 12, 18, 12)
	chapter.TextColor3 = Theme.Hazard
	local title = text(objective, "Title", 38, 48, 21)
	local destination = text(objective, "Destination", 91, 20, 14)
	destination.TextColor3 = Color3.fromRGB(183, 190, 170)
	local action = text(objective, "Action", 118, 68, 15)
	local progress = text(objective, "Progress", 196, 16, 12)
	progress.TextColor3 = Theme.Hazard
	local tipPanel = panel(canvas, "FieldTip", 288, 96)
	local tipTitle = text(tipPanel, "Heading", 10, 16, 12)
	tipTitle.TextColor3 = Theme.Hazard
	tipTitle.Text = "SUSSURROS / ORIENTAÇÃO"
	local tip = text(tipPanel, "Tip", 34, 54, 14)
	local footer = panel(canvas, "Equipment", 0, 102)
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 20, 1, -20)
	local equipment = text(footer, "Readout", 10, 18, 13)
	local inventory = text(footer, "Inventory", 36, 28, 12)
	local controls = text(footer, "Controls", 73, 18, 12)
	controls.Text = "E AÇÃO · F LUZ · Z RESPIRAR · H GUIA · TAB EQUIPE"
	controls.TextColor3 = Color3.fromRGB(183, 190, 170)
	local dossier = panel(canvas, "Dossier", 58, 380)
	dossier.Visible = false
	local heading = text(dossier, "Heading", 12, 24, 17)
	heading.Text = "GUIA DA CASA"
	heading.TextColor3 = Theme.Hazard
	heading.Size = UDim2.new(1, -120, 0, 24)
	local close = Create("TextButton", {
		Name = "Close",
		Parent = dossier,
		Position = UDim2.new(1, -98, 0, 6),
		Size = UDim2.fromOffset(90, 32),
		BackgroundTransparency = 1,
		Text = "FECHAR [H]",
		Font = Enum.Font.Code,
		TextSize = 13,
		TextColor3 = Theme.Text,
		Modal = true,
	}) :: TextButton
	local scroll = Create("ScrollingFrame", {
		Name = "Pages",
		Parent = dossier,
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 1, -58),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Hazard,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}) :: ScrollingFrame
	local pages = text(scroll, "Text", 0, 0, 14)
	pages.Position = UDim2.fromOffset(4, 0)
	pages.Size = UDim2.new(1, -16, 0, 0)
	-- Altura calculada pelo controller: AutomaticSize dentro do ScrollingFrame pode limitar o texto ao viewport.
	local feedback = text(canvas, "Feedback", 0, 48, 16)
	feedback.AnchorPoint = Vector2.new(0.5, 1)
	feedback.Position = UDim2.new(0.5, 0, 1, -104)
	feedback.Size = UDim2.new(0.8, 0, 0, 48)
	feedback.TextXAlignment = Enum.TextXAlignment.Center
	feedback.TextColor3 = Theme.Hazard
	feedback.TextStrokeTransparency = 0.2
	Create("Frame", {
		Name = "Crosshair",
		Parent = canvas,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(3, 3),
		BorderSizePixel = 0,
		BackgroundColor3 = Theme.Text,
	})
	local waypoint = text(canvas, "DestinationMarker", 0, 36, 13)
	waypoint.AnchorPoint = Vector2.new(0.5, 0.5)
	waypoint.Size = UDim2.fromOffset(230, 36)
	waypoint.TextXAlignment = Enum.TextXAlignment.Center
	waypoint.TextColor3 = Theme.Hazard
	waypoint.TextStrokeTransparency = 0
	local function resize(viewport: Vector2)
		local factor = math.clamp(math.min(viewport.X / 800, viewport.Y / 650), 0.65, 1.15)
		scale.Scale = factor
		canvas.Size = UDim2.fromOffset(viewport.X / factor, viewport.Y / factor)
		dossier.Size = UDim2.fromOffset(344, math.max(180, viewport.Y / factor - 166))
		return factor
	end
	return {
		gui = gui,
		canvas = canvas,
		order = objective,
		chapter = chapter,
		title = title,
		destination = destination,
		action = action,
		progress = progress,
		tipPanel = tipPanel,
		tip = tip,
		footer = footer,
		equipment = equipment,
		inventory = inventory,
		dossier = dossier,
		pages = pages,
		close = close,
		feedback = feedback,
		waypoint = waypoint,
		resize = resize,
	}
end

return Hud
