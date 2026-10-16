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

local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Season = require("@game/ReplicatedStorage/Shared/Game/Season")
local SeasonCatalog = require("@game/ReplicatedStorage/Shared/Game/SeasonCatalog")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local AudioController = require("./AudioController")

type Tab = "shop" | "season" | "chests" | "daily" | "collection" | "robux"

local player = Players.LocalPlayer
local TABS: { Tab } = { "shop", "season", "chests", "daily", "collection", "robux" }
local S = Text.Store

local panel: Frame? = nil
local content: ScrollingFrame? = nil
local overlay: Frame? = nil
local header: TextLabel? = nil
local xpFill: Frame? = nil
local message: TextLabel? = nil
local hintLabel: TextLabel? = nil
local toastHolder: Frame? = nil
local tabButtons: { [Tab]: TextButton } = {}
local tab: Tab = "shop"
local kindFilter: StoreCatalog.ItemKind = "flashlight"
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

local function px(value: string): string
	return PixelText.normalize(value)
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

local function isOwned(item: StoreCatalog.Item, owned: { [string]: boolean }): boolean
	if item.source == "default" then
		return true
	end
	if item.source == "vip" then
		return attr("Vip", false) == true
	end
	return owned[item.id] == true
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

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local base: { [string]: any } = {
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		AutoButtonColor = true,
		FontFace = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = Theme.SizeSmall,
		TextWrapped = true,
	}
	for key, value in props do
		base[key] = value
	end
	local b = Create("TextButton", base, {
		Create("UIStroke", {
			Color = Theme.TextDim,
			Thickness = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}) :: TextButton
	b.Activated:Connect(function()
		AudioController.play("UiBlip", 1, 1.1, true)
		onClick()
	end)
	return b
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
	return Create("Frame", {
		BackgroundColor3 = Color3.fromRGB(16, 16, 18),
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = parent,
	}, {
		Create("UIStroke", { Color = accent, Thickness = 2 }),
		Create("Frame", {
			Name = "Bar",
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
		}),
	}) :: Frame
end

local render: () -> ()

local function renderShop(c: ScrollingFrame)
	setLayout(c, true)
	local owned = jsonSet("Owned")
	local fichas = attr("Fichas", 0)
	local creditos = attr("Creditos", 0)
	local items = {}
	for _, item in StoreCatalog.Items do
		if item.kind == kindFilter then
			table.insert(items, item)
		end
	end
	table.sort(items, function(a, b)
		local ra, rb = StoreCatalog.Rarities[a.rarity].order, StoreCatalog.Rarities[b.rarity].order
		return if ra == rb then a.name < b.name else ra < rb
	end)
	for index, item in items do
		local rarity = StoreCatalog.Rarities[item.rarity]
		local accent = rgb(rarity.color)
		local box = card(c, index, accent)
		label({
			Position = UDim2.fromOffset(8, 10),
			Size = UDim2.new(1, -16, 0, 36),
			Text = px(item.name),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		label({
			Position = UDim2.fromOffset(8, 46),
			Size = UDim2.new(1, -16, 0, 16),
			Text = px(rarity.label),
			TextColor3 = accent,
			TextSize = Theme.SizeSmall,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = box,
		})
		local swatch = item.body or item.shirt or item.tint or item.color
		if swatch then
			Create("Frame", {
				Position = UDim2.new(1, -30, 0, 48),
				Size = UDim2.fromOffset(20, 12),
				BackgroundColor3 = rgb(swatch),
				BorderSizePixel = 0,
				Parent = box,
			})
		end
		local mine = isOwned(item, owned)
		if mine then
			local equipped = equippedId(item.kind) == item.id
			button({
				Position = UDim2.new(0, 8, 1, -34),
				Size = UDim2.new(1, -16, 0, 26),
				Text = if equipped then S.equipped else S.equip,
				TextColor3 = if equipped then Theme.Good else Theme.Text,
				Parent = box,
			}, function()
				if not equipped then
					local result = request("equip", item.id)
					if result and result.ok then
						setMessage(result.data.message)
					end
					render()
				end
			end)
		elseif item.source == "store" then
			local options = {}
			if item.fichas then
				table.insert(options, {
					action = "buy_fichas",
					text = string.format(S.buyFichas, item.fichas),
					can = fichas >= item.fichas,
				})
			end
			if item.creditos then
				table.insert(options, {
					action = "buy_creditos",
					text = string.format(S.buyCreditos, item.creditos),
					can = creditos >= item.creditos,
				})
			end
			for i, option in options do
				local width = 1 / #options
				button({
					Position = UDim2.new(width * (i - 1), if i == 1 then 8 else 2, 1, -34),
					Size = UDim2.new(width, -10, 0, 26),
					Text = option.text,
					TextColor3 = if option.can then Theme.Hazard else Theme.TextDim,
					Parent = box,
				}, function()
					local result = request(option.action, item.id)
					if result then
						if result.ok then
							setMessage(result.data.message)
							if result.data.ok then
								AudioController.play("Switch", 0.6, 1.4, true)
							end
						else
							setMessage("store_error")
						end
					end
					render()
				end)
			end
		else
			label({
				Position = UDim2.new(0, 8, 1, -34),
				Size = UDim2.new(1, -16, 0, 26),
				Text = px(string.format(S.locked, (S.sources :: any)[item.source] or "")),
				TextColor3 = Theme.TextDim,
				TextSize = Theme.SizeSmall,
				Parent = box,
			})
		end
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
		box.Size = UDim2.new(1, -12, 0, 100)
		label({
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 20),
			Text = string.format(Text.Season.tierLabel, index),
			Parent = box,
		})
		for column, trackName in { "free", "premium" } do
			local unlocked = reached and (trackName == "free" or premium)
			local text = if trackName == "free" then Text.Season.free else Text.Season.premium
			label({
				Position = UDim2.new((column - 1) * 0.5, 8, 0, 26),
				Size = UDim2.new(0.5, -16, 0, 68),
				Text = text
					.. " · "
					.. (if unlocked then Text.Season.received else Text.Season.locked)
					.. "\n"
					.. rewardText(if trackName == "free" then entry.free else entry.premium),
				TextSize = Theme.SizeSmall,
				TextColor3 = if unlocked then Theme.Good else Theme.TextDim,
				Parent = box,
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

render = function()
	local c = clearContent()
	if not c or not isOpen then
		return
	end
	-- Cabeçalho: saldo, nível e XP.
	local xp = attr("Xp", 0)
	local level, into, need = Economy.levelInfo(xp)
	if header then
		local vip = if attr("Vip", false) == true then "   ·   " .. S.vip else ""
		header.Text = px(
			string.format(S.balance, attr("Fichas", 0), attr("Creditos", 0))
				.. "   ·   "
				.. string.format(S.level, level)
				.. "  "
				.. string.format(S.xp, into, need)
				.. vip
		)
	end
	if xpFill then
		xpFill.Size = UDim2.fromScale(math.clamp(into / math.max(need, 1), 0, 1), 1)
	end
	for key, b in tabButtons do
		b.TextColor3 = if key == tab then Theme.Hazard else Theme.TextDim
	end
	c.CanvasPosition = Vector2.zero
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
		IgnoreGuiInset = true,
		DisplayOrder = 80,
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
		Size = UDim2.fromScale(0.9, 0.86),
		BackgroundColor3 = Color3.fromRGB(6, 6, 8),
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		Visible = false,
		Parent = screen,
	}, {
		Create("UIStroke", { Color = Theme.TextDim, Thickness = 2 }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(1100, 760) }),
	}) :: Frame
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
	label({
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(0.4, 0, 0, 30),
		Text = S.title,
		TextSize = Theme.SizeLarge,
		TextColor3 = Theme.Hazard,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	})
	header = label({
		Position = UDim2.new(0.4, 0, 0, 10),
		Size = UDim2.new(0.6, -16, 0, 22),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = p,
	})
	local bar = Create("Frame", {
		Position = UDim2.new(0.6, 0, 0, 36),
		Size = UDim2.new(0.4, -16, 0, 6),
		BackgroundColor3 = Color3.fromRGB(30, 30, 32),
		BorderSizePixel = 0,
		Parent = p,
	}) :: Frame
	xpFill = Create("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Theme.Good,
		BorderSizePixel = 0,
		Parent = bar,
	}) :: Frame

	for i, key in TABS do
		tabButtons[key :: Tab] = button({
			Name = `Tab_{key}`,
			Position = UDim2.new((i - 1) / #TABS, 16, 0, 52),
			Size = UDim2.new(1 / #TABS, -20, 0, 30),
			Text = (S.tabs :: any)[key],
			TextSize = Theme.SizeBody,
			Parent = p,
		}, function()
			tab = key :: Tab
			track("view", key)
			setMessage(nil)
			render()
		end)
	end
	-- Filtro por tipo (só na aba LOJA).
	local kinds = Create("Frame", {
		Name = "Kinds",
		Position = UDim2.fromOffset(16, 90),
		Size = UDim2.new(1, -32, 0, 24),
		BackgroundTransparency = 1,
		Parent = p,
	}) :: Frame
	for i, kind in StoreCatalog.KINDS do
		button({
			Name = `Kind_{kind}`,
			Position = UDim2.fromScale((i - 1) / #StoreCatalog.KINDS, 0),
			Size = UDim2.new(1 / #StoreCatalog.KINDS, -8, 1, 0),
			Text = (S.kinds :: any)[kind],
			Parent = kinds,
		}, function()
			kindFilter = kind :: StoreCatalog.ItemKind
			track("view", kind)
			tab = "shop"
			render()
		end)
	end
	content = Create("ScrollingFrame", {
		Name = "Content",
		Position = UDim2.fromOffset(16, 124),
		Size = UDim2.new(1, -32, 1, -176),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = p,
	}, {
		Create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4) }),
	}) :: ScrollingFrame
	message = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -12),
		Size = UDim2.new(0.7, 0, 0, 24),
		Text = "",
		TextColor3 = Theme.Hazard,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	})
	button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -10),
		Size = UDim2.fromOffset(150, 28),
		Text = S.close,
		Parent = p,
	}, function()
		setOpen(false)
	end)
	overlay = Create("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Black,
		BackgroundTransparency = 0.35,
		Visible = false,
		ZIndex = 5,
		Parent = p,
	}) :: Frame
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
