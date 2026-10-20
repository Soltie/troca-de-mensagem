--!strict
--[[
	Dificuldade e modificadores da partida (opção E, docs/AVALIACAO_20-10-2026.md). Escolhidos no lobby, valem para
	a equipe toda e ficam em CampaignState.Modifiers ("pesadelo,pilha"). Cada um deixa a partida mais difícil e
	aumenta as Fichas ganhas (tarefas e moedas). Regras puras; quem aplica:
	- speed: CreatureService (velocidade do Tung Tung, nunca passa da corrida do jogador);
	- hearing: CreatureService.makeNoise (raio do barulho);
	- battery: PlayerStateService (gasto da lanterna);
	- bonus: StoreService (Fichas de tarefa e de moeda).
]]

export type Modifier = {
	id: string,
	title: string,
	description: string,
	bonus: number,
	speed: number,
	hearing: number,
	battery: number,
}
export type Factors = { speed: number, hearing: number, battery: number, bonus: number }

local Difficulty = {}

Difficulty.List = table.freeze({
	{
		id = "pesadelo",
		title = "PESADELO",
		description = "Ele corre mais e ouve mais longe.",
		bonus = 0.5,
		speed = 1.12,
		hearing = 1.25,
		battery = 1,
	},
	{
		id = "pilha",
		title = "PILHA FRACA",
		description = "A lanterna gasta 50% mais rápido.",
		bonus = 0.15,
		speed = 1,
		hearing = 1,
		battery = 1.5,
	},
	{
		id = "faro",
		title = "FARO APURADO",
		description = "Todo barulho chega 30% mais longe.",
		bonus = 0.15,
		speed = 1,
		hearing = 1.3,
		battery = 1,
	},
	{
		id = "veloz",
		title = "PERNAS LONGAS",
		description = "Ele anda e persegue 10% mais rápido.",
		bonus = 0.2,
		speed = 1.1,
		hearing = 1,
		battery = 1,
	},
} :: { Modifier })

local byId: { [string]: Modifier } = {}
for _, m in Difficulty.List do
	byId[m.id] = m
end

-- Texto salvo no atributo -> lista válida, sem repetição, na ordem do catálogo.
function Difficulty.parse(text: string?): { string }
	local wanted: { [string]: boolean } = {}
	for id in string.gmatch(text or "", "[%w]+") do
		if byId[id] then
			wanted[id] = true
		end
	end
	local out = {}
	for _, m in Difficulty.List do
		if wanted[m.id] then
			table.insert(out, m.id)
		end
	end
	return out
end

function Difficulty.encode(ids: { string }): string
	return table.concat(Difficulty.parse(table.concat(ids, ",")), ",")
end

function Difficulty.toggle(text: string?, id: string): string
	local ids = Difficulty.parse(text)
	local found = table.find(ids, id)
	if found then
		table.remove(ids, found)
	elseif byId[id] then
		table.insert(ids, id)
	end
	return Difficulty.encode(ids)
end

function Difficulty.factors(text: string?): Factors
	local f = { speed = 1, hearing = 1, battery = 1, bonus = 0 }
	for _, id in Difficulty.parse(text) do
		local m = byId[id]
		f.speed *= m.speed
		f.hearing *= m.hearing
		f.battery *= m.battery
		f.bonus += m.bonus
	end
	return f
end

-- Velocidade final do Tung: com modificador, mas sempre abaixo da corrida do jogador (dá para fugir).
function Difficulty.creatureSpeed(base: number, text: string?, sprint: number): number
	if base <= 0 then
		return base
	end
	return math.min(base * Difficulty.factors(text).speed, math.max(base, sprint - 1))
end

-- Fichas com o bônus dos modificadores (arredondado; nunca menos que o normal).
function Difficulty.boost(fichas: number, text: string?): number
	return math.max(fichas, math.floor(fichas * (1 + Difficulty.factors(text).bonus) + 0.5))
end

-- Voto no lobby (veredito 20/10: um jogador ligava o Pesadelo para todos). Cada voto é o texto dos modificadores
-- de um jogador; liga o que tem a maioria (mais da metade de `players`). Devolve o texto ligado e a contagem.
function Difficulty.tally(votes: { string }, players: number): (string, { [string]: number })
	local counts: { [string]: number } = {}
	for _, text in votes do
		for _, id in Difficulty.parse(text) do
			counts[id] = (counts[id] or 0) + 1
		end
	end
	local on = {}
	for id, count in counts do
		if count * 2 > math.max(players, 1) then
			table.insert(on, id)
		end
	end
	return Difficulty.encode(on), counts
end

-- Votos que faltam para ligar `id` com `players` na equipe.
function Difficulty.needed(players: number): number
	return math.floor(math.max(players, 1) / 2) + 1
end

function Difficulty.get(id: string): Modifier?
	return byId[id]
end

return table.freeze(Difficulty)
