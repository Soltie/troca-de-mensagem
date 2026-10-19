--!strict
--[[
	StoreService: loja, progressão, passe de temporada e compras com Robux (autoritativo).

	- Remote "Store" (ação, argumento?): diário, roleta, baús, compra com Fichas/Créditos,
	  equipar e pedir compra em Robux. Tudo validado aqui com as regras puras de Shared/Game/Economy.
	- Robux:
	  * Developer Products -> MarketplaceService.ProcessReceipt, idempotente pelo PurchaseId
	    (o recibo e o que ele concede ficam no MESMO registro do jogador, salvo antes de confirmar).
	  * Game Passes (VIP e o passe de cada temporada) -> UserOwnsGamePassAsync na entrada +
	    PromptGamePassPurchaseFinished.
	  * ID = 0 (ainda não criado no Creator Hub): no Studio a compra é SIMULADA (testes);
	    no servidor ao vivo o item responde "store_unavailable".
	- Passe de temporada (Shared/Game/Season): XP de temporada nas partidas, fitas e diário;
	  as recompensas das trilhas saem sozinhas ao subir de nível. Comprar a trilha paga entrega
	  na hora as recompensas pagas dos níveis já alcançados.
	- PolicyService: quem tem ArePaidRandomItemsRestricted não abre o baú pago (Créditos);
	  continua podendo comprar cada item diretamente (alternativa exigida pela política).
	- Analytics (TelemetryService): cada mudança de Fichas/Créditos vira evento de economia
	  (Server/Game/EconomyEvents) e cada compra fecha o funil da loja.
	- Publica o estado no próprio Player (atributos) para a UI: Fichas, Creditos, Xp, Level, Vip,
	  Owned (JSON), Tapes (JSON), Equip*, DailyStreak/DailyClaimable, SpinsLeft, StarterBought,
	  PaidRandomRestricted, SeasonId, SeasonXp, SeasonPremium, StoreReady.
	- Notificações de recompensa: remote "StoreNotice" (servidor -> cliente).
	- Vantagens pagas (Shared/Game/Perks): melhorias de 5 níveis (Fichas ou Créditos), consumíveis
	  (Segunda Chance, Pilha Extra, Continuação), kit de uso automático e bônus de tempo. Publica
	  Perks/Consumables/Loadout (JSON), Perk<Id> (nível, lido pelo jogo) e Boost*Until (os.time).
	- Modo história (Shared/Game/StoryRewards): awardStory no fim de cada capítulo; passe Arquivo do
	  Elias dobra as moedas e entrega 3 itens. Publica StoryProgress (JSON) e StoryPass.
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoryRewards = require("@game/ReplicatedStorage/Shared/Game/StoryRewards")
local TaskRewards = require("@game/ReplicatedStorage/Shared/Game/TaskRewards")
local Difficulty = require("@game/ReplicatedStorage/Shared/Game/Difficulty")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Season = require("@game/ReplicatedStorage/Shared/Game/Season")
local SeasonCatalog = require("@game/ReplicatedStorage/Shared/Game/SeasonCatalog")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local EconomyEvents = require("../Game/EconomyEvents")
local ServerNet = require("../Net/ServerNet")
local PlayerDataService = require("./PlayerDataService")
local TelemetryService = require("./TelemetryService")
local DifficultyService = require("./DifficultyService")

export type StoreResponse = {
	ok: boolean,
	message: string,
	-- Resultado para a UI animar (item do baú, segmento da roleta, recompensa).
	item: string?,
	rarity: string?,
	duplicate: boolean?,
	refund: number?,
	segment: string?,
	granted: Economy.Granted?,
}

local log = Logger.new("StoreService")
local TX = EconomyEvents.Transaction
-- Fuso do "dia" do calendário e da roleta (Brasil, UTC-3): vira à meia-noite local.
local DAY_OFFSET = -3 * 3600

-- Game Passes que cada jogador tem nesta sessão (chave do produto -> true).
local passCache: { [Player]: { [string]: boolean } } = {}
local restrictedCache: { [Player]: boolean } = {}
local changedCallbacks: { (Player) -> () } = {}
local rng = Random.new()
-- Quem executa a Continuação (CampaignRuntime): valida a derrota e repete a etapa.
local continueHandler: ((Player) -> (boolean, string?))? = nil
-- Atributo de jogo de cada melhoria (lido por PlayerStateService, CreatureService, CampaignRuntime e cliente).
local PERK_ATTRIBUTES: { [string]: string } =
	{ bateria = "PerkBateria", folego = "PerkFolego", socorro = "PerkSocorro", silencio = "PerkSilencio" }

local function random(): number
	return rng:NextNumber()
end

local function today(): number
	return Economy.dayIndex(os.time() + DAY_OFFSET)
end

local function ownsPass(player: Player, key: string): boolean
	local passes = passCache[player]
	return passes ~= nil and passes[key] == true
end

local function setPass(player: Player, key: string)
	local passes = passCache[player] or {}
	passes[key] = true
	passCache[player] = passes
end

local function isVip(player: Player): boolean
	return ownsPass(player, "vip")
end

local function activeSeason(): SeasonCatalog.SeasonDef?
	return Season.current(os.time())
end

local function hasSeasonPass(player: Player, season: SeasonCatalog.SeasonDef): boolean
	return ownsPass(player, season.passKey)
end

-- Temporada à qual pertence o Game Pass `key` (nil = não é passe de temporada).
local function seasonOfPass(key: string): SeasonCatalog.SeasonDef?
	for _, season in SeasonCatalog.Seasons do
		if season.passKey == key then
			return season
		end
	end
	return nil
end

local function productById(id: number, kind: "product" | "pass"): StoreCatalog.Product?
	if id == 0 then
		return nil
	end
	for _, product in StoreCatalog.Products do
		if product.id == id and product.kind == kind then
			return product
		end
	end
	return nil
end

local function publish(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local vip = isVip(player)
	local level = Economy.levelInfo(data.xp)
	local owned = {}
	for id in data.owned do
		table.insert(owned, id)
	end
	table.sort(owned)
	local tapes = {}
	for id in data.tapes do
		table.insert(tapes, id)
	end
	table.sort(tapes)
	local day = today()
	local claimable, streakDay = Economy.dailyState(data, day)
	local season = activeSeason()
	player:SetAttribute("Fichas", data.wallet.fichas)
	player:SetAttribute("Creditos", data.wallet.creditos)
	player:SetAttribute("Xp", data.xp)
	player:SetAttribute("Level", level)
	player:SetAttribute("Vip", vip)
	player:SetAttribute("PaidRandomRestricted", restrictedCache[player] ~= false)
	player:SetAttribute("Owned", HttpService:JSONEncode(owned))
	player:SetAttribute("Tapes", HttpService:JSONEncode(tapes))
	player:SetAttribute("DailyStreak", streakDay)
	player:SetAttribute("DailyClaimable", claimable)
	player:SetAttribute("SpinsLeft", Economy.spinsLeft(data, day, vip))
	player:SetAttribute("StarterBought", data.oncePurchases.pacote_inicial ~= nil)
	player:SetAttribute("KitBought", data.oncePurchases.kit_sobrevivente ~= nil)
	player:SetAttribute("EquipFlashlight", Economy.equipped(data, "flashlight", vip))
	player:SetAttribute("EquipUniform", Economy.equipped(data, "uniform", vip))
	player:SetAttribute("EquipFilter", Economy.equipped(data, "filter", vip))
	player:SetAttribute("Title", Economy.equipped(data, "title", vip))
	player:SetAttribute("SeasonId", if season then season.id else "")
	player:SetAttribute("SeasonXp", if season then Season.xpOf(data, season) else 0)
	player:SetAttribute("SeasonPremium", season ~= nil and hasSeasonPass(player, season))
	-- Vantagens e história.
	local levels: { [string]: number } = {}
	for _, perk in Perks.List do
		local perkLevel = Perks.level(data, perk.id)
		levels[perk.id] = perkLevel
		player:SetAttribute(PERK_ATTRIBUTES[perk.id], perkLevel)
	end
	local stock: { [string]: number } = {}
	local kit: { string } = {}
	for _, consumable in Perks.Consumables do
		stock[consumable.id] = Perks.count(data, consumable.id)
		if data.loadout[consumable.id] then
			table.insert(kit, consumable.id)
		end
	end
	player:SetAttribute("Perks", HttpService:JSONEncode(levels))
	player:SetAttribute("Consumables", HttpService:JSONEncode(stock))
	player:SetAttribute("Loadout", HttpService:JSONEncode(kit))
	player:SetAttribute("BoostFichasUntil", data.boosts.fichasUntil)
	player:SetAttribute("BoostXpUntil", data.boosts.xpUntil)
	local cleared: { number } = {}
	local flawless: { number } = {}
	for key in data.house.cleared do
		table.insert(cleared, tonumber(key) or 0)
	end
	for key in data.house.flawless do
		table.insert(flawless, tonumber(key) or 0)
	end
	player:SetAttribute("HousePreferences", HttpService:JSONEncode(data.house.preferences))
	player:SetAttribute("StoryProgress", HttpService:JSONEncode({ cleared = cleared, flawless = flawless }))
	player:SetAttribute("StoryPass", ownsPass(player, StoreCatalog.StoryPassKey))
	player:SetAttribute("StoreReady", true)
	for _, callback in changedCallbacks do
		task.spawn(callback, player)
	end
end

local function notify(player: Player, kind: string, granted: Economy.Granted?, extra: { [string]: any }?)
	local payload: { [string]: any } = { kind = kind }
	if granted then
		payload.fichas = granted.fichas
		payload.creditos = granted.creditos
		payload.xp = granted.xp
		payload.items = granted.items
		payload.levels = granted.levels
		payload.consumables = granted.consumables
	end
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	local ok, remote = pcall(Remotes.serverEvent, "StoreNotice")
	if ok then
		remote:FireClient(player, payload)
	end
end

-- Partes de analytics das trilhas da temporada (moedas que cada trilha entregou).
local function seasonChanges(result: Season.SeasonGranted?): { EconomyEvents.Change }
	if not result then
		return {}
	end
	return {
		{ transaction = TX.Season, sku = "season_free", granted = result.free },
		{ transaction = TX.Season, sku = "season_premium", granted = result.premium },
	}
end

-- Soma XP de temporada dentro de uma mutação (nil sem temporada ativa).
local function addSeasonXp(player: Player, data: Types.PlayerData, amount: number): Season.SeasonGranted?
	local season = activeSeason()
	if not season then
		return nil
	end
	return Season.addXp(data, season, amount, hasSeasonPass(player, season))
end

-- Aviso da temporada (nível novo ou recompensas das trilhas). Junta as duas trilhas no aviso.
local function notifySeason(player: Player, result: Season.SeasonGranted?, extra: { [string]: any }?)
	if not result or (#result.tiers == 0 and not Season.hasRewards(result)) then
		return
	end
	local items = table.clone(result.free.items)
	for _, id in result.premium.items do
		table.insert(items, id)
	end
	local payload: { [string]: any } = { tiers = result.tiers, items = items }
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	notify(player, "season", {
		fichas = result.free.fichas + result.premium.fichas,
		creditos = result.free.creditos + result.premium.creditos,
		xp = 0,
		items = items,
		refunds = {},
		levels = {},
	}, payload)
end

-- Entrega uma compra em Robux (recibo real ou simulado no Studio) e salva antes de confirmar.
local function deliver(player: Player, product: StoreCatalog.Product, purchaseId: string): boolean
	local result: Economy.Granted? = nil
	local repeated = false
	local events: { EconomyEvents.Event } = {}
	local updated = PlayerDataService.update(player, function(data: Types.PlayerData)
		local ok, message, granted = Economy.grantProduct(data, product, purchaseId, os.time())
		repeated = not ok and message == "already_granted"
		result = granted
		if granted then
			events = EconomyEvents.sources(granted, data.wallet, TX.IAP, product.key)
		end
	end)
	if not updated then
		return false
	end
	if repeated then
		return true -- recibo já entregue antes (Roblox reenviou): nada a conceder de novo
	end
	if not PlayerDataService.save(player) then
		-- O recibo e a concessão ficam juntos na memória: o próximo save grava os dois,
		-- e a reentrega deste recibo será reconhecida como já concedida.
		log.warn("purchase %s for %s granted but not saved yet", purchaseId, player.Name)
		return false
	end
	log.info("delivered %s to %s (%s)", product.key, player.Name, purchaseId)
	TelemetryService.economy(player, events)
	TelemetryService.purchased(player, "product", "robux")
	publish(player)
	notify(player, "purchase", result, { product = product.key })
	return true
end

-- Game Pass confirmado (compra real ou simulada): vale na hora; passe de temporada entrega
-- as recompensas pagas dos níveis já alcançados.
-- Passe da história: entrega os itens que faltarem (idempotente; vale também na entrada).
local function grantStoryPassItems(player: Player)
	PlayerDataService.update(player, function(data)
		for _, id in StoreCatalog.StoryPassItems do
			if not data.owned[id] then
				Economy.applyReward(data, { item = id })
			end
		end
	end)
end

local function grantPass(player: Player, product: StoreCatalog.Product)
	setPass(player, product.key)
	local season = activeSeason()
	local result: Season.SeasonGranted? = nil
	local events: { EconomyEvents.Event } = {}
	if season and season.passKey == product.key then
		PlayerDataService.update(player, function(data)
			result = Season.grantReached(data, season, true)
			events = EconomyEvents.build(data.wallet, seasonChanges(result))
		end)
	end
	if product.key == StoreCatalog.StoryPassKey then
		grantStoryPassItems(player)
	end
	log.info("pass %s active for %s", product.key, player.Name)
	TelemetryService.economy(player, events)
	TelemetryService.purchased(player, "pass", "robux")
	publish(player)
	notify(player, "purchase", nil, { product = product.key })
	notifySeason(player, result, { premium = true })
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById(receipt.ProductId, "product")
	if not product then
		log.error("receipt for unknown product %s", tostring(receipt.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not PlayerDataService.waitFor(player, 15) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if deliver(player, product, tostring(receipt.PurchaseId)) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function refreshPasses(player: Player)
	for _, product in StoreCatalog.Products do
		if product.kind == "pass" and product.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.id)
			end)
			if ok and owns == true then
				setPass(player, product.key)
			end
		end
	end
end

local function refreshPolicy(player: Player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	if ok and type(info) == "table" then
		restrictedCache[player] = info.ArePaidRandomItemsRestricted == true
	else
		-- Sem resposta da política: por segurança, trata como restrito só para o baú pago.
		restrictedCache[player] = true
		log.warn("policy lookup failed for %s; paid random items disabled", player.Name)
	end
end

-- Entrada: põe os dados na temporada atual e entrega o que faltar (ex.: comprou a trilha paga
-- noutro servidor). Idempotente.
local function syncSeason(player: Player)
	local season = activeSeason()
	if not season then
		return
	end
	local result: Season.SeasonGranted? = nil
	local events: { EconomyEvents.Event } = {}
	PlayerDataService.update(player, function(data)
		result = Season.grantReached(data, season, hasSeasonPass(player, season))
		events = EconomyEvents.build(data.wallet, seasonChanges(result))
	end)
	TelemetryService.economy(player, events)
	notifySeason(player, result)
end

local function onPlayer(player: Player)
	refreshPolicy(player)
	refreshPasses(player)
	if PlayerDataService.waitFor(player, 30) then
		syncSeason(player)
		if ownsPass(player, StoreCatalog.StoryPassKey) then
			grantStoryPassItems(player)
		end
		publish(player)
	end
end

local function mutate(player: Player, mutator: (data: Types.PlayerData) -> StoreResponse): StoreResponse
	local response: StoreResponse = { ok = false, message = "store_loading" }
	local loaded = PlayerDataService.update(player, function(data)
		response = mutator(data)
	end)
	if not loaded then
		return { ok = false, message = "store_loading" }
	end
	if response.ok then
		publish(player)
	end
	return response
end

local function requestProduct(player: Player, key: string): StoreResponse
	local product = StoreCatalog.ProductByKey[key]
	if not product then
		return { ok = false, message = "store_unknown" }
	end
	local data = PlayerDataService.get(player)
	if not data then
		return { ok = false, message = "store_loading" }
	end
	if product.kind == "pass" and ownsPass(player, product.key) then
		return { ok = false, message = "store_owned" }
	end
	if product.once and data.oncePurchases[product.key] then
		return { ok = false, message = "store_owned" }
	end
	local passSeason = seasonOfPass(product.key)
	if passSeason and activeSeason() ~= passSeason then
		return { ok = false, message = "season_closed" }
	end
	if product.id == 0 then
		if not RunService:IsStudio() then
			return { ok = false, message = "store_unavailable" }
		end
		-- Studio: compra simulada (sem Robux), pelo mesmo caminho de entrega do recibo real.
		if product.kind == "pass" then
			grantPass(player, product)
			return { ok = true, message = "store_mock" }
		end
		local delivered = deliver(player, product, `studio-{HttpService:GenerateGUID(false)}`)
		return { ok = delivered, message = if delivered then "store_mock" else "store_error" }
	end
	if product.kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, product.id)
	else
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
	return { ok = true, message = "store_prompted" }
end

local function handle(player: Player, action: string, arg: string?): StoreResponse
	local vip = isVip(player)
	local day = today()
	local events: { EconomyEvents.Event } = {}
	local purchase: { kind: string, currency: StoreCatalog.Currency }? = nil
	local seasonResult: Season.SeasonGranted? = nil
	local response: StoreResponse
	if action == "claim_daily" then
		response = mutate(player, function(data)
			local ok, err, streakDay, granted = Economy.claimDaily(data, day)
			if not ok or not granted then
				return { ok = false, message = err or "daily_claimed" }
			end
			seasonResult = addSeasonXp(player, data, SeasonCatalog.XpSources.daily)
			local changes: { EconomyEvents.Change } =
				{ { transaction = TX.TimedReward, sku = `daily_d{streakDay or 1}`, granted = granted } }
			for _, change in seasonChanges(seasonResult) do
				table.insert(changes, change)
			end
			events = EconomyEvents.build(data.wallet, changes)
			notify(player, "daily", granted, {
				day = streakDay,
				seasonXp = if seasonResult then seasonResult.xp else 0,
			})
			return { ok = true, message = "daily_ok", granted = granted }
		end)
	elseif action == "spin" then
		response = mutate(player, function(data)
			local ok, err, segment, granted = Economy.spin(data, day, vip, random)
			if not ok or not segment or not granted then
				return { ok = false, message = err or "spin_used" }
			end
			events = EconomyEvents.sources(granted, data.wallet, TX.TimedReward, `spin_{segment.id}`)
			return { ok = true, message = "spin_ok", segment = segment.id, granted = granted }
		end)
	elseif action == "open_chest" and arg then
		local restricted = restrictedCache[player] ~= false
		response = mutate(player, function(data)
			local ok, err, result = Economy.openChest(data, arg, random, restricted)
			if not ok or not result then
				return { ok = false, message = err or "store_error" }
			end
			local chest = StoreCatalog.ChestById[arg]
			events = EconomyEvents.build(data.wallet, {
				{
					transaction = TX.Shop,
					sku = chest.id,
					spend = { currency = chest.currency, amount = chest.price },
					granted = {
						fichas = result.refund,
						creditos = 0,
						xp = 0,
						items = {},
						refunds = if result.refund > 0 then { [result.item] = result.refund } else {},
						levels = {},
					},
				},
			})
			purchase = { kind = "chest", currency = chest.currency }
			log.info("%s opened %s -> %s (%s)", player.Name, arg, result.item, result.rarity)
			return {
				ok = true,
				message = "chest_ok",
				item = result.item,
				rarity = result.rarity,
				duplicate = result.duplicate,
				refund = result.refund,
			}
		end)
	elseif (action == "buy_fichas" or action == "buy_creditos") and arg then
		local currency: StoreCatalog.Currency = if action == "buy_fichas" then "fichas" else "creditos"
		response = mutate(player, function(data)
			local ok, err = Economy.buyItem(data, arg, currency, vip)
			if not ok then
				return { ok = false, message = err or "store_error" }
			end
			local price = Economy.price(StoreCatalog.ItemById[arg], currency) or 0
			events = EconomyEvents.sink(currency, price, data.wallet, TX.Shop, arg)
			purchase = { kind = "item", currency = currency }
			return { ok = true, message = "store_bought", item = arg }
		end)
	elseif action == "equip" and arg then
		response = mutate(player, function(data)
			local ok, err = Economy.equip(data, arg, vip)
			return { ok = ok, message = if ok then "store_equipped" else err or "store_error", item = arg }
		end)
	elseif (action == "upgrade_fichas" or action == "upgrade_creditos") and arg then
		local currency: Perks.Currency = if action == "upgrade_fichas" then "fichas" else "creditos"
		response = mutate(player, function(data)
			local price = Perks.nextCost(arg, Perks.level(data, arg), currency)
			local ok, err, level = Perks.upgrade(data, arg, currency)
			if not ok or not price then
				return { ok = false, message = err or "store_error" }
			end
			events = EconomyEvents.sink(currency, price, data.wallet, TX.Shop, `perk_{arg}_{level}`)
			purchase = { kind = "perk", currency = currency }
			log.info("%s upgraded %s to %d (%s)", player.Name, arg, level or 0, currency)
			return { ok = true, message = "perk_upgraded", item = arg }
		end)
	elseif (action == "consumable_fichas" or action == "consumable_creditos") and arg then
		local currency: Perks.Currency = if action == "consumable_fichas" then "fichas" else "creditos"
		response = mutate(player, function(data)
			local ok, err = Perks.buyConsumable(data, arg, currency)
			if not ok then
				return { ok = false, message = err or "store_error" }
			end
			local def = Perks.ConsumableById[arg]
			local price = (if currency == "fichas" then def.fichas else def.creditos) or 0
			events = EconomyEvents.sink(currency, price, data.wallet, TX.Shop, `consumable_{arg}`)
			purchase = { kind = "consumable", currency = currency }
			return { ok = true, message = "consumable_bought", item = arg }
		end)
	elseif (action == "loadout_on" or action == "loadout_off") and arg then
		response = mutate(player, function(data)
			local ok, err = Perks.setLoadout(data, arg, action == "loadout_on")
			return { ok = ok, message = if ok then "loadout_saved" else err or "store_error", item = arg }
		end)
	elseif action == "use_continue" then
		local data = PlayerDataService.get(player)
		if not data then
			return { ok = false, message = "store_loading" }
		end
		if Perks.count(data, "continuar") <= 0 then
			return { ok = false, message = "continue_none" }
		end
		local handler = continueHandler
		if not handler then
			return { ok = false, message = "continue_unavailable" }
		end
		local ok, reason = handler(player)
		if not ok then
			return { ok = false, message = reason or "continue_unavailable" }
		end
		-- A etapa já foi reaberta: gasta a unidade (se o save falhar, o próximo save grava).
		response = mutate(player, function(mutable)
			Perks.consume(mutable, "continuar")
			return { ok = true, message = "continue_used" }
		end)
		log.info("%s used a continue", player.Name)
	elseif action == "buy_product" and arg then
		return requestProduct(player, arg)
	else
		return { ok = false, message = "store_unknown" }
	end
	TelemetryService.economy(player, events)
	if purchase and response.ok then
		TelemetryService.purchased(player, purchase.kind, purchase.currency)
	end
	notifySeason(player, seasonResult)
	return response
end

local StoreService = {
	Name = "StoreService",
}

function StoreService.Start()
	ServerNet.onInvoke("Store", {
		args = {
			Guard.literal(
				"claim_daily",
				"spin",
				"open_chest",
				"buy_fichas",
				"buy_creditos",
				"equip",
				"buy_product",
				"upgrade_fichas",
				"upgrade_creditos",
				"consumable_fichas",
				"consumable_creditos",
				"loadout_on",
				"loadout_off",
				"use_continue"
			),
			Guard.optional(Guard.string({ maxLength = 32, pattern = "[%w_]+" })),
		},
		rateLimit = { capacity = 8, refillPerSecond = 3 },
	}, handle)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			local product = productById(passId, "pass")
			if purchased and product and not ownsPass(player, product.key) then
				grantPass(player, product)
			end
		end
	)

	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		passCache[player] = nil
		restrictedCache[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
end

function StoreService.isVip(player: Player): boolean
	return isVip(player)
end

-- Item equipado (com fallback ao padrão).
function StoreService.equipped(player: Player, kind: StoreCatalog.ItemKind): string
	local data = PlayerDataService.get(player)
	if not data then
		return StoreCatalog.defaultFor(kind)
	end
	return Economy.equipped(data, kind, isVip(player))
end

--[[
	Fim de partida: aplica recompensa e XP de temporada e avisa o cliente (tela de resultado).
	`sku` = contexto para o analytics (RewardService: modo e resultado, ex. "campaign_won").
]]
-- Conclusão de estação: pagamento imediato, sem contar outra partida nem alterar o formato salvo.
function StoreService.awardTask(player: Player, contributed: boolean): Economy.Granted?
	local granted: Economy.Granted? = nil
	local events: { EconomyEvents.Event } = {}
	if
		not PlayerDataService.update(player, function(data)
			local reward = TaskRewards.reward(contributed)
			-- Modificadores da partida pagam mais (Difficulty.boost).
			local fichas = Difficulty.boost(reward.fichas, DifficultyService.modifiers())
			granted = Economy.applyReward(data, { fichas = fichas, xp = reward.xp })
			events = EconomyEvents.build(
				data.wallet,
				{ { transaction = TX.Gameplay, sku = "campaign_task", granted = granted } }
			)
		end)
	then
		return nil
	end
	TelemetryService.economy(player, events)
	publish(player)
	notify(player, "task", granted, { contributed = contributed })
	return granted
end

-- Moeda pega na casa: paga na hora, sem aviso (o HUD anima a carteira). Retorna o que entrou.
function StoreService.awardCoin(player: Player, fichas: number, xp: number): Economy.Granted?
	local granted: Economy.Granted? = nil
	local events: { EconomyEvents.Event } = {}
	if
		not PlayerDataService.update(player, function(data)
			granted =
				Economy.applyReward(data, { fichas = Difficulty.boost(fichas, DifficultyService.modifiers()), xp = xp })
			events = EconomyEvents.build(
				data.wallet,
				{ { transaction = TX.Gameplay, sku = "house_coin", granted = granted } }
			)
		end)
	then
		return nil
	end
	TelemetryService.economy(player, events)
	publish(player)
	return granted
end

function StoreService.awardRun(player: Player, summary: Economy.RunSummary, sku: string?): Economy.Granted?
	local granted: Economy.Granted? = nil
	local seasonResult: Season.SeasonGranted? = nil
	local events: { EconomyEvents.Event } = {}
	local ok = PlayerDataService.update(player, function(data)
		local run = Economy.recordRun(data, summary, isVip(player), os.time())
		granted = run
		seasonResult = addSeasonXp(player, data, Season.runXp(summary))
		local changes: { EconomyEvents.Change } = { { transaction = TX.Gameplay, sku = sku or "run", granted = run } }
		for _, change in seasonChanges(seasonResult) do
			table.insert(changes, change)
		end
		events = EconomyEvents.build(data.wallet, changes)
	end)
	if not ok then
		return nil
	end
	TelemetryService.economy(player, events)
	publish(player)
	notify(player, "run", granted, {
		summary = summary,
		vip = isVip(player),
		seasonXp = if seasonResult then seasonResult.xp else 0,
	})
	notifySeason(player, seasonResult)
	return granted
end

-- Fita colecionável. Retorna true se era nova para o jogador. Toda fita achada pela equipe
-- dá XP de temporada (nova ou repetida); só a nova dá Fichas/XP da conta.
function StoreService.awardTape(player: Player, tapeId: string, finder: string?): boolean
	local isNew = false
	local granted: Economy.Granted? = nil
	local seasonResult: Season.SeasonGranted? = nil
	local events: { EconomyEvents.Event } = {}
	PlayerDataService.update(player, function(data)
		isNew, granted = Economy.addTape(data, tapeId, os.time(), isVip(player))
		seasonResult = addSeasonXp(player, data, SeasonCatalog.XpSources.tape)
		local changes = seasonChanges(seasonResult)
		if granted then
			table.insert(changes, 1, { transaction = TX.Gameplay, sku = "tape", granted = granted })
		end
		events = EconomyEvents.build(data.wallet, changes)
	end)
	TelemetryService.economy(player, events)
	publish(player)
	notify(player, "tape", granted, {
		tape = tapeId,
		new = isNew,
		finder = finder,
		seasonXp = if seasonResult then seasonResult.xp else 0,
	})
	notifySeason(player, seasonResult)
	return isNew
end

-- Fitas que o jogador já tem (para escolher qual fita aparece na partida).
function StoreService.ownedTapes(player: Player): { [string]: boolean }
	local data = PlayerDataService.get(player)
	local result = {}
	if data then
		for id in data.tapes do
			result[id] = true
		end
	end
	return result
end

-- Avisado quando o estado de um jogador muda (cosméticos reaplicam).
function StoreService.onChanged(callback: (Player) -> ())
	table.insert(changedCallbacks, callback)
end

-- ===================== Vantagens e história (jogo) =====================

function StoreService.perkLevel(player: Player, id: string): number
	local data = PlayerDataService.get(player)
	return if data then Perks.level(data, id) else 0
end

-- Consumível de kit pronto para uso automático?
function StoreService.inLoadout(player: Player, id: string): boolean
	local data = PlayerDataService.get(player)
	return data ~= nil and Perks.inLoadout(data, id)
end

-- Gasta uma unidade (uso automático na partida). false se não tinha.
function StoreService.consume(player: Player, id: string): boolean
	local used = false
	PlayerDataService.update(player, function(data)
		used = Perks.consume(data, id)
	end)
	if used then
		publish(player)
	end
	return used
end

-- CampaignRuntime registra quem repete a etapa (a validação da derrota fica com ele).
function StoreService.setContinueHandler(handler: (Player) -> (boolean, string?))
	continueHandler = handler
end

function StoreService.hasStoryPass(player: Player): boolean
	return ownsPass(player, StoreCatalog.StoryPassKey)
end

-- Fim de capítulo do modo história (RewardService). Avisa a tela de resultado.
function StoreService.awardStory(player: Player, chapter: number, flawless: boolean): StoryRewards.Outcome?
	local granted: Economy.Granted? = nil
	local outcome: StoryRewards.Outcome? = nil
	local events: { EconomyEvents.Event } = {}
	local pass = StoreService.hasStoryPass(player)
	PlayerDataService.update(player, function(data)
		granted, outcome = StoryRewards.award(data, chapter, flawless, pass, os.time())
		if granted then
			events = EconomyEvents.sources(granted, data.wallet, TX.Gameplay, `story_{chapter}`)
		end
	end)
	local result = outcome
	if not granted or not result then
		return nil
	end
	TelemetryService.economy(player, events)
	publish(player)
	notify(player, "story", granted, {
		chapter = chapter,
		first = result.first,
		flawless = result.flawless,
		completed = result.completed,
		pass = pass,
		consumables = granted.consumables,
	})
	return result
end

-- Depuração (DebugBridge): dá moedas sem compra (fora do analytics).
function StoreService.debugGrant(player: Player, fichas: number, creditos: number)
	PlayerDataService.update(player, function(data)
		Economy.applyReward(data, { fichas = fichas, creditos = creditos })
	end)
	publish(player)
end

-- Depuração (DebugBridge): XP de temporada sem jogar (as recompensas saem normalmente).
function StoreService.debugSeasonXp(player: Player, amount: number)
	local result: Season.SeasonGranted? = nil
	PlayerDataService.update(player, function(data)
		result = addSeasonXp(player, data, amount)
	end)
	publish(player)
	notifySeason(player, result)
end

return StoreService
