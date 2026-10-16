--!strict
--[[
	StoreService: loja, progressão e compras com Robux (autoritativo).

	- Remote "Store" (ação, argumento?): diário, roleta, baús, compra com Fichas/Créditos,
	  equipar e pedir compra em Robux. Tudo validado aqui com as regras puras de Shared/Game/Economy.
	- Robux:
	  * Developer Products -> MarketplaceService.ProcessReceipt, idempotente pelo PurchaseId
	    (o recibo e o que ele concede ficam no MESMO registro do jogador, salvo antes de confirmar).
	  * Game Pass VIP -> UserOwnsGamePassAsync na entrada + PromptGamePassPurchaseFinished.
	  * ID = 0 (ainda não criado no Creator Hub): no Studio a compra é SIMULADA (testes);
	    no servidor ao vivo o item responde "store_unavailable".
	- PolicyService: quem tem ArePaidRandomItemsRestricted não abre o baú pago (Créditos);
	  continua podendo comprar cada item diretamente (alternativa exigida pela política).
	- Publica o estado no próprio Player (atributos) para a UI: Fichas, Creditos, Xp, Level, Vip,
	  Owned (JSON), Tapes (JSON), Equip*, DailyStreak/DailyClaimable, SpinsLeft, StarterBought,
	  PaidRandomRestricted, StoreReady.
	- Notificações de recompensa: remote "StoreNotice" (servidor -> cliente).
]]

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local RunService = game:GetService("RunService")

local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local ServerNet = require("../Net/ServerNet")
local PlayerDataService = require("./PlayerDataService")

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
-- Fuso do "dia" do calendário e da roleta (Brasil, UTC-3): vira à meia-noite local.
local DAY_OFFSET = -3 * 3600

local vipCache: { [Player]: boolean } = {}
local restrictedCache: { [Player]: boolean } = {}
local changedCallbacks: { (Player) -> () } = {}
local rng = Random.new()

local function random(): number
	return rng:NextNumber()
end

local function today(): number
	return Economy.dayIndex(os.time() + DAY_OFFSET)
end

local function isVip(player: Player): boolean
	return vipCache[player] == true
end

local function productById(id: number): StoreCatalog.Product?
	if id == 0 then
		return nil
	end
	for _, product in StoreCatalog.Products do
		if product.id == id then
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
	player:SetAttribute("EquipFlashlight", Economy.equipped(data, "flashlight", vip))
	player:SetAttribute("EquipUniform", Economy.equipped(data, "uniform", vip))
	player:SetAttribute("EquipFilter", Economy.equipped(data, "filter", vip))
	player:SetAttribute("Title", Economy.equipped(data, "title", vip))
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

-- Entrega uma compra em Robux (recibo real ou simulado no Studio) e salva antes de confirmar.
local function deliver(player: Player, product: StoreCatalog.Product, purchaseId: string): boolean
	local result: Economy.Granted? = nil
	local repeated = false
	local updated = PlayerDataService.update(player, function(data: Types.PlayerData)
		local ok, message, granted = Economy.grantProduct(data, product, purchaseId, os.time())
		repeated = not ok and message == "already_granted"
		result = granted
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
	publish(player)
	notify(player, "purchase", result, { product = product.key })
	return true
end

local function processReceipt(receipt: { [string]: any }): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local product = productById(receipt.ProductId)
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

local function refreshVip(player: Player)
	local pass = StoreCatalog.ProductByKey.vip
	if pass.id ~= 0 then
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ok then
			vipCache[player] = owns == true
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

local function onPlayer(player: Player)
	refreshPolicy(player)
	refreshVip(player)
	if PlayerDataService.waitFor(player, 30) then
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
	if product.kind == "pass" and isVip(player) then
		return { ok = false, message = "store_owned" }
	end
	if product.once and data.oncePurchases[product.key] then
		return { ok = false, message = "store_owned" }
	end
	if product.id == 0 then
		if not RunService:IsStudio() then
			return { ok = false, message = "store_unavailable" }
		end
		-- Studio: compra simulada (sem Robux), pelo mesmo caminho de entrega do recibo real.
		if product.kind == "pass" then
			vipCache[player] = true
			publish(player)
			notify(player, "purchase", nil, { product = product.key })
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
	if action == "claim_daily" then
		return mutate(player, function(data)
			local ok, err, streakDay, granted = Economy.claimDaily(data, day)
			if not ok then
				return { ok = false, message = err or "daily_claimed" }
			end
			notify(player, "daily", granted, { day = streakDay })
			return { ok = true, message = "daily_ok", granted = granted }
		end)
	elseif action == "spin" then
		return mutate(player, function(data)
			local ok, err, segment, granted = Economy.spin(data, day, vip, random)
			if not ok or not segment then
				return { ok = false, message = err or "spin_used" }
			end
			return { ok = true, message = "spin_ok", segment = segment.id, granted = granted }
		end)
	elseif action == "open_chest" and arg then
		local restricted = restrictedCache[player] ~= false
		return mutate(player, function(data)
			local ok, err, result = Economy.openChest(data, arg, random, restricted)
			if not ok or not result then
				return { ok = false, message = err or "store_error" }
			end
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
		return mutate(player, function(data)
			local ok, err = Economy.buyItem(data, arg, currency, vip)
			if not ok then
				return { ok = false, message = err or "store_error" }
			end
			return { ok = true, message = "store_bought", item = arg }
		end)
	elseif action == "equip" and arg then
		return mutate(player, function(data)
			local ok, err = Economy.equip(data, arg, vip)
			return { ok = ok, message = if ok then "store_equipped" else err or "store_error", item = arg }
		end)
	elseif action == "buy_product" and arg then
		return requestProduct(player, arg)
	end
	return { ok = false, message = "store_unknown" }
end

local StoreService = {
	Name = "StoreService",
}

function StoreService.Start()
	ServerNet.onInvoke("Store", {
		args = {
			Guard.literal("claim_daily", "spin", "open_chest", "buy_fichas", "buy_creditos", "equip", "buy_product"),
			Guard.optional(Guard.string({ maxLength = 32, pattern = "[%w_]+" })),
		},
		rateLimit = { capacity = 8, refillPerSecond = 3 },
	}, handle)

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(
		function(player: Player, passId: number, purchased: boolean)
			if purchased and passId == StoreCatalog.ProductByKey.vip.id and passId ~= 0 then
				vipCache[player] = true
				publish(player)
				notify(player, "purchase", nil, { product = "vip" })
			end
		end
	)

	Players.PlayerAdded:Connect(onPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		vipCache[player] = nil
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

-- Fim de partida: aplica recompensa e avisa o cliente (tela de resultado).
function StoreService.awardRun(player: Player, summary: Economy.RunSummary): Economy.Granted?
	local granted: Economy.Granted? = nil
	local ok = PlayerDataService.update(player, function(data)
		granted = Economy.recordRun(data, summary, isVip(player))
	end)
	if not ok then
		return nil
	end
	publish(player)
	notify(player, "run", granted, { summary = summary, vip = isVip(player) })
	return granted
end

-- Fita colecionável. Retorna true se era nova para o jogador.
function StoreService.awardTape(player: Player, tapeId: string, finder: string?): boolean
	local isNew = false
	local granted: Economy.Granted? = nil
	PlayerDataService.update(player, function(data)
		isNew, granted = Economy.addTape(data, tapeId, os.time(), isVip(player))
	end)
	if isNew then
		publish(player)
	end
	notify(player, "tape", granted, { tape = tapeId, new = isNew, finder = finder })
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

-- Depuração (DebugBridge): dá moedas sem compra.
function StoreService.debugGrant(player: Player, fichas: number, creditos: number)
	PlayerDataService.update(player, function(data)
		Economy.applyReward(data, { fichas = fichas, creditos = creditos })
	end)
	publish(player)
end

return StoreService
