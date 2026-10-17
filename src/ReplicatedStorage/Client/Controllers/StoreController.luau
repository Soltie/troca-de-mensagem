--!strict
--[[
	Loja do Turno (cliente): só MOSTRA e PEDE. Preço, posse, sorteio, política e moedas são
	decididos no servidor (StoreService); o estado vem dos atributos do Player.

	Abre com L (ou Select no controle) fora da ação: intro, intervalo, telas finais, ou enquanto
	espera/assiste na campanha. Abas: LOJA, BAÚS, DIÁRIO, COLEÇÃO, CRÉDITOS.
	- Baús: botão "CHANCES (DETALHES)" mostra todas as chances em % ANTES de abrir (regra de
	  itens aleatórios pagos). O baú pago some/trava para contas restritas pela PolicyService.
	- Recompensas (StoreNotice): relatório do turno, fita achada, nível novo e compra, em
	  avisos curtos com som. Botão modal libera o mouse da primeira pessoa enquanto aberta.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Season = require("@game/ReplicatedStorage/Shared/Game/Season")
local SeasonCatalog = require("@game/ReplicatedStorage/Shared/Game/SeasonCatalog")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local StoreView = require("@game/ReplicatedStorage/Shared/Game/StoreView")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local Components = require("../UI/Components")
local Create = require("../UI/Create")
local ItemPreview = require("../UI/ItemPreview")
local Theme = require("../UI/Theme")
local ViewportQA = require("../UI/ViewportQA")
local AudioController = require("./AudioController")

type Tab = "shop" | "season" | "chests" | "daily" | "collection" | "robux"

local player = Players.LocalPlayer
local TABS: { Tab } = { "shop", "season", "chests", "daily", "collection", "robux" }
local S = Text.Store

local panel: Frame? = nil
local content: ScrollingFrame? = nil
local overlay: Frame? = nil
local message: TextLabel? = nil
local hintLabel: TextLabel? = nil
local toastHolder: Frame? = nil
local tabButtons: { [Tab]: TextButton } = {}
local kindButtons: { [string]: TextButton } = {}
local tab: Tab = "shop"
local kindFilter: StoreCatalog.ItemKind = "flashlight"
-- Remaster: item em foco no painel de detalhe, layout da janela e setters da barra superior.
local selectedItem: string? = nil
local detail: Frame? = nil
local kindsBar: Frame? = nil
local compactStore = false
local shortStore = false
local twoPane = true
local setFichasBadge: ((number) -> ())? = nil
local setCreditosBadge: ((number) -> ())? = nil
local setXpBar: ((number) -> ())? = nil
local levelChip: TextLabel? = nil

local TAB_ICONS: { [Tab]: string } = {
	shop = "Store",
	season = "Season",
	chests = "Chest",
	daily = "Daily",
	collection = "Tape",
	robux = "Gem",
}
local isOpen = false
-- Animação em curso (roleta/baú): mudanças de atributo não redesenham a aba no meio dela.
local animating = false
local busy = false
local phase: GameState.Phase = "Loading"
local mouseWasEnabled = false
local toastToken = 0

local function rgb(c: StoreCatalog.RGB): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- A fonte do tema (FredokaOne) tem acentos; o texto passa direto.
local function px(value: string): string
	return value
end

local function attr(name: string, fallback: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

local function jsonSet(name: string): { [string]: boolean }
	local set = {}
	local ok, list = pcall(function()
		return HttpService:JSONDecode(attr(name, "[]"))
	end)
	if ok and type(list) == "table" then
		for _, id in list do
			set[id] = true
		end
	end
	return set
end

local function equippedId(kind: StoreCatalog.ItemKind): string
	local names = { flashlight = "EquipFlashlight", uniform = "EquipUniform", filter = "EquipFilter", title = "Title" }
	return attr((names :: any)[kind], StoreCatalog.defaultFor(kind))
end

-- Pode abrir agora? (fora da ação, ou esperando/assistindo na campanha)
local function allowed(): boolean
	local status = player:GetAttribute("CampaignStatus")
	return phase ~= "Playing" or status == "Waiting" or status == "Escaped"
end

local function label(props: { [string]: any }): TextLabel
	local base: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = Theme.SizeBody,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	return Create("TextLabel", base) :: TextLabel
end

-- Botão do tema. A cor de texto legada vira variante: destaque (Hazard) = principal,
-- verde (Good) = sucesso, apagado (TextDim) ou demais = secundário. O clique sempre chega.
local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local color = props.TextColor3
	local variant: Components.Variant = props.Variant
		or (if color == Theme.Hazard then "primary" elseif color == Theme.Good then "success" else "secondary")
	props.Variant, props.TextColor3, props.BackgroundColor3 = nil, nil, nil
	if props.TextSize == nil then
		props.TextSize = Theme.SizeSmall
	end
	return Components.button(variant, props, function()
		AudioController.play("UiBlip", 1, 1.1, true)
		onClick()
	end)
end

local function setMessage(key: string?)
	local m = message
	if not m then
		return
	end
	local text = if key then (Text.Messages :: any)[key] or key else ""
	m.Text = text
end

local function request(action: string, arg: string?): Types.Result<any>?
	if busy then
		return nil
	end
	busy = true
	local ok, response = pcall(function()
		return Remotes.clientFunction("Store", 5):InvokeServer(action, arg)
	end)
	busy = false
	if not ok then
		setMessage("store_error")
		return nil
	end
	return response
end

local function track(event: string, offer: string?)
	Remotes.clientEvent("StoreTrack", 5):FireServer(event, offer)
end

-- ===================== Avisos (toasts) =====================

local function showToast(lines: { string }, color: Color3?, duration: number?)
	local holder = toastHolder
	if not holder then
		return
	end
	-- Cenas (abertura, fuga, capítulo) passam limpas: o aviso espera a cena terminar (CinematicController).
	if player:GetAttribute("CinematicHold") == true then
		task.delay(0.5, showToast, lines, color, duration)
		return
	end
	toastToken += 1
	local card = Create("Frame", {
		Size = UDim2.fromOffset(330, 26 + #lines * 20),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		LayoutOrder = -toastToken,
		Parent = holder,
	}, {
		Create("UIStroke", { Color = color or Theme.Hazard, Thickness = 2 }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 8) }),
		Create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame
	for index, line in lines do
		label({
			Size = UDim2.new(1, -10, 0, 20),
			Text = px(line),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = if index == 1 then (color or Theme.Hazard) else Theme.Text,
			LayoutOrder = index,
			Parent = card,
		})
	end
	task.delay(duration or 5, function()
		card:Destroy()
	end)
end

-- O aviso do fim da partida chega junto com a fase: espera um instante para a cena de fuga começar.
local function toast(lines: { string }, color: Color3?, duration: number?)
	task.delay(0.35, showToast, lines, color, duration)
end

local function itemName(id: string): string
	local item = StoreCatalog.ItemById[id]
	return if item then item.name else id
end

local function onNotice(payload: { [string]: any })
	local lines: { string } = {}
	local kind = payload.kind
	if kind == "run" then
		table.insert(lines, Text.Rewards.run)
	elseif kind == "task" then
		table.insert(lines, "OBJETIVO CONCLUÍDO")
		table.insert(lines, if payload.contributed then "BÔNUS POR AJUDAR A EQUIPE" else "RECOMPENSA DA EQUIPE")
	elseif kind == "tape" then
		local tape = StoreCatalog.TapeById[payload.tape or ""]
		local title = if tape then tape.title else "?"
		if payload.new then
			table.insert(lines, string.format(Text.Rewards.tape, payload.finder or "", title))
		else
			table.insert(lines, string.format(Text.Rewards.tapeOld, title))
		end
	elseif kind == "daily" then
		table.insert(lines, string.format(Text.Rewards.daily, payload.day or 1))
	elseif kind == "purchase" then
		table.insert(lines, Text.Rewards.purchase)
	elseif kind == "story" then
		table.insert(lines, string.format(Text.Rewards.story, payload.chapter or 1))
		if payload.first then
			table.insert(lines, Text.Rewards.storyFirst)
		end
		if payload.flawless then
			table.insert(lines, Text.Rewards.storyFlawless)
		end
		if payload.completed then
			table.insert(lines, Text.Rewards.storyComplete)
		end
		if payload.pass then
			table.insert(lines, Text.Rewards.storyPass)
		end
	elseif kind == "season" then
		table.insert(lines, if payload.premium then Text.Rewards.seasonPremium else Text.Rewards.seasonRewards)
		for _, tier in payload.tiers or {} do
			table.insert(lines, string.format(Text.Rewards.season, tier))
		end
	end
	if (payload.seasonXp or 0) > 0 then
		table.insert(lines, string.format(Text.Rewards.seasonXp, payload.seasonXp))
	end
	if (payload.fichas or 0) > 0 then
		table.insert(lines, string.format(Text.Rewards.fichas, payload.fichas))
	end
	if (payload.creditos or 0) > 0 then
		table.insert(lines, string.format(Text.Rewards.creditos, payload.creditos))
	end
	if (payload.xp or 0) > 0 then
		table.insert(lines, string.format(Text.Rewards.xp, payload.xp))
	end
	if kind == "run" and payload.vip then
		table.insert(lines, Text.Rewards.vipBonus)
	end
	for _, level in payload.levels or {} do
		table.insert(lines, string.format(Text.Rewards.level, level))
	end
	for _, id in payload.items or {} do
		table.insert(lines, string.format(Text.Rewards.item, itemName(id)))
	end
	-- Consumíveis (Segunda Chance, Pilha Extra, Continuação) que entraram no estoque.
	for id, amount in payload.consumables or {} do
		local def = Perks.ConsumableById[id]
		if def and type(amount) == "number" then
			table.insert(lines, string.format(Text.Rewards.consumable, amount, def.name))
		end
	end
	if #lines == 0 then
		return
	end
	local leveled = payload.levels and #payload.levels > 0
	AudioController.play(if leveled then "StingerWin" else "Pickup", if leveled then 0.6 else 0.8, nil, true)
	toast(lines, if leveled then Theme.Good else Theme.Hazard, if kind == "run" then 9 else 5)
end

-- ===================== Conteúdo das abas =====================

local function clearContent(): ScrollingFrame?
	local c = content
	if not c then
		return nil
	end
	for _, child in c:GetChildren() do
		if not child:IsA("UIGridLayout") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	return c
end

local function setLayout(c: ScrollingFrame, grid: boolean)
	for _, child in c:GetChildren() do
		if child:IsA("UIGridLayout") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if grid then
		Create("UIGridLayout", {
			CellSize = UDim2.fromOffset(196, 132),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = c,
		})
	else
		Create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = c,
		})
	end
end

local function card(parent: Instance, order: number, accent: Color3): Frame
	local box = Create("Frame", {
		BackgroundColor3 = Theme.BgPanel,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UIStroke", { Color = accent, Thickness = 1, Transparency = 0.3 }),
		Create("Frame", {
			Name = "Bar",
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}),
	}) :: Frame
	Components.corner(box, Theme.CornerSmall)
	return box
end

local render: () -> ()

local function priceText(currency: StoreCatalog.Currency, price: number): string
	return `{Components.formatNumber(price)} {if currency == "fichas" then "FICHAS" else "CRÉDITOS"}`
end

local function walletOf(currency: StoreCatalog.Currency): number
	return tonumber(attr(if currency == "fichas" then "Fichas" else "Creditos", 0)) or 0
end

local function clearOverlay(): Frame?
	local o = overlay
	if not o then
		return nil
	end
	for _, child in o:GetChildren() do
		child:Destroy()
	end
	o.Visible = true
	return o
end

local function modalBox(o: Frame, size: UDim2): Frame
	local box = Components.panel({
		Name = "Modal",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		BackgroundColor3 = Theme.BgPanel,
		BackgroundTransparency = 0,
		Parent = o,
	})
	local outline = box:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color, outline.Transparency = Theme.Gold, 0.3
	end
	return box
end

local function buyResult(result: Types.Result<any>?)
	if not result then
		return
	end
	if result.ok then
		setMessage(result.data.message)
		if result.data.ok then
			AudioController.play("Switch", 0.6, 1.4, true)
		end
	else
		setMessage("store_error")
	end
end

-- Pedido de compra confirmado: o servidor valida preço, saldo e posse (StoreService).
local function purchase(item: StoreCatalog.Item, currency: StoreCatalog.Currency)
	if overlay then
		overlay.Visible = false
	end
	buyResult(request(if currency == "fichas" then "buy_fichas" else "buy_creditos", item.id))
	render()
end

-- Compra com moeda do jogo: mostra item, preço e o saldo que sobra antes de pedir ao servidor.
local function confirmPurchase(item: StoreCatalog.Item, option: StoreView.PriceOption)
	local o = clearOverlay()
	if not o then
		return
	end
	local box = modalBox(o, UDim2.fromOffset(if compactStore then 360 else 440, 0))
	box.AutomaticSize = Enum.AutomaticSize.Y
	Components.padding(box, 18)
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = box,
	})
	local thumb = Create("Frame", {
		Name = "Thumb",
		Size = UDim2.fromOffset(96, 96),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = box,
	})
	ItemPreview.thumbnail(thumb, item)
	Components.title({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = `COMPRAR {item.name}?`,
		TextSize = 20,
		LayoutOrder = 2,
		Parent = box,
	})
	local left = walletOf(option.currency) - option.price
	Components.text({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center,
		FontFace = Theme.FontNote,
		TextColor3 = Theme.TextSecondary,
		Text = `Custa {priceText(option.currency, option.price)}. Depois você fica com {priceText(
			option.currency,
			left
		)}.`,
		TextSize = 15,
		LayoutOrder = 3,
		Parent = box,
	})
	local row = Create("Frame", {
		Name = "Actions",
		Size = UDim2.new(1, 0, 0, Theme.TouchMin),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
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
		o.Visible = false
	end)
	button({
		Name = "Confirm",
		Variant = "primary",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0.5, -5, 1, 0),
		Text = "CONFIRMAR",
		TextSize = 16,
		Parent = row,
	}, function()
		purchase(item, option.currency)
	end)
end

local openDetailModal: (StoreCatalog.Item) -> ()

-- Conteúdo do detalhe: prévia (3D girável quando há modelo), raridade, quem vê, como obter e ação.
local function fillDetail(container: Frame, item: StoreCatalog.Item, inModal: boolean)
	local rarity = StoreCatalog.Rarities[item.rarity]
	local accent = rgb(rarity.color)
	local owned = jsonSet("Owned")
	local vip = attr("Vip", false) == true
	local state = StoreView.state(item, owned, equippedId(item.kind), vip)
	-- A prévia cede espaço para o texto: nome, selos, quem vê e como obter precisam de ~140 px
	-- além dos botões (1 ou 2). Painel ainda sem medida (primeiro quadro) usa a proporção padrão.
	local buttonCount = if state == "buyable"
		then #StoreView.prices(item, walletOf("fichas"), walletOf("creditos"))
		elseif state == "locked" then 0
		else 1
	local height = container.AbsoluteSize.Y - 24
	local previewHeight = 0.44
	if height > 0 then
		local free = height - 150 - buttonCount * (Theme.TouchMin + 8)
		previewHeight = math.clamp(free / height, 0.22, 0.5)
	end
	local preview = Create("Frame", {
		Name = "Preview",
		Size = UDim2.fromScale(1, previewHeight),
		BackgroundColor3 = Theme.BgSunken,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = container,
	}, {
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Theme.BgElevated, Theme.BgSunken),
		}),
	})
	Components.corner(preview, Theme.CornerSmall)
	Components.stroke(preview, accent, 1, 0.4)
	local viewport = ItemPreview.model(preview, item)
	if viewport then
		Components.text({
			Name = "RotateHint",
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -6),
			Size = UDim2.new(1, -12, 0, 16),
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "ARRASTE PARA GIRAR",
			TextSize = 11,
			TextColor3 = Theme.TextMuted,
			Parent = preview,
		})
	else
		local holder = Create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.8, 0.8),
			BackgroundTransparency = 1,
			Parent = preview,
		}, { Create("UIAspectRatioConstraint", { AspectRatio = if item.kind == "title" then 2 else 1.3 }) })
		ItemPreview.thumbnail(holder, item)
	end
	if inModal then
		Components.iconButton("secondary", "Close", nil, {
			Name = "Back",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -6, 0, 6),
			Size = UDim2.fromOffset(Theme.TouchMin, Theme.TouchMin),
			Parent = preview,
		}, function()
			AudioController.play("UiBlip", 1, 1.1, true)
			if overlay then
				overlay.Visible = false
			end
		end)
	end

	local actions: { { variant: Components.Variant, text: string, disabled: boolean, run: (() -> ())? } } = {}
	if state == "equipped" then
		table.insert(actions, { variant = "success", text = "EQUIPADO", disabled = true })
	elseif state == "owned" then
		table.insert(actions, {
			variant = "primary",
			text = "EQUIPAR",
			disabled = false,
			run = function()
				local result = request("equip", item.id)
				if result and result.ok then
					setMessage(result.data.message)
				end
				if inModal and overlay then
					overlay.Visible = false
				end
				render()
			end,
		})
	elseif state == "buyable" then
		local options = StoreView.prices(item, walletOf("fichas"), walletOf("creditos"))
		for index, option in options do
			table.insert(actions, {
				variant = if index == 1 then "primary" else "secondary",
				text = if option.affordable
					then `COMPRAR · {priceText(option.currency, option.price)}`
					else `FALTAM {priceText(option.currency, option.missing)}`,
				disabled = not option.affordable,
				run = function()
					confirmPurchase(item, option)
				end,
			})
		end
	end
	local actionHeight = #actions * (Theme.TouchMin + 8)
	local info = Create("Frame", {
		Name = "Info",
		Position = UDim2.new(0, 0, previewHeight, 10),
		Size = UDim2.new(1, 0, 1 - previewHeight, -(10 + actionHeight)),
		BackgroundTransparency = 1,
		Parent = container,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	label({
		Name = "ItemName",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Text = item.name,
		TextSize = if compactStore then 19 else 22,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.TextPrimary,
		LayoutOrder = 1,
		Parent = info,
	})
	local chips = Create("Frame", {
		Name = "Chips",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = info,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	Components.chip(rarity.label, accent, { LayoutOrder = 1, Parent = chips })
	local stateLabel, stateColor = "BLOQUEADO", Theme.TextMuted
	if state == "equipped" then
		stateLabel, stateColor = "EQUIPADO", Theme.Success
	elseif state == "owned" then
		stateLabel, stateColor = "ADQUIRIDO", Theme.Success
	elseif state == "buyable" then
		stateLabel, stateColor = "À VENDA", Theme.Gold
	end
	Components.chip(stateLabel, stateColor, { LayoutOrder = 2, Parent = chips })
	Components.text({
		Name = "KindNote",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Theme.FontNote,
		TextSize = 14,
		TextColor3 = Theme.TextSecondary,
		Text = StoreView.kindNote(item.kind),
		LayoutOrder = 3,
		Parent = info,
	})
	local how = Create("Frame", {
		Name = "HowToGet",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = info,
	})
	Components.icon(
		how,
		if state == "locked" then "Lock" elseif state == "buyable" then "Coin" else "Check",
		24,
		if state == "locked" then Theme.TextMuted elseif state == "buyable" then Theme.Coin else Theme.Success
	)
	Components.text({
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -32, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		FontFace = Theme.Font,
		TextSize = 14,
		TextColor3 = Theme.TextPrimary,
		Text = if (state == "owned" or state == "equipped") and item.source ~= "default"
			then "VOCÊ JÁ TEM ESTE ITEM."
			else StoreView.howToGet(item),
		Parent = how,
	})
	for index, action in actions do
		local b = button({
			Name = `Action_{index}`,
			Variant = action.variant,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -(#actions - index) * (Theme.TouchMin + 8)),
			Size = UDim2.new(1, 0, 0, Theme.TouchMin),
			Text = action.text,
			TextSize = 16,
			Parent = container,
		}, function()
			local run = action.run
			if run then
				run()
			end
		end)
		Components.setDisabled(b, action.disabled)
	end
end

local function renderDetail()
	local d = detail
	if not d then
		return
	end
	for _, child in d:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local item = if selectedItem then StoreCatalog.ItemById[selectedItem] else nil
	if not item or item.kind ~= kindFilter then
		item = StoreCatalog.ItemById[equippedId(kindFilter)]
	end
	if not item then
		return
	end
	selectedItem = item.id
	fillDetail(d, item, false)
end

openDetailModal = function(item: StoreCatalog.Item)
	local o = clearOverlay()
	if not o then
		return
	end
	local box = modalBox(o, UDim2.new(1, -24, 1, -24))
	Create("UISizeConstraint", { MaxSize = Vector2.new(460, 620), Parent = box })
	Components.padding(box, 12)
	fillDetail(box, item, true)
end

-- Grade da loja: miniatura real, nome, raridade e estado; tocar abre o detalhe.
local function renderShop(c: ScrollingFrame)
	setLayout(c, true)
	local grid = c:FindFirstChildOfClass("UIGridLayout")
	local width = math.max(c.AbsoluteSize.X - 16, 200)
	local columns = if compactStore then (if width >= 520 then 3 else 2) else math.clamp(math.floor(width / 186), 2, 5)
	-- Tela baixa: mais colunas para que uma linha inteira de cartões caiba na altura visível.
	local visibleHeight = c.AbsoluteSize.Y
	if visibleHeight > 0 then
		local widest = math.floor((visibleHeight - 12) / 1.16)
		columns = math.clamp(math.max(columns, math.ceil((width + 10) / (widest + 10))), 2, 6)
	end
	local cellWidth = math.floor((width - (columns - 1) * 10) / columns)
	if grid then
		grid.CellSize = UDim2.fromOffset(cellWidth, math.floor(cellWidth * 1.16))
		grid.CellPadding = UDim2.fromOffset(10, 10)
	end
	local owned = jsonSet("Owned")
	local vip = attr("Vip", false) == true
	local fichas, creditos = walletOf("fichas"), walletOf("creditos")
	local items = StoreView.itemsOfKind(kindFilter)
	local current = if selectedItem then StoreCatalog.ItemById[selectedItem] else nil
	if not current or current.kind ~= kindFilter then
		selectedItem = equippedId(kindFilter)
	end
	local strokes: { [string]: UIStroke } = {}
	for index, item in items do
		local rarity = StoreCatalog.Rarities[item.rarity]
		local accent = rgb(rarity.color)
		local state = StoreView.state(item, owned, equippedId(item.kind), vip)
		local cell = Create("TextButton", {
			Name = `Item_{item.id}`,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Theme.BgPanel,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = c,
		}) :: TextButton
		cell:SetAttribute("State", state)
		Components.corner(cell, Theme.CornerSmall)
		local selected = twoPane and item.id == selectedItem
		local outline = Components.stroke(
			cell,
			if selected then Theme.Gold else accent,
			if selected then 2 else 1,
			if selected then 0 else 0.45
		)
		strokes[item.id] = outline
		Create("Frame", {
			Name = "RarityBar",
			Size = UDim2.new(1, 0, 0, 3),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Parent = cell,
		})
		local thumb = Create("Frame", {
			Name = "ThumbHolder",
			Position = UDim2.fromOffset(6, 9),
			Size = UDim2.new(1, -12, 0.56, -9),
			BackgroundTransparency = 1,
			Parent = cell,
		})
		ItemPreview.thumbnail(thumb, item)
		label({
			Name = "ItemName",
			Position = UDim2.new(0, 8, 0.56, 6),
			Size = UDim2.new(1, -16, 0, 30),
			Text = item.name,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = cell,
		})
		label({
			Name = "Rarity",
			Position = UDim2.new(0, 8, 0.56, 38),
			Size = UDim2.new(1, -16, 0, 14),
			Text = rarity.label,
			TextSize = 11,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cell,
		})
		local status = Create("Frame", {
			Name = "Status",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 8, 1, -6),
			Size = UDim2.new(1, -16, 0, 20),
			BackgroundTransparency = 1,
			Parent = cell,
		}, {
			Create("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
		local function statusText(text: string, color: Color3, order: number)
			label({
				Size = UDim2.fromOffset(0, 20),
				AutomaticSize = Enum.AutomaticSize.X,
				Text = text,
				TextSize = 12,
				TextWrapped = false,
				TextColor3 = color,
				LayoutOrder = order,
				Parent = status,
			})
		end
		if state == "equipped" then
			Components.icon(status, "Check", 12, Theme.Success, { LayoutOrder = 1 })
			statusText("EQUIPADO", Theme.Success, 2)
		elseif state == "owned" then
			statusText("ADQUIRIDO", Theme.TextSecondary, 1)
		elseif state == "buyable" then
			for order, option in StoreView.prices(item, fichas, creditos) do
				local fichasOption = option.currency == "fichas"
				Components.icon(
					status,
					if fichasOption then "Coin" else "Gem",
					12,
					if option.affordable then (if fichasOption then Theme.Coin else Theme.Info) else Theme.TextMuted,
					{ LayoutOrder = order * 2 - 1 }
				)
				statusText(
					Components.formatNumber(option.price),
					if option.affordable then Theme.TextPrimary else Theme.TextMuted,
					order * 2
				)
			end
		else
			Components.icon(status, "Lock", 12, Theme.TextMuted, { LayoutOrder = 1 })
			statusText("BLOQUEADO", Theme.TextMuted, 2)
		end
		cell.Activated:Connect(function()
			AudioController.play("UiBlip", 1, 1.1, true)
			selectedItem = item.id
			if twoPane then
				for id, stroke in strokes do
					local entry = StoreCatalog.ItemById[id]
					local mine = id == item.id
					stroke.Color = if mine then Theme.Gold else rgb(StoreCatalog.Rarities[entry.rarity].color)
					stroke.Thickness = if mine then 2 else 1
					stroke.Transparency = if mine then 0 else 0.45
				end
				renderDetail()
			else
				openDetailModal(item)
			end
		end)
	end
	if twoPane then
		renderDetail()
	end
end

local function showOdds(title: string, lines: { string })
	track("view", "odds")
	local o = overlay
	if not o then
		return
	end
	for _, child in o:GetChildren() do
		child:Destroy()
	end
	o.Visible = true
	local box = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = o,
	}, {
		Create("UIStroke", { Color = Theme.Hazard, Thickness = 2 }),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 12),
			PaddingRight = UDim.new(0, 12),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}),
		Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame
	label({
		Size = UDim2.new(1, 0, 0, 22),
		Text = px(title),
		TextColor3 = Theme.Hazard,
		LayoutOrder = 0,
		Parent = box,
	})
	for i, line in lines do
		label({
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Text = px(line),
			TextSize = Theme.SizeSmall,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			Parent = box,
		})
	end
	button({
		Name = "OddsOk",
		Size = UDim2.fromOffset(140, 24),
		Text = "OK",
		LayoutOrder = #lines + 1,
		Parent = box,
	}, function()
		o.Visible = false
	end)
end

local function percent(value: number): string
	-- 4 casas: a política pede ao menos 4 casas após o primeiro dígito não-zero quando arredonda.
	local text = string.format("%.4f", value)
	text = string.gsub(text, "%.?0+$", "")
	return text
end

local function oddsLines(chest: StoreCatalog.Chest): { string }
	local lines = {}
	for _, line in Economy.chestOdds(chest) do
		local rarity = StoreCatalog.Rarities[line.rarity]
		table.insert(lines, string.format(S.oddsLine, rarity.label, percent(line.percent), percent(line.perItem)))
		local names = {}
		for _, id in line.items do
			table.insert(names, itemName(id))
		end
		table.insert(lines, "  " .. table.concat(names, ", "))
	end
	table.insert(lines, S.oddsNote)
	return lines
end

-- Rolo de nomes que desacelera e para no item sorteado pelo servidor.
local function playReel(
	pool: { string },
	result: string,
	rarity: StoreCatalog.Rarity,
	duplicate: boolean,
	refund: number
)
	local o = overlay
	if not o then
		return
	end
	for _, child in o:GetChildren() do
		child:Destroy()
	end
	o.Visible = true
	local accent = rgb(StoreCatalog.Rarities[rarity].color)
	local box = Create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 170),
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		Parent = o,
	}, { Create("UIStroke", { Color = Theme.TextDim, Thickness = 2 }) }) :: Frame
	local name = label({
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 40),
		Text = "",
		TextSize = Theme.SizeLarge,
		Parent = box,
	})
	local sub = label({
		Position = UDim2.fromOffset(10, 90),
		Size = UDim2.new(1, -20, 0, 22),
		Text = "",
		TextColor3 = Theme.TextDim,
		Parent = box,
	})
	local rng = Random.new()
	local delay = 0.04
	while delay < 0.32 do
		name.Text = px(itemName(pool[rng:NextInteger(1, #pool)]))
		AudioController.play("UiBlip", 0.5, 1.6, true)
		task.wait(delay)
		delay *= 1.16
	end
	name.Text = px(itemName(result))
	name.TextColor3 = accent
	local stroke = box:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = accent
	end
	sub.Text = px(
		if duplicate
			then string.format(S.duplicate, refund)
			else string.format(S.newItem, StoreCatalog.Rarities[rarity].label)
	)
	AudioController.play(if rarity == "legendary" or rarity == "epic" then "StingerWin" else "Switch", 0.7, nil, true)
	button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(160, 26),
		Text = "OK",
		Parent = box,
	}, function()
		o.Visible = false
		animating = false
		render()
	end)
end

local function renderChests(c: ScrollingFrame)
	setLayout(c, false)
	local restricted = attr("PaidRandomRestricted", true) == true
	for index, chest in StoreCatalog.Chests do
		local blocked = chest.paidRandom and restricted
		local box = card(c, index, if chest.paidRandom then Theme.Hazard else Theme.TextDim)
		box.Size = UDim2.new(1, -12, 0, 120)
		label({
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(0.6, 0, 0, 24),
			Text = px(chest.name),
			TextSize = Theme.SizeLarge,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		-- Chances resumidas sempre visíveis no card (antes de qualquer compra).
		local summary = {}
		for _, line in Economy.chestOdds(chest) do
			table.insert(summary, `{StoreCatalog.Rarities[line.rarity].label} {percent(line.percent)}%`)
		end
		label({
			Position = UDim2.fromOffset(12, 42),
			Size = UDim2.new(0.62, 0, 0, 40),
			Text = px(table.concat(summary, "  ·  ")),
			TextSize = Theme.SizeSmall,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		local price = if chest.currency == "fichas"
			then string.format(S.fichas, chest.price)
			else string.format(S.creditos, chest.price)
		button({
			Name = `Open_{chest.id}`,
			Position = UDim2.new(0.66, 0, 0, 14),
			Size = UDim2.new(0.32, -6, 0, 34),
			Text = if blocked then S.restricted else string.format(S.open, price),
			TextColor3 = if blocked then Theme.TextDim else Theme.Hazard,
			Parent = box,
		}, function()
			if blocked then
				setMessage("store_restricted")
				return
			end
			animating = true
			local result = request("open_chest", chest.id)
			if not result or not result.ok then
				animating = false
				return
			end
			local data = result.data
			if not data.ok then
				animating = false
				setMessage(data.message)
				return
			end
			setMessage(nil)
			local pool = {}
			for _, line in Economy.chestOdds(chest) do
				for _, id in line.items do
					table.insert(pool, id)
				end
			end
			task.spawn(playReel, pool, data.item, data.rarity, data.duplicate == true, data.refund or 0)
		end)
		button({
			Name = `Odds_{chest.id}`,
			Position = UDim2.new(0.66, 0, 0, 56),
			Size = UDim2.new(0.32, -6, 0, 28),
			Text = S.odds,
			Parent = box,
		}, function()
			showOdds(string.format(S.oddsTitle, chest.name), oddsLines(chest))
		end)
	end
end

local function renderDaily(c: ScrollingFrame)
	setLayout(c, false)
	local streak = attr("DailyStreak", 1)
	local claimable = attr("DailyClaimable", false) == true
	local calendar = card(c, 1, Theme.Hazard)
	calendar.Size = UDim2.new(1, -12, 0, 130)
	for day, reward in StoreCatalog.Daily do
		local current = day == streak
		local done = day < streak or (day == streak and not claimable)
		local cell = Create("Frame", {
			Position = UDim2.new((day - 1) / 7, 6, 0, 12),
			Size = UDim2.new(1 / 7, -10, 0, 64),
			BackgroundColor3 = if current then Color3.fromRGB(40, 34, 16) else Color3.fromRGB(22, 22, 24),
			BorderSizePixel = 0,
			Parent = calendar,
		}, {
			Create("UIStroke", { Color = if current then Theme.Hazard else Theme.TextDim, Thickness = 1 }),
		}) :: Frame
		local parts = {}
		if reward.fichas then
			table.insert(parts, `{reward.fichas} F`)
		end
		if reward.creditos then
			table.insert(parts, `{reward.creditos} C`)
		end
		label({
			Size = UDim2.fromScale(1, 0.45),
			Text = px(string.format(S.dailyDay, day)),
			TextSize = Theme.SizeSmall,
			TextColor3 = if done then Theme.Good else Theme.Text,
			Parent = cell,
		})
		label({
			Position = UDim2.fromScale(0, 0.45),
			Size = UDim2.fromScale(1, 0.55),
			Text = table.concat(parts, " + "),
			TextSize = Theme.SizeSmall,
			TextColor3 = Theme.Hazard,
			Parent = cell,
		})
	end
	button({
		Name = "ClaimDaily",
		Position = UDim2.new(0, 12, 1, -42),
		Size = UDim2.new(0.5, -18, 0, 30),
		Text = if claimable then string.format(S.daily, streak) else string.format(S.dailyDone, streak % 7 + 1),
		TextColor3 = if claimable then Theme.Hazard else Theme.TextDim,
		Parent = calendar,
	}, function()
		if claimable then
			local result = request("claim_daily")
			if result and result.ok then
				setMessage(result.data.message)
			end
			render()
		end
	end)

	-- Roleta: faixa de segmentos; o destaque desacelera até o resultado do servidor.
	local wheel = card(c, 2, Theme.TextDim)
	wheel.Size = UDim2.new(1, -12, 0, 150)
	local cells: { Frame } = {}
	for i, segment in StoreCatalog.Spin do
		local cell = Create("Frame", {
			Position = UDim2.new((i - 1) / #StoreCatalog.Spin, 6, 0, 14),
			Size = UDim2.new(1 / #StoreCatalog.Spin, -10, 0, 56),
			BackgroundColor3 = Color3.fromRGB(22, 22, 24),
			BorderSizePixel = 0,
			Parent = wheel,
		}) :: Frame
		label({ Size = UDim2.fromScale(1, 1), Text = px(segment.label), TextSize = Theme.SizeSmall, Parent = cell })
		table.insert(cells, cell)
	end
	local spins = attr("SpinsLeft", 0)
	label({
		Position = UDim2.new(0.55, 0, 1, -64),
		Size = UDim2.new(0.43, 0, 0, 20),
		Text = px(string.format(S.spinsLeft, spins)),
		TextColor3 = Theme.TextDim,
		TextSize = Theme.SizeSmall,
		Parent = wheel,
	})
	button({
		Name = "Spin",
		Position = UDim2.new(0, 12, 1, -42),
		Size = UDim2.new(0.42, -12, 0, 30),
		Text = S.spin,
		TextColor3 = if spins > 0 then Theme.Hazard else Theme.TextDim,
		Parent = wheel,
	}, function()
		if spins <= 0 then
			setMessage("spin_used")
			return
		end
		animating = true
		local result = request("spin")
		if not result or not result.ok or not result.data.ok then
			animating = false
			if result and result.ok then
				setMessage(result.data.message)
			end
			return
		end
		local target = 1
		for i, segment in StoreCatalog.Spin do
			if segment.id == result.data.segment then
				target = i
			end
		end
		task.spawn(function()
			local steps = #cells * 3 + target
			local delay = 0.03
			for step = 1, steps do
				local index = (step - 1) % #cells + 1
				for i, cell in cells do
					cell.BackgroundColor3 = if i == index then Theme.Hazard else Color3.fromRGB(22, 22, 24)
				end
				AudioController.play("UiBlip", 0.4, 1.8, true)
				task.wait(delay)
				delay = math.min(0.3, delay * 1.07)
			end
			AudioController.play("Switch", 0.7, 1.2, true)
			task.wait(0.8)
			animating = false
			render()
			-- O prêmio aparece depois do giro (o saldo já veio do servidor).
			local segment = StoreCatalog.Spin[target]
			if message and segment then
				message.Text = px("+ " .. segment.label)
			end
		end)
	end)
	button({
		Position = UDim2.new(0.55, 0, 1, -42),
		Size = UDim2.new(0.43, -6, 0, 30),
		Text = S.spinOdds,
		Parent = wheel,
	}, function()
		local lines = {}
		for _, segment in StoreCatalog.Spin do
			table.insert(lines, `{segment.label}: {segment.weight}%`)
		end
		showOdds(S.spinOdds, lines)
	end)
end

local function renderCollection(c: ScrollingFrame)
	setLayout(c, true)
	local tapes = jsonSet("Tapes")
	local count = 0
	for _ in tapes do
		count += 1
	end
	if message then
		message.Text = px(string.format(S.tapes, count))
	end
	for index, tape in StoreCatalog.Tapes do
		local found = tapes[tape.id] == true
		local box = card(c, index, if found then Theme.Hazard else Theme.TextDim)
		label({
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.new(1, -16, 0, 22),
			Text = px(if found then tape.title else S.tapeMissing),
			TextColor3 = if found then Theme.Hazard else Theme.TextDim,
			Parent = box,
		})
		label({
			Position = UDim2.fromOffset(8, 36),
			Size = UDim2.new(1, -16, 0, 80),
			Text = if found then tape.line else "",
			FontFace = Theme.FontNote,
			TextSize = Theme.SizeBody,
			Parent = box,
		})
	end
	local order = #StoreCatalog.Tapes
	local amounts = {}
	for amount in StoreCatalog.TapeMilestones do
		table.insert(amounts, amount)
	end
	table.sort(amounts)
	for _, amount in amounts do
		local reward = StoreCatalog.TapeMilestones[amount]
		order += 1
		local box = card(c, order, if count >= amount then Theme.Good else Theme.TextDim)
		local parts = {}
		if reward.item then
			table.insert(parts, itemName(reward.item))
		end
		if reward.fichas then
			table.insert(parts, `{reward.fichas} FICHAS`)
		end
		if reward.creditos then
			table.insert(parts, `{reward.creditos} CRÉDITOS`)
		end
		label({
			Position = UDim2.fromOffset(8, 12),
			Size = UDim2.new(1, -16, 1, -24),
			Text = px(string.format(S.milestone, amount, table.concat(parts, " + "))),
			Parent = box,
		})
	end
end

local function rewardText(reward: StoreCatalog.Reward?): string
	if not reward then
		return Text.Season.empty
	end
	local parts = {}
	if reward.item then
		table.insert(parts, itemName(reward.item))
	end
	if reward.fichas then
		table.insert(parts, string.format(Text.Rewards.fichas, reward.fichas))
	end
	if reward.creditos then
		table.insert(parts, string.format(Text.Rewards.creditos, reward.creditos))
	end
	return table.concat(parts, " · ")
end

local function renderSeason(c: ScrollingFrame)
	setLayout(c, false)
	local season = SeasonCatalog.SeasonById[attr("SeasonId", "")]
	if not season then
		label({ Size = UDim2.new(1, -12, 0, 64), Text = Text.Season.none, Parent = c })
		return
	end
	local tier, into, need = Season.tierInfo(season, attr("SeasonXp", 0))
	local premium = attr("SeasonPremium", false) == true
	local intro = card(c, 0, Theme.Hazard)
	intro.Name = "SeasonSummary"
	intro.Size = UDim2.new(1, -12, 0, 172)
	label({
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -24, 0, 26),
		Text = string.format(Text.Season.header, season.number, season.name),
		TextColor3 = Theme.Hazard,
		Parent = intro,
	})
	label({
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 24),
		Text = string.format(Text.Season.tier, tier, #season.tiers)
			.. " · "
			.. string.format(Text.Season.xp, into, need),
		Parent = intro,
	})
	label({
		Position = UDim2.fromOffset(12, 62),
		Size = UDim2.new(1, -24, 0, 40),
		Text = Text.Season.how,
		TextSize = Theme.SizeSmall,
		Parent = intro,
	})
	local progress = Create("Frame", {
		Name = "SeasonProgress",
		Parent = intro,
		Position = UDim2.fromOffset(12, 104),
		Size = UDim2.new(1, -24, 0, 5),
		BackgroundColor3 = Theme.PanelLight,
		BorderSizePixel = 0,
	}) :: Frame
	Create("Frame", {
		Name = "Fill",
		Parent = progress,
		Size = UDim2.fromScale(if need > 0 then math.clamp(into / need, 0, 1) else 1, 1),
		BackgroundColor3 = Theme.Hazard,
		BorderSizePixel = 0,
	})
	label({
		Position = UDim2.fromOffset(12, 112),
		Size = UDim2.new(0.4, -18, 0, 44),
		Text = string.format(Text.Season.daysLeft, Season.daysLeft(season, os.time())),
		TextSize = Theme.SizeSmall,
		Parent = intro,
	})
	local product = StoreCatalog.ProductByKey[season.passKey]
	button({
		Name = "BuySeason",
		Position = UDim2.new(0.4, 0, 0, 112),
		Size = UDim2.new(0.6, -12, 0, 44),
		Text = if premium then Text.Season.owned else string.format(Text.Season.buy, product.robux),
		TextColor3 = if premium then Theme.Good else Theme.Hazard,
		Parent = intro,
	}, function()
		if premium then
			return
		end
		local result = request("buy_product", season.passKey)
		if result then
			setMessage(if result.ok then result.data.message else result.error)
		end
		task.delay(0.6, render)
	end)
	for index, entry in season.tiers do
		local reached = index <= tier
		local box = card(c, index, if reached then Theme.Good else Theme.TextDim)
		box.Name = `SeasonTier_{index}`
		box.Size = UDim2.new(1, -12, 0, 154)
		label({
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 20),
			Text = string.format(Text.Season.tierLabel, index),
			Parent = box,
		})
		for column, trackName in { "free", "premium" } do
			local unlocked = reached and (trackName == "free" or premium)
			local text = if trackName == "free" then Text.Season.free else Text.Season.premium
			local trackPanel = Create("Frame", {
				Name = trackName,
				Parent = box,
				Position = UDim2.new((column - 1) * 0.5, 8, 0, 28),
				Size = UDim2.new(0.5, -16, 1, -38),
				BackgroundColor3 = Theme.Panel,
				BorderSizePixel = 0,
			}, { Create("UICorner", { CornerRadius = Theme.CornerSmall }) }) :: Frame
			label({
				Name = "TrackPreview",
				Position = UDim2.fromOffset(6, 4),
				Size = UDim2.new(1, -12, 1, -8),
				Text = text .. " · " .. (if unlocked
					then Text.Season.received
					elseif not reached then `Nível {index}`
					else "Requer passe premium") .. "\n" .. rewardText(
					if trackName == "free" then entry.free else entry.premium
				),
				TextSize = Theme.SizeSmall,
				TextColor3 = if unlocked
					then Theme.Good
					elseif trackName == "premium" then Theme.Hazard
					else Theme.TextDim,
				TextWrapped = true,
				Parent = trackPanel,
			})
		end
	end
end

local function renderRobux(c: ScrollingFrame)
	setLayout(c, false)
	for index, product in StoreCatalog.Products do
		local owned = (product.key == "vip" and attr("Vip", false) == true)
			or (product.key == "pacote_inicial" and attr("StarterBought", false) == true)
			or (product.key == "turno_extra_s1" and attr("SeasonPremium", false) == true)
		local box = card(c, index, if product.kind == "pass" then Theme.Hazard else Theme.TextDim)
		box.Size = UDim2.new(1, -12, 0, 74)
		label({
			Position = UDim2.fromOffset(12, 10),
			Size = UDim2.new(0.62, 0, 0, 24),
			Text = px(product.name),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		label({
			Position = UDim2.fromOffset(12, 36),
			Size = UDim2.new(0.62, 0, 0, 32),
			Text = product.description,
			FontFace = Theme.FontNote,
			TextSize = Theme.SizeSmall,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		button({
			Name = `Buy_{product.key}`,
			Position = UDim2.new(0.66, 0, 0, 18),
			Size = UDim2.new(0.32, -6, 0, 36),
			Text = if owned then S.owned else string.format(S.buyRobux, product.robux),
			TextColor3 = if owned then Theme.Good else Theme.Hazard,
			Parent = box,
		}, function()
			if owned then
				return
			end
			local result = request("buy_product", product.key)
			if result and result.ok then
				setMessage(result.data.message)
			end
			task.delay(0.6, render)
		end)
	end
end

-- Distribui a janela conforme a tela: PC (janela central, grade + detalhe ao lado) ou toque/tela
-- pequena (quase tela cheia; detalhe abre por cima). O Studio pode simular um aparelho (ViewportQA).
local function applyLayout()
	local p = panel
	local c = content
	if not p or not c then
		return
	end
	local qaWidth, qaHeight = ViewportQA.size()
	local viewport = workspace.CurrentCamera.ViewportSize
	compactStore = qaWidth ~= nil or UserInputService.TouchEnabled or viewport.X < 1000 or viewport.Y < 600
	local width, height
	if qaWidth and qaHeight then
		p.Size = UDim2.fromOffset(qaWidth - 16, qaHeight - 16)
		width, height = qaWidth - 16, qaHeight - 16
	elseif compactStore then
		p.Size = UDim2.new(1, -16, 1, -16)
		width, height = viewport.X - 16, viewport.Y - 16
	else
		p.Size = UDim2.fromScale(0.92, 0.9)
		width, height = math.min(viewport.X * 0.92, 1180), math.min(viewport.Y * 0.9, 780)
	end
	-- Celular na horizontal é baixo: uma coluna de grade e detalhe por cima (openDetailModal).
	shortStore = height < 520
	twoPane = width >= 760 and not shortStore
	local shop = tab == "shop"
	local pad = if shortStore then 8 elseif compactStore then 10 else 16
	local headerHeight = if shortStore then 40 elseif compactStore then 44 else 52
	local tabsY = pad + headerHeight + (if shortStore then 4 else 6)
	local tabsHeight = if shortStore then 40 else 44
	local kindsHeight = if shortStore then 36 else 40
	local kindsY = tabsY + tabsHeight + (if shortStore then 6 else 8)
	local contentY = if shop then kindsY + kindsHeight + 8 else tabsY + tabsHeight + 8
	local footer = if shortStore then 26 else 40
	local m = message
	if m then
		m.Size = UDim2.new(1, -2 * pad, 0, footer - 6)
		m.Position = UDim2.new(0, pad, 1, -4)
	end
	local kinds = kindsBar
	if kinds then
		kinds.Visible = shop
		kinds.Position = UDim2.fromOffset(pad, kindsY)
		kinds.Size = UDim2.new(1, -2 * pad, 0, kindsHeight)
	end
	local topBar = p:FindFirstChild("TopBar")
	if topBar and topBar:IsA("Frame") then
		topBar.Position = UDim2.fromOffset(pad, pad)
		topBar.Size = UDim2.new(1, -2 * pad, 0, headerHeight)
	end
	local tabBar = p:FindFirstChild("Tabs")
	if tabBar and tabBar:IsA("GuiObject") then
		tabBar.Position = UDim2.fromOffset(pad, tabsY)
		tabBar.Size = UDim2.new(1, -2 * pad, 0, tabsHeight + 4)
	end
	local split = shop and twoPane
	c.Position = UDim2.fromOffset(pad, contentY)
	c.Size = UDim2.new(if split then 0.62 else 1, if split then -pad - 6 else -2 * pad, 1, -(contentY + footer + pad))
	local d = detail
	if d then
		d.Visible = split
		d.Position = UDim2.new(0.62, 6, 0, contentY)
		d.Size = UDim2.new(0.38, -pad - 6, 1, -(contentY + footer + pad))
	end
	-- Abas: no PC dividem a largura; no toque têm largura fixa e rolam na horizontal.
	for index, key in TABS do
		local b = tabButtons[key :: Tab]
		if b then
			if compactStore then
				b.Size = UDim2.fromOffset(146, tabsHeight)
			else
				b.Size = UDim2.new(1 / #TABS, -6, 0, tabsHeight)
			end
			b.LayoutOrder = index
		end
	end
end

render = function()
	local c = clearContent()
	if not c or not isOpen then
		return
	end
	applyLayout()
	-- Barra superior: saldo, nível e XP (atributos publicados pelo StoreService).
	local xp = attr("Xp", 0)
	local level, into, need = Economy.levelInfo(xp)
	if setFichasBadge then
		setFichasBadge(tonumber(attr("Fichas", 0)) or 0)
	end
	if setCreditosBadge then
		setCreditosBadge(tonumber(attr("Creditos", 0)) or 0)
	end
	if levelChip then
		local vip = if attr("Vip", false) == true then " · VIP" else ""
		levelChip.Text = px(string.format(S.level, level) .. vip)
	end
	if setXpBar then
		setXpBar(into / math.max(need, 1))
	end
	for key, b in tabButtons do
		Components.setVariant(b, if key == tab then "secondary" else "ghost")
	end
	for kind, b in kindButtons do
		Components.setVariant(b, if kind == kindFilter then "secondary" else "ghost")
	end
	-- Mesma aba e filtro (redesenho por compra/saldo): mantém a rolagem; trocou: volta ao topo.
	local view = `{tab}/{kindFilter}`
	local keep = if c:GetAttribute("View") == view then c.CanvasPosition else Vector2.zero
	c:SetAttribute("View", view)
	c.CanvasPosition = Vector2.zero
	task.defer(function()
		c.CanvasPosition = keep
	end)
	if tab == "shop" then
		renderShop(c)
	elseif tab == "season" then
		renderSeason(c)
	elseif tab == "chests" then
		renderChests(c)
	elseif tab == "daily" then
		renderDaily(c)
	elseif tab == "collection" then
		renderCollection(c)
	else
		renderRobux(c)
	end
end

local function setOpen(value: boolean)
	local p = panel
	if not p then
		return
	end
	if value and not allowed() then
		setMessage(nil)
		toast({ S.blocked }, Theme.TextDim, 3)
		return
	end
	if value == isOpen then
		return
	end
	isOpen = value
	p.Visible = value
	if value then
		track("open")
		mouseWasEnabled = UserInputService.MouseIconEnabled
		UserInputService.MouseIconEnabled = true
		setMessage(nil)
		render()
	else
		UserInputService.MouseIconEnabled = mouseWasEnabled
		if overlay then
			overlay.Visible = false
		end
	end
end

local function build()
	local screen = Create("ScreenGui", {
		Name = "StoreUi",
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		-- Camadas por hierarquia: diálogos dentro do Overlay ficam acima do véu escuro.
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 220,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui

	toastHolder = Create("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 60),
		Size = UDim2.fromOffset(340, 500),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
	}) :: Frame

	hintLabel = label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -40),
		Size = UDim2.fromOffset(160, 16),
		Text = S.hint,
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = screen,
	})

	local p = Create("Frame", {
		Name = "Store",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.9),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.03,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	}, {
		Create("UISizeConstraint", { MaxSize = Vector2.new(1180, 780) }),
	}) :: Frame
	Components.corner(p, Theme.CornerLarge)
	Components.stroke(p, Theme.Gold, 1, 0.55)
	panel = p
	-- Modal: libera o mouse da trava de primeira pessoa enquanto a loja está aberta.
	Create("TextButton", {
		Name = "MouseRelease",
		Size = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Modal = true,
		Parent = p,
	})

	-- Barra superior: título, moedas, nível/XP e fechar.
	local top = Create("Frame", {
		Name = "TopBar",
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 48),
		BackgroundTransparency = 1,
		Parent = p,
	})
	Components.icon(top, "Store", 24, Theme.Gold, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
	})
	local title = Components.title({
		Name = "Title",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 34, 0.5, 0),
		Size = UDim2.fromOffset(160, 34),
		Text = S.title,
		TextSize = 26,
		TextColor3 = Theme.GoldLight,
		Parent = top,
	})
	title.TextStrokeColor3 = Theme.Overlay
	title.TextStrokeTransparency = 0.3
	local status = Create("Frame", {
		Name = "Status",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(1, -180, 1, 0),
		BackgroundTransparency = 1,
		Parent = top,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	local _, setF =
		Components.currency("fichas", { Size = UDim2.fromOffset(124, 38), LayoutOrder = 1, Parent = status })
	local _, setC =
		Components.currency("creditos", { Size = UDim2.fromOffset(124, 38), LayoutOrder = 2, Parent = status })
	setFichasBadge, setCreditosBadge = setF, setC
	local level = Create("Frame", {
		Name = "Level",
		Size = UDim2.fromOffset(150, 38),
		BackgroundColor3 = Theme.BgSunken,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		LayoutOrder = 3,
		Parent = status,
	}) :: Frame
	Components.corner(level, Theme.CornerPill)
	Components.stroke(level, Theme.Success, 1, 0.55)
	levelChip = Components.text({
		Name = "LevelText",
		Position = UDim2.fromOffset(12, 3),
		Size = UDim2.new(1, -24, 0, 18),
		FontFace = Theme.Font,
		TextSize = 13,
		TextWrapped = false,
		TextColor3 = Theme.TextPrimary,
		Text = "",
		Parent = level,
	})
	local xpTrack, setXp = Components.progress({
		Name = "Xp",
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.new(1, -24, 0, 5),
	}, Theme.Success)
	xpTrack.Parent = level
	setXpBar = setXp
	local close = Components.iconButton("secondary", "Close", "FECHAR", {
		Name = "Close",
		Size = UDim2.fromOffset(124, 44),
		TextSize = 15,
		LayoutOrder = 4,
		Parent = status,
	}, function()
		AudioController.play("UiBlip", 1, 1.1, true)
		setOpen(false)
	end)
	close:SetAttribute("Hint", S.close)

	-- Abas com ícones.
	local tabBar = Create("ScrollingFrame", {
		Name = "Tabs",
		Parent = p,
		Position = UDim2.fromOffset(16, 72),
		Size = UDim2.new(1, -32, 0, 48),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: ScrollingFrame
	for _, key in TABS do
		tabButtons[key :: Tab] = Components.iconButton("ghost", TAB_ICONS[key :: Tab], (S.tabs :: any)[key], {
			Name = `Tab_{key}`,
			Size = UDim2.fromOffset(132, 44),
			TextSize = 15,
			Parent = tabBar,
		}, function()
			AudioController.play("UiBlip", 1, 1.1, true)
			tab = key :: Tab
			track("view", key)
			setMessage(nil)
			render()
		end)
	end
	-- Filtro por tipo (só na aba LOJA).
	local kinds = Create("Frame", {
		Name = "Kinds",
		Position = UDim2.fromOffset(16, 128),
		Size = UDim2.new(1, -32, 0, 40),
		BackgroundTransparency = 1,
		Parent = p,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}) :: Frame
	kindsBar = kinds
	for i, kind in StoreCatalog.KINDS do
		kindButtons[kind] = button({
			Name = `Kind_{kind}`,
			Variant = "ghost",
			Size = UDim2.new(1 / #StoreCatalog.KINDS, -6, 1, 0),
			Text = (S.kinds :: any)[kind],
			TextSize = 14,
			LayoutOrder = i,
			Parent = kinds,
		}, function()
			kindFilter = kind :: StoreCatalog.ItemKind
			selectedItem = nil
			setMessage(nil)
			track("view", kind)
			tab = "shop"
			render()
		end)
	end
	content = Create("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, 178),
		Size = UDim2.new(1, -32, 1, -230),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Gold,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = p,
	}, {
		Create("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 2),
			PaddingRight = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 6),
		}),
	}) :: ScrollingFrame
	-- Painel de detalhe do item (PC); no toque o detalhe abre por cima (openDetailModal).
	local d = Components.panel({
		Name = "Detail",
		BackgroundColor3 = Theme.BgPanel,
		BackgroundTransparency = 0.05,
		Parent = p,
	})
	Components.padding(d, 12)
	detail = d
	message = label({
		Name = "Message",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -10),
		Size = UDim2.new(1, -32, 0, 30),
		Text = "",
		TextSize = 14,
		TextColor3 = Theme.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	})
	overlay = Create("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Overlay,
		BackgroundTransparency = 0.3,
		Visible = false,
		ZIndex = 5,
		Parent = p,
	}) :: Frame
	local last = ""
	RunService.RenderStepped:Connect(function()
		local touch = UserInputService.TouchEnabled
		if isOpen then
			-- Mudou a classe da tela (rotação, janela, simulação no Studio): redistribui e redesenha.
			local qaWidth, qaHeight = ViewportQA.size()
			local viewport = workspace.CurrentCamera.ViewportSize
			local key = `{qaWidth or 0}x{qaHeight or 0}/{math.floor(viewport.X)}x{math.floor(viewport.Y)}`
			if key ~= last then
				last = key
				if not animating and not (overlay and overlay.Visible) then
					render()
				end
			end
			-- No toque, sobram só ícone e moedas na barra superior.
			close.Size = if compactStore then UDim2.fromOffset(44, 44) else UDim2.fromOffset(124, 44)
			local closeLabel = close:FindFirstChild("Label")
			if closeLabel and closeLabel:IsA("GuiObject") then
				closeLabel.Visible = not compactStore
			end
			local closeIcon = close:FindFirstChild("IconSlot")
			if closeIcon and closeIcon:IsA("GuiObject") then
				closeIcon.AnchorPoint = if compactStore then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5)
				closeIcon.Position = if compactStore then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 14, 0.5, 0)
			end
			level.Visible = not compactStore
			title.Visible = not (compactStore and p.AbsoluteSize.X < 560)
		end
		if touch and toastHolder then
			toastHolder.Visible = player:GetAttribute("ModeMenuOpen") ~= true
				and player:GetAttribute("FieldGuideOpen") ~= true
				and player:GetAttribute("ComfortMenuOpen") ~= true
				and player:GetAttribute("TouchBackpackOpen") ~= true
		end
		if hintLabel and touch then
			hintLabel.Visible = false
		end
	end)
end

local StoreController = {
	Name = "StoreController",
}

function StoreController.isOpen(): boolean
	return isOpen
end

function StoreController.setOpen(value: boolean)
	setOpen(value)
end

-- Abre numa aba (menu inicial: LOJA, PASSE, RECOMPENSAS, ROBUX).
function StoreController.openTab(key: string)
	if table.find(TABS, key :: Tab) then
		tab = key :: Tab
		track("view", key)
	end
	if isOpen then
		setMessage(nil)
		render()
	else
		setOpen(true)
	end
end

function StoreController.Init()
	build()
end

function StoreController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
		if isOpen and not allowed() then
			setOpen(false)
		end
		if hintLabel then
			hintLabel.Visible = allowed() and phase ~= "Loading"
		end
	end)
	player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
		if isOpen and not allowed() then
			setOpen(false)
		end
		if hintLabel then
			hintLabel.Visible = allowed() and phase ~= "Loading"
		end
	end)
	-- Qualquer mudança de saldo/itens redesenha a loja aberta.
	for _, name in
		{
			"Fichas",
			"Creditos",
			"Xp",
			"Owned",
			"Tapes",
			"EquipFlashlight",
			"EquipUniform",
			"EquipFilter",
			"Title",
			"Vip",
			"SpinsLeft",
			"DailyClaimable",
			"DailyStreak",
			"StarterBought",
			"SeasonId",
			"SeasonXp",
			"SeasonPremium",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(function()
			if isOpen and not animating and not (overlay and overlay.Visible) then
				render()
			end
		end)
	end
	-- QA no Studio (automação sem foco de janela): o atributo StoreQARequest executa o mesmo
	-- caminho dos cliques. "kind:uniform" | "select:<id>" | "detail:<id>" | "confirm:<id>:fichas|creditos".
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("StoreQARequest"):Connect(function()
			local raw = player:GetAttribute("StoreQARequest")
			if type(raw) ~= "string" then
				return
			end
			local command, arg, extra = string.match(raw, "^(%a+):([%w_]+):?(%a*)$")
			local item = if arg then StoreCatalog.ItemById[arg] else nil
			if command == "kind" and table.find(StoreCatalog.KINDS, arg :: any) then
				tab, kindFilter, selectedItem = "shop", arg :: any, nil
				render()
			elseif command == "select" and item then
				tab, kindFilter, selectedItem = "shop", item.kind, item.id
				render()
			elseif command == "detail" and item then
				openDetailModal(item)
			elseif command == "confirm" and item then
				for _, option in StoreView.prices(item, walletOf("fichas"), walletOf("creditos")) do
					if option.currency == extra then
						confirmPurchase(item, option)
					end
				end
			elseif command == "buy" and item and (extra == "fichas" or extra == "creditos") then
				-- Equivale a tocar CONFIRMAR no diálogo.
				purchase(item, extra :: StoreCatalog.Currency)
			elseif command == "close" then
				if overlay then
					overlay.Visible = false
				end
			end
		end)
	end
	task.spawn(function()
		local ok, remote = pcall(Remotes.clientEvent, "StoreNotice", 30)
		if ok then
			remote.OnClientEvent:Connect(function(payload: any)
				if type(payload) == "table" then
					onNotice(payload)
				end
			end)
		end
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.L or input.KeyCode == Enum.KeyCode.ButtonSelect then
			setOpen(not isOpen)
		end
	end)
end

return StoreController
