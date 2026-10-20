--!strict
--[[
	Menu inicial (lobby da campanha). Substitui o antigo ModeMenuController.
	Remaster "Cursed Mansion" (docs/ui-remaster): barra superior com perfil e moedas, trilho de
	navegação com ícones próprios (no celular: 4 destinos + MAIS) e cartões de campanha ilustrados.
	O layout é reconstruído só quando a classe da tela muda (MenuLayout.mode), não a cada quadro.

	  Topo      logo, Fichas, Créditos (+ abre CRÉDITOS na loja), avatar, nível e XP.
	  Trilho    JOGAR em destaque e os demais destinos.
	  Painel    conteúdo da aba:
	    JOGAR       votar História ou Co-op, equipe no servidor, contagem, kit do turno e bônus;
	    MELHORIAS   vantagens permanentes (5 níveis), consumíveis e pacotes em Robux;
	    SERVIDORES  lista de servidores (LobbyService) com ENTRAR;
	    AMIGOS      amigos online (entrar no servidor deles) e convite;
	    LOJA / PASSE / RECOMPENSAS abrem a loja (StoreController) na aba certa.
	  Fundo     câmeras de segurança ao vivo (CinematicController, laço Attract) atrás de um véu.

	Nada é decidido aqui: votos (SelectGameMode), compras (Store) e teleporte (Lobby) passam por
	remotes validados no servidor. O estado vem dos atributos publicados (StoreService, CampaignRuntime).
	Na primeira entrada o menu espera a abertura do jogo (atributo OpeningActive).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Season = require("@game/ReplicatedStorage/Shared/Game/Season")
local SeasonCatalog = require("@game/ReplicatedStorage/Shared/Game/SeasonCatalog")
local StoryRewards = require("@game/ReplicatedStorage/Shared/Game/StoryRewards")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Components = require("../UI/Components")
local DifficultyPanel = require("../UI/DifficultyPanel")
local Create = require("../UI/Create")
local MenuLayout = require("../UI/MenuLayout")
local Theme = require("../UI/Theme")
local ViewportQA = require("../UI/ViewportQA")
local AudioController = require("./AudioController")
local Cinema = require("./CinematicController")
local Store = require("./StoreController")
local Settings = require("./SettingsController")
local Camera = require("./CameraController")
local MenuSkin = require("../UI/MenuSkin")
local MenuStage = require("../UI/MenuStage")

type TabId = "home" | "play" | "skins" | "perks" | "store" | "season" | "daily" | "servers" | "friends" | "settings"

local player = Players.LocalPlayer
local log = Logger.new("MainMenu")
local GREEN = Theme.Success
local CARD = Theme.BgPanel
-- Menu preto (página "Menu da Casa de Madeira"): osso sobre preto, brasa só no foco, logo em serifa cor de osso.
local BONE = Color3.fromRGB(233, 223, 210)
local BONE_DIM = Color3.fromRGB(138, 123, 109)
local EMBER = Color3.fromRGB(226, 114, 63)
local BRASS = Color3.fromRGB(201, 160, 92)
local CARD_EDGE = Color3.fromRGB(122, 74, 46)
local LOGO_FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular)
local MENU_FONT = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Medium)
local MENU_FONT_BOLD = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.SemiBold)
local TIP_FONT = Font.new("rbxasset://fonts/families/Merriweather.json", Enum.FontWeight.Regular, Enum.FontStyle.Italic)

-- `short` é o rótulo da coluna no celular. No celular os 4 primeiros ficam à vista e o resto vai para MAIS.
local NAV: { { id: TabId, label: string, short: string, icon: string } } = {
	{ id = "play", label = "JOGAR", short = "JOGAR", icon = "Play" },
	{ id = "store", label = "LOJA", short = "LOJA", icon = "Store" },
	{ id = "skins", label = "SKINS", short = "SKINS", icon = "Store" },
	{ id = "season", label = "PASSE DE BATALHA", short = "PASSE", icon = "Season" },
	{ id = "perks", label = "MELHORIAS", short = "MELHORIAS", icon = "Perks" },
	{ id = "daily", label = "PRÊMIO DIÁRIO", short = "PRÊMIOS", icon = "Daily" },
	{ id = "servers", label = "SERVIDORES", short = "SERVIDORES", icon = "Servers" },
	{ id = "friends", label = "AMIGOS", short = "AMIGOS", icon = "Friends" },
	{ id = "settings", label = "AJUSTES", short = "AJUSTES", icon = "Settings" },
}
-- Abas que só abrem a loja (SKINS = loja filtrada em uniformes).
local STORE_TABS: { [string]: string } = { store = "shop", skins = "shop", season = "season", daily = "daily" }
local STORE_KIND: { [string]: string } = { skins = "uniform" }
-- Frases do rodapé (uma por vez): dicas na voz da casa.
local TIPS = {
	"Não deixe a lamparina apagar.",
	"Ouviu tum, tum, tum? Apague a lanterna e se esconda.",
	"Agachado, a madeira range menos.",
	"Se alguém cair, chegue perto e levante. Ninguém fica para trás.",
	"Moeda que brilha vira ficha. A gema roxa vale muito mais.",
	"Tem fita escondida nesta casa. Ache, e o time todo ganha.",
	"Em grupo é mais fácil. E menos solitário.",
}
-- Quem fala no rodapé (como na página do menu).
local TIP_AUTHOR = "Dona Cida"

local Controller = { Name = "MainMenuController" }

local gui: ScreenGui? = nil
local body: Frame? = nil
local header: TextLabel? = nil
local subheader: TextLabel? = nil
local feedback: TextLabel? = nil
local navButtons: { [string]: TextButton } = {}
-- Atualizações contínuas da moldura (moedas, nível, selos, dica); trocadas a cada reconstrução.
local frameUpdates: { (number) -> () } = {}
local menuMode: MenuLayout.Mode? = nil
local columnsShown = 0
local bodyTop = 66
-- Ação do diálogo de confirmação aberto (QA no Studio confirma pelo atributo MenuQARequest).
local pendingConfirm: (() -> ())? = nil
local rootFrame: Frame? = nil
local rootScale: UIScale? = nil
local currentTab: TabId = "home"
local dirty = true
local live: { () -> () } = {}
local busy = false
local feedbackToken = 0
local serverCache: { [string]: any }? = nil
local friendsCache: { any }? = nil
local friendsError: string? = nil
local lastServerFetch = 0
local wasOpen = false
local tipIndex = 1
local compactMenu = false
-- Palco 3D (UI/MenuStage) atrás de tudo, painel de conteúdo e a borda direita do trilho (unidades do Root).
local stage: MenuStage.Stage? = nil
local contentPanel: Frame? = nil
local railRight = 0
local brandScale: UIScale? = nil
-- Só aparecem na tela inicial (sem aba aberta): passe de batalha e skin em destaque.
local homeOnly: { GuiObject } = {}
-- Definida com a coluna do menu (mais abaixo); o renderTab repinta os botões.
local paintNav: (id: string, hovered: boolean?) -> ()

-- A fonte do tema (FredokaOne) tem acentos; o texto passa direto.
local function px(value: string): string
	return value
end

local function campaign(): Instance?
	return ReplicatedStorage:FindFirstChild("CampaignState")
end

local function json(name: string, fallback: any): any
	local raw = player:GetAttribute(name)
	if type(raw) ~= "string" then
		return fallback
	end
	local ok, value = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok then value else fallback
end

local function number(value: number): string
	local s = tostring(math.floor(value))
	local result = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return if result:sub(1, 1) == "." then result:sub(2) else result
end

local function clock(seconds: number): string
	local total = math.max(0, math.floor(seconds))
	if total >= 3600 then
		return string.format("%d:%02d:%02d", total // 3600, (total // 60) % 60, total % 60)
	end
	return string.format("%02d:%02d", total // 60, total % 60)
end

-- ===================== Construção =====================

local function label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Theme.TextPrimary,
		TextSize = Theme.SizeBody,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	if type(base.Text) == "string" and base.FontFace == Theme.Font then
		base.Text = px(base.Text)
	end
	return Create("TextLabel", base) :: TextLabel
end

-- Texto corrido em máquina de escrever (acentos completos).
local function note(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		TextColor3 = Theme.TextSecondary,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	return Create("TextLabel", base) :: TextLabel
end

local function frame(props: { [string]: any }, children: { any }?): Frame
	local base: { [string]: any } = { BorderSizePixel = 0, BackgroundColor3 = CARD }
	for key, value in props do
		base[key] = value
	end
	local result = Create("Frame", base, children) :: Frame
	-- Cartões visíveis ganham o canto do tema; contêineres transparentes ficam como estão.
	if result.BackgroundTransparency < 1 and not result:FindFirstChildOfClass("UICorner") then
		Components.corner(result, Theme.CornerSmall)
	end
	return result
end

local function click()
	AudioController.play("UiBlip", 0.5, 1.1, true)
end

-- Botão do tema. `Variant` escolhe o estilo; `Accent = GREEN` (legado) vira "success".
-- Cor de fundo avulsa é ignorada: o estado visual vem da variante (normal/hover/pressão/desabilitado).
local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local variant: Components.Variant = props.Variant or (if props.Accent == GREEN then "success" else "secondary")
	props.Variant, props.Accent, props.BackgroundColor3, props.BackgroundTransparency = nil, nil, nil, nil
	if type(props.Text) == "string" then
		props.Text = px(props.Text)
	end
	return Components.button(variant, props, function()
		click()
		onClick()
	end)
end

local function say(key: string?)
	local f = feedback
	if not f then
		return
	end
	feedbackToken += 1
	local token = feedbackToken
	local message = if key then (Text.Messages :: any)[key] or key else ""
	f.Text = px(message)
	f.Visible = message ~= ""
	task.delay(4, function()
		if token == feedbackToken and feedback then
			feedback.Visible = false
		end
	end)
end

-- Remote com envelope { ok, data | error }. Retorna (data, chave de erro).
local function invoke(name: string, ...: any): (any, string?)
	if busy then
		return nil, "wait"
	end
	busy = true
	local args = table.pack(...)
	local ok, result = pcall(function()
		return Remotes.clientFunction(name, 5):InvokeServer(table.unpack(args, 1, args.n))
	end)
	busy = false
	if not ok or type(result) ~= "table" then
		return nil, "store_error"
	end
	if not result.ok then
		return nil, if result.error == "rate_limited" then "wait" else "store_error"
	end
	return result.data, nil
end

local function store(action: string, arg: string?): any
	local data, err = invoke("Store", action, arg)
	if err then
		say(err)
		return nil
	end
	if type(data) == "table" and data.message then
		say(data.message)
	end
	dirty = true
	return data
end

local function buyProduct(key: string)
	local product = StoreCatalog.ProductByKey[key]
	if not product or product.id <= 0 then
		say("INDISPONÍVEL NESTA BUILD")
		return
	end
	store("buy_product", key)
end

-- ===================== Abas =====================

local function clearBody(): Frame?
	local b = body
	if not b then
		return nil
	end
	for _, child in b:GetChildren() do
		child:Destroy()
	end
	live = {}
	return b
end

local function storyCleared(): ({ [number]: boolean }, { [number]: boolean })
	local progress = json("StoryProgress", {})
	local cleared, flawless = {}, {}
	for _, chapter in (if type(progress.cleared) == "table" then progress.cleared else {}) do
		cleared[tonumber(chapter) or 0] = true
	end
	for _, chapter in (if type(progress.flawless) == "table" then progress.flawless else {}) do
		flawless[tonumber(chapter) or 0] = true
	end
	return cleared, flawless
end

-- Recompensa da próxima vitória de capítulo (o primeiro ainda não vencido, ou o 1 de novo).
local function storyPreview(): (number, string)
	local cleared = storyCleared()
	local chapter = 1
	for c = 1, #StoryRewards.Chapters do
		if not cleared[c] then
			chapter = c
			break
		end
	end
	local def = StoryRewards.Chapters[chapter]
	local first = not cleared[chapter]
	local reward = if first then def.first else def.again
	local multiplier = if player:GetAttribute("StoryPass") == true then StoryRewards.PassMultiplier else 1
	local parts = { `+{number((reward.fichas or 0) * multiplier)} FICHAS` }
	if (reward.creditos or 0) > 0 then
		table.insert(parts, `+{number((reward.creditos or 0) * multiplier)} CRÉDITOS`)
	end
	if reward.item then
		local entry = StoreCatalog.ItemById[reward.item]
		table.insert(parts, if entry then entry.name else reward.item)
	end
	return chapter, table.concat(parts, " · ")
end

local function effectText(id: string, level: number): string
	local factor = Perks.factor(id, level)
	local percent = math.floor(math.abs(factor - 1) * 100 + 0.5)
	if id == "bateria" then
		return `+{percent}% DE BATERIA`
	elseif id == "folego" then
		return `+{percent}% DE FÔLEGO`
	elseif id == "socorro" then
		return `-{percent}% TEMPO DE RESGATE`
	end
	return `-{percent}% DE BARULHO`
end

-- Ícone e cor de cada melhoria/consumível (pictogramas próprios do Icons).
local PERK_LOOK: { [string]: { icon: string, color: Color3 } } = {
	bateria = { icon = "Battery", color = Theme.Gold },
	folego = { icon = "Lungs", color = Theme.Info },
	socorro = { icon = "Medkit", color = Color3.fromRGB(224, 104, 104) },
	silencio = { icon = "Steps", color = Theme.Success },
	segunda_chance = { icon = "Heart", color = Color3.fromRGB(224, 104, 104) },
	pilha_extra = { icon = "Battery", color = Theme.Gold },
	continuar = { icon = "Replay", color = Theme.Info },
}

local function walletOf(currency: string): number
	return tonumber(player:GetAttribute(if currency == "fichas" then "Fichas" else "Creditos")) or 0
end

local function priceText(currency: string, price: number): string
	return `{number(price)} {if currency == "fichas" then "FICHAS" else "CRÉDITOS"}`
end

-- Diálogo de confirmação do menu (compras com Fichas/Créditos). Tocar fora cancela.
local function confirmDialog(title: string, message: string, confirmText: string, onConfirm: () -> ())
	local root = rootFrame
	if not root then
		return
	end
	local old = root:FindFirstChild("Confirm")
	if old then
		old:Destroy()
	end
	local holder = Create("Frame", {
		Name = "Confirm",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = root,
	}) :: Frame
	local dismiss = Create("TextButton", {
		Name = "Dismiss",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Overlay,
		BackgroundTransparency = 0.35,
		AutoButtonColor = false,
		Text = "",
		Parent = holder,
	}) :: TextButton
	dismiss.Activated:Connect(function()
		holder:Destroy()
	end)
	pendingConfirm = function()
		holder:Destroy()
		onConfirm()
	end
	holder.Destroying:Connect(function()
		pendingConfirm = nil
	end)
	local box = Components.panel({
		Name = "Box",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(if compactMenu then 340 else 440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.BgPanel,
		BackgroundTransparency = 0,
		Active = true,
		Parent = holder,
	})
	local outline = box:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color, outline.Transparency = Theme.Gold, 0.3
	end
	Components.padding(box, 18)
	Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
	Components.title({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = title,
		TextSize = 20,
		LayoutOrder = 1,
		Parent = box,
	})
	note({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = message,
		TextSize = 15,
		LayoutOrder = 2,
		Parent = box,
	})
	local row = Create("Frame", {
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, Theme.TouchMin),
		BackgroundTransparency = 1,
		LayoutOrder = 3,
		Parent = box,
	})
	button({
		Name = "Cancel",
		Variant = "secondary",
		Size = UDim2.new(0.5, -5, 1, 0),
		Text = "CANCELAR",
		TextSize = 16,
		Parent = row,
	}, function()
		holder:Destroy()
	end)
	button({
		Name = "Confirm",
		Variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -5, 1, 0),
		Text = confirmText,
		TextSize = 16,
		Parent = row,
	}, function()
		holder:Destroy()
		onConfirm()
	end)
end

-- Botão de preço: mostra a moeda com ícone; sem saldo fica desativado e diz quanto falta.
local function priceButton(
	parent: Instance,
	currency: string,
	price: number,
	props: { [string]: any },
	onBuy: () -> ()
): TextButton
	local have = walletOf(currency)
	local affordable = have >= price
	local fichas = currency == "fichas"
	props.Text = if affordable then priceText(currency, price) else `FALTAM {priceText(currency, price - have)}`
	props.Variant = if fichas then "primary" else "secondary"
	props.TextSize = props.TextSize or 14
	local b = button(props, onBuy)
	-- Espaço para o ícone da moeda à esquerda sem sobrepor o texto centralizado.
	Create("UIPadding", { PaddingLeft = UDim.new(0, 30), PaddingRight = UDim.new(0, 6), Parent = b })
	local icon = Components.icon(b, if fichas then "Coin" else "Gem", 24, if fichas then Theme.Coin else Theme.Info, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, -22, 0.5, 0),
	})
	icon.Name = "Currency"
	Components.setDisabled(b, not affordable)
	b.Parent = parent
	return b
end

local function cardShell(
	parent: Instance,
	name: string,
	order: number,
	height: number,
	look: { icon: string, color: Color3 }
): Frame
	local card = Components.panel({
		Name = name,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		Parent = parent,
	})
	Components.padding(card, 12)
	local tile = Create("Frame", {
		Name = "IconTile",
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = look.color:Lerp(Theme.Bg, 0.75),
		BorderSizePixel = 0,
		Parent = card,
	})
	Components.corner(tile, Theme.CornerSmall)
	Components.stroke(tile, look.color, 1, 0.4)
	Components.icon(tile, look.icon, 36, look.color, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})
	return card
end

local function sectionHeader(parent: Instance, order: number, title: string, subtitle: string)
	local box = Create("Frame", {
		Name = `Section_{order}`,
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = parent,
	})
	label({ Size = UDim2.new(1, 0, 0, 22), Text = title, TextSize = 18, TextColor3 = Theme.Gold, Parent = box })
	note({
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 18),
		Text = subtitle,
		TextSize = 13,
		Parent = box,
	})
end

local function buildPerks(b: Frame)
	local width = b.AbsoluteSize.X
	local columns = if width >= 640 then 2 else 1

	local scroll = Create("ScrollingFrame", {
		Name = "PerksScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = b,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
	}) :: ScrollingFrame
	local levels = json("Perks", {})
	local stock = json("Consumables", {})
	local loadout: { [string]: boolean } = {}
	for _, id in json("Loadout", {}) do
		loadout[tostring(id)] = true
	end

	local function grid(order: number, cellHeight: number): Frame
		return Create("Frame", {
			Name = `Grid_{order}`,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = scroll,
		}, {
			Create("UIGridLayout", {
				CellSize = UDim2.new(1 / columns, if columns == 2 then -5 else 0, 0, cellHeight),
				CellPadding = UDim2.fromOffset(10, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		}) :: Frame
	end

	sectionHeader(scroll, 1, "MELHORIAS PERMANENTES", "Valem em todas as partidas. Cada uma tem 5 níveis.")
	local perkGrid = grid(2, 196)
	for i, perk in Perks.List do
		local level = math.clamp(tonumber(levels[perk.id]) or 0, 0, Perks.MAX_LEVEL)
		local look = PERK_LOOK[perk.id] or { icon = "Perks", color = Theme.Gold }
		local card = cardShell(perkGrid, `Perk_{perk.id}`, i, 196, look)
		card:SetAttribute("Level", level)
		label({
			Name = "PerkName",
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.new(1, -64, 0, 22),
			Text = perk.name,
			TextSize = 17,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		note({
			Position = UDim2.fromOffset(64, 24),
			Size = UDim2.new(1, -64, 0, 30),
			Text = perk.description,
			TextSize = 13,
			Parent = card,
		})
		-- Nível em 5 etapas + rótulo (não depende só de cor).
		local steps = Create("Frame", {
			Name = "Levels",
			Position = UDim2.fromOffset(0, 62),
			Size = UDim2.new(1, -86, 0, 10),
			BackgroundTransparency = 1,
			Parent = card,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		for step = 1, Perks.MAX_LEVEL do
			local segment = Create("Frame", {
				LayoutOrder = step,
				Size = UDim2.new(1 / Perks.MAX_LEVEL, -4, 1, 0),
				BackgroundColor3 = if step <= level then look.color else Theme.BgSunken,
				BorderSizePixel = 0,
				Parent = steps,
			})
			Components.corner(segment, Theme.CornerPill)
		end
		label({
			Name = "LevelText",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 0, 0, 56),
			Size = UDim2.fromOffset(80, 22),
			Text = `NÍVEL {level}/{Perks.MAX_LEVEL}`,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = look.color,
			Parent = card,
		})
		local now = if level > 0 then effectText(perk.id, level) else "SEM EFEITO"
		label({
			Name = "Effect",
			Position = UDim2.fromOffset(0, 82),
			Size = UDim2.new(1, 0, 0, 36),
			Text = if level >= Perks.MAX_LEVEL
				then `AGORA: {now} · NÍVEL MÁXIMO`
				else `AGORA: {now}\nPRÓXIMO: {effectText(perk.id, level + 1)}`,
			TextSize = 13,
			TextColor3 = GREEN,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = card,
		})
		local actions = Create("Frame", {
			Name = "Actions",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, Theme.TouchMin),
			BackgroundTransparency = 1,
			Parent = card,
		})
		if level >= Perks.MAX_LEVEL then
			local done = button(
				{ Variant = "success", Size = UDim2.fromScale(1, 1), Text = "NÍVEL MÁXIMO", Parent = actions },
				function() end
			)
			Components.setDisabled(done, true)
		else
			for column, currency in { "fichas", "creditos" } do
				local price = Perks.nextCost(perk.id, level, currency :: Perks.Currency) or 0
				priceButton(actions, currency, price, {
					Name = if currency == "fichas" then "UpgradeFichas" else "UpgradeCreditos",
					Position = UDim2.new((column - 1) * 0.5, if column == 1 then 0 else 5, 0, 0),
					Size = UDim2.new(0.5, -5, 1, 0),
				}, function()
					confirmDialog(
						`MELHORAR {perk.name}?`,
						`Nível {level + 1}: {effectText(perk.id, level + 1)}. Custa {priceText(currency, price)}; você fica com {priceText(
							currency,
							walletOf(currency) - price
						)}.`,
						"MELHORAR",
						function()
							store(if currency == "fichas" then "upgrade_fichas" else "upgrade_creditos", perk.id)
						end
					)
				end)
			end
		end
	end

	sectionHeader(
		scroll,
		3,
		"CONSUMÍVEIS PARA A PARTIDA",
		"Compre aqui; coloque na mochila para usar sozinho na partida (aba JOGAR)."
	)
	local itemGrid = grid(4, 264)
	for i, def in Perks.Consumables do
		local count = tonumber(stock[def.id]) or 0
		local on = loadout[def.id] == true
		local look = PERK_LOOK[def.id] or { icon = "Backpack", color = Theme.Gold }
		local card = cardShell(itemGrid, `Consumable_{def.id}`, i, 264, look)
		card:SetAttribute("Count", count)
		label({
			Name = "ItemName",
			Position = UDim2.fromOffset(64, 0),
			Size = UDim2.new(1, -64, 0, 22),
			Text = def.name,
			TextSize = 17,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})
		local stateText, stateColor = "FORA DA MOCHILA", Theme.TextSecondary
		if count <= 0 then
			stateText, stateColor = "SEM ESTOQUE", Theme.TextMuted
		elseif not def.loadout then
			stateText, stateColor = "USO NO BOTÃO CONTINUAR", Theme.Info
		elseif on then
			stateText, stateColor = "NA MOCHILA", GREEN
		end
		local chips = Create("Frame", {
			Name = "Chips",
			Position = UDim2.fromOffset(64, 26),
			Size = UDim2.new(1, -64, 0, 24),
			BackgroundTransparency = 1,
			Parent = card,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		Components.chip(`VOCÊ TEM {count}`, look.color, { LayoutOrder = 1, Parent = chips })
		Components.chip(stateText, stateColor, { LayoutOrder = 2, Parent = chips })
		note({
			Position = UDim2.fromOffset(0, 60),
			Size = UDim2.new(1, 0, 0, 34),
			Text = def.description,
			TextSize = 13,
			Parent = card,
		})
		label({
			Position = UDim2.fromOffset(0, 96),
			Size = UDim2.new(1, 0, 0, 18),
			Text = if def.bundle > 1 then `CADA COMPRA: {def.bundle} UNIDADES` else "CADA COMPRA: 1 UNIDADE",
			TextSize = 12,
			TextColor3 = Theme.TextSecondary,
			Parent = card,
		})
		local full = count + def.bundle > Perks.MAX_STOCK
		local buyRow = Create("Frame", {
			Name = "Buy",
			Position = UDim2.new(0, 0, 1, -(2 * Theme.TouchMin + 8)),
			Size = UDim2.new(1, 0, 0, Theme.TouchMin),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local options: { { currency: string, price: number } } = {}
		if def.fichas then
			table.insert(options, { currency = "fichas", price = def.fichas })
		end
		if def.creditos then
			table.insert(options, { currency = "creditos", price = def.creditos })
		end
		for index, option in options do
			local share = 1 / #options
			local buyButton = priceButton(buyRow, option.currency, option.price, {
				Name = if option.currency == "fichas" then "BuyFichas" else "BuyCreditos",
				Position = UDim2.new(share * (index - 1), if index == 1 then 0 else 5, 0, 0),
				Size = UDim2.new(share, if #options > 1 then -5 else 0, 1, 0),
			}, function()
				confirmDialog(
					`COMPRAR {def.name}?`,
					`Recebe {def.bundle} {if def.bundle > 1 then "unidades" else "unidade"}. Custa {priceText(
						option.currency,
						option.price
					)}; você fica com {priceText(option.currency, walletOf(option.currency) - option.price)}.`,
					"COMPRAR",
					function()
						store(
							if option.currency == "fichas" then "consumable_fichas" else "consumable_creditos",
							def.id
						)
					end
				)
			end)
			if full then
				buyButton.Text = `ESTOQUE CHEIO ({Perks.MAX_STOCK})`
				Components.setDisabled(buyButton, true)
			end
		end
		-- Ativação separada da compra: só itens de mochila com estoque.
		local toggleRow = Create("Frame", {
			Name = "Loadout",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, Theme.TouchMin),
			BackgroundTransparency = 1,
			Parent = card,
		})
		local toggle = button({
			Name = "Toggle",
			Variant = if on and count > 0 then "success" elseif def.loadout and count > 0 then "secondary" else "ghost",
			Size = UDim2.fromScale(1, 1),
			Text = if not def.loadout
				then "APARECE QUANDO O TIME PERDER"
				elseif count <= 0 then "COMPRE PARA USAR NA MOCHILA"
				elseif on then "NA MOCHILA · TOCAR PARA TIRAR"
				else "COLOCAR NA MOCHILA",
			TextSize = 14,
			Parent = toggleRow,
		}, function()
			if def.loadout and count > 0 then
				store(if on then "loadout_off" else "loadout_on", def.id)
			end
		end)
		Components.setDisabled(toggle, not def.loadout or count <= 0)
	end

	-- Pacotes em Robux só aparecem quando o produto existe no Creator Hub (ID publicado).
	local keys = {
		"kit_sobrevivente",
		"segunda_chance_3",
		"segunda_chance_10",
		"pilhas_10",
		"bonus_fichas_1h",
		"bonus_duplo_3h",
		"arquivo_elias",
		"creditos_550",
		"creditos_1200",
		"creditos_2800",
	}
	local sellable = {}
	for _, key in keys do
		local product = StoreCatalog.ProductByKey[key]
		if product and product.id > 0 then
			table.insert(sellable, product)
		end
	end
	if #sellable > 0 then
		sectionHeader(scroll, 5, "PACOTES EM ROBUX", "Compra pela janela oficial do Roblox.")
		local packs = grid(6, 132)
		for i, product in sellable do
			local card = Components.panel({ Name = `Product_{product.key}`, LayoutOrder = i, Parent = packs })
			Components.padding(card, 10)
			label({ Size = UDim2.new(1, 0, 0, 22), Text = product.name, TextSize = 15, Parent = card })
			note({
				Position = UDim2.fromOffset(0, 24),
				Size = UDim2.new(1, 0, 0, 40),
				Text = product.description,
				TextSize = 12,
				Parent = card,
			})
			button({
				Name = "Buy",
				Variant = "success",
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, Theme.TouchMin),
				Text = `R$ {product.robux}`,
				Parent = card,
			}, function()
				buyProduct(product.key)
			end)
		end
	end
end

local PHASE_NAMES: { [string]: string } = {
	Lobby = "NO LOBBY",
	Playing = "EM PARTIDA",
	Intermission = "ENTRE ETAPAS",
	Extracting = "FUGINDO",
	Won = "TERMINANDO",
	Lost = "TERMINANDO",
}

local function fetchServers()
	lastServerFetch = os.clock()
	task.spawn(function()
		local data, err = invoke("Lobby", "servers")
		if err then
			say(err)
			return
		end
		serverCache = data
		if currentTab == "servers" then
			dirty = true
		end
	end)
end

-- Lista rolável padrão das abas sociais (uma única rolagem vertical).
local function socialList(parent: Instance, top: number): ScrollingFrame
	return Create("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, top),
		Size = UDim2.new(1, 0, 1, -top),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = parent,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10) }),
	}) :: ScrollingFrame
end

-- Estado vazio/aviso com ícone: explica o que acontece e o que fazer, sem botão falso.
local function emptyState(parent: Instance, icon: string, title: string, message: string)
	local box = Components.panel({ Name = "Empty", Size = UDim2.new(1, 0, 0, 92), LayoutOrder = 0, Parent = parent })
	Components.padding(box, 14)
	Components.icon(box, icon, 36, Theme.TextMuted, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
	})
	label({
		Position = UDim2.fromOffset(52, 4),
		Size = UDim2.new(1, -52, 0, 22),
		Text = title,
		TextSize = 16,
		Parent = box,
	})
	note({
		Position = UDim2.fromOffset(52, 30),
		Size = UDim2.new(1, -52, 0, 34),
		Text = message,
		TextSize = 13,
		Parent = box,
	})
end

local function buildServers(b: Frame)
	local data = serverCache
	if not data or os.clock() - lastServerFetch > 20 then
		fetchServers()
	end
	local current = if data then data.current else nil
	local head = Components.panel({ Name = "Current", Size = UDim2.new(1, -10, 0, 64), Parent = b })
	Components.padding(head, 12, 8)
	Components.icon(head, "Servers", 24, Theme.Gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
	})
	label({
		Position = UDim2.fromOffset(34, 0),
		Size = UDim2.new(1, -194, 0.5, 0),
		Text = "ESTE SERVIDOR",
		TextSize = 13,
		TextColor3 = Theme.TextSecondary,
		Parent = head,
	})
	label({
		Name = "CurrentStatus",
		Position = UDim2.new(0, 34, 0.5, 0),
		Size = UDim2.new(1, -194, 0.5, 0),
		Text = if current
			then `{current.players}/{current.max} JOGADORES · {PHASE_NAMES[current.phase] or current.phase}`
			else "CARREGANDO...",
		TextSize = 16,
		TextColor3 = Theme.Gold,
		Parent = head,
	})
	button({
		Name = "Refresh",
		Variant = "secondary",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(150, Theme.TouchMin),
		Text = "ATUALIZAR",
		TextSize = 14,
		Parent = head,
	}, fetchServers)
	local list = socialList(b, 76)
	if not data then
		emptyState(list, "Servers", "PROCURANDO SERVIDORES...", "A lista aparece em instantes.")
		return
	end
	if not data.online then
		emptyState(
			list,
			"Servers",
			"SÓ NO JOGO PUBLICADO",
			"A lista de outros servidores funciona no jogo publicado. No Studio só existe este servidor."
		)
		return
	end
	local servers = if type(data.servers) == "table" then data.servers else {}
	if #servers == 0 then
		emptyState(list, "Friends", "NENHUM OUTRO SERVIDOR ABERTO", "Chame amigos pela aba AMIGOS e joguem juntos.")
	end
	for i, entry in servers do
		local full = entry.players >= entry.max
		local row =
			Components.panel({ Name = `Server_{i}`, Size = UDim2.new(1, 0, 0, 72), LayoutOrder = i, Parent = list })
		Components.padding(row, 12, 10)
		local chips = Create("Frame", {
			Size = UDim2.new(1, -170, 0, 24),
			BackgroundTransparency = 1,
			Parent = row,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local mode = if entry.mode == "Story"
			then "HISTÓRIA"
			elseif entry.mode == "Standard" then "DESAFIO"
			else "VOTANDO"
		Components.chip(
			PHASE_NAMES[entry.phase] or tostring(entry.phase),
			Theme.Info,
			{ LayoutOrder = 1, Parent = chips }
		)
		Components.chip(mode, Theme.Gold, { LayoutOrder = 2, Parent = chips })
		if (entry.stage or 0) > 0 then
			Components.chip(`CAPÍTULO {entry.stage}`, Theme.TextSecondary, { LayoutOrder = 3, Parent = chips })
		end
		Components.icon(row, "Friends", 12, Theme.TextSecondary, { Position = UDim2.fromOffset(0, 36) })
		label({
			Position = UDim2.fromOffset(18, 30),
			Size = UDim2.fromOffset(80, 22),
			Text = `{entry.players}/{entry.max}`,
			TextSize = 14,
			Parent = row,
		})
		local bar, setBar = Components.progress({
			Position = UDim2.fromOffset(90, 38),
			Size = UDim2.new(1, -270, 0, 6),
		}, if full then Theme.Danger else GREEN)
		bar.Parent = row
		setBar(entry.players / math.max(entry.max, 1))
		local join = button({
			Name = "Join",
			Variant = "success",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(150, Theme.TouchMin),
			Text = if full then "CHEIO" else "ENTRAR",
			TextSize = 15,
			Parent = row,
		}, function()
			local result, err = invoke("Lobby", "join", entry.job)
			say(err or (if type(result) == "table" then result.message else nil))
		end)
		Components.setDisabled(join, full)
	end
end

local function fetchFriends()
	task.spawn(function()
		local ok, result = pcall(function()
			return player:GetFriendsOnline(50)
		end)
		if ok and type(result) == "table" then
			friendsCache, friendsError = result, nil
		else
			friendsCache, friendsError = {}, tostring(result)
		end
		if currentTab == "friends" then
			dirty = true
		end
	end)
end

local function invite()
	task.spawn(function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and can then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
		else
			say("lobby_studio")
		end
	end)
end

local function buildFriends(b: Frame)
	if not friendsCache then
		fetchFriends()
	end
	local head = Components.panel({ Name = "Invite", Size = UDim2.new(1, -10, 0, 64), Parent = b })
	Components.padding(head, 8)
	Components.iconButton("primary", "Friends", "CONVIDAR AMIGOS", {
		Name = "Invite",
		Size = UDim2.new(1, -168, 1, 0),
		TextSize = 17,
		Parent = head,
	}, function()
		AudioController.play("UiBlip", 0.5, 1.1, true)
		invite()
	end)
	button({
		Name = "Refresh",
		Variant = "secondary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 158, 1, 0),
		Text = "ATUALIZAR",
		TextSize = 14,
		Parent = head,
	}, fetchFriends)
	local list = socialList(b, 76)
	local friends = friendsCache
	if not friends then
		emptyState(list, "Friends", "PROCURANDO AMIGOS ONLINE...", "A lista aparece em instantes.")
		return
	end
	if friendsError then
		emptyState(list, "Friends", "NÃO DEU PARA LER SEUS AMIGOS", "Tente ATUALIZAR em alguns segundos.")
		return
	end
	if #friends == 0 then
		emptyState(list, "Friends", "NENHUM AMIGO ONLINE AGORA", "Use CONVIDAR AMIGOS para chamar alguém para a casa.")
	end
	-- Quem está neste jogo aparece primeiro.
	table.sort(friends, function(a, c)
		local inA = a.PlaceId == game.PlaceId and game.PlaceId ~= 0
		local inC = c.PlaceId == game.PlaceId and game.PlaceId ~= 0
		if inA ~= inC then
			return inA
		end
		return tostring(a.DisplayName or a.UserName) < tostring(c.DisplayName or c.UserName)
	end)
	for i, friend in friends do
		local here = friend.PlaceId == game.PlaceId and game.PlaceId ~= 0
		local row =
			Components.panel({ Name = `Friend_{i}`, Size = UDim2.new(1, 0, 0, 68), LayoutOrder = i, Parent = list })
		Components.padding(row, 10)
		local face = Create("ImageLabel", {
			Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = Theme.BgSunken,
			BorderSizePixel = 0,
			Image = `rbxthumb://type=AvatarHeadShot&id={friend.VisitorId}&w=48&h=48`,
			Parent = row,
		})
		Components.corner(face, Theme.CornerPill)
		Components.stroke(face, if here then GREEN else Theme.Border, 2, if here then 0 else 0.5)
		label({
			Position = UDim2.fromOffset(60, 2),
			Size = UDim2.new(1, -230, 0, 22),
			Text = tostring(friend.DisplayName or friend.UserName or "?"),
			TextSize = 16,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		label({
			Position = UDim2.fromOffset(60, 26),
			Size = UDim2.new(1, -230, 0, 18),
			Text = if here then "JOGANDO TUNG TUNG SAHUR" else tostring(friend.LastLocation or "ONLINE"),
			TextSize = 12,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = if here then GREEN else Theme.TextSecondary,
			Parent = row,
		})
		if here then
			button({
				Name = "JoinFriend",
				Variant = "success",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(150, Theme.TouchMin),
				Text = "ENTRAR",
				TextSize = 15,
				Parent = row,
			}, function()
				local result, err = invoke("Lobby", "friend", tostring(friend.VisitorId))
				say(err or (if type(result) == "table" then result.message else nil))
			end)
		end
	end
end

type CardMetrics = { art: number, height: number, title: number, desc: number, pad: number, vote: number }

-- Medidas do cartão de campanha (PC em pixels de desenho 1280×720; compacto em pixels reais).
local function cardMetrics(): CardMetrics
	if compactMenu then
		return { art = 76, height = 270, title = 21, desc = 13, pad = 12, vote = 44 }
	end
	return { art = 88, height = 306, title = 28, desc = 15, pad = 14, vote = 48 }
end

-- Arte do cartão de campanha (tábuas e luz; sem pixel art).
local function campaignArt(parent: Instance, story: boolean, m: CardMetrics): Frame
	-- Faixa de tábuas iluminada de baixo (História: brasa da lamparina; Desafio: musgo da floresta).
	-- Sem pixel art: só madeira, luz e o título do modo por cima (desenhado pelo modeCard).
	local art = Create("Frame", {
		Name = "Art",
		Size = UDim2.new(1, 0, 0, m.art),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}) :: Frame
	Components.corner(art, Theme.CornerLarge)
	Create("UIGradient", {
		Rotation = 90,
		Color = if story
			then ColorSequence.new(Color3.fromRGB(12, 8, 6), Color3.fromRGB(104, 48, 22))
			else ColorSequence.new(Color3.fromRGB(8, 9, 9), Color3.fromRGB(48, 58, 30)),
		Parent = art,
	})
	local random = Random.new(if story then 5 else 9)
	local x = 0
	while x < 1 do
		local width = random:NextNumber(0.07, 0.12)
		Create("Frame", {
			Name = "Seam",
			Position = UDim2.fromScale(x + width, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			Parent = art,
		})
		x += width
	end
	-- Escurece o topo: o título lê bem e a luz parece vir de baixo.
	Create("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = art,
	}, {
		Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(0.7, 0.85),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	return art
end

-- Trilha dos 8 capítulos: estado por ícone e texto, não só por cor.
local function chapterTrack(parent: Instance, y: number, height: number)
	local cleared, flawless = storyCleared()
	local states = MenuLayout.chapters(cleared, flawless, #StoryRewards.Chapters)
	local track = Create("Frame", {
		Name = "Chapters",
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 4),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local count = #states
	for chapter, state in states do
		local won = state == "cleared" or state == "flawless"
		local tile = Create("Frame", {
			Name = `Chapter_{chapter}`,
			LayoutOrder = chapter,
			Size = UDim2.new(1 / count, -4 * (count - 1) / count, 1, 0),
			BackgroundColor3 = if won then Theme.GoldDeep else Theme.BgSunken,
			BorderSizePixel = 0,
			Parent = track,
		}) :: Frame
		tile:SetAttribute("State", state)
		Components.corner(tile, Theme.CornerSmall)
		Components.stroke(
			tile,
			if state == "next" or won then Theme.Gold else Theme.Border,
			if state == "next" then 2 else 1,
			if state == "open" then 0.6 else 0.1
		)
		if won then
			Components.icon(tile, if state == "flawless" then "Star" else "Check", 12, Theme.GoldLight, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
			})
		else
			label({
				Size = UDim2.fromScale(1, 1),
				Text = tostring(chapter),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if state == "next" then Theme.GoldLight else Theme.TextMuted,
				Parent = tile,
			})
		end
	end
end

local function modeCard(
	parent: Instance,
	index: number,
	columns: number,
	id: string,
	eyebrow: string,
	title: string,
	description: string,
	extra: (Frame, CardMetrics) -> ()
)
	local m = cardMetrics()
	local card = Create("Frame", {
		Name = `Mode_{id}`,
		Position = if columns == 2
			then UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 6, 0, 0)
			else UDim2.fromOffset(0, (index - 1) * (m.height + 12)),
		Size = if columns == 2 then UDim2.new(0.5, -6, 1, 0) else UDim2.new(1, 0, 0, m.height),
		BackgroundColor3 = Theme.BgPanel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Parent = parent,
	}) :: Frame
	Components.corner(card, Theme.CornerLarge)
	local border = Components.stroke(card, Theme.Border, 1, 0.45)
	local story = id == "Story"
	local art = campaignArt(card, story, m)
	Components.chip(eyebrow, if story then Theme.Gold else Color3.fromRGB(173, 150, 130), {
		Position = UDim2.fromOffset(m.pad, 10),
		Parent = art,
	})
	local titleLabel = label({
		Name = "Title",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, m.pad, 1, -8),
		Size = UDim2.new(1, -2 * m.pad, 0, m.title + 6),
		Text = title,
		TextSize = m.title,
		TextWrapped = false,
		TextScaled = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = art,
	})
	titleLabel.TextStrokeColor3 = Theme.Overlay
	titleLabel.TextStrokeTransparency = 0.2
	local inner = Create("Frame", {
		Name = "Info",
		Position = UDim2.fromOffset(m.pad, m.art + 10),
		Size = UDim2.new(1, -2 * m.pad, 1, -(m.art + 10 + m.pad)),
		BackgroundTransparency = 1,
		Parent = card,
	}) :: Frame
	note({
		Name = "Description",
		Size = UDim2.new(1, 0, 0, if compactMenu then 32 else 36),
		Text = description,
		TextSize = m.desc,
		Parent = inner,
	})
	extra(inner, m)
	Components.icon(inner, "Friends", 24, Theme.TextSecondary, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -(m.vote - 24) // 2),
	})
	local votes = label({
		Name = "Votes",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 32, 1, 0),
		Size = UDim2.new(0.45, -32, 0, m.vote),
		Text = "0 VOTOS",
		TextSize = 15,
		TextColor3 = Theme.TextSecondary,
		Parent = inner,
	})
	local vote = button({
		Name = "Vote",
		Variant = "primary",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.55, 0, 0, m.vote),
		Text = "VOTAR",
		TextSize = if compactMenu then 20 else 22,
	}, function()
		local data, err = invoke("SelectGameMode", id)
		if err then
			say(err)
		elseif type(data) == "table" and not data.accepted then
			say("not_available")
		end
	end)
	vote.Parent = inner
	table.insert(live, function()
		local state = campaign()
		local count = tonumber(if state then state:GetAttribute(if story then "StoryVotes" else "StandardVotes") else 0)
			or 0
		votes.Text = px(if count == 1 then "1 VOTO" else `{count} VOTOS`)
		local mine = player:GetAttribute("GameModeVote") == id
		local wanted: Components.Variant = if mine then "success" else "primary"
		if vote:GetAttribute("Variant") ~= wanted then
			Components.setVariant(vote, wanted)
		end
		vote.Text = px(if mine then "SEU VOTO" else "VOTAR")
		border.Color = if mine then Theme.Gold else CARD_EDGE
		border.Transparency = if mine then 0 else 0.45
		border.Thickness = if mine then 2 else 1
	end)
end

-- Slots de informação dentro do cartão (A: trilha/linha 1, B: recompensa/linha 2, C: oferta/estado).
local function slotY(m: CardMetrics, slot: string): (number, number)
	local compact = m.art < 84
	if slot == "A" then
		return if compact then 36 else 40, if compact then 28 else 30
	elseif slot == "B" then
		return if compact then 68 else 76, if compact then 16 else 18
	end
	return if compact then 90 else 100, if compact then 32 else 36
end

local function teamPanel(parent: Instance, position: UDim2, size: UDim2)
	local panel = Components.panel({ Name = "Team", Position = position, Size = size, Parent = parent })
	Components.padding(panel, 12, 10)
	Components.icon(panel, "Friends", 24, Theme.Gold)
	local status = label({
		Name = "Status",
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -164, 0, 24),
		Text = "",
		TextSize = 15,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextColor3 = Theme.Gold,
		Parent = panel,
	})
	button({
		Name = "Invite",
		Variant = "ghost",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -4),
		Size = UDim2.fromOffset(124, if compactMenu then 40 else 32),
		Text = "CONVIDAR",
		TextSize = 14,
	}, invite).Parent =
		panel
	local slots = Create("Frame", {
		Name = "Slots",
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 1, -34),
		BackgroundTransparency = 1,
		Parent = panel,
	})
	local avatar = if compactMenu then 36 else 40
	local slotFrames: { Frame } = {}
	local max = Config.Campaign.maxPlayers
	for i = 1, max do
		local slot = Create("Frame", {
			Name = `Slot_{i}`,
			Position = UDim2.fromScale((i - 1) / max, 0),
			Size = UDim2.fromScale(1 / max, 1),
			BackgroundTransparency = 1,
			Parent = slots,
		}) :: Frame
		local face = Create("ImageLabel", {
			Name = "Face",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(avatar, avatar),
			BackgroundColor3 = Theme.BgSunken,
			BorderSizePixel = 0,
			Image = "",
			Parent = slot,
		}) :: ImageLabel
		Components.corner(face, Theme.CornerPill)
		Components.stroke(face, Theme.Border, 2, 0.5).Name = "Ring"
		Components.icon(face, "Plus", 12, Theme.TextMuted, {
			Name = "Empty",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
		label({
			Name = "Who",
			Position = UDim2.fromOffset(0, avatar + 2),
			Size = UDim2.new(1, 0, 0, 16),
			Text = "",
			TextSize = 12,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = slot,
		})
		table.insert(slotFrames, slot)
	end
	table.insert(live, function()
		local state = campaign()
		local list = Players:GetPlayers()
		local count = #list
		local remaining = if state
			then math.ceil((tonumber(state:GetAttribute("NextStageAt")) or 0) - workspace:GetServerTimeNow())
			else 0
		status.Text = px(
			if remaining > 0
				then `TIME REUNIDO · COMEÇANDO EM {remaining}s`
				elseif
					count < Config.Campaign.minPlayers
				then `TIME {count}/{max} · FALTAM {Config.Campaign.minPlayers - count} PARA COMEÇAR`
				else `TIME {count}/{max} · ESPERANDO OS VOTOS`
		)
		for i, slot in slotFrames do
			local other = list[i]
			local face = slot:FindFirstChild("Face") :: ImageLabel
			local who = slot:FindFirstChild("Who") :: TextLabel
			local ring = face:FindFirstChild("Ring") :: UIStroke
			local empty = face:FindFirstChild("Empty") :: Frame
			if other then
				face.Image = `rbxthumb://type=AvatarHeadShot&id={other.UserId}&w=48&h=48`
				empty.Visible = false
				who.Text = px(other.DisplayName)
				local vote = other:GetAttribute("GameModeVote")
				ring.Color = if vote == "Story" then Theme.Gold elseif vote == "Standard" then GREEN else Theme.Border
				ring.Transparency = if vote == "Story" or vote == "Standard" then 0 else 0.5
			else
				face.Image = ""
				empty.Visible = true
				who.Text = ""
				ring.Color, ring.Transparency = Theme.Border, 0.7
			end
		end
	end)
end

-- Mochila da partida: consumíveis reais (estoque/kit publicados pelo StoreService).
local function kitPanel(parent: Instance, position: UDim2, size: UDim2)
	local panel = Components.panel({ Name = "Kit", Position = position, Size = size, Parent = parent })
	Components.padding(panel, 12, 10)
	Components.icon(panel, "Backpack", 24, Theme.Gold)
	label({
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -32, 0, 24),
		Text = "MOCHILA DA PARTIDA",
		TextSize = 15,
		TextColor3 = Theme.Gold,
		Parent = panel,
	})
	local stock = json("Consumables", {})
	local loadout: { [string]: boolean } = {}
	for _, id in json("Loadout", {}) do
		loadout[tostring(id)] = true
	end
	local holder = Create("Frame", {
		Name = "Slots",
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 1, -32),
		BackgroundTransparency = 1,
		Parent = panel,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local total = #Perks.Consumables
	for i, def in Perks.Consumables do
		local count = tonumber(stock[def.id]) or 0
		local on = loadout[def.id] == true
		local active = def.loadout and on and count > 0
		local stateText = if count <= 0
			then "SEM ESTOQUE"
			elseif not def.loadout then "USO NA DERROTA"
			elseif on then "NA MOCHILA"
			else "FORA DA MOCHILA"
		local tile = Components.button(if active then "success" else "secondary", {
			Name = `Kit_{def.id}`,
			LayoutOrder = i,
			Size = UDim2.new(1 / total, -6 * (total - 1) / total, 1, 0),
			Text = "",
		}, function()
			click()
			if count <= 0 then
				currentTab = "perks"
				dirty = true
			elseif def.loadout then
				store(if on then "loadout_off" else "loadout_on", def.id)
			else
				say("Use no botão CONTINUAR depois de uma derrota.")
			end
		end)
		tile.Parent = holder
		label({
			Name = "ItemName",
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.new(1, -12, 0.62, -4),
			Text = `{def.name} x{count}`,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = tile,
		})
		label({
			Name = "ItemState",
			Position = UDim2.new(0, 6, 0.62, 0),
			Size = UDim2.new(1, -12, 0.38, -4),
			Text = stateText,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = if active then GREEN elseif count <= 0 then Theme.TextMuted else Theme.TextSecondary,
			Parent = tile,
		})
	end
end

local function buildPlay(parent: Frame)
	local width = parent.AbsoluteSize.X
	if width <= 0 then
		width = if compactMenu then 600 else 900
	end
	local columns = MenuLayout.columns(width)
	columnsShown = columns

	local m = cardMetrics()
	-- Conteúdo maior que o painel rola numa única lista vertical.
	local scroll = Create("ScrollingFrame", {
		Name = "PlayScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Gold,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 6) }),
	})
	local modes = frame({
		Name = "Modes",
		Size = UDim2.new(1, 0, 0, if columns == 2 then m.height else m.height * 2 + 12),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = scroll,
	})
	modeCard(
		modes,
		1,
		columns,
		"Story",
		"MODO HISTÓRIA",
		"A CASA DE MADEIRA",
		"Casa + floresta: 8 capítulos, perseguição e resgate. Solo ou equipe de até 6.",
		function(inner, cm)
			local ay, ah = slotY(cm, "A")
			chapterTrack(inner, ay, ah)
			local by, bh = slotY(cm, "B")
			local chapter, reward = storyPreview()
			label({
				Name = "NextReward",
				Position = UDim2.fromOffset(0, by),
				Size = UDim2.new(1, 0, 0, bh),
				Text = `PRÓXIMO: CAP. {chapter} · {reward}`,
				TextSize = 13,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = GREEN,
				Parent = inner,
			})
			local cy, ch = slotY(cm, "C")
			if player:GetAttribute("StoryPass") == true then
				Components.chip("PASSE DA HISTÓRIA ATIVO · RECOMPENSAS x2", Theme.Gold, {
					Position = UDim2.fromOffset(0, cy + (ch - 24) // 2),
					Parent = inner,
				})
			else
				-- Produto sem ID publicado não vira botão morto (ver docs/ui-remaster/AUDITORIA.md).
				local pass = StoreCatalog.ProductByKey[StoreCatalog.StoryPassKey]
				if not pass or pass.id <= 0 then
					local cleared, flawless = storyCleared()
					local won, perfect = 0, 0
					for index = 1, #StoryRewards.Chapters do
						won += if cleared[index] then 1 else 0
						perfect += if flawless[index] then 1 else 0
					end
					label({
						Name = "Progress",
						Position = UDim2.fromOffset(0, cy),
						Size = UDim2.new(1, 0, 0, ch),
						Text = `VENCIDOS {won}/{#StoryRewards.Chapters} · SEM QUEDAS {perfect}/{#StoryRewards.Chapters}`,
						TextSize = 13,
						TextColor3 = Theme.TextSecondary,
						Parent = inner,
					})
				else
					button({
						Name = "StoryPass",
						Position = UDim2.fromOffset(0, cy),
						Size = UDim2.new(1, 0, 0, ch),
						Text = `PASSE DA HISTÓRIA · RECOMPENSAS x2 · R$ {pass.robux}`,
						TextSize = 13,
					}, function()
						buyProduct(StoreCatalog.StoryPassKey)
					end).Parent =
						inner
				end
			end
		end
	)
	modeCard(
		modes,
		2,
		columns,
		"Standard",
		"MODO DESAFIO",
		"MAIS UMA NOITE",
		"Casa, jardins e floresta: 8 capítulos com itens e passagens sorteados. 1–6 jogadores.",
		function(inner, cm)
			local ay, ah = slotY(cm, "A")
			Components.icon(inner, "Coin", 24, Theme.Coin, {
				Position = UDim2.fromOffset(0, ay + (ah - 24) // 2),
			})
			label({
				Position = UDim2.fromOffset(32, ay),
				Size = UDim2.new(1, -32, 0, ah),
				Text = "FICHAS E XP POR CAPÍTULO, FUGA E AJUDA AO TIME",
				TextSize = 13,
				TextColor3 = GREEN,
				Parent = inner,
			})
			local by, bh = slotY(cm, "B")
			label({
				Position = UDim2.fromOffset(32, by),
				Size = UDim2.new(1, -32, 0, bh),
				Text = "MOEDAS E FITAS VHS ESPALHADAS PELA CASA",
				TextSize = 12,
				TextWrapped = false,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = Theme.TextSecondary,
				Parent = inner,
			})
			local cy, ch = slotY(cm, "C")
			local product = StoreCatalog.ProductByKey.bonus_duplo_3h
			local sellable = product ~= nil and product.id > 0
			local boost = label({
				Name = "Boost",
				Position = UDim2.fromOffset(0, cy),
				Size = UDim2.new(if sellable then 0.5 else 1, -4, 0, ch),
				Text = "",
				TextSize = 12,
				TextColor3 = Theme.Gold,
				Parent = inner,
			})
			table.insert(live, function()
				local now = workspace:GetServerTimeNow()
				local fichas = (tonumber(player:GetAttribute("BoostFichasUntil")) or 0) - now
				local xp = (tonumber(player:GetAttribute("BoostXpUntil")) or 0) - now
				local parts = {}
				if fichas > 0 then
					table.insert(parts, `FICHAS x2 · {clock(fichas)}`)
				end
				if xp > 0 then
					table.insert(parts, `XP x2 · {clock(xp)}`)
				end
				if player:GetAttribute("Vip") == true then
					table.insert(parts, "VIP x1,5")
				end
				boost.Text = px(if #parts > 0 then "ATIVO: " .. table.concat(parts, " · ") else "")
			end)
			if sellable then
				button({
					Name = "Boost",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, 0, 0, cy),
					Size = UDim2.new(0.5, -4, 0, ch),
					Text = `FICHAS E XP x2 · 3H · R$ {product.robux}`,
					TextSize = 12,
				}, function()
					buyProduct("bonus_duplo_3h")
				end).Parent =
					inner
			end
		end
	)
	local rowHeight = if compactMenu then 116 else 124
	local party = frame({
		Name = "Party",
		Size = UDim2.new(1, 0, 0, if columns == 2 then rowHeight else rowHeight * 2 + 12),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = scroll,
	})
	if columns == 2 then
		teamPanel(party, UDim2.new(), UDim2.new(0.56, -6, 1, 0))
		kitPanel(party, UDim2.new(0.56, 6, 0, 0), UDim2.new(0.44, -6, 1, 0))
	else
		teamPanel(party, UDim2.new(), UDim2.new(1, 0, 0, rowHeight))
		kitPanel(party, UDim2.fromOffset(0, rowHeight + 12), UDim2.new(1, 0, 0, rowHeight))
	end
	-- Dificuldade, modificadores e conquistas (UI/DifficultyPanel).
	DifficultyPanel.build(scroll, 3, columns)
end

local TITLES: { [string]: { string } } = {
	play = {
		"ESCOLHA A CAMPANHA",
		`A maioria da equipe decide. Com {Config.Campaign.minPlayers} ou mais pessoas, a contagem começa.`,
	},
	perks = { "MELHORIAS E CONSUMÍVEIS", "Vantagens que valem em todas as partidas. Compre com Fichas ou Créditos." },
	servers = { "SERVIDORES", "Entre num lobby aberto ou numa partida com vaga." },
	friends = { "AMIGOS", "Entre no servidor de um amigo ou chame a equipe." },
}

local function renderTab()
	-- Redesenho por mudança de saldo/estoque (compra, mochila) mantém a rolagem da mesma aba.
	local keep: Vector2? = nil
	local previous = body
	if previous and previous:GetAttribute("Tab") == currentTab then
		local scroller = previous:FindFirstChildWhichIsA("ScrollingFrame")
		if scroller then
			keep = scroller.CanvasPosition
		end
	end
	local b = clearBody()
	if not b then
		return
	end
	b:SetAttribute("Tab", currentTab)
	local titles = TITLES[currentTab] or TITLES.play
	if header then
		header.Text = px(titles[1])
	end
	if subheader then
		subheader.Text = titles[2]
	end
	for id in navButtons do
		paintNav(id)
	end
	-- Tela inicial: só o palco, o logo e os botões; o painel aparece quando uma aba abre.
	local home = currentTab == "home"
	local panel = contentPanel
	if panel then
		panel.Visible = not home
	end
	for _, item in homeOnly do
		item.Visible = home
	end
	if home then
		return
	end
	if currentTab == "perks" then
		buildPerks(b)
	elseif currentTab == "servers" then
		buildServers(b)
	elseif currentTab == "friends" then
		buildFriends(b)
	else
		buildPlay(b)
	end
	local saved = keep
	if saved then
		local scroller = b:FindFirstChildWhichIsA("ScrollingFrame")
		if scroller then
			-- A lista nova mede o canvas no próximo quadro; aplica a posição depois disso.
			task.defer(function()
				scroller.CanvasPosition = saved
			end)
		end
		return
	end
	-- Entrada da aba: desliza 12 px.
	local top = bodyTop
	b.Position = UDim2.fromOffset(0, top + 12)
	TweenService:Create(b, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(0, top) }):Play()
end

local function selectTab(id: TabId)
	if id == "settings" then
		Settings.toggleMenu()
		return
	end
	local storeTab = STORE_TABS[id]
	if storeTab then
		Store.openTab(storeTab, STORE_KIND[id])
		return
	end
	local s = stage
	if s and id == "play" and currentTab ~= "play" then
		-- Entrar no JOGAR: ele percebe (gesto de alerta) e o palco desliza para a faixa ao lado do painel.
		MenuStage.react(s, "bash")
	end
	currentTab = id
	dirty = true
end

-- Só no Studio: atributo MenuViewportQA = "844x390" simula a tela de um celular (capturas de QA).
local qaViewport = ViewportQA.size

-- Selo de notificação: só quando há prêmio diário ou giro disponível de verdade.
local function dailyReady(): boolean
	return player:GetAttribute("DailyClaimable") == true or (tonumber(player:GetAttribute("SpinsLeft")) or 0) > 0
end

local function notifyDot(parent: Instance, position: UDim2): Frame
	local dot = Create("Frame", {
		Name = "Badge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.Gold,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
		Parent = parent,
	}) :: Frame
	Components.corner(dot, Theme.CornerPill)
	Components.stroke(dot, Theme.Overlay, 2, 0)
	table.insert(frameUpdates, function()
		dot.Visible = dailyReady()
	end)
	return dot
end

-- Carteira e perfil em osso e latão sobre preto (sem os selos coloridos da loja). Devolve a altura ocupada.
-- PC: à direita no topo. Celular: no rodapé da coluna esquerda, longe do rosto do Tung.
local function wallet(parent: Instance, compact: boolean): Frame
	local row = Create("Frame", {
		Name = "Wallet",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, if compact then 44 else 40),
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, if compact then 12 else 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	local function amount(order: number, caption: string): TextLabel
		return Create("TextLabel", {
			Name = caption,
			LayoutOrder = order,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			FontFace = MENU_FONT,
			RichText = true,
			Text = "",
			TextSize = if compact then 17 else 20,
			TextColor3 = BONE_DIM,
			Parent = row,
		}) :: TextLabel
	end
	local fichas = amount(1, "Fichas")
	local creditos = amount(2, "Creditos")
	local add = Create("TextButton", {
		Name = "AddCredits",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(44, 44),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		FontFace = MENU_FONT_BOLD,
		Text = "+",
		TextSize = 28,
		TextColor3 = BRASS,
		Parent = row,
	}) :: TextButton
	add.MouseEnter:Connect(function()
		add.TextColor3 = BONE
	end)
	add.MouseLeave:Connect(function()
		add.TextColor3 = BRASS
	end)
	add.Activated:Connect(function()
		click()
		Store.openTab("robux")
	end)
	local brass = BRASS:ToHex()
	table.insert(frameUpdates, function()
		local f = number(tonumber(player:GetAttribute("Fichas")) or 0)
		local c = number(tonumber(player:GetAttribute("Creditos")) or 0)
		fichas.Text = `<font color="#{brass}">{f}</font>  FICHAS`
		creditos.Text = `<font color="#{brass}">{c}</font>  CRÉDITOS`
	end)
	return row
end

local function topBar(root: Frame, mode: MenuLayout.Mode): number
	local compact = mode.compact
	local height = if compact then 44 else 56
	local margin = if compact then 8 else 40
	local y = if compact then 6 else 34
	if compact then
		-- Celular: nada no topo (o rosto do Tung fica livre); a carteira vai para a coluna (menuColumn).
		return y + height
	end
	local bar = Create("Frame", {
		Name = "TopBar",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -margin, 0, y),
		Size = UDim2.fromOffset(640, height),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 26),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	wallet(bar, false).LayoutOrder = 1
	-- Perfil: retrato redondo com aro de latão, nome e nível (sem caixa).
	local profile = Create("Frame", {
		Name = "Profile",
		LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, height),
		BackgroundTransparency = 1,
		Parent = bar,
	}) :: Frame
	local face = Create("ImageLabel", {
		Name = "Avatar",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(44, 44),
		BackgroundColor3 = Color3.fromRGB(20, 15, 11),
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
		Parent = profile,
	})
	Components.corner(face, Theme.CornerPill)
	Components.stroke(face, BRASS, 1.5, 0.2)
	local nameLabel = Create("TextLabel", {
		Name = "PlayerName",
		Position = UDim2.fromOffset(56, 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 24),
		BackgroundTransparency = 1,
		FontFace = MENU_FONT,
		Text = player.DisplayName,
		TextSize = 20,
		TextColor3 = BONE,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = profile,
	}) :: TextLabel
	local levelLabel = Create("TextLabel", {
		Name = "Level",
		Position = UDim2.fromOffset(56, 30),
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 1,
		FontFace = MENU_FONT,
		Text = "",
		TextSize = 16,
		TextColor3 = BRASS,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = profile,
	}) :: TextLabel
	table.insert(frameUpdates, function()
		local level, into, needed = Economy.levelInfo(tonumber(player:GetAttribute("Xp")) or 0)
		levelLabel.Text = `NÍVEL {level}  ·  {number(into)}/{number(needed)} XP`
		local titleId = player:GetAttribute("Title")
		local titleItem = if type(titleId) == "string" then StoreCatalog.ItemById[titleId] else nil
		nameLabel.Text = player.DisplayName
			.. (if titleItem then `  ·  {titleItem.name}` else "")
			.. (if player:GetAttribute("Vip") == true then "  ·  VIP" else "")
	end)
	return y + height
end

-- ===================== Tela inicial: passe de batalha e skin em destaque =====================

local function featuredSkin(): StoreCatalog.Item?
	local best: StoreCatalog.Item? = nil
	local bestRank = -1
	for _, item in StoreCatalog.Items do
		if item.kind == "uniform" and (item.fichas or item.creditos) then
			local rarity = (StoreCatalog.Rarities :: any)[item.rarity]
			local rank = if rarity then rarity.order else 0
			if rank > bestRank then
				best, bestRank = item, rank
			end
		end
	end
	return best
end

-- Espaçamento entre letras (a página usa letter-spacing; o Roblox não tem): espaço fino entre cada letra.
local function tracked(text: string): string
	local letters = {}
	for _, code in utf8.codes(text) do
		table.insert(letters, utf8.char(code))
	end
	return table.concat(letters, "\u{2009}")
end

local function caption(parent: Instance, text: string, position: UDim2, size: UDim2, textSize: number, color: Color3)
	return Create("TextLabel", {
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		FontFace = MENU_FONT,
		Text = text,
		TextSize = textSize,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = parent,
	}) :: TextLabel
end

-- Passe de batalha e skin em destaque: só texto no canto de baixo, como o rodapé da página (sem caixas).
local function homeWidgets(root: Frame, mode: MenuLayout.Mode)
	local compact = mode.compact
	local width = if compact then 230 else 330
	local holder = Create("Frame", {
		Name = "HomeWidgets",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, if compact then -14 else -64, 1, if compact then -10 else -34),
		Size = UDim2.fromOffset(width, if compact then 96 else 104),
		BackgroundTransparency = 1,
		Parent = root,
	}) :: Frame
	homeOnly = { holder }
	local function link(name: string, y: number, height: number, onClick: () -> ()): TextButton
		local entry = Create("TextButton", {
			Name = name,
			Position = UDim2.fromOffset(0, y),
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			Text = "",
			Parent = holder,
		}) :: TextButton
		entry.Activated:Connect(function()
			click()
			onClick()
		end)
		return entry
	end
	local pass = link("PassWidget", 0, 48, function()
		selectTab("season")
	end)
	local passLevel = caption(pass, "", UDim2.new(), UDim2.new(1, 0, 0, 20), if compact then 16 else 15, BONE_DIM)
	local track = Create("Frame", {
		Name = "Track",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 28),
		Size = UDim2.new(1, 0, 0, 3),
		BackgroundColor3 = Color3.fromRGB(40, 30, 22),
		BorderSizePixel = 0,
		Parent = pass,
	})
	local fill = Create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = EMBER,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	pass.MouseEnter:Connect(function()
		passLevel.TextColor3 = BONE
	end)
	pass.MouseLeave:Connect(function()
		passLevel.TextColor3 = BONE_DIM
	end)
	table.insert(frameUpdates, function()
		local id = player:GetAttribute("SeasonId")
		local season = if type(id) == "string" then SeasonCatalog.SeasonById[id] else nil
		if not season then
			passLevel.Text = "PASSE  ·  EM BREVE"
			fill.Size = UDim2.fromScale(0, 1)
			return
		end
		local tier, into, need = Season.tierInfo(season, tonumber(player:GetAttribute("SeasonXp")) or 0)
		passLevel.Text = `PASSE  ·  NÍVEL {tier}`
		fill.Size = UDim2.fromScale(math.clamp(into / math.max(need, 1), 0, 1), 1)
	end)
	local item = featuredSkin()
	if item then
		local skin = link("FeaturedSkin", 52, 44, function()
			selectTab("skins")
		end)
		local price = if item.creditos then `{number(item.creditos)} CRÉDITOS` else `{number(item.fichas or 0)} FICHAS`
		local title = caption(
			skin,
			tracked("SKIN EM DESTAQUE"),
			UDim2.new(),
			UDim2.new(1, 0, 0, 18),
			if compact then 16 else 14,
			BONE_DIM
		)
		local name = caption(
			skin,
			`{string.upper(item.name)}  ·  {price}`,
			UDim2.fromOffset(0, 20),
			UDim2.new(1, 0, 0, 22),
			if compact then 16 else 17,
			BONE
		)
		skin.MouseEnter:Connect(function()
			title.TextColor3 = BONE
			name.TextColor3 = EMBER
		end)
		skin.MouseLeave:Connect(function()
			title.TextColor3 = BONE_DIM
			name.TextColor3 = BONE
		end)
	end
end

-- ===================== Coluna esquerda: logo e botões só de texto (página "Menu da Casa de Madeira") =====================

-- Logo como na página: duas linhas da mesma serifa, cor de osso, e o subtítulo espaçado em cinza quente.
local function brand(parent: Instance, compact: boolean, short: boolean): number
	local size = if compact then (if short then 30 else 36) else 64
	local line = math.floor(size * 0.98)
	local subtitle = if short then 0 else (if compact then 22 else 30)
	local holder = Create("Frame", {
		Name = "Brand",
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, line * 2 + subtitle),
		BackgroundTransparency = 1,
		Parent = parent,
	}) :: Frame
	brandScale = Create("UIScale", { Parent = holder }) :: UIScale
	for index, word in { "TUNG TUNG", "SAHUR" } do
		Create("TextLabel", {
			Name = `Word{index}`,
			Position = UDim2.fromOffset(0, (index - 1) * line),
			Size = UDim2.new(1, 0, 0, line),
			BackgroundTransparency = 1,
			FontFace = LOGO_FONT,
			Text = word,
			TextSize = size,
			TextColor3 = BONE,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			Parent = holder,
		})
	end
	if not short then
		Create("TextLabel", {
			Name = "Subtitle",
			Position = UDim2.fromOffset(2, line * 2 + 6),
			Size = UDim2.new(1, 0, 0, subtitle - 6),
			BackgroundTransparency = 1,
			FontFace = MENU_FONT,
			Text = tracked("A  CASA  DE  MADEIRA"),
			TextSize = 16,
			TextColor3 = BONE_DIM,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = holder,
		})
	end
	return holder.Size.Y.Offset
end

-- Pinta um botão do menu: cinza quente parado; osso e ponto de brasa no foco ou na aba aberta.
function paintNav(id: string, hovered: boolean?)
	local nav = navButtons[id]
	if not nav then
		return
	end
	local selected = id == currentTab
	local lit = hovered == true or selected
	nav.TextColor3 = if lit then BONE else BONE_DIM
	local dot = nav:FindFirstChild("Dot")
	if dot and dot:IsA("Frame") then
		dot.Visible = lit
	end
end

-- A cabeça do Tung vira para o botão em foco (o menu fica à esquerda da tela = à direita dele).
local function lookAt(nav: GuiObject)
	local s = stage
	local root = rootFrame
	if not s or not root then
		return
	end
	local height = math.max(root.AbsoluteSize.Y, 1)
	local v = (nav.AbsolutePosition.Y + nav.AbsoluteSize.Y / 2 - root.AbsolutePosition.Y) / height
	MenuStage.look(s, 34 - (v - 0.5) * 10)
end

local function navHeight(compact: boolean): number
	return if compact then 44 else 36
end

local function navItem(
	parent: Instance,
	id: string,
	text: string,
	order: number,
	mode: MenuLayout.Mode,
	onClick: () -> ()
): TextButton
	local compact = mode.compact
	local nav = Create("TextButton", {
		Name = `Nav_{id}`,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, navHeight(compact)),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		FontFace = MENU_FONT_BOLD,
		Text = tracked(text),
		TextSize = if compact then 17 else 17,
		TextColor3 = BONE_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	}) :: TextButton
	-- Sem o retângulo cinza de seleção do Roblox (foco por controle/teclado usa o mesmo ponto de brasa).
	nav.SelectionImageObject = Create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }) :: Frame
	nav.SelectionGained:Connect(function()
		paintNav(id, true)
	end)
	nav.SelectionLost:Connect(function()
		paintNav(id, false)
	end)
	local dot = Create("Frame", {
		Name = "Dot",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, -14, 0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = EMBER,
		BorderSizePixel = 0,
		Visible = false,
		Parent = nav,
	})
	Components.corner(dot, Theme.CornerPill)
	nav.MouseEnter:Connect(function()
		paintNav(id, true)
		lookAt(nav)
		AudioController.play("CreakWood", 0.16, 1.5 + order * 0.02, true)
	end)
	nav.MouseLeave:Connect(function()
		paintNav(id, false)
		local s = stage
		if s then
			MenuStage.look(s, 0)
		end
	end)
	nav.Activated:Connect(function()
		click()
		lookAt(nav)
		onClick()
	end)
	navButtons[id] = nav
	paintNav(id)
	return nav
end

-- Coluna da página: logo + lista, centrada na altura da tela e a 5% da borda esquerda.
local function menuColumn(root: Frame, mode: MenuLayout.Mode): number
	local compact = mode.compact
	local x = if compact then 30 else 72
	local width = if compact then 230 else 360
	local visible, overflow = MenuLayout.split(NAV, compact)
	local count = #visible + (if #overflow > 0 then 1 else 0)
	local gap = if compact then 10 else 22
	local column = Create("Frame", {
		Name = "Column",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, x, 0.5, if compact then -16 else 0),
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, gap), SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame
	brand(column, compact, mode.short)
	local list = Create("Frame", {
		Name = "Rail",
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, count * (navHeight(compact) + 2)),
		BackgroundTransparency = 1,
		Parent = column,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in visible do
		local nav = navItem(list, item.id, if compact then item.short else item.label, i, mode, function()
			selectTab(item.id)
		end)
		if item.id == "daily" then
			notifyDot(nav, UDim2.new(1, -16, 0.5, 0))
		end
	end
	if compact then
		-- Celular: carteira no pé da coluna (no topo ela cobriria o rosto do Tung).
		local purse = wallet(root, true)
		purse.AnchorPoint = Vector2.new(0, 1)
		purse.Position = UDim2.new(0, x, 1, -6)
	end
	if #overflow > 0 then
		-- MAIS (celular): os outros destinos num menu curto ao lado da coluna.
		local catcher = Create("TextButton", {
			Name = "MoreCatcher",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			Text = "",
			AutoButtonColor = false,
			Visible = false,
			ZIndex = 20,
			Parent = root,
		}) :: TextButton
		local popover = Create("Frame", {
			Name = "More",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, x + width - 40, 0.5, 0),
			Size = UDim2.fromOffset(250, #overflow * 46 + 24),
			BackgroundColor3 = Color3.fromRGB(8, 6, 5),
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 21,
			Parent = root,
		}, {
			Create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
		}) :: Frame
		Components.corner(popover, Theme.CornerSmall)
		Components.stroke(popover, EMBER, 1, 0.7)
		Components.padding(popover, 12, 12)
		local function setMore(open: boolean)
			popover.Visible = open
			catcher.Visible = open
		end
		catcher.Activated:Connect(function()
			setMore(false)
		end)
		for i, item in overflow do
			local entry = navItem(popover, item.id, item.label, i, mode, function()
				setMore(false)
				selectTab(item.id)
			end)
			for _, child in entry:GetDescendants() do
				if child:IsA("GuiObject") then
					child.ZIndex = 22
				end
			end
			entry.ZIndex = 22
			if item.id == "daily" then
				notifyDot(entry, UDim2.new(1, -16, 0.5, 0)).ZIndex = 23
			end
		end
		local more = navItem(list, "more", "MAIS", #visible + 1, mode, function()
			setMore(not popover.Visible)
		end)
		notifyDot(more, UDim2.new(1, -16, 0.5, 0))
	end
	return x + width
end

local function build(mode: MenuLayout.Mode): ScreenGui
	frameUpdates = {}
	navButtons = {}
	compactMenu = mode.compact
	local screen = Create("ScreenGui", {
		Name = "MainMenu",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 200,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	screen:SetAttribute("Layout", mode.key)
	local safe = frame({ Name = "SafeArea", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	local qaWidth, qaHeight = qaViewport()
	if qaWidth and qaHeight then
		-- QA no Studio: simula a tela de um aparelho no centro da janela, com moldura visível.
		safe.AnchorPoint, safe.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
		safe.Size, safe.ClipsDescendants = UDim2.fromOffset(qaWidth, qaHeight), true
		Components.stroke(safe, Theme.Danger, 2, 0)
	end
	local root = frame({
		Name = "Root",
		Size = UDim2.fromScale(1 / mode.scale, 1 / mode.scale),
		BackgroundTransparency = 1,
		Parent = safe,
	})
	rootFrame = root
	rootScale = Create("UIScale", { Scale = mode.scale, Parent = root }) :: UIScale
	-- Marcador para o PvPHudController (fora deste repo): com um "MidnightHuntEntry" dentro do menu ligado, o
	-- atalho solto da Caçada no rodapé some. A entrada de verdade fica no painel do JOGAR.
	Create("Frame", { Name = "MidnightHuntEntry", Visible = false, BackgroundTransparency = 1, Parent = root })
	-- Atrás da UI fica a cena 3D (UI/MenuStage). Só um véu à esquerda para o texto ler bem sobre o preto.
	Create("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = root,
	}, {
		Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.15),
				NumberSequenceKeypoint.new(0.32, 0.55),
				NumberSequenceKeypoint.new(0.6, 1),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})

	local top = topBar(root, mode) + (if mode.compact then 6 else 20)
	local left = menuColumn(root, mode)
	railRight = left
	homeWidgets(root, mode)
	local margin = if mode.compact then 8 else 28

	-- Painel à direita, deixando uma faixa entre a coluna e o painel para o Tung continuar à vista (PC e celular).
	local right = Components.panel({
		Name = "Content",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -margin, 0, if mode.compact then 8 else top),
		Size = if mode.compact
			then UDim2.new(1, -(left + margin + 150), 1, -16)
			else UDim2.new(0.5, 0, 1, -(top + margin)),
		BackgroundColor3 = Color3.fromRGB(10, 8, 7),
		BackgroundTransparency = 0.06,
		Visible = false,
		Parent = root,
	})
	contentPanel = right
	-- Conteúdo das abas na pele "Casa de Madeira" (UI/MenuSkin): mesmos construtores, outra aparência.
	MenuSkin.apply(right, if mode.compact then 16 else 14)
	if not mode.compact then
		Create("UISizeConstraint", { MinSize = Vector2.new(680, 0), Parent = right })
	end
	local outline = right:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color, outline.Transparency = EMBER, 0.78
	end
	local padX = if mode.compact then 10 else 20
	local padY = if mode.compact then 8 else 16
	Components.padding(right, padX, padY)
	header = Components.title({
		Name = "Header",
		Size = UDim2.new(1, -130, 0, if mode.compact then 26 else 32),
		Text = "",
		FontFace = MENU_FONT_BOLD,
		TextColor3 = BONE,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = if mode.compact then 22 else 30,
		Parent = right,
	})
	-- Voltar à tela inicial (o Tung volta para o centro do palco).
	local back = Create("TextButton", {
		Name = "Back",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, -4),
		Size = UDim2.fromOffset(120, 44),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		FontFace = MENU_FONT,
		Text = "‹  VOLTAR",
		TextSize = if mode.compact then 18 else 20,
		TextColor3 = BONE_DIM,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = right,
	}) :: TextButton
	back.MouseEnter:Connect(function()
		back.TextColor3 = BONE
	end)
	back.MouseLeave:Connect(function()
		back.TextColor3 = BONE_DIM
	end)
	back.Activated:Connect(function()
		click()
		selectTab("home")
	end)
	subheader = note({
		Name = "Subheader",
		Position = UDim2.fromOffset(0, if mode.compact then 28 else 36),
		Size = UDim2.new(1, 0, 0, if mode.compact then 18 else 22),
		Text = "",
		TextSize = if mode.compact then 13 else 15,
		Visible = not mode.short,
		Parent = right,
	})
	bodyTop = if mode.short then 32 elseif mode.compact then 52 else 66
	local footer = if mode.compact then 0 else 28
	body = frame({
		Name = "Body",
		Position = UDim2.fromOffset(0, bodyTop),
		Size = UDim2.new(1, 0, 1, -(bodyTop + footer)),
		BackgroundTransparency = 1,
		Parent = right,
	})
	-- Rodapé: uma frase da casa por vez (dicas), em serifa itálica, sob a coluna do menu.
	local tip = Create("TextLabel", {
		Name = "Tip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, if mode.compact then 16 else 56, 1, if mode.compact then -6 else -26),
		Size = UDim2.fromOffset(if mode.compact then 230 else 520, if mode.compact then 30 else 22),
		BackgroundTransparency = 1,
		FontFace = TIP_FONT,
		Text = "",
		TextSize = if mode.compact then 12 else 16,
		TextColor3 = BONE_DIM,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		TextWrapped = mode.compact,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Visible = not mode.compact,
		Parent = root,
	}) :: TextLabel
	local tipClock = 0
	table.insert(frameUpdates, function(dt)
		tipClock += dt
		if tipClock > 7 or tip.Text == "" then
			tipClock = 0
			tipIndex = tipIndex % #TIPS + 1
			tip.Text = `“{TIPS[tipIndex]}” — {TIP_AUTHOR}`
		end
	end)
	-- Aviso curto de resultado (compra, erro, voto). No celular fica sobre a base do painel.
	feedback = label({
		Name = "Feedback",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = if mode.compact then UDim2.new(1, 0, 0, 34) else UDim2.fromOffset(420, 22),
		Text = "",
		TextSize = if mode.compact then 14 else Theme.SizeSmall,
		TextColor3 = GREEN,
		TextXAlignment = if mode.compact then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right,
		BackgroundColor3 = Theme.BgSunken,
		BackgroundTransparency = if mode.compact then 0.08 else 1,
		Visible = false,
		ZIndex = 5,
		Parent = right,
	})
	if mode.compact then
		local f = feedback :: TextLabel
		Components.corner(f, Theme.CornerSmall)
	end
	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
end

-- Classe de layout pela viewport da câmera: não depende da GUI recém-criada (sem medir 0 no
-- primeiro quadro e reconstruir em laço). As margens seguras ficam com o ScreenInsets.
local function currentMode(): MenuLayout.Mode
	local qaWidth, qaHeight = qaViewport()
	if qaWidth and qaHeight then
		local mode = MenuLayout.mode(qaWidth, qaHeight, true)
		mode.key ..= `@{qaWidth}x{qaHeight}`
		return mode
	end
	local size = workspace.CurrentCamera.ViewportSize
	return MenuLayout.mode(size.X, size.Y, UserInputService.TouchEnabled)
end

-- ===================== Palco 3D =====================

-- Fração horizontal da tela onde o Tung fica (desliza quando o painel abre ou fecha).
local stageU = 0.65
-- Momento (time()) da primeira abertura com o palco: medido para a régua de "abre em menos de 3 s".
local openedAt: number? = nil

-- Centro da faixa livre entre a coluna do menu e o painel (ou a borda direita), em fração da tela.
local function stageTarget(viewport: Vector2): number
	local root = rootFrame
	if not root or root.AbsoluteSize.X <= 0 or viewport.X <= 0 then
		return stageU
	end
	local scale = if rootScale then rootScale.Scale else 1
	local left = root.AbsolutePosition.X + railRight * scale
	local right = root.AbsolutePosition.X + root.AbsoluteSize.X
	local panel = contentPanel
	if panel and panel.Visible then
		right = panel.AbsolutePosition.X - 8
	end
	-- Tela inicial: o Tung fica entre a coluna e os cartões do passe/skin (no celular eles ficariam em cima dele).
	local widgets = homeOnly[1]
	if widgets and widgets.Visible and not (panel and panel.Visible) then
		right = math.min(right, widgets.AbsolutePosition.X - 8)
	end
	return math.clamp((left + right) / 2 / viewport.X, 0.2, 0.85)
end

-- Abertura: TUM · TUM · TUM e o Tung bate o bastão.
local function openingKnocks()
	local s = stage
	if s then
		MenuStage.react(s, "bash")
	end
	task.spawn(function()
		for index = 1, 3 do
			AudioController.play("StepWood", 0.42 - index * 0.06, 0.5, true)
			task.wait(0.42)
		end
	end)
end

local function updateStage(dt: number, open: boolean, opened: boolean)
	local s = stage
	if not s then
		return
	end
	MenuStage.setActive(s, open)
	-- O palco substitui as câmeras de segurança (laço Attract do CinematicController) atrás do menu.
	if player:GetAttribute("MenuStageActive") ~= open then
		player:SetAttribute("MenuStageActive", open)
		if open then
			Cinema.stop()
		end
	end
	if not open then
		if opened then
			Camera.endCinema()
		end
		return
	end
	-- Uma ação principal só (JOGAR): o atalho solto da Caçada (MidnightHuntUi, fora deste repo) some com o menu
	-- aberto; a Caçada fica dentro do painel do JOGAR.
	local hunt = player.PlayerGui:FindFirstChild("MidnightHuntUi")
	local huntEntry = hunt and hunt:FindFirstChild("MidnightHuntEntry", true)
	if huntEntry and huntEntry:IsA("GuiObject") then
		huntEntry.Visible = false
	end
	if not openedAt then
		-- Prova do tempo de abertura (régua do Crítico: menos de 3 s até o menu aparecer com o palco).
		local now = time()
		openedAt = now
		log.info("open with 3D stage at %.2f s of client time", now)
	end
	local beat = MenuStage.step(s, dt)
	local camera = workspace.CurrentCamera
	local viewport = camera.ViewportSize
	stageU += (stageTarget(viewport) - stageU) * (1 - math.exp(-dt * 6))
	local frameCf, fov = MenuStage.frame(s, stageU, viewport.X / math.max(viewport.Y, 1), camera.FieldOfView)
	Camera.setCinema(frameCf, fov)
	if beat then
		AudioController.play("StepWood", 0.22, 0.5, true)
	end
	local logo = brandScale
	if logo then
		logo.Scale = 1 + s.pulse * s.pulse * 0.035
	end
end

-- ===================== Ciclo =====================

function Controller.debugState(): { [string]: any }
	return {
		open = gui ~= nil and gui.Enabled,
		tab = currentTab,
		servers = serverCache ~= nil,
		friends = friendsCache ~= nil,
	}
end

-- Para QA: troca a aba como um clique faria.
function Controller.select(id: string)
	selectTab(id :: TabId)
end

-- Abertura em menos de 3 s: logo sobre preto já no Init (antes de o mundo e o palco existirem). Some com um
-- esmaecer quando o menu abre de verdade (ou quando a abertura do jogo assume a tela).
local splash: ScreenGui? = nil

function Controller.Init()
	local screen = Create("ScreenGui", {
		Name = "MenuSplash",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 250,
	}) :: ScreenGui
	local black = Create("Frame", {
		Name = "Black",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = screen,
	})
	Create("TextLabel", {
		Name = "Logo",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.new(1, -40, 0, 70),
		BackgroundTransparency = 1,
		FontFace = LOGO_FONT,
		Text = "TUNG TUNG SAHUR",
		TextScaled = true,
		TextColor3 = BONE,
		Parent = black,
	}, {
		Create("UITextSizeConstraint", { MaxTextSize = 64 }),
	})
	Create("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.46, 50),
		Size = UDim2.new(1, -40, 0, 24),
		BackgroundTransparency = 1,
		FontFace = MENU_FONT,
		Text = "A CASA ESTÁ ACORDANDO...",
		TextSize = 18,
		TextColor3 = BONE_DIM,
		Parent = black,
	})
	screen.Parent = player:WaitForChild("PlayerGui")
	splash = screen
	log.info("splash on screen at %.2f s of client time", time())
end

-- Tira a abertura com um esmaecer curto (a cena 3D aparece por baixo).
local function dropSplash()
	local screen = splash
	if not screen then
		return
	end
	splash = nil
	for _, item in screen:GetDescendants() do
		if item:IsA("Frame") then
			TweenService:Create(item, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("TextLabel") then
			TweenService:Create(item, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end
	task.delay(0.9, function()
		screen:Destroy()
	end)
end

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		dropSplash()
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState")
	menuMode = currentMode()
	gui = build(menuMode :: MenuLayout.Mode)
	-- Cena 3D do menu (fica apagada e parada enquanto o menu está fechado).
	stage = MenuStage.build()
	MenuStage.setActive(stage :: MenuStage.Stage, false)
	-- Loja, Ajustes e Caçada abrem por cima do menu: mesma pele (madeira escura, Oswald), sem mudar tamanhos.
	task.spawn(function()
		for _, name in { "StoreUi", "ComfortOptions", "MidnightHuntUi" } do
			local screen = player:WaitForChild("PlayerGui"):WaitForChild(name, 10)
			if screen then
				MenuSkin.apply(screen, 0, 0)
			end
		end
	end)
	-- Qualquer mudança de saldo, estoque, nível ou voto redesenha a aba (no máximo uma vez por quadro).
	for _, name in
		{
			"Fichas",
			"Creditos",
			"Perks",
			"Consumables",
			"Loadout",
			"StoryProgress",
			"StoryPass",
			"Vip",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			dirty = true
		end)
	end
	-- QA (harness da campanha): vota pelo atributo ModeQARequest, como o menu antigo.
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		if ok and type(args) == "table" and args.modeMenuQA then
			local function qaVote()
				local command = player:GetAttribute("ModeQARequest")
				local mode = if type(command) == "string" then string.match(command, "^([%a]+):%d+$") else nil
				if mode == "Story" or mode == "Standard" then
					task.spawn(function()
						Remotes.clientFunction("SelectGameMode"):InvokeServer(mode)
					end)
				end
			end
			player:GetAttributeChangedSignal("ModeQARequest"):Connect(qaVote)
			qaVote()
		end
		-- QA de layout/fluxo sem foco de janela: "tab:perks" | "confirm:x" (toca CONFIRMAR no diálogo).
		player:GetAttributeChangedSignal("MenuQARequest"):Connect(function()
			local raw = player:GetAttribute("MenuQARequest")
			if type(raw) ~= "string" then
				return
			end
			local command, arg = string.match(raw, "^(%a+):([%w_]+)$")
			if command == "tab" and arg then
				selectTab(arg :: TabId)
			elseif command == "confirm" then
				local run = pendingConfirm
				if run then
					run()
				end
			end
		end)
	end
	RunService:BindToRenderStep("S9MainMenu", Enum.RenderPriority.Last.Value, function(dt: number)
		local screen = gui
		if not screen then
			return
		end
		local open = state:GetAttribute("Phase") == "Lobby" and player:GetAttribute("OpeningActive") ~= true
		if
			splash and (open or player:GetAttribute("OpeningActive") == true or state:GetAttribute("Phase") ~= "Lobby")
		then
			dropSplash()
		end
		player:SetAttribute("ModeMenuOpen", open)
		if open then
			-- Troca de classe (PC ↔ celular ↔ celular baixo) reconstrói a moldura; só escala, ajusta.
			local mode = currentMode()
			local current = menuMode
			if not current or mode.key ~= current.key then
				menuMode = mode
				local rebuilt = build(mode)
				screen:Destroy()
				gui, screen = rebuilt, rebuilt
				dirty = true
			elseif math.abs(mode.scale - current.scale) > 0.005 then
				menuMode = mode
				local root, scale = rootFrame, rootScale
				if root and scale then
					scale.Scale = mode.scale
					root.Size = UDim2.fromScale(1 / mode.scale, 1 / mode.scale)
				end
			end
			local b = body
			if b and currentTab == "play" and b.AbsoluteSize.X > 0 then
				if MenuLayout.columns(b.AbsoluteSize.X) ~= columnsShown then
					dirty = true
				end
			end
		end
		-- A loja abre por cima: a moldura some enquanto ela estiver aberta. O ScreenGui segue ligado (o atalho
		-- solto da Caçada, fora deste repo, só some com o menu ligado), só o conteúdo se esconde.
		screen.Enabled = open
		local frameRoot = rootFrame
		if frameRoot then
			frameRoot.Visible = not Store.isOpen()
		end
		if open and not wasOpen then
			Cinema.stop()
			currentTab = "home"
			openingKnocks()
			dirty = true
		end
		if open then
			if not Store.isOpen() then
				UserInputService.MouseBehavior = Enum.MouseBehavior.Default
				UserInputService.MouseIconEnabled = true
			end
			if dirty then
				dirty = false
				renderTab()
			end
			for _, update in live do
				update()
			end
			for _, update in frameUpdates do
				update(dt)
			end
		elseif wasOpen then
			UserInputService.MouseIconEnabled = false
		end
		updateStage(dt, open, wasOpen)
		wasOpen = open
	end)
end

return Controller
