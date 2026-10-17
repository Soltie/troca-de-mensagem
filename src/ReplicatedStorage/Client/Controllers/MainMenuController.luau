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
local Create = require("../UI/Create")
local MenuLayout = require("../UI/MenuLayout")
local Theme = require("../UI/Theme")
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

local function stroke(color: Color3, thickness: number?, transparency: number?): Instance
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
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

local function sectionTitle(parent: Instance, text: string, order: number): TextLabel
	return label({
		Size = UDim2.new(1, 0, 0, if compactMenu and singleColumn then 44 else 22),
		Text = text,
		TextColor3 = Theme.Hazard,
		LayoutOrder = order,
		Parent = parent,
	})
end

local function pips(parent: Instance, filled: number, total: number, position: UDim2)
	local row = frame({
		Position = position,
		Size = UDim2.fromOffset(total * 18, 10),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	for i = 1, total do
		frame({
			Position = UDim2.fromOffset((i - 1) * 18, 0),
			Size = UDim2.fromOffset(14, 10),
			BackgroundColor3 = if i <= filled then Theme.Hazard else Color3.fromRGB(40, 44, 46),
			Parent = row,
		})
	end
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

local function buildPerks(b: Frame)
	local scroll = Create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Hazard,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = b,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingRight = UDim.new(0, 12) }),
	}) :: ScrollingFrame
	local levels = json("Perks", {})
	local stock = json("Consumables", {})
	sectionTitle(scroll, "MELHORIAS PERMANENTES · VALEM EM TODAS AS PARTIDAS", 1)
	for i, perk in Perks.List do
		local level = math.clamp(tonumber(levels[perk.id]) or 0, 0, Perks.MAX_LEVEL)
		local row = frame({
			Name = `Perk_{perk.id}`,
			Size = UDim2.new(1, 0, 0, 86),
			BackgroundTransparency = 0.08,
			LayoutOrder = 1 + i,
			Parent = scroll,
		}, { stroke(Theme.TextDim, 1, 0.7) })
		label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(0.5, 0, 0, 22),
			Text = perk.name,
			TextSize = 18,
			Parent = row,
		})
		note({
			Position = UDim2.fromOffset(14, 32),
			Size = UDim2.new(0.5, -14, 0, 20),
			Text = perk.description,
			Parent = row,
		})
		pips(row, level, Perks.MAX_LEVEL, UDim2.fromOffset(14, 62))
		label({
			Position = UDim2.fromOffset(112, 56),
			Size = UDim2.new(0.5, -110, 0, 22),
			Text = if level >= Perks.MAX_LEVEL
				then `NÍVEL MÁXIMO · {effectText(perk.id, level)}`
				else `AGORA: {if level > 0 then effectText(perk.id, level) else "-"} · PRÓXIMO: {effectText(
					perk.id,
					level + 1
				)}`,
			TextSize = Theme.SizeSmall,
			TextColor3 = GREEN,
			Parent = row,
		})
		if level < Perks.MAX_LEVEL then
			local fichas = Perks.nextCost(perk.id, level, "fichas") or 0
			local creditos = Perks.nextCost(perk.id, level, "creditos") or 0
			button({
				Name = "UpgradeFichas",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 12),
				Size = UDim2.fromOffset(220, 30),
				Text = `MELHORAR · {number(fichas)} FICHAS`,
				TextSize = Theme.SizeSmall,
				Parent = row,
			}, function()
				store("upgrade_fichas", perk.id)
			end)
			button({
				Name = "UpgradeCreditos",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 48),
				Size = UDim2.fromOffset(220, 30),
				Text = `MELHORAR · {number(creditos)} CRÉDITOS`,
				TextSize = Theme.SizeSmall,
				BackgroundColor3 = Color3.fromRGB(40, 34, 18),
				Parent = row,
			}, function()
				store("upgrade_creditos", perk.id)
			end)
		end
	end
	sectionTitle(scroll, "CONSUMÍVEIS · LIGUE NA MOCHILA DA PARTIDA (ABA JOGAR)", 20)
	for i, def in Perks.Consumables do
		local row = frame({
			Name = `Consumable_{def.id}`,
			Size = UDim2.new(1, 0, 0, 70),
			BackgroundTransparency = 0.08,
			LayoutOrder = 20 + i,
			Parent = scroll,
		}, { stroke(Theme.TextDim, 1, 0.7) })
		label({
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(0.55, 0, 0, 22),
			Text = `{def.name} · VOCÊ TEM {tonumber(stock[def.id]) or 0}`,
			TextSize = 18,
			Parent = row,
		})
		note({
			Position = UDim2.fromOffset(14, 34),
			Size = UDim2.new(0.55, -14, 0, 30),
			Text = def.description,
			Parent = row,
		})
		local slot = 0
		if def.fichas then
			slot += 1
			button({
				Name = "BuyFichas",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 4 + (slot - 1) * 32),
				Size = UDim2.fromOffset(220, 28),
				Text = `x{def.bundle} · {number(def.fichas)} FICHAS`,
				TextSize = Theme.SizeSmall,
				Parent = row,
			}, function()
				store("consumable_fichas", def.id)
			end)
		end
		if def.creditos then
			slot += 1
			button({
				Name = "BuyCreditos",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 4 + (slot - 1) * 32),
				Size = UDim2.fromOffset(220, 28),
				Text = `x{def.bundle} · {number(def.creditos)} CRÉDITOS`,
				TextSize = Theme.SizeSmall,
				BackgroundColor3 = Color3.fromRGB(40, 34, 18),
				Parent = row,
			}, function()
				store("consumable_creditos", def.id)
			end)
		end
	end
	sectionTitle(scroll, "PACOTES EM ROBUX", 40)
	local grid = frame({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 41,
		Parent = scroll,
	}, {
		Create("UIGridLayout", {
			CellSize = UDim2.new(0.333, -8, 0, 112),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
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
	for i, key in keys do
		local product = StoreCatalog.ProductByKey[key]
		if product then
			local cell = frame(
				{ Name = `Product_{key}`, BackgroundTransparency = 0.05, LayoutOrder = i, Parent = grid },
				{
					stroke(
						if key == "kit_sobrevivente" or key == "arquivo_elias" then Theme.Hazard else Theme.TextDim,
						1,
						0.4
					),
				}
			)
			label({
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -20, 0, 34),
				Text = product.name,
				TextSize = Theme.SizeSmall,
				Parent = cell,
			})
			note({
				Position = UDim2.fromOffset(10, 42),
				Size = UDim2.new(1, -20, 0, 34),
				Text = product.description,
				TextSize = 12,
				Parent = cell,
			})
			button({
				Name = "Buy",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -8),
				Size = UDim2.new(1, -20, 0, 24),
				Text = if product.id > 0 then `R$ {product.robux}` else "INDISPONÍVEL",
				TextSize = Theme.SizeSmall,
				BackgroundColor3 = Color3.fromRGB(28, 44, 30),
				Accent = GREEN,
				Parent = cell,
			}, function()
				buyProduct(key)
			end)
		end
	end
	if compactMenu and singleColumn then
		-- Uma coluna na tela estreita: descrição e compra não disputam a mesma linha.
		for _, row in scroll:GetChildren() do
			if
				row:IsA("Frame")
				and (row.Name:find("Perk_", 1, true) == 1 or row.Name:find("Consumable_", 1, true) == 1)
			then
				local perk = row.Name:find("Perk_", 1, true) == 1
				local nextY = if perk then 140 else 84
				for _, child in row:GetChildren() do
					if child:IsA("TextButton") then
						child.AnchorPoint = Vector2.zero
						child.Position, child.Size = UDim2.fromOffset(14, nextY), UDim2.new(1, -28, 0, 44)
						nextY += 52
					elseif child:IsA("TextLabel") then
						local originalY = child.Position.Y.Offset
						child.Position = UDim2.fromOffset(14, if originalY == 56 then 94 else originalY)
						child.Size = UDim2.new(1, -28, 0, if originalY == 8 then 24 else 40)
					elseif child:IsA("Frame") and child.Position.Y.Offset == 62 then
						child.Position = UDim2.fromOffset(14, 80)
					end
				end
				row.Size = UDim2.new(1, 0, 0, nextY)
			end
		end
		local layout = grid:FindFirstChildOfClass("UIGridLayout") :: UIGridLayout
		layout.CellSize = UDim2.new(1, -8, 0, 132)
		for _, child in grid:GetDescendants() do
			if child:IsA("TextButton") then
				child.Size = UDim2.new(1, -20, 0, 44)
			end
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

local function buildServers(b: Frame)
	local data = serverCache
	if not data or os.clock() - lastServerFetch > 20 then
		fetchServers()
	end
	local top = frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Parent = b })
	local current = if data then data.current else nil
	label({
		Size = UDim2.new(1, -170, 1, 0),
		Text = if current
			then `ESTE SERVIDOR: {current.players}/{current.max} · {PHASE_NAMES[current.phase] or current.phase}`
			else "CARREGANDO...",
		TextColor3 = Theme.Hazard,
		Parent = top,
	})
	button({
		Name = "Refresh",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(160, 30),
		Text = "ATUALIZAR",
		TextSize = Theme.SizeSmall,
		Parent = top,
	}, fetchServers)
	local list = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = b,
	}, { Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }) :: ScrollingFrame
	if not data then
		return
	end
	if not data.online then
		note({
			Size = UDim2.new(1, 0, 0, 60),
			Text = "A lista de servidores funciona no jogo publicado. No Studio só existe este servidor.",
			Parent = list,
		})
		return
	end
	local servers = if type(data.servers) == "table" then data.servers else {}
	if #servers == 0 then
		note({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Nenhum outro servidor aberto agora. Chame amigos!",
			Parent = list,
		})
	end
	for i, entry in servers do
		local row = frame({
			Name = `Server_{i}`,
			Size = UDim2.new(1, -10, 0, 52),
			BackgroundTransparency = 0.08,
			LayoutOrder = i,
			Parent = list,
		}, {
			stroke(Theme.TextDim, 1, 0.7),
		})
		local mode = if entry.mode == "Story"
			then "HISTÓRIA"
			elseif entry.mode == "Standard" then "CO-OP"
			else "VOTANDO"
		local stage = if (entry.stage or 0) > 0 then ` · ETAPA {entry.stage}` else ""
		label({
			Position = UDim2.fromOffset(14, 0),
			Size = UDim2.new(1, -200, 1, 0),
			Text = `{PHASE_NAMES[entry.phase] or entry.phase} · {mode}{stage} · {entry.players}/{entry.max}`,
			Parent = row,
		})
		local full = entry.players >= entry.max
		button({
			Name = "Join",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(150, 32),
			Text = if full then "CHEIO" else "ENTRAR",
			TextSize = Theme.SizeSmall,
			Accent = if full then Theme.TextDim else GREEN,
			Parent = row,
		}, function()
			if not full then
				local result, err = invoke("Lobby", "join", entry.job)
				say(err or (if type(result) == "table" then result.message else nil))
			end
		end)
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
	local top = frame({ Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = b })
	button({
		Name = "Invite",
		Size = UDim2.fromOffset(260, 38),
		Text = "CONVIDAR AMIGOS",
		TextSize = Theme.SizeLarge,
		Accent = GREEN,
		BackgroundColor3 = Color3.fromRGB(28, 44, 30),
		Parent = top,
	}, invite)
	button({
		Name = "Refresh",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 4),
		Size = UDim2.fromOffset(160, 30),
		Text = "ATUALIZAR",
		TextSize = Theme.SizeSmall,
		Parent = top,
	}, fetchFriends)
	local list = Create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 54),
		Size = UDim2.new(1, 0, 1, -54),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = b,
	}, { Create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) }) :: ScrollingFrame
	local friends = friendsCache
	if not friends then
		note({ Size = UDim2.new(1, 0, 0, 30), Text = "Procurando amigos online...", Parent = list })
		return
	end
	if friendsError then
		note({
			Size = UDim2.new(1, 0, 0, 40),
			Text = "Não foi possível ler seus amigos agora. Tente atualizar.",
			Parent = list,
		})
		return
	end
	if #friends == 0 then
		note({ Size = UDim2.new(1, 0, 0, 40), Text = "Nenhum amigo online agora. Use CONVIDAR AMIGOS.", Parent = list })
	end
	-- Quem está na Subestação 9 primeiro.
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
		local row = frame({
			Name = `Friend_{i}`,
			Size = UDim2.new(1, -10, 0, 52),
			BackgroundTransparency = 0.08,
			LayoutOrder = i,
			Parent = list,
		}, {
			stroke(if here then GREEN else Theme.TextDim, 1, 0.6),
		})
		Create("ImageLabel", {
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.fromOffset(40, 40),
			BackgroundTransparency = 1,
			Image = `rbxthumb://type=AvatarHeadShot&id={friend.VisitorId}&w=48&h=48`,
			Parent = row,
		})
		label({
			Position = UDim2.fromOffset(58, 6),
			Size = UDim2.new(1, -230, 0, 20),
			Text = tostring(friend.DisplayName or friend.UserName or "?"),
			Parent = row,
		})
		label({
			Position = UDim2.fromOffset(58, 26),
			Size = UDim2.new(1, -230, 0, 18),
			Text = if here then "NA TUNG TUNG SAHUR" else tostring(friend.LastLocation or "ONLINE"),
			TextSize = Theme.SizeSmall,
			TextColor3 = if here then GREEN else Theme.TextDim,
			Parent = row,
		})
		if here then
			button({
				Name = "JoinFriend",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(150, 32),
				Text = "ENTRAR",
				TextSize = Theme.SizeSmall,
				Accent = GREEN,
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
		return { art = 64, height = 258, title = 22, desc = 13, pad = 12, vote = 44 }
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
	local compact = m.art < 80
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
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0.5, -2),
			Text = `{def.name} x{count}`,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = tile,
		})
		label({
			Name = "ItemState",
			Position = UDim2.new(0, 8, 0.5, 0),
			Size = UDim2.new(1, -16, 0.5, -4),
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
				if pass and pass.id > 0 then
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
	showcase(scroll, 3)
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
	local b = clearBody()
	if not b then
		return
	end
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
	local brandY = if compact then 0 else -9
	local rec = Create("Frame", {
		Name = "Rec",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, brandY),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = bar,
	}) :: Frame
	Components.corner(rec, Theme.CornerPill)
	local logo = Components.title({
		Name = "Logo",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 18, 0.5, brandY),
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
			Position = UDim2.new(0, 18, 0.5, 11),
			Size = UDim2.fromOffset(440, 18),
			Text = "THE CURSED HOUSE · EXPLORE, PEGUE MOEDAS E FUJA DO TUM TUM TUM",
			FontFace = Theme.Font,
			TextSize = 13,
			TextColor3 = Theme.TextSecondary,
			TextWrapped = false,
			Parent = bar,
		})
	end
	table.insert(frameUpdates, function()
		rec.Visible = (os.clock() * 1.4) % 1 < 0.6
	end)

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
