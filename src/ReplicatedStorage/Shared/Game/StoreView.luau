--!strict
--[[
	Apresentação da loja (puro, testado no Lune): só LÊ os catálogos para explicar cada item na UI.
	Nada aqui decide posse, preço ou concessão — isso é do StoreService.

	  state       equipado / adquirido / à venda / bloqueado (a partir dos atributos publicados)
	  howToGet    como conseguir o item, com o número real (nível, fitas, capítulo, nível do passe)
	  kindNote    quem vê / onde aparece o cosmético
	  prices      opções de compra direta e quanto falta de cada moeda
]]

local SeasonCatalog = require("./SeasonCatalog")
local StoreCatalog = require("./StoreCatalog")
local StoryRewards = require("./StoryRewards")

type Item = StoreCatalog.Item

export type ItemState = "equipped" | "owned" | "buyable" | "locked"
export type PriceOption = {
	currency: StoreCatalog.Currency,
	price: number,
	affordable: boolean,
	missing: number,
}

local StoreView = {}

local KIND_NOTES: { [StoreCatalog.ItemKind]: string } = {
	flashlight = "LANTERNA · SÓ VOCÊ VÊ, NA SUA MÃO.",
	uniform = "FARDA · SEUS COLEGAS VEEM NO SEU PERSONAGEM.",
	filter = "FILTRO · MUDA AS CORES DA SUA TELA.",
	title = "TÍTULO · APARECE AO LADO DO SEU NOME.",
}

function StoreView.kindNote(kind: StoreCatalog.ItemKind): string
	return KIND_NOTES[kind] or ""
end

function StoreView.isOwned(item: Item, owned: { [string]: boolean }, vip: boolean): boolean
	if item.source == "default" then
		return true
	end
	if item.source == "vip" then
		return vip
	end
	return owned[item.id] == true
end

function StoreView.state(item: Item, owned: { [string]: boolean }, equippedId: string, vip: boolean): ItemState
	if StoreView.isOwned(item, owned, vip) then
		return if equippedId == item.id then "equipped" else "owned"
	end
	if item.source == "store" and (item.fichas ~= nil or item.creditos ~= nil) then
		return "buyable"
	end
	return "locked"
end

local function levelOf(itemId: string): number?
	for level, reward in StoreCatalog.LevelMilestones do
		if reward.item == itemId then
			return level
		end
	end
	return nil
end

local function tapesFor(itemId: string): number?
	for amount, reward in StoreCatalog.TapeMilestones do
		if reward.item == itemId then
			return amount
		end
	end
	return nil
end

local function seasonTier(itemId: string): (number?, string?)
	for _, season in SeasonCatalog.Seasons do
		for index, tier in season.tiers do
			if tier.free and tier.free.item == itemId then
				return index, "GRÁTIS"
			end
			if tier.premium and tier.premium.item == itemId then
				return index, "PREMIUM"
			end
		end
	end
	return nil, nil
end

local function storyChapter(itemId: string): number?
	for chapter, def in StoryRewards.Chapters do
		if def.first.item == itemId then
			return chapter
		end
	end
	return nil
end

-- Texto curto e verdadeiro sobre como conseguir o item (usa os catálogos reais).
function StoreView.howToGet(item: Item): string
	local source = item.source
	if source == "default" then
		return "ITEM PADRÃO: TODO MUNDO JÁ TEM."
	elseif source == "store" then
		return "COMPRE AQUI NA LOJA OU GANHE NOS BAÚS."
	elseif source == "level" then
		local level = levelOf(item.id)
		return if level then `RECOMPENSA AO CHEGAR NO NÍVEL {level}.` else "RECOMPENSA DE NÍVEL."
	elseif source == "tapes" then
		local amount = tapesFor(item.id)
		return if amount then `JUNTE {amount} FITAS VHS ESCONDIDAS NA CASA.` else "COLEÇÃO DE FITAS VHS."
	elseif source == "vip" then
		return "EXCLUSIVO DE QUEM TEM O VIP."
	elseif source == "starter" then
		return "VEM NO PACOTE INICIAL."
	elseif source == "escape" then
		return "FUJA DA CASA PELA PRIMEIRA VEZ."
	elseif source == "season" then
		local tier, track = seasonTier(item.id)
		return if tier then `PASSE DA TEMPORADA · NÍVEL {tier} ({track}).` else "PASSE DA TEMPORADA."
	elseif source == "story" then
		if item.id == StoryRewards.CompletionItem then
			return `VENÇA OS {#StoryRewards.Chapters} CAPÍTULOS DO MODO HISTÓRIA.`
		end
		local chapter = storyChapter(item.id)
		return if chapter then `VENÇA O CAPÍTULO {chapter} DO MODO HISTÓRIA.` else "MODO HISTÓRIA."
	elseif source == "storypass" then
		return "VEM NO PASSE DA HISTÓRIA (ARQUIVO DO ELIAS)."
	end
	return ""
end

-- Opções de compra direta (só itens da loja), em ordem Fichas → Créditos.
function StoreView.prices(item: Item, fichas: number, creditos: number): { PriceOption }
	local options: { PriceOption } = {}
	if item.source ~= "store" then
		return options
	end
	if item.fichas then
		table.insert(options, {
			currency = "fichas",
			price = item.fichas,
			affordable = fichas >= item.fichas,
			missing = math.max(0, item.fichas - fichas),
		})
	end
	if item.creditos then
		table.insert(options, {
			currency = "creditos",
			price = item.creditos,
			affordable = creditos >= item.creditos,
			missing = math.max(0, item.creditos - creditos),
		})
	end
	return options
end

-- Aplica um filtro (brilho, contraste, saturação e tinta, como o ColorCorrection) numa cor 0..255.
-- Usado na prévia dos filtros: a cena é desenhada já com as cores corrigidas.
function StoreView.grade(color: StoreCatalog.RGB, filter: Item): StoreCatalog.RGB
	local brightness = filter.brightness or 0
	local contrast = filter.contrast or 0
	local saturation = filter.saturation or 0
	local tint = filter.tint or { 255, 255, 255 }
	local channels = {}
	for index = 1, 3 do
		local value = color[index] / 255 + brightness
		channels[index] = (value - 0.5) * (1 + contrast) + 0.5
	end
	local luminance = channels[1] * 0.299 + channels[2] * 0.587 + channels[3] * 0.114
	local out = {}
	for index = 1, 3 do
		local value = luminance + (channels[index] - luminance) * (1 + saturation)
		value *= tint[index] / 255
		out[index] = math.floor(math.clamp(value, 0, 1) * 255 + 0.5)
	end
	return out
end

-- Itens de um tipo em ordem de raridade e nome (mesma ordem da loja antiga).
function StoreView.itemsOfKind(kind: StoreCatalog.ItemKind): { Item }
	local list = {}
	for _, entry in StoreCatalog.Items do
		if entry.kind == kind then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = StoreCatalog.Rarities[a.rarity].order, StoreCatalog.Rarities[b.rarity].order
		return if ra == rb then a.name < b.name else ra < rb
	end)
	return list
end

return StoreView
