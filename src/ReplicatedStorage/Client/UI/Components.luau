--!strict
--[[
	Componentes reutilizáveis da remaster "Cursed Mansion" (docs/ui-remaster).
	Só apresentação: nenhum componente chama remotes nem decide preço, posse ou recompensa.

	  text / title            rótulos com a tipografia do tema
	  panel                   cartão com canto, contorno sutil e fundo do tema
	  button(variant, ...)    primary | secondary | ghost | success | danger, com hover/pressão/desabilitado
	  icon / iconButton       pictogramas pixel-art (Icons.pixel) e botão com ícone
	  currency                selo de Fichas/Créditos com setter reativo
	  progress                barra de progresso com setter
	  chip                    etiqueta curta de estado (raridade, voto, equipado...)
]]

local Create = require("./Create")
local Icons = require("./Icons")
local Theme = require("./Theme")

export type Variant = "primary" | "secondary" | "ghost" | "success" | "danger"

type Palette = { bg: Color3, text: Color3, stroke: Color3, hover: Color3, bgTransparency: number }

local Components = {}

local PALETTES: { [string]: Palette } = {
	primary = {
		bg = Theme.Gold,
		text = Theme.Bg,
		stroke = Theme.GoldLight,
		hover = Theme.GoldLight,
		bgTransparency = 0,
	},
	secondary = {
		bg = Theme.BgElevated,
		text = Theme.TextPrimary,
		stroke = Theme.Border,
		hover = Theme.BgElevated:Lerp(Theme.Gold, 0.18),
		bgTransparency = 0,
	},
	ghost = {
		bg = Theme.BgElevated,
		text = Theme.TextSecondary,
		stroke = Theme.Border,
		hover = Theme.BgElevated,
		bgTransparency = 1,
	},
	success = {
		bg = Theme.Success:Lerp(Theme.Bg, 0.55),
		text = Theme.TextPrimary,
		stroke = Theme.Success,
		hover = Theme.Success:Lerp(Theme.Bg, 0.4),
		bgTransparency = 0,
	},
	danger = {
		bg = Theme.Danger,
		text = Theme.TextPrimary,
		stroke = Theme.Danger:Lerp(Theme.TextPrimary, 0.3),
		hover = Theme.Danger:Lerp(Theme.TextPrimary, 0.12),
		bgTransparency = 0,
	},
}

local DISABLED: Palette = {
	bg = Theme.BgSunken,
	text = Theme.TextMuted,
	stroke = Theme.Border,
	hover = Theme.BgSunken,
	bgTransparency = 0.1,
}

local function merge(base: { [string]: any }, props: { [string]: any }?): { [string]: any }
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	return base
end

function Components.formatNumber(value: number): string
	local s = tostring(math.floor(value))
	local negative = s:sub(1, 1) == "-"
	if negative then
		s = s:sub(2)
	end
	local result = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	if result:sub(1, 1) == "." then
		result = result:sub(2)
	end
	return if negative then "-" .. result else result
end

function Components.corner(parent: Instance, radius: UDim?): UICorner
	return Create("UICorner", { CornerRadius = radius or Theme.Corner, Parent = parent }) :: UICorner
end

function Components.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Create("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		Transparency = transparency or 0.35,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	}) :: UIStroke
end

function Components.padding(parent: Instance, x: number, y: number?): UIPadding
	return Create("UIPadding", {
		PaddingLeft = UDim.new(0, x),
		PaddingRight = UDim.new(0, x),
		PaddingTop = UDim.new(0, y or x),
		PaddingBottom = UDim.new(0, y or x),
		Parent = parent,
	}) :: UIPadding
end

function Components.text(props: { [string]: any }): TextLabel
	return Create(
		"TextLabel",
		merge({
			BackgroundTransparency = 1,
			FontFace = Theme.FontBody,
			TextColor3 = Theme.TextPrimary,
			TextSize = Theme.SizeBody,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextWrapped = true,
		}, props)
	) :: TextLabel
end

function Components.title(props: { [string]: any }): TextLabel
	return Components.text(merge({ FontFace = Theme.Font, TextSize = Theme.SizeLarge, TextWrapped = false }, props))
end

function Components.panel(props: { [string]: any }?, children: { any }?): Frame
	local panel = Create(
		"Frame",
		merge({ BackgroundColor3 = Theme.BgPanel, BackgroundTransparency = 0.08, BorderSizePixel = 0 }, props),
		children
	) :: Frame
	Components.corner(panel)
	Components.stroke(panel, Theme.Border, 1, 0.55)
	return panel
end

-- Pinta o botão conforme variante e estado. "disabled" ignora cliques (atributo Disabled).
local function paint(button: TextButton, hovered: boolean?)
	local disabled = button:GetAttribute("Disabled") == true
	local variant = tostring(button:GetAttribute("Variant") or "secondary")
	local palette = if disabled then DISABLED else PALETTES[variant] or PALETTES.secondary
	button.BackgroundColor3 = if hovered and not disabled then palette.hover else palette.bg
	button.BackgroundTransparency = if hovered
			and not disabled
			and variant == "ghost"
		then 0.4
		else palette.bgTransparency
	button.TextColor3 = palette.text
	local outline = button:FindFirstChild("Outline")
	if outline and outline:IsA("UIStroke") then
		outline.Color = palette.stroke
		outline.Transparency = if variant == "ghost" and not hovered then 1 else 0.2
	end
	local icon = button:FindFirstChild("IconSlot")
	if icon then
		local holder = icon:FindFirstChildWhichIsA("Frame")
		if holder then
			Icons.tint(holder, palette.text)
		end
	end
end

function Components.setVariant(button: TextButton, variant: Variant)
	button:SetAttribute("Variant", variant)
	paint(button)
end

function Components.setDisabled(button: TextButton, disabled: boolean)
	button:SetAttribute("Disabled", disabled)
	button.Active = not disabled
	paint(button)
end

function Components.button(variant: Variant, props: { [string]: any }, onActivate: (() -> ())?): TextButton
	local button = Create(
		"TextButton",
		merge({
			AutoButtonColor = false,
			BorderSizePixel = 0,
			FontFace = Theme.Font,
			TextSize = Theme.SizeBody,
			TextWrapped = true,
			Size = UDim2.new(1, 0, 0, Theme.TouchMin),
		}, props)
	) :: TextButton
	button:SetAttribute("Variant", variant)
	Components.corner(button, Theme.CornerSmall)
	local outline = Components.stroke(button, nil, 1, 0.2)
	outline.Name = "Outline"
	local scale = Create("UIScale", { Name = "PressScale", Parent = button }) :: UIScale
	button.MouseEnter:Connect(function()
		paint(button, true)
	end)
	button.MouseLeave:Connect(function()
		paint(button, false)
		scale.Scale = 1
	end)
	button.MouseButton1Down:Connect(function()
		if button:GetAttribute("Disabled") ~= true then
			scale.Scale = 0.97
		end
	end)
	button.MouseButton1Up:Connect(function()
		scale.Scale = 1
	end)
	if onActivate then
		button.Activated:Connect(function()
			if button:GetAttribute("Disabled") ~= true then
				onActivate()
			end
		end)
	end
	paint(button)
	return button
end

-- Ícone pixel-art num quadrado `size` (múltiplo de 12 deixa os pixels nítidos).
function Components.icon(parent: Instance, kind: string, size: number, color: Color3, props: { [string]: any }?): Frame
	local slot = Create(
		"Frame",
		merge({
			Name = "IconSlot",
			Size = UDim2.fromOffset(size, size),
			BackgroundTransparency = 1,
		}, props)
	) :: Frame
	Icons.pixel(slot, kind, color)
	slot.Parent = parent
	return slot
end

-- Botão com ícone à esquerda e rótulo; sem rótulo vira botão só de ícone centralizado.
function Components.iconButton(
	variant: Variant,
	kind: string,
	text: string?,
	props: { [string]: any },
	onActivate: (() -> ())?
): TextButton
	local iconSize = (props.IconSize :: number?) or 24
	props.IconSize = nil
	local button = Components.button(variant, merge({ Text = "" }, props), onActivate)
	local hasText = text ~= nil and text ~= ""
	Components.icon(button, kind, iconSize, button.TextColor3, {
		AnchorPoint = if hasText then Vector2.new(0, 0.5) else Vector2.new(0.5, 0.5),
		Position = if hasText then UDim2.new(0, 14, 0.5, 0) else UDim2.fromScale(0.5, 0.5),
	})
	if hasText then
		Components.text({
			Name = "Label",
			Position = UDim2.fromOffset(iconSize + 24, 0),
			Size = UDim2.new(1, -(iconSize + 34), 1, 0),
			FontFace = button.FontFace,
			TextSize = button.TextSize,
			TextColor3 = button.TextColor3,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = text,
			Parent = button,
		})
		-- O rótulo acompanha a cor do texto do botão (estados).
		local label = button:FindFirstChild("Label") :: TextLabel
		button:GetPropertyChangedSignal("TextColor3"):Connect(function()
			label.TextColor3 = button.TextColor3
		end)
	end
	paint(button)
	return button
end

-- Selo de moeda. Retorna o quadro e um setter (valor já formatado com separador de milhar).
function Components.currency(kind: "fichas" | "creditos", props: { [string]: any }?): (Frame, (number) -> ())
	local fichas = kind == "fichas"
	local badge = Create(
		"Frame",
		merge({
			Name = if fichas then "Fichas" else "Creditos",
			Size = UDim2.fromOffset(132, 36),
			BackgroundColor3 = Theme.BgSunken,
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
		}, props)
	) :: Frame
	Components.corner(badge, Theme.CornerPill)
	Components.stroke(badge, if fichas then Theme.Gold else Theme.Info, 1, 0.5)
	Components.icon(badge, if fichas then "Coin" else "Gem", 24, if fichas then Theme.Coin else Theme.Info, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
	})
	local amount = Components.text({
		Name = "Amount",
		Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, -46, 1, 0),
		FontFace = Theme.Font,
		TextSize = 18,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "0",
		Parent = badge,
	})
	local accessible = if fichas then "Fichas" else "Créditos"
	local function set(value: number)
		local formatted = Components.formatNumber(value)
		amount.Text = formatted
		badge:SetAttribute("Value", value)
		badge:SetAttribute("Label", `{formatted} {accessible}`)
	end
	set(0)
	return badge, set
end

function Components.progress(props: { [string]: any }?, color: Color3?): (Frame, (number) -> ())
	local track = Create(
		"Frame",
		merge({
			Name = "Progress",
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Theme.BgSunken,
			BorderSizePixel = 0,
		}, props)
	) :: Frame
	Components.corner(track, Theme.CornerPill)
	local fill = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = color or Theme.Gold,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	Components.corner(fill, Theme.CornerPill)
	local function set(fraction: number)
		fill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	end
	return track, set
end

function Components.chip(text: string, color: Color3, props: { [string]: any }?): Frame
	local chip = Create(
		"Frame",
		merge({
			Name = "Chip",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 24),
			BackgroundColor3 = color:Lerp(Theme.Bg, 0.7),
			BorderSizePixel = 0,
		}, props)
	) :: Frame
	Components.corner(chip, Theme.CornerPill)
	Components.stroke(chip, color, 1, 0.3)
	Components.padding(chip, 10, 0)
	Components.text({
		Name = "Label",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		FontFace = Theme.Font,
		TextSize = 13,
		TextColor3 = color:Lerp(Theme.TextPrimary, 0.35),
		TextWrapped = false,
		Text = text,
		Parent = chip,
	})
	return chip
end

return Components
