--!strict
--[[
	Passe de temporada "Turno Extra" (dados puros, compartilhados; testados no Lune).
	Regras em ./Season; política e valores em docs/MONETIZATION.md.

	- Cada temporada tem 30 níveis com duas trilhas: GRÁTIS (todos) e PAGA (Game Pass próprio da
	  temporada, `passKey` em StoreCatalog.Products). Os cosméticos ficam em StoreCatalog.Items com
	  source = "season" (só saem das trilhas: nem loja nem baú).
	- XP de temporada é separado do XP da conta: vem das partidas, das fitas e do diário (XpSources).
	  Pagar não acelera o XP; a trilha paga só libera recompensas (nada compra vantagem no jogo).
	- Recompensas são entregues sozinhas ao alcançar o nível. Quem compra a trilha paga no meio da
	  temporada recebe na hora as recompensas pagas dos níveis já alcançados.
	- Datas em os.time (UTC). O "dia" do jogo vira à meia-noite de Brasília (UTC-3).
	  Nova temporada = nova entrada em Seasons (id novo), itens novos e um Game Pass novo.
]]

local StoreCatalog = require("./StoreCatalog")

type Reward = StoreCatalog.Reward

export type Track = "free" | "premium"

export type Tier = {
	free: Reward?,
	premium: Reward?,
}

export type SeasonDef = {
	id: string,
	number: number,
	name: string,
	tagline: string,
	-- Início (inclusive) e fim (exclusive), em os.time UTC.
	startsAt: number,
	endsAt: number,
	-- Chave do Game Pass da trilha paga em StoreCatalog.Products.
	passKey: string,
	-- XP de temporada para subir cada nível (constante: o progresso é fácil de ler).
	xpPerTier: number,
	tiers: { Tier },
}

local SeasonCatalog = {}

SeasonCatalog.TRACKS = { "free", "premium" } :: { Track }

-- XP de temporada por fonte (sem multiplicador VIP: o passe vale igual para todos).
SeasonCatalog.XpSources = {
	participation = 40,
	perStage = 30,
	perFuse = 10,
	breakers = 20,
	escaped = 60,
	perContribution = 4,
	contributionCap = 15,
	tape = 50,
	daily = 40,
}

SeasonCatalog.Seasons = {
	{
		id = "s1",
		number = 1,
		name = "NOITE EXTRA",
		tagline = "A casa do Tung Tung guarda novos segredos. Cada partida conta!",
		-- 15/10/2026 00:00 a 01/12/2026 00:00 (horário de Brasília).
		startsAt = 1792033200,
		endsAt = 1796094000,
		passKey = "turno_extra_s1",
		xpPerTier = 400,
		tiers = {
			{ free = { fichas = 100 }, premium = { item = "farda_hora_extra" } },
			{ free = { fichas = 50 }, premium = { fichas = 100 } },
			{ free = { fichas = 50 }, premium = { creditos = 30 } },
			{ free = { fichas = 75 }, premium = { fichas = 150 } },
			{ free = { item = "titulo_hora_extra" }, premium = { item = "lanterna_ponto" } },
			{ free = { fichas = 75 }, premium = { fichas = 150 } },
			{ free = { fichas = 75 }, premium = { creditos = 30 } },
			{ free = { fichas = 100 }, premium = { fichas = 200 } },
			{ free = { fichas = 100 }, premium = { fichas = 200 } },
			{ free = { item = "lanterna_plantao" }, premium = { item = "filtro_ponto" } },
			{ free = { fichas = 100 }, premium = { creditos = 30 } },
			{ free = { fichas = 100 }, premium = { fichas = 250 } },
			{ free = { fichas = 125 }, premium = { fichas = 250 } },
			{ free = { fichas = 125 }, premium = { creditos = 30 } },
			{ free = { creditos = 15 }, premium = { item = "titulo_insone" } },
			{ free = { fichas = 125 }, premium = { fichas = 300 } },
			{ free = { fichas = 150 }, premium = { fichas = 300 } },
			{ free = { fichas = 150 }, premium = { creditos = 30 } },
			{ free = { fichas = 150 }, premium = { fichas = 300 } },
			{ free = { item = "filtro_madrugada" }, premium = { item = "farda_madrugada" } },
			{ free = { fichas = 150 }, premium = { fichas = 350 } },
			{ free = { fichas = 175 }, premium = { creditos = 30 } },
			{ free = { fichas = 175 }, premium = { fichas = 350 } },
			{ free = { fichas = 175 }, premium = { fichas = 350 } },
			{ free = { creditos = 25 }, premium = { item = "lanterna_tres" } },
			{ free = { fichas = 200 }, premium = { creditos = 30 } },
			{ free = { fichas = 200 }, premium = { fichas = 400 } },
			{ free = { fichas = 200 }, premium = { fichas = 400 } },
			{ free = { fichas = 250 }, premium = { fichas = 500 } },
			{ free = { item = "titulo_turno_extra" }, premium = { item = "titulo_dono_madrugada", creditos = 90 } },
		},
	},
} :: { SeasonDef }

SeasonCatalog.SeasonById = {} :: { [string]: SeasonDef }
for _, season in SeasonCatalog.Seasons do
	SeasonCatalog.SeasonById[season.id] = season
end

return SeasonCatalog
