--!strict
--[[
	Regras puras da economia e da progressão (testadas no Lune). Operam sobre os dados do
	jogador (Types.PlayerData). Só o SERVIDOR chama as funções que alteram dados; o cliente usa
	as de leitura (nível, chances, estado do diário) para exibir.

	Sorteios recebem `random: () -> number` (0 <= x < 1) injetado: testável e auditável.
]]

local Perks = require("./Perks")
local StoreCatalog = require("./StoreCatalog")
local Types = require("../Types")

type Data = Types.PlayerData
type Reward = StoreCatalog.Reward
type Item = StoreCatalog.Item
type Chest = StoreCatalog.Chest

export type Granted = {
	fichas: number,
	creditos: number,
	xp: number,
	items: { string },
	-- Itens repetidos convertidos em Fichas (id -> fichas).
	refunds: { [string]: number },
	-- Níveis alcançados nesta concessão.
	levels: { number },
	-- Consumíveis que entraram no estoque (id -> unidades).
	consumables: { [string]: number }?,
}

export type OddsLine = {
	rarity: StoreCatalog.Rarity,
	percent: number,
	items: { string },
	perItem: number,
}

export type RunSummary = {
	won: boolean,
	escaped: boolean,
	stages: number,
	fuses: number,
	breakers: boolean,
	contributions: number,
}

local SECONDS_PER_DAY = 86400

local Economy = {}

local function emptyGranted(): Granted
	return { fichas = 0, creditos = 0, xp = 0, items = {}, refunds = {}, levels = {} }
end

-- ===================== Leitura =====================

function Economy.xpToNext(level: number): number
	return StoreCatalog.LevelBase + StoreCatalog.LevelStep * (level - 1)
end

-- Nível atual, XP dentro do nível e XP necessário para o próximo.
function Economy.levelInfo(xp: number): (number, number, number)
	local level = 1
	local remaining = math.max(0, xp)
	while level < StoreCatalog.LevelCap and remaining >= Economy.xpToNext(level) do
		remaining -= Economy.xpToNext(level)
		level += 1
	end
	return level, remaining, Economy.xpToNext(level)
end

function Economy.isOwned(data: Data, itemId: string, vip: boolean?): boolean
	local entry = StoreCatalog.ItemById[itemId]
	if not entry then
		return false
	end
	if entry.source == "default" then
		return true
	end
	if entry.source == "vip" then
		return vip == true
	end
	return data.owned[itemId] == true
end

function Economy.price(entry: Item, currency: StoreCatalog.Currency): number?
	if currency == "fichas" then
		return entry.fichas
	end
	return entry.creditos
end

-- Itens que um baú pode dar, por raridade (só itens de loja: sem padrão/VIP/nível/fitas).
function Economy.chestPool(chest: Chest): { [string]: { string } }
	local pool: { [string]: { string } } = {}
	for _, entry in StoreCatalog.Items do
		if entry.source == "store" and entry.kind ~= "title" and chest.odds[entry.rarity] ~= nil then
			local list = pool[entry.rarity] or {}
			table.insert(list, entry.id)
			pool[entry.rarity] = list
		end
	end
	return pool
end

-- Chances exibidas antes da compra: por raridade e por item (somam 100%).
function Economy.chestOdds(chest: Chest): { OddsLine }
	local pool = Economy.chestPool(chest)
	local lines: { OddsLine } = {}
	for rarity, percent in chest.odds do
		local items = pool[rarity] or {}
		table.sort(items)
		table.insert(lines, {
			rarity = rarity :: StoreCatalog.Rarity,
			percent = percent,
			items = items,
			perItem = if #items > 0 then percent / #items else 0,
		})
	end
	table.sort(lines, function(a, b)
		return StoreCatalog.Rarities[a.rarity].order < StoreCatalog.Rarities[b.rarity].order
	end)
	return lines
end

function Economy.dayIndex(serverTime: number): number
	return math.floor(serverTime / SECONDS_PER_DAY)
end

-- Estado do calendário diário para o dia `day` (pode resgatar? qual dia da sequência?).
function Economy.dailyState(data: Data, day: number): (boolean, number, Reward)
	local daily = data.daily
	local claimable = daily.lastDay ~= day
	local streakDay: number
	if not claimable then
		streakDay = daily.streak
	elseif daily.lastDay == day - 1 then
		streakDay = daily.streak % #StoreCatalog.Daily + 1
	else
		streakDay = 1
	end
	return claimable, math.max(1, streakDay), StoreCatalog.Daily[math.max(1, streakDay)]
end

function Economy.spinsLeft(data: Data, day: number, vip: boolean?): number
	local total = 1 + (if vip then 1 else 0)
	if data.daily.spinDay ~= day then
		return total
	end
	return math.max(0, total - data.daily.spinsUsed)
end

function Economy.multiplier(vip: boolean?): number
	return if vip then StoreCatalog.VipMultiplier else 1
end

-- Recompensa de uma partida (antes de aplicar). VIP multiplica Fichas e XP.
function Economy.runReward(summary: RunSummary, vip: boolean?): Reward
	local R = StoreCatalog.RunRewards
	local fichas = R.participation.fichas + R.perStage.fichas * summary.stages + R.perFuse.fichas * summary.fuses
	local xp = R.participation.xp + R.perStage.xp * summary.stages + R.perFuse.xp * summary.fuses
	if summary.breakers then
		fichas += R.breakers.fichas
		xp += R.breakers.xp
	end
	if summary.won or summary.escaped then
		fichas += R.escaped.fichas
		xp += R.escaped.xp
	end
	local contributions = math.clamp(summary.contributions, 0, R.contributionCap)
	fichas += R.perContribution.fichas * contributions
	xp += R.perContribution.xp * contributions
	local m = Economy.multiplier(vip)
	return { fichas = math.floor(fichas * m + 0.5), xp = math.floor(xp * m + 0.5) }
end

-- ===================== Escrita (só servidor) =====================

local function grantItem(data: Data, itemId: string, granted: Granted)
	local entry = StoreCatalog.ItemById[itemId]
	if not entry then
		return
	end
	if entry.source ~= "default" and entry.source ~= "vip" and not data.owned[itemId] then
		data.owned[itemId] = true
		table.insert(granted.items, itemId)
		return
	end
	-- Repetido: vira Fichas conforme a raridade.
	local refund = StoreCatalog.Rarities[entry.rarity].refund
	if refund > 0 then
		data.wallet.fichas += refund
		granted.fichas += refund
		granted.refunds[itemId] = refund
	end
end

local function addXp(data: Data, amount: number, granted: Granted)
	if amount <= 0 then
		return
	end
	data.xp += amount
	granted.xp += amount
	local level = Economy.levelInfo(data.xp)
	while data.rewardedLevel < level do
		data.rewardedLevel += 1
		local reached = data.rewardedLevel
		table.insert(granted.levels, reached)
		local fichas = StoreCatalog.LevelFichasBase + StoreCatalog.LevelFichasStep * reached
		data.wallet.fichas += fichas
		granted.fichas += fichas
		local milestone = StoreCatalog.LevelMilestones[reached]
		if milestone then
			if milestone.fichas then
				data.wallet.fichas += milestone.fichas
				granted.fichas += milestone.fichas
			end
			if milestone.creditos then
				data.wallet.creditos += milestone.creditos
				granted.creditos += milestone.creditos
			end
			if milestone.item then
				grantItem(data, milestone.item, granted)
			end
		end
	end
end

-- Aplica uma recompensa (moedas, XP com níveis e marcos, item). Retorna o que foi dado.
function Economy.applyReward(data: Data, reward: Reward, into: Granted?): Granted
	local granted = into or emptyGranted()
	if reward.fichas and reward.fichas > 0 then
		data.wallet.fichas += reward.fichas
		granted.fichas += reward.fichas
	end
	if reward.creditos and reward.creditos > 0 then
		data.wallet.creditos += reward.creditos
		granted.creditos += reward.creditos
	end
	if reward.item then
		grantItem(data, reward.item, granted)
	end
	if reward.xp then
		addXp(data, reward.xp, granted)
	end
	if reward.consumables then
		for id, amount in reward.consumables do
			local added = Perks.add(data, id, amount)
			if added > 0 then
				local list = granted.consumables or {}
				list[id] = (list[id] or 0) + added
				granted.consumables = list
			end
		end
	end
	return granted
end

function Economy.buyItem(data: Data, itemId: string, currency: StoreCatalog.Currency, vip: boolean?): (boolean, string?)
	local entry = StoreCatalog.ItemById[itemId]
	if not entry or entry.source ~= "store" then
		return false, "store_unknown"
	end
	if Economy.isOwned(data, itemId, vip) then
		return false, "store_owned"
	end
	local price = Economy.price(entry, currency)
	if not price then
		return false, "store_no_price"
	end
	if data.wallet[currency] < price then
		return false, "store_poor"
	end
	data.wallet[currency] -= price
	data.owned[itemId] = true
	return true, nil
end

-- Sorteio ponderado: `entries` com campo `weight`; devolve o índice.
function Economy.pickWeighted(weights: { number }, random: () -> number): number
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local roll = random() * total
	for index, weight in weights do
		roll -= weight
		if roll < 0 then
			return index
		end
	end
	return #weights
end

export type ChestResult = { item: string, rarity: StoreCatalog.Rarity, duplicate: boolean, refund: number }

--[[
	Abre um baú: cobra, sorteia a raridade pelas chances publicadas e um item da raridade
	(uniforme). Repetido vira Fichas. `restricted` = PolicyService proíbe itens aleatórios pagos
	para este jogador (só bloqueia baús pagos).
]]
function Economy.openChest(
	data: Data,
	chestId: string,
	random: () -> number,
	restricted: boolean?
): (boolean, string?, ChestResult?)
	local chest = StoreCatalog.ChestById[chestId]
	if not chest then
		return false, "store_unknown", nil
	end
	if chest.paidRandom and restricted then
		return false, "store_restricted", nil
	end
	if data.wallet[chest.currency] < chest.price then
		return false, "store_poor", nil
	end
	local lines = Economy.chestOdds(chest)
	local weights = {}
	for _, line in lines do
		table.insert(weights, if #line.items > 0 then line.percent else 0)
	end
	local line = lines[Economy.pickWeighted(weights, random)]
	local itemId = line.items[math.clamp(math.floor(random() * #line.items) + 1, 1, #line.items)]
	data.wallet[chest.currency] -= chest.price
	data.stats.chests += 1
	local granted = emptyGranted()
	grantItem(data, itemId, granted)
	local refund = granted.refunds[itemId] or 0
	return true, nil, { item = itemId, rarity = line.rarity, duplicate = refund > 0, refund = refund }
end

function Economy.claimDaily(data: Data, day: number): (boolean, string?, number?, Granted?)
	local claimable, streakDay, reward = Economy.dailyState(data, day)
	if not claimable then
		return false, "daily_claimed", nil, nil
	end
	data.daily.lastDay = day
	data.daily.streak = streakDay
	return true, nil, streakDay, Economy.applyReward(data, reward)
end

function Economy.spin(
	data: Data,
	day: number,
	vip: boolean?,
	random: () -> number
): (boolean, string?, StoreCatalog.SpinSegment?, Granted?)
	if Economy.spinsLeft(data, day, vip) <= 0 then
		return false, "spin_used", nil, nil
	end
	if data.daily.spinDay ~= day then
		data.daily.spinDay = day
		data.daily.spinsUsed = 0
	end
	data.daily.spinsUsed += 1
	local weights = {}
	for _, segment in StoreCatalog.Spin do
		table.insert(weights, segment.weight)
	end
	local segment = StoreCatalog.Spin[Economy.pickWeighted(weights, random)]
	return true, nil, segment, Economy.applyReward(data, segment.reward)
end

-- Fim de partida: estatísticas, recompensa e título da primeira fuga.
-- `now` (os.time) liga os bônus de tempo comprados (Fichas/XP ×2; ver Perks).
function Economy.recordRun(data: Data, summary: RunSummary, vip: boolean?, now: number?): Granted
	data.stats.runs += 1
	data.stats.stages += summary.stages
	if summary.won or summary.escaped then
		data.stats.escapes += 1
	else
		data.stats.captures += 1
	end
	local reward = Economy.runReward(summary, vip)
	if now then
		local fichasMult, xpMult = Perks.runMultipliers(data, now)
		reward.fichas = math.floor((reward.fichas or 0) * fichasMult + 0.5)
		reward.xp = math.floor((reward.xp or 0) * xpMult + 0.5)
	end
	local granted = Economy.applyReward(data, reward)
	if (summary.won or summary.escaped) and not data.owned[StoreCatalog.FirstEscapeItem] then
		grantItem(data, StoreCatalog.FirstEscapeItem, granted)
	end
	return granted
end

-- Fita colecionável. Retorna (nova?, concedido). Repetida não dá nada.
function Economy.addTape(data: Data, tapeId: string, now: number, vip: boolean?): (boolean, Granted?)
	if not StoreCatalog.TapeById[tapeId] or data.tapes[tapeId] then
		return false, nil
	end
	data.tapes[tapeId] = now
	local R = StoreCatalog.RunRewards.tape
	local m = Economy.multiplier(vip)
	local granted = Economy.applyReward(data, {
		fichas = math.floor(R.fichas * m + 0.5),
		xp = math.floor(R.xp * m + 0.5),
	})
	local count = 0
	for _ in data.tapes do
		count += 1
	end
	local milestone = StoreCatalog.TapeMilestones[count]
	if milestone then
		Economy.applyReward(data, milestone, granted)
	end
	return true, granted
end

function Economy.tapeCount(data: Data): number
	local count = 0
	for _ in data.tapes do
		count += 1
	end
	return count
end

function Economy.equip(data: Data, itemId: string, vip: boolean?): (boolean, string?)
	local entry = StoreCatalog.ItemById[itemId]
	if not entry then
		return false, "store_unknown"
	end
	if not Economy.isOwned(data, itemId, vip) then
		return false, "store_locked"
	end
	data.equipped[entry.kind] = itemId
	return true, nil
end

-- Item equipado válido (volta ao padrão se o jogador perdeu o acesso, ex.: VIP).
function Economy.equipped(data: Data, kind: StoreCatalog.ItemKind, vip: boolean?): string
	local current = data.equipped[kind]
	if current and Economy.isOwned(data, current, vip) then
		local entry = StoreCatalog.ItemById[current]
		if entry and entry.kind == kind then
			return current
		end
	end
	return StoreCatalog.defaultFor(kind)
end

--[[
	Compra com Robux já confirmada pela Roblox (ProcessReceipt). Idempotente pelo `purchaseId`:
	repetir o mesmo recibo não concede de novo. `once` = no máximo uma por conta.
]]
function Economy.grantProduct(
	data: Data,
	product: StoreCatalog.Product,
	purchaseId: string,
	now: number
): (boolean, string?, Granted?)
	if data.purchases[purchaseId] then
		return false, "already_granted", nil
	end
	data.purchases[purchaseId] = now
	if product.once and data.oncePurchases[product.key] then
		-- Já tinha o pacote: devolve em Créditos (nunca cobra por nada).
		return true, "once_converted", Economy.applyReward(data, { creditos = product.grant.creditos or 0 })
	end
	if product.once then
		data.oncePurchases[product.key] = now
	end
	local granted = Economy.applyReward(data, product.grant)
	local boost = product.grant.boost
	if boost then
		Perks.addBoost(data, "fichas", boost.fichas or 0, now)
		Perks.addBoost(data, "xp", boost.xp or 0, now)
	end
	if product.key == "pacote_inicial" then
		for _, itemId in StoreCatalog.StarterItems do
			grantItem(data, itemId, granted)
		end
	end
	Economy.trimPurchases(data, 200)
	return true, nil, granted
end

-- Mantém só os `max` recibos mais recentes (os antigos já foram concedidos há muito).
function Economy.trimPurchases(data: Data, max: number)
	local ids = {}
	for id, at in data.purchases do
		table.insert(ids, { id = id, at = at })
	end
	if #ids <= max then
		return
	end
	table.sort(ids, function(a, b)
		return a.at > b.at
	end)
	for i = max + 1, #ids do
		data.purchases[ids[i].id] = nil
	end
end

return Economy
