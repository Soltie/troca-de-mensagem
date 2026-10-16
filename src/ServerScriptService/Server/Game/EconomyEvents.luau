--!strict
--[[
	Regras puras do analytics de economia (testadas no Lune): transformam o que as regras de
	Shared/Game/Economy concederam ou cobraram em eventos de fonte/sumidouro, no formato de
	AnalyticsService:LogEconomyEvent. Quem envia é o TelemetryService (só em servidor publicado).

	- Valores sempre positivos (o painel mostra sumidouros como negativos).
	- `balance` = saldo DEPOIS do evento; vários eventos da mesma concessão terminam, em ordem,
	  no saldo atual da carteira.
	- Uma concessão é quebrada em: parte base (o contexto: partida, diário, compra...), níveis
	  da conta ("level_up") e itens repetidos convertidos em Fichas ("duplicate_refund").
	- SKUs e tipos de transação têm poucos valores fixos: o painel agrupa melhor e não estoura
	  os limites de cardinalidade.
]]

local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")

export type Flow = "Source" | "Sink"

export type Event = {
	flow: Flow,
	currency: StoreCatalog.Currency,
	amount: number,
	balance: number,
	transaction: string,
	sku: string,
}

type Part = { transaction: string, sku: string, fichas: number, creditos: number }
type Entry = { flow: Flow, currency: StoreCatalog.Currency, amount: number, transaction: string, sku: string }

local EconomyEvents = {}

-- Nome da moeda no painel (no máximo 5 moedas por experiência).
EconomyEvents.CurrencyNames = table.freeze({ fichas = "Fichas", creditos = "Creditos" })

-- Tipos de transação: os nomes de Enum.AnalyticsEconomyTransactionType, mais um próprio.
EconomyEvents.Transaction = table.freeze({
	IAP = "IAP",
	Shop = "Shop",
	Gameplay = "Gameplay",
	TimedReward = "TimedReward",
	ContextualPurchase = "ContextualPurchase",
	Season = "SeasonPass",
})

EconomyEvents.LEVEL_SKU = "level_up"
EconomyEvents.REFUND_SKU = "duplicate_refund"

-- Fichas e Créditos que os níveis da conta deram dentro de `granted` (curva + marcos).
local function levelPart(granted: Economy.Granted): (number, number)
	local fichas, creditos = 0, 0
	for _, level in granted.levels do
		fichas += StoreCatalog.LevelFichasBase + StoreCatalog.LevelFichasStep * level
		local milestone = StoreCatalog.LevelMilestones[level]
		if milestone then
			fichas += milestone.fichas or 0
			creditos += milestone.creditos or 0
		end
	end
	return fichas, creditos
end

local function refundPart(granted: Economy.Granted): number
	local total = 0
	for _, fichas in granted.refunds do
		total += fichas
	end
	return total
end

-- Eventos em ordem; o saldo de cada moeda termina em `wallet` no último evento dela.
local function withBalances(entries: { Entry }, wallet: { fichas: number, creditos: number }): { Event }
	local running: { [string]: number } = {}
	for _, currency in StoreCatalog.CURRENCIES do
		local delta = 0
		for _, entry in entries do
			if entry.currency == currency then
				delta += if entry.flow == "Source" then entry.amount else -entry.amount
			end
		end
		running[currency] = (wallet :: any)[currency] - delta
	end
	local events: { Event } = {}
	for _, entry in entries do
		local balance = running[entry.currency] + (if entry.flow == "Source" then entry.amount else -entry.amount)
		running[entry.currency] = balance
		table.insert(events, {
			flow = entry.flow,
			currency = entry.currency,
			amount = entry.amount,
			balance = math.max(0, balance),
			transaction = entry.transaction,
			sku = entry.sku,
		})
	end
	return events
end

export type Spend = { currency: StoreCatalog.Currency, amount: number }

-- Uma parte de uma transação: gasto (opcional) e/ou concessão (opcional), com seu tipo e SKU.
export type Change = {
	transaction: string,
	sku: string,
	spend: Spend?,
	granted: Economy.Granted?,
}

local function addChange(entries: { Entry }, change: Change)
	local spend = change.spend
	if spend and spend.amount > 0 then
		table.insert(entries, {
			flow = "Sink",
			currency = spend.currency,
			amount = spend.amount,
			transaction = change.transaction,
			sku = change.sku,
		})
	end
	local granted = change.granted
	if not granted then
		return
	end
	local levelFichas, levelCreditos = levelPart(granted)
	local refunds = refundPart(granted)
	local parts: { Part } = {
		{
			transaction = change.transaction,
			sku = change.sku,
			fichas = math.max(0, granted.fichas - levelFichas - refunds),
			creditos = math.max(0, granted.creditos - levelCreditos),
		},
		{
			transaction = EconomyEvents.Transaction.Gameplay,
			sku = EconomyEvents.LEVEL_SKU,
			fichas = levelFichas,
			creditos = levelCreditos,
		},
		{ transaction = change.transaction, sku = EconomyEvents.REFUND_SKU, fichas = refunds, creditos = 0 },
	}
	for _, part in parts do
		for _, currency in StoreCatalog.CURRENCIES do
			local amount = (part :: any)[currency] :: number
			if amount > 0 then
				table.insert(entries, {
					flow = "Source",
					currency = currency :: StoreCatalog.Currency,
					amount = amount,
					transaction = part.transaction,
					sku = part.sku,
				})
			end
		end
	end
end

--[[
	Eventos de UMA transação, na ordem das partes (em cada parte: gasto antes das fontes).
	`wallet` = carteira DEPOIS de tudo. Ex.: partida + trilhas da temporada no mesmo fim de rodada,
	ou o preço do baú + o reembolso do item repetido.
]]
function EconomyEvents.build(wallet: { fichas: number, creditos: number }, changes: { Change }): { Event }
	local entries: { Entry } = {}
	for _, change in changes do
		addChange(entries, change)
	end
	return withBalances(entries, wallet)
end

-- Atalhos: só fontes / só gasto.
function EconomyEvents.sources(
	granted: Economy.Granted,
	wallet: { fichas: number, creditos: number },
	transaction: string,
	sku: string
): { Event }
	return EconomyEvents.build(wallet, { { transaction = transaction, sku = sku, granted = granted } })
end

function EconomyEvents.sink(
	currency: StoreCatalog.Currency,
	amount: number,
	wallet: { fichas: number, creditos: number },
	transaction: string,
	sku: string
): { Event }
	return EconomyEvents.build(
		wallet,
		{ { transaction = transaction, sku = sku, spend = { currency = currency, amount = amount } } }
	)
end

return EconomyEvents
