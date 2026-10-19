--!strict
--[[
	HUD de terror (referência do humano em docs/evidence/hud-reference/): tela limpa, só dois botões discretos no canto
	(Objetivo J, Mochila TAB), a barra fina de fôlego embaixo e uma linha sutil com o objetivo atual no canto.
	Painéis em preto translúcido com moldura dourada fina e cantoneiras; fonte serifada (nada arredondado ou colorido).
	O CampaignController preenche os dados; aqui só monta e anima (folha virando, pulso do botão).
]]
local TweenService = game:GetService("TweenService")
local Create = require("./Create")

local Noir = {}

local rgb = Color3.fromRGB
Noir.Gold = rgb(201, 170, 112)
Noir.GoldDim = rgb(138, 114, 74)
Noir.Ink = rgb(10, 9, 8)
Noir.Paper = rgb(226, 214, 190)
Noir.TextDim = rgb(170, 160, 140)
Noir.Blood = rgb(150, 46, 40)
Noir.Serif = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular)
Noir.SerifBold = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Bold)

export type Slot = { button: TextButton, icon: Frame, count: TextLabel, item: string }
export type Ui = {
	gui: ScreenGui,
	objectiveButton: TextButton,
	bagButton: TextButton,
	cornerTitle: TextLabel,
	cornerChapter: TextLabel,
	stamina: Frame,
	staminaFill: Frame,
	air: Frame,
	airFill: Frame,
	note: Frame,
	notePage: Frame,
	noteChapter: TextLabel,
	noteTitle: TextLabel,
	noteBody: TextLabel,
	noteList: TextLabel,
	noteProgress: TextLabel,
	bag: Frame,
	slots: { Slot },
	detailName: TextLabel,
	detailText: TextLabel,
	useButton: TextButton,
	modal: TextButton,
}

local function text(parent: Instance, name: string, size: number, color: Color3, props: { [string]: any }?): TextLabel
	local label = Create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Noir.Serif,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = parent,
	}) :: TextLabel
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

-- Moldura fina dourada com cantoneiras em L (o "frame" pedido pelo humano).
function Noir.frame(parent: GuiObject, inset: number?, alpha: number?)
	local pad = inset or 4
	local fade = alpha or 0.15
	Create("UIStroke", {
		Color = Noir.GoldDim,
		Thickness = 1,
		Transparency = 0.35 + fade,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	for _, corner in { Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) } do
		for _, horizontal in { true, false } do
			Create("Frame", {
				Name = "Ornament",
				AnchorPoint = corner,
				Position = UDim2.new(
					corner.X,
					if corner.X == 0 then pad else -pad,
					corner.Y,
					if corner.Y == 0 then pad else -pad
				),
				Size = if horizontal then UDim2.fromOffset(12, 1) else UDim2.fromOffset(1, 12),
				BackgroundColor3 = Noir.Gold,
				BackgroundTransparency = fade,
				BorderSizePixel = 0,
				Parent = parent,
			})
		end
	end
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local frame = Create("Frame", {
		Name = name,
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundColor3 = Noir.Ink,
		BackgroundTransparency = 0.18,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	}) :: Frame
	Noir.frame(frame, 6)
	return frame
end

-- Pictogramas finos em linhas (sem pixel-art nem emoji), em caixas de 28 × 28.
local function line(parent: Instance, x: number, y: number, w: number, h: number, rotation: number?)
	Create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rotation or 0,
		BackgroundColor3 = Noir.Paper,
		BorderSizePixel = 0,
		Parent = parent,
	})
end
local function hollow(parent: Instance, x: number, y: number, w: number, h: number)
	Create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { Create("UIStroke", { Color = Noir.Paper, Thickness = 1.4 }) })
end
function Noir.icon(parent: Instance, kind: string): Frame
	local box = Create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	if kind == "note" then
		hollow(box, 6, 3, 16, 22)
		for row = 0, 3 do
			line(box, 9, 8 + row * 4, 10, 1)
		end
	elseif kind == "bag" then
		hollow(box, 5, 9, 18, 16)
		hollow(box, 9, 4, 10, 6)
		line(box, 5, 15, 18, 1)
	elseif kind == "flashlight" then
		hollow(box, 3, 11, 15, 6)
		hollow(box, 18, 8, 6, 12)
	elseif kind == "key" then
		hollow(box, 3, 9, 9, 9)
		line(box, 12, 13, 13, 2)
		line(box, 20, 15, 2, 4)
		line(box, 24, 15, 2, 3)
	elseif kind == "fuse" then
		hollow(box, 8, 6, 12, 16)
		line(box, 12, 2, 4, 4)
		line(box, 12, 22, 4, 4)
	elseif kind == "battery" then
		hollow(box, 4, 9, 18, 11)
		line(box, 22, 12, 3, 5)
		line(box, 7, 12, 6, 5)
	elseif kind == "oxygen" then
		hollow(box, 7, 6, 14, 18)
		line(box, 11, 3, 6, 3)
		line(box, 13, 12, 2, 7)
	elseif kind == "decoy" then
		hollow(box, 5, 7, 18, 14)
		line(box, 9, 3, 1, 5, -25)
		line(box, 9, 11, 6, 6)
		line(box, 17, 11, 2, 2)
		line(box, 17, 15, 2, 2)
	elseif kind == "artifact" then
		hollow(box, 8, 8, 12, 12)
		local diamond = box:FindFirstChildOfClass("Frame")
		if diamond then
			diamond.Rotation = 45
		end
	end
	return box
end

local function squareButton(parent: Instance, name: string, label: string, key: string, icon: string): TextButton
	local button = Create("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(56, 56),
		BackgroundColor3 = Noir.Ink,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}) :: TextButton
	Noir.frame(button, 3, 0.25)
	Noir.icon(button, icon)
	text(button, "Label", 14, Noir.Paper, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 4),
		Size = UDim2.fromOffset(90, 16),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
	})
	local keyCap = Create("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 1, 22),
		Size = UDim2.fromOffset(32, 16),
		BackgroundColor3 = Noir.Ink,
		BackgroundTransparency = 0.4,
		BorderSizePixel = 0,
		Parent = button,
	})
	Create("UIStroke", { Color = Noir.GoldDim, Thickness = 1, Transparency = 0.4, Parent = keyCap })
	text(keyCap, "Text", 11, Noir.TextDim, {
		Size = UDim2.fromScale(1, 1),
		Text = key,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center,
	})
	return button
end

local function bar(parent: Instance, name: string, label: string, y: number): (Frame, Frame)
	local holder = Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, y),
		Size = UDim2.fromOffset(300, 26),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	text(holder, "Label", 15, Noir.Paper, {
		Size = UDim2.new(1, 0, 0, 14),
		Text = label,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 0.15,
	})
	local track = Create("Frame", {
		Name = "Track",
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = Noir.Ink,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Parent = holder,
	}) :: Frame
	Create("UIStroke", { Color = Noir.GoldDim, Thickness = 1, Transparency = 0.35, Parent = track })
	-- Pontas em losango, como na referência.
	for _, side in { 0, 1 } do
		Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(side, if side == 0 then -6 else 6, 0.5, 0),
			Size = UDim2.fromOffset(5, 5),
			Rotation = 45,
			BackgroundColor3 = Noir.Gold,
			BorderSizePixel = 0,
			Parent = track,
		})
	end
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Noir.Paper,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	return holder, fill
end

local ITEMS = {
	{ id = "flashlight", icon = "flashlight" },
	{ id = "keys", icon = "key" },
	{ id = "fuses", icon = "fuse" },
	{ id = "artifact", icon = "artifact" },
	{ id = "battery", icon = "battery" },
	{ id = "oxygen", icon = "oxygen" },
	{ id = "decoy", icon = "decoy" },
	{ id = "empty", icon = "" },
}

function Noir.build(parent: Instance, touch: boolean): Ui
	local gui = Create("ScreenGui", {
		Name = "NoirHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 58,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Linha discreta do objetivo, no canto superior esquerdo.
	local corner = Create("Frame", {
		Name = "Objective",
		Position = UDim2.fromOffset(24, if touch then 64 else 22),
		Size = UDim2.fromOffset(420, 52),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local cornerChapter = text(corner, "Chapter", 13, Noir.GoldDim, { Size = UDim2.new(1, 0, 0, 16) })
	local cornerTitle = text(corner, "Title", 20, Noir.Paper, {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 34),
		TextTransparency = 0.1,
		TextStrokeTransparency = 0.6,
	})

	-- Botões no canto (no celular, acima do direcional: canto superior direito).
	local buttons = Create("Frame", {
		Name = "Buttons",
		AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.new(1, -20, 0, 70) else UDim2.new(0, 24, 1, -56),
		Size = UDim2.fromOffset(140, 56),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 26),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttons,
	})
	local objectiveButton = squareButton(buttons, "ObjectiveButton", "Objetivo", if touch then "" else "J", "note")
	local bagButton = squareButton(buttons, "BagButton", "Mochila", if touch then "" else "TAB", "bag")
	objectiveButton.LayoutOrder, bagButton.LayoutOrder = 1, 2
	if touch then
		for _, b in { objectiveButton, bagButton } do
			local cap = b:FindFirstChild("Key")
			if cap then
				cap:Destroy()
			end
		end
	end

	local stamina, staminaFill = bar(gui, "Stamina", "Fôlego", -18)
	local air, airFill = bar(gui, "Air", "Ar", -54)
	air.Visible = false

	-- Anotação do objetivo (folha escura com moldura). A folha interna "vira" ao concluir.
	local note = panel(gui, "ObjectiveNote", UDim2.fromOffset(380, 420), UDim2.new(0, 24, 0.5, 0), Vector2.new(0, 0.5))
	local notePage = Create("Frame", {
		Name = "Page",
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.new(1, -36, 1, -32),
		BackgroundTransparency = 1,
		Parent = note,
	}) :: Frame
	text(notePage, "Heading", 26, Noir.Paper, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = "OBJETIVO",
		FontFace = Noir.SerifBold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	Create("Frame", {
		Position = UDim2.new(0.2, 0, 0, 36),
		Size = UDim2.new(0.6, 0, 0, 1),
		BackgroundColor3 = Noir.GoldDim,
		BorderSizePixel = 0,
		Parent = notePage,
	})
	local noteChapter = text(notePage, "Chapter", 14, Noir.GoldDim, {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local noteTitle = text(notePage, "Title", 22, Noir.Paper, {
		Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 56),
		FontFace = Noir.SerifBold,
	})
	local noteBody = text(notePage, "Body", 16, Noir.TextDim, {
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, 64),
	})
	local noteList = text(notePage, "List", 15, Noir.TextDim, {
		Position = UDim2.fromOffset(0, 198),
		Size = UDim2.new(1, 0, 1, -228),
		LineHeight = 1.15,
	})
	local noteProgress = text(notePage, "Progress", 14, Noir.GoldDim, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	-- Mochila: grade 4 × 2, detalhe do item e botão de usar.
	local bag = panel(gui, "Backpack", UDim2.fromOffset(430, 400), UDim2.new(0, 24, 0.5, 0), Vector2.new(0, 0.5))
	text(bag, "Heading", 26, Noir.Paper, {
		Position = UDim2.fromOffset(24, 18),
		Size = UDim2.new(1, -80, 0, 30),
		Text = "MOCHILA",
		FontFace = Noir.SerifBold,
	})
	local grid = Create("Frame", {
		Name = "Grid",
		Position = UDim2.fromOffset(24, 62),
		Size = UDim2.new(1, -48, 0, 180),
		BackgroundTransparency = 1,
		Parent = bag,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(86, 86),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = grid,
	})
	local slots: { Slot } = {}
	for index, spec in ITEMS do
		local cell = Create("TextButton", {
			Name = spec.id,
			LayoutOrder = index,
			BackgroundColor3 = Noir.Ink,
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			AutoButtonColor = false,
			Text = "",
			Parent = grid,
		}) :: TextButton
		local outline = Create("UIStroke", {
			Name = "Outline",
			Color = Noir.GoldDim,
			Thickness = 1,
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Parent = cell,
		})
		local icon = if spec.icon ~= ""
			then Noir.icon(cell, spec.icon)
			else Create("Frame", { BackgroundTransparency = 1, Parent = cell }) :: Frame
		icon.Size = UDim2.fromOffset(28, 28)
		Create("UIScale", { Scale = 1.5, Parent = icon })
		local count = text(cell, "Count", 15, Noir.Paper, {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -6, 1, -4),
			Size = UDim2.fromOffset(60, 16),
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		local _ = outline
		table.insert(slots, { button = cell, icon = icon, count = count, item = spec.id })
	end
	Create("Frame", {
		Position = UDim2.fromOffset(24, 254),
		Size = UDim2.new(1, -48, 0, 1),
		BackgroundColor3 = Noir.GoldDim,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Parent = bag,
	})
	local detailName = text(bag, "DetailName", 22, Noir.Paper, {
		Position = UDim2.fromOffset(24, 264),
		Size = UDim2.new(1, -48, 0, 26),
		FontFace = Noir.SerifBold,
	})
	local detailText = text(bag, "DetailText", 15, Noir.TextDim, {
		Position = UDim2.fromOffset(24, 292),
		Size = UDim2.new(1, -48, 0, 38),
	})
	local useButton = Create("TextButton", {
		Name = "Use",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 334),
		Size = UDim2.fromOffset(180, 36),
		BackgroundColor3 = Noir.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		FontFace = Noir.SerifBold,
		TextSize = 17,
		TextColor3 = Noir.Paper,
		Text = "USAR",
		Parent = bag,
	}) :: TextButton
	Noir.frame(useButton, 3, 0.2)
	text(bag, "Hint", 12, Noir.GoldDim, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(200, 14),
		Text = if touch then "toque fora para fechar" else "TAB · Fechar",
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	-- Botão modal invisível: solta o mouse enquanto um painel está aberto (o CameraController respeita Modal).
	local modal = Create("TextButton", {
		Name = "Modal",
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Modal = false,
		Visible = false,
		Parent = gui,
	}) :: TextButton

	gui.Parent = parent
	return {
		gui = gui,
		objectiveButton = objectiveButton,
		bagButton = bagButton,
		cornerTitle = cornerTitle,
		cornerChapter = cornerChapter,
		stamina = stamina,
		staminaFill = staminaFill,
		air = air,
		airFill = airFill,
		note = note,
		notePage = notePage,
		noteChapter = noteChapter,
		noteTitle = noteTitle,
		noteBody = noteBody,
		noteList = noteList,
		noteProgress = noteProgress,
		bag = bag,
		slots = slots,
		detailName = detailName,
		detailText = detailText,
		useButton = useButton,
		modal = modal,
	}
end

-- Folha virando: a página encolhe no eixo X, troca o conteúdo (callback) e volta.
function Noir.flip(ui: Ui, swap: () -> ())
	local page = ui.notePage
	local scale = page:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = page })
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local half =
		TweenService:Create(page, info, { Position = UDim2.new(0.5, 0, 0, 16), Size = UDim2.new(0, 0, 1, -32) })
	half.Completed:Once(function()
		swap()
		local back = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(page, back, { Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -36, 1, -32) })
			:Play()
	end)
	half:Play()
	local _ = scale
end

-- Pulso suave do botão (objetivo mudou).
function Noir.pulse(button: GuiObject)
	local scale = button:FindFirstChildOfClass("UIScale") or Create("UIScale", { Parent = button })
	local s = scale :: UIScale
	local info = TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true)
	s.Scale = 1
	TweenService:Create(s, info, { Scale = 1.12 }):Play()
end

return Noir
