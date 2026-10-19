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
local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
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
local TungTungRig = require("../Creature/TungTungRig")

type TabId = "play" | "perks" | "store" | "season" | "daily" | "servers" | "friends" | "settings"

local player = Players.LocalPlayer
local GREEN = Theme.Success
local VEIL = Theme.Overlay
local CARD = Theme.BgPanel

-- `short` é o rótulo do trilho compacto (cabe em 76 px).
local NAV: { { id: TabId, label: string, short: string, icon: string } } = {
	{ id = "play", label = "JOGAR", short = "JOGAR", icon = "Play" },
	{ id = "perks", label = "MELHORIAS", short = "MELHORIAS", icon = "Perks" },
	{ id = "store", label = "LOJA", short = "LOJA", icon = "Store" },
	{ id = "season", label = "PASSE DA TEMPORADA", short = "PASSE", icon = "Season" },
	{ id = "daily", label = "PRÊMIO DIÁRIO", short = "PRÊMIOS", icon = "Daily" },
	{ id = "servers", label = "SERVIDORES", short = "SERVIDORES", icon = "Servers" },
	{ id = "friends", label = "AMIGOS", short = "AMIGOS", icon = "Friends" },
	{ id = "settings", label = "AJUSTES", short = "AJUSTES", icon = "Settings" },
}
-- Abas que só abrem a loja.
local STORE_TABS: { [string]: string } = { store = "shop", season = "season", daily = "daily" }
local TIPS = {
	"OUVIU TUM TUM TUM? APAGUE A LANTERNA E SE ESCONDA!",
	"AGACHADO VOCÊ FAZ MENOS BARULHO.",
	"AMIGO CAIU? CHEGUE PERTO E APERTE E PARA AJUDAR.",
	"MOEDAS BRILHANTES VIRAM FICHAS. A GEMA ROXA VALE MUITO MAIS!",
	"FITAS VHS ESCONDIDAS DÃO FICHAS PARA O TIME TODO.",
	"NO MODO HISTÓRIA, TERMINAR SEM CAIR DÁ BÔNUS.",
	"CONVIDE AMIGOS: EM TIME É MAIS FÁCIL (E MAIS DIVERTIDO)!",
}

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
local currentTab: TabId = "play"
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
local singleColumn = false

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
	singleColumn = columns == 1
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

-- Arte original do cartão: céu noturno em gradiente, lua e horizonte pixel-art (casa ou mata).
local function campaignArt(parent: Instance, story: boolean, m: CardMetrics): Frame
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
			then ColorSequence.new(Color3.fromRGB(30, 42, 66), Color3.fromRGB(86, 58, 36))
			else ColorSequence.new(Color3.fromRGB(16, 34, 44), Color3.fromRGB(24, 56, 42)),
		Parent = art,
	})
	local moon = Create("Frame", {
		Name = "Moon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 10),
		Size = UDim2.fromOffset(22, 22),
		BackgroundColor3 = Theme.GoldLight,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		Parent = art,
	})
	Components.corner(moon, Theme.CornerPill)
	-- Horizonte: silhuetas escuras; as janelas da casa deixam o céu quente aparecer como luz acesa.
	local big = math.max(36, math.floor((m.art - 16) / 12) * 12)
	local small = math.max(24, big - 24)
	local shapes: { { string | number } } = if story
		then { { "Tree", small, 0.52 }, { "House", big, 0.66 }, { "Tree", small, 0.8 } }
		else {
			{ "Tree", small, 0.5 },
			{ "Tree", big, 0.62 },
			{ "Tree", small + 12, 0.75 },
			{ "Tree", small, 0.86 },
		}
	for _, shape in shapes do
		local size = shape[2] :: number
		Components.icon(art, shape[1] :: string, size, Theme.Overlay, {
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(shape[3] :: number, 0, 1, 2),
		})
	end
	Create("Frame", {
		Name = "Ground",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.Overlay,
		BorderSizePixel = 0,
		Parent = art,
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
	Components.chip(eyebrow, if story then Theme.Gold else GREEN, {
		Position = UDim2.fromOffset(m.pad, 10),
		Parent = art,
	})
	local titleLabel = label({
		Name = "Title",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, m.pad, 1, -8),
		Size = UDim2.new(0.62, 0, 0, m.title + 6),
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
		border.Color = if mine then Theme.Gold else Theme.Border
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

-- Vitrine: o próprio Tung Tung do jogo, animado, com a "fala" dele.
local function showcase(parent: Instance, order: number)
	local portraitWidth = if singleColumn then 110 else 200
	local textX = portraitWidth + 10
	local box = Components.panel({
		Name = "Showcase",
		ClipsDescendants = true,
		Size = UDim2.new(1, 0, 0, if compactMenu then 132 else 150),
		LayoutOrder = order,
		Parent = parent,
	})
	Create("UIGradient", {
		Color = ColorSequence.new(Theme.BgElevated, Theme.Bg),
		Rotation = 0,
		Parent = box,
	})
	local viewport = Create("ViewportFrame", {
		Name = "TungTung",
		Size = UDim2.new(0, portraitWidth, 1, 0),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 140, 170),
		LightColor = Color3.fromRGB(255, 226, 180),
		LightDirection = Vector3.new(-0.6, -1, 0.4),
		Parent = box,
	}) :: ViewportFrame
	Components.icon(box, "Drum", 24, Theme.Gold, { Position = UDim2.fromOffset(textX, 12) })
	label({
		Position = UDim2.fromOffset(textX + 32, 8),
		Size = UDim2.new(1, -textX - 44, 0, 32),
		Text = "TUNG TUNG SAHUR",
		TextSize = if singleColumn then 20 else 26,
		TextColor3 = Theme.GoldLight,
		Parent = box,
	})
	note({
		Position = UDim2.fromOffset(textX, 46),
		Size = UDim2.new(1, -textX - 12, 0, 24),
		Text = "“TUM... TUM... TUM... SAHUR!”",
		TextSize = 15,
		TextColor3 = Theme.TextPrimary,
		Parent = box,
	})
	note({
		Position = UDim2.fromOffset(textX, 74),
		Size = UDim2.new(1, -textX - 12, 0, 56),
		Text = "Ele anda pela casa com o bastão. Apague a lanterna, se esconda nos armários e salve seus amigos!",
		TextSize = 14,
		Parent = box,
	})
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local rig = TungTungRig.build(world)
	if rig then
		local camera = Instance.new("Camera")
		camera.FieldOfView = 30
		camera.CFrame = CFrame.lookAt(Vector3.new(0, 4.6, -13.5), Vector3.new(0, 3.9, 0))
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		local clips: { TungTungRig.ClipName } = { "idle", "slash", "strafe", "walk", "sheath" }
		local index, showClock, sway = 1, 0, 0
		local connection: RBXScriptConnection? = nil
		connection = RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then
				if connection then
					connection:Disconnect()
				end
				return
			end
			local screen = gui
			if not screen or not screen.Enabled then
				return
			end
			showClock += dt
			sway += dt
			if showClock > 3 then
				showClock = 0
				index = index % #clips + 1
				TungTungRig.play(rig, clips[index], 0.3)
			end
			TungTungRig.place(rig, CFrame.Angles(0, math.sin(sway * 0.6) * 0.5, 0))
			TungTungRig.step(rig, dt)
		end)
	end
end

local function buildPlay(parent: Frame)
	local width = parent.AbsoluteSize.X
	if width <= 0 then
		width = if compactMenu then 600 else 900
	end
	local columns = MenuLayout.columns(width)
	columnsShown = columns
	singleColumn = columns == 1
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
		"THE CURSED HOUSE",
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
	showcase(scroll, 4)
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
	for id, nav in navButtons do
		local selected = id == currentTab
		-- No PC o JOGAR é sempre a ação principal; os demais destinos marcam a aba aberta.
		if id ~= "play" or compactMenu then
			Components.setVariant(nav, if selected then "secondary" elseif id == "play" then "primary" else "ghost")
		end
		local bar = nav:FindFirstChild("Bar")
		if bar and bar:IsA("Frame") then
			bar.Visible = selected
		end
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
		Store.openTab(storeTab)
		return
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

-- Barra superior: marca à esquerda; moedas, + Créditos e perfil (nível/XP) à direita.
local function topBar(root: Frame, mode: MenuLayout.Mode): number
	local compact = mode.compact
	local height = if mode.short then 46 elseif compact then 52 else 60
	local margin = if compact then 8 else 28
	local y = if compact then 6 else 20
	local bar = Create("Frame", {
		Name = "TopBar",
		Position = UDim2.fromOffset(margin, y),
		Size = UDim2.new(1, -2 * margin, 0, height),
		BackgroundTransparency = 1,
		Parent = root,
	})
	-- O "REC" da câmera de segurança já aparece atrás do menu (CinematicController); sem ponto duplicado.
	local brandY = if compact then 0 else -9
	local logo = Components.title({
		Name = "Logo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, brandY),
		Size = UDim2.fromOffset(if compact then 210 else 440, 38),
		Text = "TUNG TUNG SAHUR",
		TextSize = if compact then 21 else 34,
		TextColor3 = Theme.GoldLight,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = bar,
	})
	logo.TextStrokeColor3 = Theme.Overlay
	logo.TextStrokeTransparency = 0.1
	if not compact then
		Components.text({
			Name = "Subtitle",
			Position = UDim2.new(0, 0, 0.5, 11),
			Size = UDim2.fromOffset(440, 18),
			Text = "THE CURSED HOUSE · EXPLORE, PEGUE MOEDAS E FUJA DO TUM TUM TUM",
			FontFace = Theme.Font,
			TextSize = 13,
			TextColor3 = Theme.TextSecondary,
			TextWrapped = false,
			Parent = bar,
		})
	end

	local status = Create("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(1, -240, 1, 0),
		BackgroundTransparency = 1,
		Parent = bar,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local badgeHeight = if compact then 38 else 40
	local badgeWidth = if compact then 100 else 140
	local _, setFichas = Components.currency("fichas", {
		Size = UDim2.fromOffset(badgeWidth, badgeHeight),
		LayoutOrder = 1,
		Parent = status,
	})
	local _, setCreditos = Components.currency("creditos", {
		Size = UDim2.fromOffset(badgeWidth, badgeHeight),
		LayoutOrder = 2,
		Parent = status,
	})
	Components.iconButton("success", "Plus", nil, {
		Name = "AddCredits",
		Size = UDim2.fromOffset(badgeHeight, badgeHeight),
		LayoutOrder = 3,
		Parent = status,
	}, function()
		click()
		Store.openTab("robux")
	end)

	local profileHeight = if compact then 40 else 48
	local avatar = profileHeight - 8
	local profile = Create("Frame", {
		Name = "Profile",
		Size = UDim2.fromOffset(if compact then 118 else 240, profileHeight),
		BackgroundColor3 = Theme.BgSunken,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		LayoutOrder = 4,
		Parent = status,
	})
	Components.corner(profile, Theme.CornerLarge)
	Components.stroke(profile, Theme.Gold, 1, 0.55)
	local face = Create("ImageLabel", {
		Name = "Avatar",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.fromOffset(avatar, avatar),
		BackgroundColor3 = Theme.BgElevated,
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
		Parent = profile,
	})
	Components.corner(face, Theme.CornerPill)
	local textX = avatar + 12
	local nameLabel: TextLabel? = nil
	if not compact then
		nameLabel = Components.text({
			Name = "PlayerName",
			Position = UDim2.fromOffset(textX, 4),
			Size = UDim2.new(1, -(textX + 8), 0, 18),
			FontFace = Theme.Font,
			TextSize = 15,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = player.DisplayName,
			Parent = profile,
		})
	end
	local levelLabel = Components.text({
		Name = "Level",
		Position = UDim2.fromOffset(textX, if compact then 3 else 22),
		Size = UDim2.new(1, -(textX + 8), 0, 16),
		FontFace = Theme.Font,
		TextSize = 13,
		TextColor3 = Theme.Gold,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Text = "",
		Parent = profile,
	})
	local xpTrack, setXp = Components.progress({
		Name = "Xp",
		Position = UDim2.new(0, textX, 1, -12),
		Size = UDim2.new(1, -(textX + 10), 0, 6),
	}, GREEN)
	xpTrack.Parent = profile
	table.insert(frameUpdates, function()
		setFichas(tonumber(player:GetAttribute("Fichas")) or 0)
		setCreditos(tonumber(player:GetAttribute("Creditos")) or 0)
		local xp = tonumber(player:GetAttribute("Xp")) or 0
		local level, into, needed = Economy.levelInfo(xp)
		levelLabel.Text =
			px(if compact then `NÍVEL {level}` else `NÍVEL {level} · {number(into)}/{number(needed)} XP`)
		setXp(into / math.max(needed, 1))
		local nameText = nameLabel
		if nameText then
			local titleId = player:GetAttribute("Title")
			local titleItem = if type(titleId) == "string" then StoreCatalog.ItemById[titleId] else nil
			local suffix = (if titleItem then ` · {titleItem.name}` else "")
				.. (if player:GetAttribute("Vip") == true then " · VIP" else "")
			nameText.Text = player.DisplayName .. suffix
		end
	end)
	return y + height
end

-- Trilho do PC: JOGAR em destaque e os demais destinos com ícone e rótulo.
local function desktopRail(root: Frame, top: number): number
	local width = 248
	local rail = Create("Frame", {
		Name = "Rail",
		Position = UDim2.fromOffset(28, top),
		Size = UDim2.new(0, width, 1, -(top + 28)),
		BackgroundTransparency = 1,
		Parent = root,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in NAV do
		local isPlay = item.id == "play"
		local nav = Components.iconButton(if isPlay then "primary" else "ghost", item.icon, item.label, {
			Name = `Nav_{item.id}`,
			LayoutOrder = i * 10,
			Size = UDim2.new(1, 0, 0, if isPlay then 60 else 46),
			TextSize = if isPlay then 26 else 18,
			Parent = rail,
		}, function()
			click()
			selectTab(item.id)
		end)
		if not isPlay then
			Create("Frame", {
				Name = "Bar",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.new(0, 4, 0.6, 0),
				BackgroundColor3 = Theme.Gold,
				BorderSizePixel = 0,
				Visible = false,
				Parent = nav,
			})
		end
		if STORE_TABS[item.id] or item.id == "settings" then
			-- Abre outra janela (loja/ajustes): seta discreta deixa isso claro antes do clique.
			Components.text({
				Name = "Opens",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(16, 20),
				Text = "›",
				TextSize = 22,
				TextColor3 = Theme.TextMuted,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = nav,
			})
		end
		if item.id == "daily" then
			notifyDot(nav, UDim2.new(1, -38, 0.5, 0))
		end
		if isPlay then
			Create("Frame", {
				Name = "Spacer",
				Size = UDim2.new(1, 0, 0, 6),
				BackgroundTransparency = 1,
				LayoutOrder = 15,
				Parent = rail,
			})
		end
		navButtons[item.id] = nav
	end
	return 28 + width + 20
end

-- Peça do trilho compacto: ícone em cima, rótulo curto embaixo (alvo de toque >= 52 px).
local function railTile(
	parent: Instance,
	id: string,
	text: string,
	icon: string,
	order: number,
	height: number,
	onClick: () -> ()
): TextButton
	local tile = Components.button(if id == "play" then "primary" else "ghost", {
		Name = `Nav_{id}`,
		Text = "",
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		Parent = parent,
	}, function()
		click()
		onClick()
	end)
	Components.icon(tile, icon, 24, tile.TextColor3, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, if height < 56 then 6 else 8),
	})
	local caption = Components.text({
		Name = "Label",
		Position = UDim2.new(0, 2, 1, -20),
		Size = UDim2.new(1, -4, 0, 16),
		Text = text,
		FontFace = Theme.Font,
		TextSize = 11,
		TextColor3 = tile.TextColor3,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = tile,
	})
	tile:GetPropertyChangedSignal("TextColor3"):Connect(function()
		caption.TextColor3 = tile.TextColor3
	end)
	return tile
end

-- Trilho do celular: 4 destinos + MAIS (prêmio diário, servidores, amigos, ajustes num menu curto).
local function compactRail(root: Frame, top: number, mode: MenuLayout.Mode): number
	local width = 76
	local rail = Create("ScrollingFrame", {
		Name = "Rail",
		Position = UDim2.fromOffset(8, top),
		Size = UDim2.new(0, width, 1, -(top + 8)),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = root,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local height = if mode.short then 52 else 58
	local visible, overflow = MenuLayout.split(NAV, true)
	for i, item in visible do
		navButtons[item.id] = railTile(rail, item.id, item.short, item.icon, i, height, function()
			selectTab(item.id)
		end)
	end
	-- Fundo que fecha o MAIS ao tocar fora; o menu fica ao lado do trilho, acima do painel.
	local catcher = Create("TextButton", {
		Name = "MoreCatcher",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Overlay,
		BackgroundTransparency = 0.6,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 20,
		Parent = root,
	}) :: TextButton
	local itemHeight = Theme.TouchMin
	local popover = Components.panel({
		Name = "More",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8 + width + 8, 1, -8),
		Size = UDim2.fromOffset(240, #overflow * (itemHeight + 6) + 18),
		BackgroundColor3 = Theme.BgPanel,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 21,
		Parent = root,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	Components.padding(popover, 9)
	local function setMore(open: boolean)
		popover.Visible = open
		catcher.Visible = open
	end
	catcher.Activated:Connect(function()
		setMore(false)
	end)
	for i, item in overflow do
		local entry = Components.iconButton("ghost", item.icon, item.label, {
			Name = `More_{item.id}`,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, itemHeight),
			TextSize = 16,
			ZIndex = 22,
			Parent = popover,
		}, function()
			click()
			setMore(false)
			selectTab(item.id)
		end)
		for _, child in entry:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = 22
			end
		end
		if item.id == "daily" then
			notifyDot(entry, UDim2.new(1, -16, 0.5, 0)).ZIndex = 23
		end
	end
	local more = railTile(rail, "more", "MAIS", "More", #visible + 1, height, function()
		setMore(not popover.Visible)
	end)
	notifyDot(more, UDim2.new(1, -12, 0, 12))
	return 8 + width + 8
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
	-- Véu: escuro à esquerda (leitura), aberto à direita (as câmeras da casa aparecem atrás).
	Create("Frame", {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = VEIL,
		BorderSizePixel = 0,
		Parent = root,
	}, {
		Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.05),
				NumberSequenceKeypoint.new(0.35, 0.25),
				NumberSequenceKeypoint.new(1, 0.5),
			}),
		}),
	})

	local top = topBar(root, mode) + (if mode.compact then 6 else 20)
	local left = if mode.compact then compactRail(root, top, mode) else desktopRail(root, top)
	local margin = if mode.compact then 8 else 28

	local right = Components.panel({
		Name = "Content",
		Position = UDim2.fromOffset(left, top),
		Size = UDim2.new(1, -(left + margin), 1, -(top + margin)),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.12,
		Parent = root,
	})
	local rightCorner = right:FindFirstChildOfClass("UICorner")
	if rightCorner then
		rightCorner.CornerRadius = Theme.CornerLarge
	end
	local padX = if mode.compact then 10 else 20
	local padY = if mode.compact then 8 else 16
	Components.padding(right, padX, padY)
	header = Components.title({
		Name = "Header",
		Size = UDim2.new(1, 0, 0, if mode.compact then 26 else 32),
		Text = "",
		TextSize = if mode.compact then 20 else 28,
		Parent = right,
	})
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
	if not mode.compact then
		local tip = label({
			Name = "Tip",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, -440, 0, 20),
			Text = "",
			TextSize = Theme.SizeSmall,
			TextColor3 = Theme.TextMuted,
			Parent = right,
		})
		tip.TextWrapped, tip.TextTruncate = false, Enum.TextTruncate.AtEnd
		local tipClock = 0
		table.insert(frameUpdates, function(dt)
			tipClock += dt
			if tipClock > 6 or tip.Text == "" then
				tipClock = 0
				tipIndex = tipIndex % #TIPS + 1
				tip.Text = px("DICA: " .. TIPS[tipIndex])
			end
		end)
	end
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

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState")
	menuMode = currentMode()
	gui = build(menuMode :: MenuLayout.Mode)
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
		-- A loja abre por cima: o menu some enquanto ela estiver aberta.
		screen.Enabled = open and not Store.isOpen()
		if open and not wasOpen then
			Cinema.stop()
			currentTab = "play"
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
		wasOpen = open
	end)
end

return Controller
