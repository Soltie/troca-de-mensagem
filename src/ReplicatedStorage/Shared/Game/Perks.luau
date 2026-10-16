--!strict
--[[
	Vantagens de jogo pagas (decisão do humano, 16/10/2026: monetização com vantagem).

	Melhorias permanentes (5 níveis cada), compradas com Fichas (jogando) ou Créditos (Robux):
	  bateria   a lanterna dura mais (gasto ÷ 1 + 15%/nível);
	  folego    mais corrida (fôlego e recarga × 1 + 15%/nível);
	  socorro   resgata colegas mais rápido (tempo × 1 - 10%/nível);
	  silencio  passos correndo fazem menos barulho para o Vigia (raio × 1 - 8%/nível).
	Consumíveis (estoque na conta):
	  segunda_chance  levanta sozinho 3 s depois de ser pego (co-op), se estiver no kit;
	  pilha_extra     pilha reserva da etapa: quando a lanterna apagar, entra sozinha (+60%), se no kit;
	  continuar       a equipe repete a etapa perdida em vez de voltar ao menu (botão na derrota).
	Bônus de tempo (produto Robux): Fichas ×2 e/ou XP ×2 nas recompensas de partida.

	Limites de projeto: nenhuma vantagem deixa o jogador invencível ou tira o Vigia do jogo, e o
	jogo continua ganhável sem pagar. Puro: o servidor aplica (StoreService, PerkService,
	PlayerStateService, CampaignRuntime, CreatureService); o cliente lê os atributos para exibir
	(e para o fôlego, que já é local).
]]

local Types = require("../Types")

type Data = Types.PlayerData

export type Currency = "fichas" | "creditos"
export type PerkId = "bateria" | "folego" | "socorro" | "silencio"
export type ConsumableId = "segunda_chance" | "pilha_extra" | "continuar"
export type BoostKind = "fichas" | "xp"

export type Perk = {
	id: PerkId,
	name: string,
	description: string,
	-- Efeito por nível (fração) e sentido: +1 aumenta, -1 reduz.
	step: number,
	sign: number,
	-- Preço de cada nível (índice = nível que será comprado).
	fichas: { number },
	creditos: { number },
}

export type Consumable = {
	id: ConsumableId,
	name: string,
	description: string,
	-- Quantas unidades cada compra entrega e o preço do pacote (nil = só por Robux).
	bundle: number,
	fichas: number?,
	creditos: number?,
	-- Pode ficar "no kit" (uso automático) ou é usado por botão.
	loadout: boolean,
}

local MAX_LEVEL = 5
local MAX_STOCK = 99

local Perks = {}

Perks.MAX_LEVEL = MAX_LEVEL
Perks.MAX_STOCK = MAX_STOCK
-- Segunda Chance: segundos caído antes de levantar sozinho.
Perks.SECOND_CHANCE_DELAY = 3
-- Pilha Extra: carga da pilha reserva (entra quando a lanterna apaga).
Perks.EXTRA_BATTERY = 0.6
Perks.BOOST_MULTIPLIER = 2

local PERK_LIST: { Perk } = {
	{
		id = "bateria",
		name = "BATERIA DE LÍTIO",
		description = "A lanterna dura mais.",
		step = 0.15,
		sign = 1,
		fichas = { 300, 600, 1000, 1600, 2500 },
		creditos = { 60, 120, 200, 320, 500 },
	},
	{
		id = "folego",
		name = "FÔLEGO DE MARATONA",
		description = "Corre por mais tempo e recupera mais rápido.",
		step = 0.15,
		sign = 1,
		fichas = { 300, 600, 1000, 1600, 2500 },
		creditos = { 60, 120, 200, 320, 500 },
	},
	{
		id = "socorro",
		name = "MÃOS DE SOCORRISTA",
		description = "Resgata colegas mais rápido.",
		step = 0.1,
		sign = -1,
		fichas = { 250, 500, 850, 1300, 2000 },
		creditos = { 50, 100, 170, 260, 400 },
	},
	{
		id = "silencio",
		name = "PASSOS LEVES",
		description = "Correr faz menos barulho para o Vigia.",
		step = 0.08,
		sign = -1,
		fichas = { 350, 700, 1150, 1800, 2800 },
		creditos = { 70, 140, 230, 360, 560 },
	},
}

local CONSUMABLE_LIST: { Consumable } = {
	{
		id = "segunda_chance",
		name = "SEGUNDA CHANCE",
		description = "Levanta sozinho 3 s depois de ser pego. Uma por etapa.",
		bundle = 1,
		fichas = 900,
		creditos = 60,
		loadout = true,
	},
	{
		id = "pilha_extra",
		name = "PILHA EXTRA",
		description = "Pilha reserva: quando a lanterna apagar, entra sozinha (+60%). Uma por etapa.",
		bundle = 3,
		fichas = 300,
		creditos = 30,
		loadout = true,
	},
	{
		id = "continuar",
		name = "CONTINUAÇÃO",
		description = "Depois de uma derrota, a equipe repete a etapa em vez de recomeçar.",
		bundle = 1,
		fichas = nil,
		creditos = 120,
		loadout = false,
	},
}

Perks.List = table.freeze(PERK_LIST)
Perks.Consumables = table.freeze(CONSUMABLE_LIST)
Perks.ById = {} :: { [string]: Perk }
Perks.ConsumableById = {} :: { [string]: Consumable }
for _, perk in PERK_LIST do
	Perks.ById[perk.id] = perk
end
for _, consumable in CONSUMABLE_LIST do
	Perks.ConsumableById[consumable.id] = consumable
end

-- ===================== Leitura (cliente e servidor) =====================

function Perks.level(data: Data, id: string): number
	local value = data.perks[id]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_LEVEL)
end

-- Multiplicador do efeito no nível (ex.: bateria 5 -> 1.75; socorro 5 -> 0.5).
function Perks.factor(id: string, level: number): number
	local perk = Perks.ById[id]
	if not perk then
		return 1
	end
	local l = math.clamp(math.floor(level), 0, MAX_LEVEL)
	return 1 + perk.sign * perk.step * l
end

-- Preço do PRÓXIMO nível (nil = no máximo).
function Perks.nextCost(id: string, level: number, currency: Currency): number?
	local perk = Perks.ById[id]
	if not perk or level >= MAX_LEVEL then
		return nil
	end
	local list = if currency == "fichas" then perk.fichas else perk.creditos
	return list[level + 1]
end

function Perks.count(data: Data, id: string): number
	local value = data.consumables[id]
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, MAX_STOCK)
end

function Perks.inLoadout(data: Data, id: string): boolean
	return data.loadout[id] == true and Perks.count(data, id) > 0
end

function Perks.boostActive(data: Data, kind: BoostKind, now: number): boolean
	local untilTime = if kind == "fichas" then data.boosts.fichasUntil else data.boosts.xpUntil
	return type(untilTime) == "number" and untilTime > now
end

-- Multiplicadores de Fichas e XP das recompensas de partida.
function Perks.runMultipliers(data: Data, now: number): (number, number)
	return if Perks.boostActive(data, "fichas", now) then Perks.BOOST_MULTIPLIER else 1,
		if Perks.boostActive(data, "xp", now) then Perks.BOOST_MULTIPLIER else 1
end

-- ===================== Escrita (só servidor) =====================

function Perks.upgrade(data: Data, id: string, currency: Currency): (boolean, string?, number?)
	local perk = Perks.ById[id]
	if not perk then
		return false, "store_unknown", nil
	end
	local level = Perks.level(data, id)
	local price = Perks.nextCost(id, level, currency)
	if not price then
		return false, "perk_max", nil
	end
	if data.wallet[currency] < price then
		return false, "store_poor", nil
	end
	data.wallet[currency] -= price
	data.perks[id] = level + 1
	return true, nil, level + 1
end

-- Soma unidades ao estoque (compras e produtos Robux). Retorna quanto entrou de fato.
function Perks.add(data: Data, id: string, amount: number): number
	if not Perks.ConsumableById[id] or amount ~= amount or amount <= 0 then
		return 0
	end
	local before = Perks.count(data, id)
	local after = math.min(MAX_STOCK, before + math.floor(amount))
	data.consumables[id] = after
	return after - before
end

function Perks.buyConsumable(data: Data, id: string, currency: Currency): (boolean, string?)
	local consumable = Perks.ConsumableById[id]
	if not consumable then
		return false, "store_unknown"
	end
	local price = if currency == "fichas" then consumable.fichas else consumable.creditos
	if not price then
		return false, "store_no_price"
	end
	if Perks.count(data, id) + consumable.bundle > MAX_STOCK then
		return false, "perk_stock_full"
	end
	if data.wallet[currency] < price then
		return false, "store_poor"
	end
	data.wallet[currency] -= price
	Perks.add(data, id, consumable.bundle)
	return true, nil
end

-- Gasta uma unidade. false se não tem.
function Perks.consume(data: Data, id: string): boolean
	local count = Perks.count(data, id)
	if count <= 0 then
		return false
	end
	data.consumables[id] = count - 1
	return true
end

-- Liga/desliga o uso automático (só consumíveis de kit).
function Perks.setLoadout(data: Data, id: string, on: boolean): (boolean, string?)
	local consumable = Perks.ConsumableById[id]
	if not consumable or not consumable.loadout then
		return false, "store_unknown"
	end
	if on then
		data.loadout[id] = true
	else
		data.loadout[id] = nil
	end
	return true, nil
end

-- Bônus de tempo: soma minutos a partir de agora (ou do fim do bônus ainda ativo).
function Perks.addBoost(data: Data, kind: BoostKind, minutes: number, now: number)
	if minutes ~= minutes or minutes <= 0 then
		return
	end
	local field = if kind == "fichas" then "fichasUntil" else "xpUntil"
	local current = (data.boosts :: any)[field]
	local base = if type(current) == "number" and current > now then current else now;
	(data.boosts :: any)[field] = base + math.floor(minutes * 60)
end

return table.freeze(Perks)
