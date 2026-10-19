--!strict
--[[
	HUD de terror (referências do humano em docs/evidence/hud-reference/): tela limpa e quase invisível.
	- Canto inferior esquerdo: dois ícones finos com legenda espaçada (OBJETIVO J | MOCHILA TAB), sem caixas.
	- Canto inferior direito: pulmão + barra fina de fôlego (a parte gasta fica vermelha); a do ar aparece acima.
	- Objetivo (J): faixa escura à esquerda com a tarefa atual (uma por vez); a folha "vira" ao concluir.
	- Mochila (TAB): faixa escura no rodapé com os itens em 3D lado a lado; o escolhido mostra nome e barra;
	  [E] equipa. A cena continua visível atrás.
	Fonte sem serifa fina (Montserrat) com letras espaçadas. O CampaignController preenche os dados.
]]
local TweenService = game:GetService("TweenService")
local Create = require("./Create")

local Noir = {}

local rgb = Color3.fromRGB
Noir.Gold = rgb(214, 196, 160)
Noir.GoldDim = rgb(150, 138, 116)
Noir.Ink = rgb(6, 5, 4)
Noir.Paper = rgb(236, 230, 218)
Noir.TextDim = rgb(176, 168, 152)
Noir.Blood = rgb(168, 40, 36)
Noir.Sans = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Regular)
Noir.SansLight = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Light)
Noir.SansMedium = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium)

export type Slot = {
	button: TextButton,
	icon: Frame,
	count: TextLabel,
	name: TextLabel,
	track: Frame,
	fill: Frame,
	item: string,
}
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
	hint: TextLabel,
	work: Frame,
	workFill: Frame,
}

-- Letras espaçadas (o Roblox não tem espaçamento de letra): "MOCHILA" -> "M O C H I L A" com espaço fino.
function Noir.spaced(value: string, gap: string?): string
	local out = {}
	for _, code in utf8.codes(value) do
		table.insert(out, utf8.char(code))
	end
	return table.concat(out, gap or "\u{2009}")
end

local function text(parent: Instance, name: string, size: number, color: Color3, props: { [string]: any }?): TextLabel
	local label = Create("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = Noir.Sans,
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

local function rule(parent: Instance, position: UDim2, size: UDim2, alpha: number?): Frame
	return Create("Frame", {
		Name = "Rule",
		Position = position,
		Size = size,
		BackgroundColor3 = Noir.Paper,
		BackgroundTransparency = alpha or 0.75,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
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
local function hollow(parent: Instance, x: number, y: number, w: number, h: number, round: number?)
	Create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Create("UIStroke", { Color = Noir.Paper, Thickness = 1.2 }),
		Create("UICorner", { CornerRadius = UDim.new(0, round or 2) }),
	})
end
function Noir.icon(parent: Instance, kind: string): Frame
	local box = Create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	if kind == "note" then
		hollow(box, 7, 3, 14, 21)
		for row = 0, 3 do
			line(box, 10, 8 + row * 4, 8, 1)
		end
	elseif kind == "bag" then
		hollow(box, 5, 10, 18, 14, 3)
		hollow(box, 10, 5, 8, 6, 3)
		line(box, 5, 16, 18, 1)
		line(box, 13, 15, 2, 3)
	elseif kind == "lungs" then
		hollow(box, 5, 9, 8, 14, 5)
		hollow(box, 15, 9, 8, 14, 5)
		line(box, 13, 3, 2, 9)
	elseif kind == "air" then
		hollow(box, 8, 8, 12, 12, 6)
		hollow(box, 3, 4, 5, 5, 3)
		hollow(box, 20, 18, 4, 4, 2)
	end
	return box
end

-- Botão do canto: ícone, legenda espaçada e tecla, sem caixa (área de toque confortável).
local function cornerButton(parent: Instance, name: string, label: string, key: string, icon: string): TextButton
	local button = Create("TextButton", {
		Name = name,
		Size = UDim2.fromOffset(78, 66),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}) :: TextButton
	local glyph = Noir.icon(button, icon)
	glyph.Position = UDim2.fromOffset(25, 2)
	glyph.AnchorPoint = Vector2.zero
	text(button, "Label", 9, Noir.Paper, {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 12),
		Text = Noir.spaced(string.upper(label)),
		FontFace = Noir.SansMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTransparency = 0.1,
	})
	text(button, "Key", 10, Noir.TextDim, {
		Position = UDim2.fromOffset(0, 52),
		Size = UDim2.new(1, 0, 0, 12),
		Text = Noir.spaced(key),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
	})
	return button
end

-- Barra fina no canto inferior direito: ícone + trilho vermelho (gasto) + preenchimento claro.
local function bar(parent: Instance, name: string, icon: string, y: number): (Frame, Frame)
	local holder = Create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -30, 1, y),
		Size = UDim2.fromOffset(138, 28),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	local glyph = Noir.icon(holder, icon)
	glyph.AnchorPoint = Vector2.new(0, 0.5)
	glyph.Position = UDim2.fromScale(0, 0.5)
	glyph.Size = UDim2.fromOffset(28, 28)
	Create("UIScale", { Scale = 0.85, Parent = glyph })
	local track = Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(98, 2),
		BackgroundColor3 = Noir.Blood,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		Parent = holder,
	}) :: Frame
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Noir.Paper,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	return holder, fill
end

-- Faixa escura com degradê (a cena continua visível).
local function shade(parent: Instance, name: string, rotation: number, props: { [string]: any }): Frame
	local frame = Create("Frame", {
		Name = name,
		BackgroundColor3 = Noir.Ink,
		BorderSizePixel = 0,
		Visible = false,
		Parent = parent,
	}) :: Frame
	for key, value in props do
		(frame :: any)[key] = value
	end
	Create("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.35, 0.45),
			NumberSequenceKeypoint.new(1, 0.12),
		}),
		Parent = frame,
	})
	return frame
end

--[[ Itens em 3D (ViewportFrame) feitos de peças simples, iluminados como objetos da casa. ]]
local function piece(
	model: Model,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
)
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Block
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
end

local CYL = Enum.PartType.Cylinder
local METAL = Enum.Material.Metal
local BRASS = rgb(176, 136, 64)

local function buildItem(kind: string): Model
	local m = Instance.new("Model")
	local tilt = CFrame.Angles(0, 0, math.rad(28))
	if kind == "flashlight" then
		piece(m, Vector3.new(2.2, 0.5, 0.5), tilt, rgb(30, 31, 34), METAL, CYL)
		piece(m, Vector3.new(0.6, 0.78, 0.78), tilt * CFrame.new(1.3, 0, 0), rgb(46, 47, 50), METAL, CYL)
		piece(
			m,
			Vector3.new(0.05, 0.62, 0.62),
			tilt * CFrame.new(1.62, 0, 0),
			rgb(236, 232, 214),
			Enum.Material.Neon,
			CYL
		)
		piece(m, Vector3.new(0.2, 0.08, 0.16), tilt * CFrame.new(0.2, 0.27, 0), rgb(120, 30, 26))
	elseif kind == "keys" then
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			piece(
				m,
				Vector3.new(0.14, 0.2, 0.12),
				tilt * CFrame.new(-1 + math.cos(a) * 0.4, math.sin(a) * 0.4, 0) * CFrame.Angles(0, 0, a),
				BRASS,
				METAL
			)
		end
		piece(m, Vector3.new(1.7, 0.14, 0.12), tilt * CFrame.new(0.2, 0, 0), BRASS, METAL)
		piece(m, Vector3.new(0.12, 0.34, 0.12), tilt * CFrame.new(0.85, -0.2, 0), BRASS, METAL)
		piece(m, Vector3.new(0.12, 0.24, 0.12), tilt * CFrame.new(0.6, -0.15, 0), BRASS, METAL)
	elseif kind == "fuses" then
		piece(m, Vector3.new(1.3, 0.62, 0.62), tilt, rgb(226, 220, 204), Enum.Material.SmoothPlastic, CYL)
		piece(m, Vector3.new(0.3, 0.66, 0.66), tilt * CFrame.new(-0.75, 0, 0), BRASS, METAL, CYL)
		piece(m, Vector3.new(0.3, 0.66, 0.66), tilt * CFrame.new(0.75, 0, 0), BRASS, METAL, CYL)
	elseif kind == "artifact" then
		piece(
			m,
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.Angles(math.rad(45), math.rad(35), 0),
			rgb(120, 22, 26),
			Enum.Material.Glass
		)
		piece(
			m,
			Vector3.new(0.4, 0.4, 0.4),
			CFrame.Angles(math.rad(45), math.rad(35), 0),
			rgb(255, 90, 70),
			Enum.Material.Neon
		)
	elseif kind == "battery" then
		piece(m, Vector3.new(1.4, 0.6, 0.6), tilt, rgb(40, 52, 40), METAL, CYL)
		piece(m, Vector3.new(0.3, 0.62, 0.62), tilt * CFrame.new(-0.55, 0, 0), rgb(170, 160, 140), METAL, CYL)
		piece(m, Vector3.new(0.14, 0.24, 0.24), tilt * CFrame.new(0.76, 0, 0), BRASS, METAL, CYL)
	elseif kind == "oxygen" then
		piece(m, Vector3.new(1.5, 0.7, 0.7), CFrame.Angles(0, 0, math.rad(90)), rgb(120, 126, 130), METAL, CYL)
		piece(
			m,
			Vector3.new(0.3, 0.3, 0.3),
			CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.rad(90)),
			rgb(60, 62, 66),
			METAL,
			CYL
		)
		piece(m, Vector3.new(0.5, 0.1, 0.1), CFrame.new(0.15, 1.05, 0), rgb(150, 40, 34), METAL)
	elseif kind == "decoy" then
		piece(m, Vector3.new(0.8, 1.3, 0.4), CFrame.identity, rgb(24, 24, 26), Enum.Material.SmoothPlastic)
		piece(m, Vector3.new(0.08, 0.8, 0.08), CFrame.new(0.25, 1.05, 0), rgb(18, 18, 20), METAL)
		for row = 0, 3 do
			piece(m, Vector3.new(0.5, 0.05, 0.05), CFrame.new(0, -0.3 + row * 0.13, -0.2), rgb(70, 70, 74), METAL)
		end
		piece(m, Vector3.new(0.12, 0.12, 0.05), CFrame.new(-0.2, 0.42, -0.2), rgb(180, 50, 40), Enum.Material.Neon)
	end
	return m
end

local function viewport(parent: Instance, kind: string): Frame
	local holder = Create("Frame", {
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(130, 96),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	local view = Create("ViewportFrame", {
		Name = "View",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = rgb(176, 160, 138),
		LightColor = rgb(255, 228, 190),
		LightDirection = Vector3.new(-0.6, -1, -0.5),
		Parent = holder,
	}) :: ViewportFrame
	local model = buildItem(kind)
	model.Parent = view
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	local _, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z * 0.6) * 0.5
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0.25, -radius / math.tan(math.rad(15))), Vector3.zero)
	camera.Parent = view
	view.CurrentCamera = camera
	return holder
end

local ITEMS = { "flashlight", "keys", "fuses", "artifact", "battery", "oxygen", "decoy" }

function Noir.build(parent: Instance, touch: boolean): Ui
	local gui = Create("ScreenGui", {
		Name = "NoirHud",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 58,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Objetivo atual, sutil, no canto superior esquerdo.
	local corner = Create("Frame", {
		Name = "Objective",
		-- Abaixo do botão do Roblox (canto superior esquerdo do jogo publicado).
		Position = UDim2.fromOffset(28, if touch then 70 else 64),
		Size = UDim2.fromOffset(420, 52),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local cornerChapter = text(corner, "Chapter", 10, Noir.TextDim, {
		Size = UDim2.new(1, 0, 0, 14),
		FontFace = Noir.SansMedium,
	})
	local cornerTitle = text(corner, "Title", 17, Noir.Paper, {
		Position = UDim2.fromOffset(0, 16),
		Size = UDim2.new(1, 0, 0, 34),
		FontFace = Noir.SansLight,
		TextTransparency = 0.08,
		TextStrokeTransparency = 0.75,
	})

	-- Botões (no celular: canto superior direito, longe do direcional).
	local buttons = Create("Frame", {
		Name = "Buttons",
		AnchorPoint = if touch then Vector2.new(1, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.new(1, -16, 0, 64) else UDim2.new(0, 24, 1, -22),
		Size = UDim2.fromOffset(176, 66),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = buttons,
	})
	local objectiveButton = cornerButton(buttons, "ObjectiveButton", "Objetivo", if touch then "" else "J", "note")
	local divider = rule(buttons, UDim2.new(), UDim2.fromOffset(1, 46), 0.55)
	local bagButton = cornerButton(buttons, "BagButton", "Mochila", if touch then "" else "TAB", "bag")
	objectiveButton.LayoutOrder, divider.LayoutOrder, bagButton.LayoutOrder = 1, 2, 3

	local stamina, staminaFill = bar(gui, "Stamina", "lungs", -30)
	local air, airFill = bar(gui, "Air", "air", -62)
	air.Visible = false

	-- Objetivo (J): faixa à esquerda, uma tarefa por vez. A página interna vira ao concluir.
	local note = shade(gui, "ObjectiveNote", 180, {
		Size = UDim2.new(0, 460, 1, 0),
	})
	local notePage = Create("Frame", {
		Name = "Page",
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 48, 0.5, 0),
		Size = UDim2.fromOffset(340, 320),
		BackgroundTransparency = 1,
		Parent = note,
	}) :: Frame
	text(notePage, "Heading", 13, Noir.Paper, {
		Size = UDim2.new(1, 0, 0, 18),
		Text = Noir.spaced("OBJETIVO", "\u{2009}\u{2009}"),
		FontFace = Noir.SansMedium,
	})
	rule(notePage, UDim2.fromOffset(0, 26), UDim2.new(1, 0, 0, 1))
	local noteChapter = text(notePage, "Chapter", 10, Noir.TextDim, {
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 14),
		FontFace = Noir.SansMedium,
	})
	local noteTitle = text(notePage, "Title", 22, Noir.Paper, {
		Position = UDim2.fromOffset(0, 62),
		Size = UDim2.new(1, 0, 0, 58),
		FontFace = Noir.SansLight,
	})
	local noteBody = text(notePage, "Body", 14, Noir.TextDim, {
		Position = UDim2.fromOffset(0, 126),
		Size = UDim2.new(1, 0, 0, 60),
		FontFace = Noir.SansLight,
		LineHeight = 1.2,
	})
	local noteList = text(notePage, "List", 12, Noir.TextDim, {
		Position = UDim2.fromOffset(0, 196),
		Size = UDim2.new(1, 0, 0, 90),
		FontFace = Noir.SansLight,
		LineHeight = 1.25,
	})
	local noteProgress = text(notePage, "Progress", 10, Noir.TextDim, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 14),
		FontFace = Noir.SansMedium,
	})

	-- Mochila (TAB): faixa no rodapé com os itens em linha.
	local bag = shade(gui, "Backpack", 90, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 340),
	})
	text(bag, "Heading", 13, Noir.Paper, {
		Position = UDim2.fromOffset(72, 64),
		Size = UDim2.fromOffset(150, 18),
		Text = Noir.spaced("MOCHILA", "\u{2009}\u{2009}"),
		FontFace = Noir.SansMedium,
		TextWrapped = false,
	})
	rule(bag, UDim2.fromOffset(196, 72), UDim2.new(1, -400, 0, 1), 0.8)
	text(bag, "Close", 10, Noir.Paper, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -72, 0, 66),
		Size = UDim2.fromOffset(180, 14),
		Text = if touch then Noir.spaced("FECHAR") else `{Noir.spaced("TAB")}      {Noir.spaced("FECHAR")}`,
		FontFace = Noir.SansMedium,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
	})
	local row = Create("Frame", {
		Name = "Grid",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 110),
		Size = UDim2.new(1, -120, 0, 160),
		BackgroundTransparency = 1,
		Parent = bag,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, if touch then 18 else 54),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = row,
	})
	local slots: { Slot } = {}
	for index, kind in ITEMS do
		local cell = Create("TextButton", {
			Name = kind,
			LayoutOrder = index,
			Size = UDim2.fromOffset(130, 160),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = row,
		}) :: TextButton
		local icon = viewport(cell, kind)
		local count = text(cell, "Count", 10, Noir.TextDim, {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -20, 0, 96),
			Size = UDim2.fromOffset(40, 14),
			FontFace = Noir.SansMedium,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextWrapped = false,
		})
		local track = Create("Frame", {
			Name = "Track",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 104),
			Size = UDim2.fromOffset(100, 2),
			BackgroundColor3 = Noir.Paper,
			BackgroundTransparency = 0.8,
			BorderSizePixel = 0,
			Visible = false,
			Parent = cell,
		}) :: Frame
		local fill = Create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Noir.Paper,
			BorderSizePixel = 0,
			Parent = track,
		}) :: Frame
		local name = text(cell, "Name", 10, Noir.Paper, {
			Position = UDim2.fromOffset(0, 116),
			Size = UDim2.new(1, 0, 0, 40),
			FontFace = Noir.SansMedium,
			TextXAlignment = Enum.TextXAlignment.Center,
			LineHeight = 1.5,
			Visible = false,
		})
		table.insert(
			slots,
			{ button = cell, icon = icon, count = count, name = name, track = track, fill = fill, item = kind }
		)
	end
	local detailName = text(bag, "DetailName", 1, Noir.Paper, { Visible = false })
	local detailText = text(bag, "DetailText", 11, Noir.TextDim, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -64),
		Size = UDim2.fromOffset(520, 16),
		FontFace = Noir.SansLight,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local useButton = Create("TextButton", {
		Name = "Use",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -26),
		Size = UDim2.fromOffset(340, 26),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		FontFace = Noir.SansMedium,
		TextSize = 11,
		TextColor3 = Noir.Paper,
		Text = "EQUIPAR",
		Parent = bag,
	}) :: TextButton
	for _, side in { 0, 1 } do
		rule(useButton, UDim2.new(side, if side == 0 then -10 else -24, 0.5, 0), UDim2.fromOffset(34, 1), 0.6)
	end
	-- Barra fina de "forçando a porta" (cada E enche um pedaço).
	local work = Create("Frame", {
		Name = "Work",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -214),
		Size = UDim2.fromOffset(240, 24),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}) :: Frame
	text(work, "Label", 10, Noir.Paper, {
		Size = UDim2.new(1, 0, 0, 14),
		Text = Noir.spaced("FORÇANDO A PORTA") .. "   ·   [ E ]",
		FontFace = Noir.SansMedium,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
	})
	local workTrack = Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = Noir.Paper,
		BackgroundTransparency = 0.8,
		BorderSizePixel = 0,
		Parent = work,
	})
	local workFill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Noir.Paper,
		BorderSizePixel = 0,
		Parent = workTrack,
	}) :: Frame
	-- Dica curta no rodapé (ex.: dentro do armário).
	local hint = text(gui, "Hint", 21, Noir.Paper, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, if touch then -170 else -100),
		Size = UDim2.new(if touch then 0.9 else 0.62, 0, 0, 56),
		FontFace = Noir.SansLight,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextTransparency = 0.1,
		TextStrokeTransparency = 0.7,
		Visible = false,
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
		hint = hint,
		work = work,
		workFill = workFill,
	}
end

-- Rótulo do botão de usar: "[ E ]   EQUIPAR" (no celular só a palavra).
function Noir.useLabel(word: string, touch: boolean): string
	local spaced = Noir.spaced(word)
	return if touch then spaced else `[ E ]      {spaced}`
end

-- Folha virando: a página encolhe no eixo X, troca o conteúdo (callback) e volta.
function Noir.flip(ui: Ui, swap: () -> ())
	local page = ui.notePage
	local info = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local half = TweenService:Create(page, info, { Size = UDim2.fromOffset(0, 320) })
	half.Completed:Once(function()
		swap()
		local back = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(page, back, { Size = UDim2.fromOffset(340, 320) }):Play()
	end)
	half:Play()
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
