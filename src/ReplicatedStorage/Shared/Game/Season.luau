--!strict
--[[
	Regras puras do passe de temporada (testadas no Lune). Dados em ./SeasonCatalog.
	Só o SERVIDOR chama as funções que alteram dados; o cliente usa as de leitura para exibir.

	`premium` = o jogador tem o Game Pass da temporada (o servidor confere com a Roblox).
	Entrega idempotente: cada nível de cada trilha é marcado em data.season.free/premium,
	então chamar grantReached de novo nunca dá a mesma recompensa duas vezes.
]]

local Economy = require("./Economy")
local SeasonCatalog = require("./SeasonCatalog")
local StoreCatalog = require("./StoreCatalog")
local Types = require("../Types")

type Data = Types.PlayerData
type SeasonDef = SeasonCatalog.SeasonDef
type Track = SeasonCatalog.Track

export type SeasonGranted = {
	-- XP de temporada somado agora.
	xp: number,
	-- Níveis alcançados agora (para o aviso).
	tiers: { number },
	-- O que cada trilha entregou (moedas e itens), separado para o analytics.
	free: Economy.Granted,
	premium: Economy.Granted,
}

local SECONDS_PER_DAY = 86400

local Season = {}

local function emptyGranted(): Economy.Granted
	return { fichas = 0, creditos = 0, xp = 0, items = {}, refunds = {}, levels = {} }
end

local function emptyResult(): SeasonGranted
	return { xp = 0, tiers = {}, free = emptyGranted(), premium = emptyGranted() }
end

-- ===================== Leitura =====================

-- Temporada ativa no instante `now` (os.time), ou nil entre temporadas.
function Season.current(now: number): SeasonDef?
	for _, season in SeasonCatalog.Seasons do
		if now >= season.startsAt and now < season.endsAt then
			return season
		end
	end
	return nil
end

-- Dias inteiros que faltam (arredondado para cima; 0 quando acabou).
function Season.daysLeft(season: SeasonDef, now: number): number
	return math.max(0, math.ceil((season.endsAt - now) / SECONDS_PER_DAY))
end

function Season.maxTier(season: SeasonDef): number
	return #season.tiers
end

-- Nível alcançado (começa no 1, com 0 XP), XP dentro do nível e XP do nível.
-- No último nível a barra fica cheia (into = need).
function Season.tierInfo(season: SeasonDef, xp: number): (number, number, number)
	local need = season.xpPerTier
	local tier = math.floor(math.max(0, xp) / need) + 1
	if tier >= #season.tiers then
		return #season.tiers, need, need
	end
	return tier, math.max(0, xp) - (tier - 1) * need, need
end

function Season.reward(season: SeasonDef, tier: number, track: Track): StoreCatalog.Reward?
	local entry = season.tiers[tier]
	if not entry then
		return nil
	end
	return if track == "free" then entry.free else entry.premium
end

-- XP de temporada da partida (mesmo resumo da recompensa da conta).
function Season.runXp(summary: Economy.RunSummary): number
	local X = SeasonCatalog.XpSources
	local xp = X.participation + X.perStage * summary.stages + X.perFuse * summary.fuses
	if summary.breakers then
		xp += X.breakers
	end
	if summary.won or summary.escaped then
		xp += X.escaped
	end
	return xp + X.perContribution * math.clamp(summary.contributions, 0, X.contributionCap)
end

-- XP de temporada que o jogador tem NESTA temporada (dados de outra temporada valem 0).
function Season.xpOf(data: Data, season: SeasonDef): number
	return if data.season.id == season.id then data.season.xp else 0
end

function Season.isGranted(data: Data, season: SeasonDef, tier: number, track: Track): boolean
	if data.season.id ~= season.id then
		return false
	end
	local marks = if track == "free" then data.season.free else data.season.premium
	return marks[tostring(tier)] == true
end

-- ===================== Escrita (só servidor) =====================

-- Passa os dados para a temporada `season`; outra temporada zera XP e entregas. true = zerou.
function Season.sync(data: Data, season: SeasonDef): boolean
	if data.season.id == season.id then
		return false
	end
	data.season = { id = season.id, xp = 0, free = {}, premium = {} }
	return true
end

-- Entrega toda recompensa de nível alcançado que ainda não foi entregue (paga só com `premium`).
function Season.grantReached(data: Data, season: SeasonDef, premium: boolean, into: SeasonGranted?): SeasonGranted
	local result = into or emptyResult()
	Season.sync(data, season)
	local reached = Season.tierInfo(season, data.season.xp)
	for tier = 1, reached do
		local key = tostring(tier)
		local entry = season.tiers[tier]
		if not data.season.free[key] then
			data.season.free[key] = true
			if entry.free then
				Economy.applyReward(data, entry.free, result.free)
			end
		end
		if premium and not data.season.premium[key] then
			data.season.premium[key] = true
			if entry.premium then
				Economy.applyReward(data, entry.premium, result.premium)
			end
		end
	end
	return result
end

-- Soma XP de temporada e entrega o que os níveis novos liberarem.
function Season.addXp(data: Data, season: SeasonDef, amount: number, premium: boolean): SeasonGranted
	Season.sync(data, season)
	local result = emptyResult()
	local before = Season.tierInfo(season, data.season.xp)
	if amount > 0 then
		data.season.xp += math.floor(amount)
		result.xp = math.floor(amount)
	end
	local after = Season.tierInfo(season, data.season.xp)
	for tier = before + 1, after do
		table.insert(result.tiers, tier)
	end
	return Season.grantReached(data, season, premium, result)
end

-- Algo foi entregue? (para decidir se vale avisar o cliente)
function Season.hasRewards(result: SeasonGranted): boolean
	for _, granted in { result.free, result.premium } do
		if granted.fichas > 0 or granted.creditos > 0 or #granted.items > 0 then
			return true
		end
	end
	return false
end

return Season
