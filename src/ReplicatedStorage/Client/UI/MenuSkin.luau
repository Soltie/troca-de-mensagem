--!strict
--[[
	Pele "Casa de Madeira" para o conteúdo das abas do menu inicial (JOGAR, MELHORIAS, SERVIDORES, AMIGOS).

	As abas continuam montadas pelos mesmos construtores (mesmos botões, remotes e atributos); esta pele só
	troca a aparência depois de montar: painéis azul-ardósia viram madeira quase preta, contornos viram brasa
	apagada e a fonte arredondada (infantil) vira Montserrat. Ícones pixel art somem quando há texto ao lado
	(ficam só os botões que são apenas ícone, como fechar).
	Os botões do tema também mudam: a pele escuta as trocas de cor do hover (Components.paint) e converte de novo.
]]

local Theme = require("./Theme")

local MenuSkin = {}

local rgb = Color3.fromRGB

-- Paleta da página "Menu da Casa de Madeira" (painéis da loja, temporada, ajustes e caçada).
local PANEL = rgb(34, 26, 20)
local LINE = rgb(61, 48, 39)
local INK = rgb(234, 220, 203)
local MUTED = rgb(173, 150, 130)
local EMBER = rgb(226, 114, 63)
local GOLD = rgb(217, 174, 74)

-- Fundo antigo -> fundo novo (madeira escura, quente, sem azul nem verde). Vale também para os botões do tema,
-- que se repintam no hover/clique (Components.paint): a pele escuta a troca de cor e converte de novo.
local BACKGROUNDS: { { from: Color3, to: Color3 } } = {
	{ from = Theme.Bg, to = rgb(22, 17, 13) },
	{ from = Theme.BgPanel, to = PANEL },
	{ from = Theme.BgElevated, to = rgb(46, 36, 28) },
	{ from = Theme.BgElevated:Lerp(Theme.Gold, 0.18), to = rgb(66, 50, 36) },
	{ from = Theme.BgSunken, to = rgb(16, 12, 10) },
	{ from = Theme.Overlay, to = rgb(6, 5, 4) },
	{ from = Theme.Gold, to = GOLD },
	{ from = Theme.GoldLight, to = rgb(232, 196, 112) },
	-- Verde de "sucesso/equipado" vira brasa; azul de informação (gema dos Créditos) vira ouro.
	{ from = Theme.Success:Lerp(Theme.Bg, 0.55), to = rgb(74, 40, 24) },
	{ from = Theme.Success:Lerp(Theme.Bg, 0.4), to = rgb(96, 50, 28) },
	{ from = Theme.Success, to = EMBER },
	{ from = Theme.Info, to = GOLD },
}
-- Cores de texto e contorno que ainda puxam para o azul/verde do tema antigo.
local INKS: { { from: Color3, to: Color3 } } = {
	{ from = Theme.TextPrimary, to = INK },
	{ from = Theme.TextSecondary, to = MUTED },
	{ from = Theme.TextMuted, to = MUTED },
	{ from = Theme.Success, to = EMBER },
	{ from = Theme.Info, to = GOLD },
	{ from = Theme.Gold, to = GOLD },
	{ from = Theme.Border, to = LINE },
}

local FONT_TITLE = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold)
local FONT_TEXT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium)
local SERIF = "rbxasset://fonts/families/Merriweather.json"

local function close(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.02
end

local function remap(color: Color3, list: { { from: Color3, to: Color3 } }): Color3?
	for _, pair in list do
		if close(color, pair.from) then
			return pair.to
		end
	end
	return nil
end

-- Pinta agora e de novo sempre que o dono da peça trocar a cor (hover, estado, atualização ao vivo).
local function keep(item: Instance, property: string, list: { { from: Color3, to: Color3 } })
	local function apply()
		local to = remap((item :: any)[property], list)
		if to then
			(item :: any)[property] = to
		end
	end
	apply()
	item:GetPropertyChangedSignal(property):Connect(apply)
end

-- Ícone pixel art (Components.icon) ao lado de texto: some. Em botão só de ícone (fechar, +) fica, tingido.
local function hideIcon(item: Instance)
	if item.Name ~= "IconSlot" or not item:IsA("GuiObject") then
		return
	end
	local owner = item.Parent
	local iconOnly = owner ~= nil
		and owner:IsA("TextButton")
		and owner.Text == ""
		and owner:FindFirstChildWhichIsA("TextLabel") == nil
	-- Ícone em imagem (IconAssets, arte do Artista 3D) fica; só o desenho em pixels some.
	if not iconOnly and item:FindFirstChildWhichIsA("ImageLabel") == nil then
		item.Visible = false
	end
end

local function skin(item: Instance, minSize: number, grow: number)
	hideIcon(item)
	if item:IsA("GuiObject") then
		keep(item, "BackgroundColor3", BACKGROUNDS)
	end
	if item:IsA("ImageLabel") and string.sub(item.Name, 1, 5) == "Icon_" then
		-- Ícones do Artista 3D: a cor do tema antigo (azul da gema, verde) vira ouro e brasa.
		keep(item, "ImageColor3", INKS)
	end
	if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
		local text = item :: any
		local family = text.FontFace.Family
		-- Só duas famílias no menu: Montserrat (tudo) e Merriweather (logo e frases). O resto vira Montserrat.
		if family ~= FONT_TITLE.Family and family ~= SERIF then
			local bold = text.FontFace.Weight.Value >= Enum.FontWeight.SemiBold.Value or family == Theme.Font.Family
			text.FontFace = if bold or text.TextSize >= 20 then FONT_TITLE else FONT_TEXT
			-- Ajuste opcional de tamanho na troca de fonte (Montserrat tem a largura da fonte antiga).
			text.TextSize += grow
		end
		-- Nunca abaixo do mínimo da tela (16 no celular).
		if not text.TextScaled and text.TextSize < minSize then
			text.TextSize = minSize
		end
		keep(item, "TextColor3", INKS)
	elseif item:IsA("UIStroke") then
		keep(item, "Color", INKS)
		if close(item.Color, LINE) then
			item.Transparency = math.max(item.Transparency, 0.55)
		end
	end
end

-- Aplica em `root` e em tudo que for criado dentro dele depois (listas que chegam do servidor, por exemplo).
-- `minSize`: menor tamanho de texto aceito (16 no celular). `grow`: px somados ao trocar a fonte (padrão 0).
function MenuSkin.apply(root: Instance, minSize: number?, grow: number?): RBXScriptConnection
	local floor = minSize or 0
	local extra = grow or 0
	skin(root, floor, extra)
	for _, item in root:GetDescendants() do
		skin(item, floor, extra)
	end
	return root.DescendantAdded:Connect(function(item)
		-- Um quadro depois: o construtor termina de ajustar as propriedades antes da pele.
		task.defer(skin, item, floor, extra)
	end)
end

return MenuSkin
