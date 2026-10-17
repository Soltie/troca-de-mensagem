--!strict
--[[
	Menu inicial (lobby da campanha). Substitui o antigo ModeMenuController.

	  Esquerda  logo, navegação e cartão do jogador (nível, Fichas, Créditos, VIP).
	  Direita   conteúdo da aba:
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
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local AudioController = require("./AudioController")
local Cinema = require("./CinematicController")
local Store = require("./StoreController")
local Settings = require("./SettingsController")
local TungTungRig = require("../Creature/TungTungRig")

type TabId = "play" | "perks" | "store" | "season" | "daily" | "servers" | "friends" | "settings"

local player = Players.LocalPlayer
local GREEN = Color3.fromRGB(120, 200, 140)
local VEIL = Color3.fromRGB(16, 8, 34)
local CARD = Color3.fromRGB(30, 18, 56)

local NAV: { { id: TabId, label: string, icon: string } } = {
	{ id = "play", label = "JOGAR", icon = "▶️" },
	{ id = "perks", label = "MELHORIAS", icon = "⚡" },
	{ id = "store", label = "LOJA", icon = "🛒" },
	{ id = "season", label = "PASSE DA TEMPORADA", icon = "🎫" },
	{ id = "daily", label = "PRÊMIO DIÁRIO", icon = "🎁" },
	{ id = "servers", label = "SERVIDORES", icon = "🌐" },
	{ id = "friends", label = "AMIGOS", icon = "👫" },
	{ id = "settings", label = "AJUSTES", icon = "⚙️" },
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
		TextColor3 = Theme.Text,
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
		TextColor3 = Theme.TextDim,
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
	return Create("Frame", base, children) :: Frame
end

local function stroke(color: Color3, thickness: number?, transparency: number?): Instance
	return Create("UIStroke", {
		Color = color,
		Thickness = thickness or 1,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function button(props: { [string]: any }, onClick: () -> ()): TextButton
	local base: { [string]: any } = {
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Panel,
		BorderSizePixel = 0,
		FontFace = Theme.Font,
		TextColor3 = Theme.Text,
		TextSize = Theme.SizeBody,
	}
	local accent = props.Accent or Theme.Hazard
	props.Accent = nil
	for key, value in props do
		base[key] = value
	end
	if type(base.Text) == "string" then
		base.Text = px(base.Text)
	end
	local b = Create("TextButton", base, { stroke(accent, 1, 0.35) }) :: TextButton
	local idle = b.BackgroundColor3
	b.MouseEnter:Connect(function()
		b.BackgroundColor3 = idle:Lerp(accent, 0.25)
	end)
	b.MouseLeave:Connect(function()
		b.BackgroundColor3 = idle
	end)
	b.Activated:Connect(function()
		AudioController.play("UiBlip", 0.5, 1.1, true)
		onClick()
	end)
	return b
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
		Size = UDim2.new(1, 0, 0, 22),
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

local function modeCard(
	parent: Instance,
	index: number,
	id: string,
	eyebrow: string,
	title: string,
	description: string,
	extra: (Frame) -> ()
)
	local card = frame({
		Name = `Mode_{id}`,
		Position = UDim2.new((index - 1) * 0.5, if index == 1 then 0 else 8, 0, 0),
		Size = UDim2.new(0.5, -8, 0, 300),
		BackgroundColor3 = CARD,
		BackgroundTransparency = 0.08,
		Parent = parent,
	}, {
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 16),
			PaddingTop = UDim.new(0, 14),
		}),
	})
	local border = stroke(Theme.Hazard, 1, 0.55) :: UIStroke
	border.Parent = card
	label({
		Size = UDim2.new(1, 0, 0, 16),
		Text = eyebrow,
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Hazard,
		Parent = card,
	})
	label({
		Position = UDim2.fromOffset(0, 20),
		Size = UDim2.new(1, 0, 0, 30),
		Text = title,
		TextSize = 26,
		Parent = card,
	})
	note({ Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 40), Text = description, Parent = card })
	extra(card)
	local votes = label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -18),
		Size = UDim2.new(0.45, 0, 0, 20),
		Text = "VOTOS: 0",
		TextColor3 = Theme.TextDim,
		Parent = card,
	})
	local vote = button({
		Name = "Vote",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, -12),
		Size = UDim2.fromOffset(170, 36),
		Text = "VOTAR",
		TextSize = Theme.SizeLarge,
	}, function()
		local data, err = invoke("SelectGameMode", id)
		if err then
			say(err)
		elseif type(data) == "table" and not data.accepted then
			say("not_available")
		end
	end)
	vote.Parent = card
	table.insert(live, function()
		local state = campaign()
		local count = if state then state:GetAttribute(if id == "Story" then "StoryVotes" else "StandardVotes") else 0
		votes.Text = px(`VOTOS: {count or 0}`)
		local mine = player:GetAttribute("GameModeVote") == id
		vote.Text = px(if mine then "SEU VOTO" else "VOTAR")
		vote.BackgroundColor3 = if mine then Color3.fromRGB(46, 58, 40) else Theme.Panel
		border.Transparency = if mine then 0 else 0.55
		border.Thickness = if mine then 2 else 1
	end)
end

local function buildPlay(parent: Frame)
	-- Conteúdo maior que o painel precisa rolar; a vitrine antes vazava sobre a dica inferior.
	local scroll = Create("ScrollingFrame", {
		Name = "PlayScroll",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Hazard,
		CanvasSize = UDim2.fromOffset(0, 654),
		ClipsDescendants = true,
		Parent = parent,
	})
	local b =
		frame({ Name = "PlayContent", Size = UDim2.new(1, -12, 0, 650), BackgroundTransparency = 1, Parent = scroll })
	local modes = frame({ Size = UDim2.new(1, 0, 0, 300), BackgroundTransparency = 1, Parent = b })
	local cleared, flawless = storyCleared()
	modeCard(
		modes,
		1,
		"Story",
		"📖 MODO HISTÓRIA",
		"THE CURSED HOUSE",
		"Uma casa amaldiçoada em 5 capítulos. Solo ou equipe de até 6.",
		function(card)
			for chapter = 1, #StoryRewards.Chapters do
				local done = cleared[chapter] == true
				local box = frame({
					Position = UDim2.new((chapter - 1) / 5, 0, 0, 104),
					Size = UDim2.new(1 / 5, -6, 0, 40),
					BackgroundColor3 = if done then Color3.fromRGB(46, 40, 22) else Color3.fromRGB(24, 28, 30),
					Parent = card,
				}, { stroke(if done then Theme.Hazard else Theme.TextDim, 1, if done then 0 else 0.6) })
				label({
					Size = UDim2.fromScale(1, 0.6),
					Text = `CAP. {chapter}`,
					TextSize = Theme.SizeSmall,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = if done then Theme.Hazard else Theme.TextDim,
					Parent = box,
				})
				label({
					Position = UDim2.fromScale(0, 0.55),
					Size = UDim2.fromScale(1, 0.4),
					Text = if flawless[chapter] then "SEM QUEDAS" elseif done then "VENCIDO" else "",
					TextSize = 10,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextColor3 = if flawless[chapter] then GREEN else Theme.Hazard,
					Parent = box,
				})
			end
			local chapter, reward = storyPreview()
			label({
				Position = UDim2.fromOffset(0, 152),
				Size = UDim2.new(1, 0, 0, 34),
				Text = `CAPÍTULO {chapter}: {reward}`,
				TextSize = Theme.SizeSmall,
				TextColor3 = GREEN,
				Parent = card,
			})
			if player:GetAttribute("StoryPass") == true then
				label({
					Position = UDim2.fromOffset(0, 188),
					Size = UDim2.new(1, 0, 0, 16),
					Text = "⭐ PASSE DA HISTÓRIA ATIVO: RECOMPENSAS x2",
					TextSize = Theme.SizeSmall,
					TextColor3 = Theme.Hazard,
					Parent = card,
				})
			else
				local pass = StoreCatalog.ProductByKey[StoreCatalog.StoryPassKey]
				button({
					Name = "StoryPass",
					Position = UDim2.fromOffset(0, 186),
					Size = UDim2.new(1, 0, 0, 22),
					Text = if pass.id > 0
						then `PASSE DA HISTÓRIA: RECOMPENSAS x2 · R$ {pass.robux}`
						else "PASSE INDISPONÍVEL",
					TextSize = Theme.SizeSmall,
					BackgroundTransparency = 0.4,
					Parent = card,
				}, function()
					buyProduct(StoreCatalog.StoryPassKey)
				end)
			end
		end
	)
	modeCard(
		modes,
		2,
		"Standard",
		"🎲 MODO DESAFIO",
		"MAIS UMA NOITE",
		"Casa e jardins, com passagens, escadas e itens sorteados. 5 capítulos, 1–6 jogadores.",
		function(card)
			local lines = {
				"PRÊMIOS: FICHAS E XP POR CAPÍTULO, FUGA E AJUDA AO TIME",
				"MOEDAS E FITAS VHS ESPALHADAS PELA CASA",
			}
			for i, line in lines do
				label({
					Position = UDim2.fromOffset(0, 104 + (i - 1) * 22),
					Size = UDim2.new(1, 0, 0, 20),
					Text = line,
					TextSize = Theme.SizeSmall,
					TextColor3 = if i == 1 then GREEN else Theme.TextDim,
					Parent = card,
				})
			end
			local boost = label({
				Position = UDim2.fromOffset(0, 160),
				Size = UDim2.new(1, 0, 0, 20),
				Text = "",
				TextSize = Theme.SizeSmall,
				TextColor3 = Theme.Hazard,
				Parent = card,
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
			local product = StoreCatalog.ProductByKey.bonus_duplo_3h
			button({
				Name = "Boost",
				Position = UDim2.fromOffset(0, 186),
				Size = UDim2.new(1, 0, 0, 22),
				Text = if product.id > 0
					then `FICHAS E XP x2 POR 3 HORAS · R$ {product.robux}`
					else "BÔNUS INDISPONÍVEL",
				TextSize = Theme.SizeSmall,
				BackgroundTransparency = 0.4,
				Parent = card,
			}, function()
				buyProduct("bonus_duplo_3h")
			end)
		end
	)

	-- Equipe no servidor + contagem.
	local team = frame({
		Name = "Team",
		Position = UDim2.fromOffset(0, 312),
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundTransparency = 0.08,
		Parent = b,
	}, { stroke(Theme.TextDim, 1, 0.7) })
	local status = label({
		Position = UDim2.fromOffset(14, 8),
		Size = UDim2.new(1, -28, 0, 20),
		Text = "",
		TextColor3 = Theme.Hazard,
		Parent = team,
	})
	local slots = frame({
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(1, -28, 0, 52),
		BackgroundTransparency = 1,
		Parent = team,
	})
	local slotFrames: { Frame } = {}
	for i = 1, Config.Campaign.maxPlayers do
		local slot = frame({
			Position = UDim2.new((i - 1) / Config.Campaign.maxPlayers, 2, 0, 0),
			Size = UDim2.new(1 / Config.Campaign.maxPlayers, -4, 1, 0),
			BackgroundColor3 = Color3.fromRGB(20, 24, 26),
			Parent = slots,
		}, { stroke(Theme.TextDim, 1, 0.75) })
		Create("ImageLabel", {
			Name = "Face",
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(0.5, 0, 0, 3),
			BackgroundTransparency = 1,
			Image = "",
			Parent = slot,
		})
		label({
			Name = "Who",
			Position = UDim2.fromOffset(2, 34),
			Size = UDim2.new(1, -4, 0, 14),
			Text = "",
			TextSize = 10,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = Theme.Text,
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
				then `TIME {count}/{Config.Campaign.maxPlayers} · FALTAM {Config.Campaign.minPlayers - count} PARA COMEÇAR`
				else `TIME {count}/{Config.Campaign.maxPlayers} · ESPERANDO OS VOTOS`
		)
		for i, slot in slotFrames do
			local other = list[i]
			local face = slot:FindFirstChild("Face") :: ImageLabel
			local who = slot:FindFirstChild("Who") :: TextLabel
			local border = slot:FindFirstChildOfClass("UIStroke")
			if other then
				face.Image = `rbxthumb://type=AvatarHeadShot&id={other.UserId}&w=48&h=48`
				local vote = other:GetAttribute("GameModeVote")
				who.Text = px(other.DisplayName)
				if border then
					border.Color = if vote == "Story"
						then Theme.Hazard
						elseif vote == "Standard" then GREEN
						else Theme.TextDim
					border.Transparency = if vote == "Story" or vote == "Standard" then 0 else 0.75
				end
			else
				face.Image = ""
				who.Text = ""
				if border then
					border.Color = Theme.TextDim
					border.Transparency = 0.75
				end
			end
		end
	end)

	-- Kit do turno (consumíveis de uso automático) e atalhos.
	local kit = frame({
		Name = "Kit",
		Position = UDim2.fromOffset(0, 420),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
		Parent = b,
	})
	label({
		Size = UDim2.new(1, 0, 0, 16),
		Text = "🎒 MOCHILA DA PARTIDA",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Hazard,
		Parent = kit,
	})
	local stock = json("Consumables", {})
	local loadout: { [string]: boolean } = {}
	for _, id in json("Loadout", {}) do
		loadout[tostring(id)] = true
	end
	for i, def in Perks.Consumables do
		local count = tonumber(stock[def.id]) or 0
		local on = loadout[def.id] == true
		local chip = button({
			Name = `Kit_{def.id}`,
			Position = UDim2.new((i - 1) / 3, if i == 1 then 0 else 6, 0, 22),
			Size = UDim2.new(1 / 3, -6, 0, 38),
			Text = if def.loadout
				then `{def.name} x{count} · {if on and count > 0 then "LIGADO" else "DESLIGADO"}`
				else `{def.name} x{count} · NA DERROTA`,
			TextSize = Theme.SizeSmall,
			BackgroundColor3 = if on and count > 0 then Color3.fromRGB(40, 52, 36) else Theme.Panel,
			Accent = if on then GREEN else Theme.Hazard,
			Parent = kit,
		}, function()
			if count <= 0 then
				currentTab = "perks"
				dirty = true
				return
			end
			if def.loadout then
				store(if on then "loadout_off" else "loadout_on", def.id)
			end
		end)
		chip.TextWrapped = true
	end

	-- Vitrine: o próprio Tung Tung do jogo, animado, com a "fala" dele.
	local showcase = frame({
		Name = "Showcase",
		ClipsDescendants = true,
		Position = UDim2.fromOffset(0, 496),
		Size = UDim2.new(1, 0, 0, 146),
		BackgroundColor3 = Theme.PanelLight,
		BackgroundTransparency = 0.3,
		Parent = b,
	}, { Create("UICorner", { CornerRadius = Theme.Corner }), stroke(Theme.Hazard, 2, 0.35) })
	local viewport = Create("ViewportFrame", {
		Name = "TungTung",
		Size = UDim2.new(0, 210, 1, 0),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 170, 230),
		LightColor = Color3.fromRGB(255, 236, 210),
		LightDirection = Vector3.new(-0.6, -1, 0.4),
		Parent = showcase,
	}) :: ViewportFrame
	label({
		Position = UDim2.fromOffset(220, 14),
		Size = UDim2.new(1, -236, 0, 34),
		Text = "TUNG TUNG SAHUR",
		TextSize = 30,
		TextColor3 = Theme.Hazard,
		Parent = showcase,
	})
	note({
		Position = UDim2.fromOffset(220, 52),
		Size = UDim2.new(1, -236, 0, 32),
		Text = "“TUM... TUM... TUM... SAHUR!” 🥁",
		TextSize = 18,
		TextColor3 = Theme.Text,
		Parent = showcase,
	})
	note({
		Position = UDim2.fromOffset(220, 89),
		Size = UDim2.new(1, -236, 0, 50),
		Text = "Ele anda pela casa com o bastão. Apague a lanterna, se esconda nos armários e salve seus amigos!",
		TextSize = 14,
		TextColor3 = Theme.TextDim,
		Parent = showcase,
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
		nav.BackgroundTransparency = if selected then 0.55 else 1
		nav.TextColor3 = if selected then Theme.Hazard else Theme.Text
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
	-- Entrada da aba: desliza 12 px (só com efeitos de movimento ligados).
	b.Position = UDim2.fromOffset(0, 74 + 12)
	TweenService:Create(b, TweenInfo.new(0.16, Enum.EasingStyle.Quad), { Position = UDim2.fromOffset(0, 74) }):Play()
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

local function build(): ScreenGui
	local screen = Create("ScreenGui", {
		Name = "MainMenu",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 200,
		Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	local root = frame({ Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = screen })
	local scale = Create("UIScale", { Parent = root }) :: UIScale
	-- Véu: escuro à esquerda (leitura), aberto à direita (as câmeras aparecem).
	frame({
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = VEIL,
		Parent = root,
	}, {
		Create("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.04),
				NumberSequenceKeypoint.new(0.38, 0.22),
				NumberSequenceKeypoint.new(1, 0.55),
			}),
		}),
	})

	-- Coluna esquerda: logo, navegação, cartão do jogador.
	local left = frame({
		Name = "Left",
		Position = UDim2.fromOffset(44, 34),
		Size = UDim2.new(0, 380, 1, -68),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local rec = frame({
		Size = UDim2.fromOffset(12, 12),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = Theme.Accent,
		Parent = left,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	})
	label({
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -20, 0, 20),
		Text = "🌙 UMA NOITE NA CASA DO TUNG TUNG",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Accent,
		Parent = left,
	})
	label({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 58),
		Text = "TUNG TUNG SAHUR",
		TextSize = 38,
		Parent = left,
	})
	label({
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.new(1, 0, 0, 18),
		Text = "EXPLORE · PEGUE MOEDAS · FUJA DO TUM TUM TUM!",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Hazard,
		Parent = left,
	})
	local nav = frame({
		Name = "Nav",
		Position = UDim2.fromOffset(0, 128),
		Size = UDim2.new(1, 0, 0, #NAV * 44),
		BackgroundTransparency = 1,
		Parent = left,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	for i, item in NAV do
		local navButton = Create("TextButton", {
			Name = `Nav_{item.id}`,
			Size = UDim2.new(1, 0, 0, 40),
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromRGB(46, 38, 16),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			FontFace = Theme.Font,
			Text = `   {item.icon}  {item.label}`,
			TextColor3 = Theme.Text,
			TextSize = Theme.SizeLarge,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = i,
			Parent = nav,
		}) :: TextButton
		frame({
			Name = "Bar",
			Size = UDim2.new(0, 4, 1, 0),
			BackgroundColor3 = Theme.Hazard,
			Visible = false,
			Parent = navButton,
		})
		if STORE_TABS[item.id] then
			label({
				Name = "Arrow",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -10, 0.5, 0),
				Size = UDim2.fromOffset(30, 20),
				Text = ">",
				TextColor3 = Theme.TextDim,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = navButton,
			})
		end
		if item.id == "daily" then
			frame({
				Name = "Badge",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -46, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
				BackgroundColor3 = Theme.Accent,
				Visible = false,
				Parent = navButton,
			}, { Create("UICorner", { CornerRadius = UDim.new(1, 0) }) })
		end
		navButton.MouseEnter:Connect(function()
			if item.id ~= currentTab then
				navButton.BackgroundTransparency = 0.8
			end
		end)
		navButton.MouseLeave:Connect(function()
			navButton.BackgroundTransparency = if item.id == currentTab then 0.55 else 1
		end)
		navButton.Activated:Connect(function()
			AudioController.play("UiBlip", 0.5, 1.1, true)
			selectTab(item.id)
		end)
		navButtons[item.id] = navButton
	end

	-- O kit pago fica só na aba MELHORIAS (sem oferta fixa na tela inicial).

	-- Cartão do jogador.
	local cardFrame = frame({
		Name = "Player",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 128),
		BackgroundTransparency = 0.1,
		Parent = left,
	}, { stroke(Theme.Hazard, 1, 0.5) })
	Create("ImageLabel", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(64, 64),
		BackgroundColor3 = Color3.fromRGB(24, 28, 30),
		BorderSizePixel = 0,
		Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`,
		Parent = cardFrame,
	})
	local nameLabel = label({
		Position = UDim2.fromOffset(84, 8),
		Size = UDim2.new(1, -94, 0, 20),
		Text = player.DisplayName,
		Parent = cardFrame,
	})
	local titleLabel = label({
		Position = UDim2.fromOffset(84, 28),
		Size = UDim2.new(1, -94, 0, 16),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.Hazard,
		Parent = cardFrame,
	})
	local levelLabel = label({
		Position = UDim2.fromOffset(84, 46),
		Size = UDim2.new(1, -94, 0, 16),
		Text = "",
		TextSize = Theme.SizeSmall,
		Parent = cardFrame,
	})
	local barBack = frame({
		Position = UDim2.fromOffset(84, 64),
		Size = UDim2.new(1, -94, 0, 6),
		BackgroundColor3 = Color3.fromRGB(34, 38, 40),
		Parent = cardFrame,
	})
	local barFill = frame({ Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN, Parent = barBack })
	local wallet = label({
		Position = UDim2.fromOffset(10, 86),
		Size = UDim2.new(1, -100, 0, 30),
		Text = "",
		TextSize = Theme.SizeSmall,
		Parent = cardFrame,
	})
	button({
		Name = "AddCredits",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 88),
		Size = UDim2.fromOffset(80, 28),
		Text = "+ CRÉDITOS",
		TextSize = 10,
		Accent = GREEN,
		BackgroundColor3 = Color3.fromRGB(28, 44, 30),
		Parent = cardFrame,
	}, function()
		Store.openTab("robux")
	end)

	-- Painel da direita.
	local right = frame({
		Name = "Content",
		Position = UDim2.fromOffset(470, 34),
		Size = UDim2.new(1, -514, 1, -68),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.18,
		Parent = root,
	}, {
		stroke(Theme.Hazard, 1, 0.6),
		Create("UIPadding", {
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 20),
			PaddingTop = UDim.new(0, 16),
			PaddingBottom = UDim.new(0, 16),
		}),
	})
	header = label({ Size = UDim2.new(1, 0, 0, 32), Text = "", TextSize = 28, Parent = right })
	subheader = note({ Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 30), Text = "", Parent = right })
	body = frame({
		Name = "Body",
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 1, -110),
		BackgroundTransparency = 1,
		Parent = right,
	})
	local tip = label({
		Name = "Tip",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -260, 0, 20),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextColor3 = Theme.TextDim,
		Parent = right,
	})
	tip.TextWrapped, tip.TextTruncate = false, Enum.TextTruncate.AtEnd
	feedback = label({
		Name = "Feedback",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(420, 20),
		Text = "",
		TextSize = Theme.SizeSmall,
		TextColor3 = GREEN,
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = right,
	})

	-- Atualizações contínuas fora das abas (cartão, dica, escala).
	local tipClock = 0
	RunService.RenderStepped:Connect(function(dt)
		if not screen.Enabled then
			return
		end
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		-- Desenho em 1280x720: o UIScale encolhe o raiz junto, então ele cresce na mesma proporção.
		local factor = math.clamp(math.min(viewport.X / 1280, viewport.Y / 720), 0.25, 1.6)
		scale.Scale = factor
		root.Size = UDim2.fromScale(1 / factor, 1 / factor)
		rec.Visible = (os.clock() * 1.4) % 1 < 0.6
		local xp = tonumber(player:GetAttribute("Xp")) or 0
		local level, into, needed = Economy.levelInfo(xp)
		levelLabel.Text = px(`NÍVEL {level} · {number(into)}/{number(needed)} XP`)
		barFill.Size = UDim2.fromScale(math.clamp(into / math.max(needed, 1), 0, 1), 1)
		local titleId = player:GetAttribute("Title")
		local titleItem = if type(titleId) == "string" then StoreCatalog.ItemById[titleId] else nil
		titleLabel.Text = px(
			(if titleItem then titleItem.name else "") .. (if player:GetAttribute("Vip") == true then " · VIP" else "")
		)
		nameLabel.Text = player.DisplayName
		wallet.Text = px(
			`💰 {number(tonumber(player:GetAttribute("Fichas")) or 0)} FICHAS   💎 {number(
				tonumber(player:GetAttribute("Creditos")) or 0
			)} CRÉDITOS`
		)
		local badge = navButtons.daily and navButtons.daily:FindFirstChild("Badge")
		if badge and badge:IsA("Frame") then
			badge.Visible = player:GetAttribute("DailyClaimable") == true
				or (tonumber(player:GetAttribute("SpinsLeft")) or 0) > 0
		end
		tipClock += dt
		if tipClock > 6 or tip.Text == "" then
			tipClock = 0
			tipIndex = tipIndex % #TIPS + 1
			tip.Text = px("DICA: " .. TIPS[tipIndex])
		end
	end)
	screen.Parent = player:WaitForChild("PlayerGui")
	return screen
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
	gui = build()
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
	RunService:BindToRenderStep("S9MainMenu", Enum.RenderPriority.Last.Value, function()
		local screen = gui
		if not screen then
			return
		end
		local open = state:GetAttribute("Phase") == "Lobby" and player:GetAttribute("OpeningActive") ~= true
		player:SetAttribute("ModeMenuOpen", open)
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
		elseif wasOpen then
			UserInputService.MouseIconEnabled = false
		end
		wasOpen = open
	end)
end

return Controller
