--!strict
--[[
	Catálogo da loja e da progressão (dados puros, compartilhados; testados no Lune).
	O servidor é a única autoridade: o cliente só usa estes dados para MOSTRAR preços, chances e
	recompensas. Política de monetização: docs/MONETIZATION.md.

	Princípios:
	- Só cosméticos e conveniência de coleção: nada compra vantagem contra o Vigia (jogo cooperativo).
	- Fichas = moeda ganha jogando (nunca vendida). Créditos = moeda comprada com Robux.
	- Baú pago com Créditos é "item aleatório pago": chances em % antes da compra (somam 100%),
	  bloqueado para quem a PolicyService restringe (alternativa: compra direta de cada item).
	- Cores ficam como {r, g, b} (0..255): este módulo roda também no Lune, sem Color3.
]]

export type Currency = "fichas" | "creditos"
export type Rarity = "common" | "rare" | "epic" | "legendary" | "exclusive"
export type ItemKind = "flashlight" | "uniform" | "filter" | "title"
-- De onde o item vem: padrão (todos têm), loja/baús, nível, coleção de fitas, VIP ou Pacote Inicial.
export type Source = "default" | "store" | "level" | "tapes" | "vip" | "starter" | "escape"
export type RGB = { number }

export type Item = {
	id: string,
	kind: ItemKind,
	name: string,
	rarity: Rarity,
	source: Source,
	-- Compra direta (opcional por moeda).
	fichas: number?,
	creditos: number?,
	-- Aparência (por tipo).
	body: RGB?,
	head: RGB?,
	beam: RGB?,
	material: string?,
	shirt: RGB?,
	pants: RGB?,
	helmet: RGB?,
	stripe: RGB?,
	cap: boolean?,
	tint: RGB?,
	saturation: number?,
	contrast: number?,
	brightness: number?,
	color: RGB?,
}

export type Chest = {
	id: string,
	name: string,
	currency: Currency,
	price: number,
	-- Chance por raridade, em pontos percentuais (somam 100).
	odds: { [Rarity]: number },
	-- true = comprado (direta ou indiretamente) com Robux: regras de itens aleatórios pagos.
	paidRandom: boolean,
}

export type Reward = {
	fichas: number?,
	creditos: number?,
	xp: number?,
	item: string?,
}

export type SpinSegment = { id: string, label: string, weight: number, reward: Reward }

export type Product = {
	key: string,
	kind: "product" | "pass",
	name: string,
	description: string,
	-- ID do Developer Product / Game Pass no Creator Hub. 0 = ainda não criado
	-- (no Studio a compra é simulada; no servidor ao vivo o item fica indisponível).
	id: number,
	-- Preço sugerido em Robux (informativo; o preço real é o do Creator Hub).
	robux: number,
	grant: Reward,
	-- Só pode ser comprado uma vez por conta (registrado nos dados).
	once: boolean?,
}

export type Tape = { id: string, title: string, line: string }

local StoreCatalog = {}

local CURRENCIES: { Currency } = { "fichas", "creditos" }
local KINDS: { ItemKind } = { "flashlight", "uniform", "filter", "title" }
StoreCatalog.CURRENCIES = CURRENCIES
StoreCatalog.KINDS = KINDS

StoreCatalog.Rarities = {
	common = { label = "COMUM", color = { 160, 160, 150 }, refund = 50, order = 1 },
	rare = { label = "RARO", color = { 70, 140, 230 }, refund = 120, order = 2 },
	epic = { label = "ÉPICO", color = { 170, 80, 230 }, refund = 300, order = 3 },
	legendary = { label = "LENDÁRIO", color = { 240, 180, 50 }, refund = 800, order = 4 },
	exclusive = { label = "EXCLUSIVO", color = { 230, 70, 60 }, refund = 0, order = 5 },
}

-- Item padrão de cada tipo (todos possuem; equipado na conta nova).
StoreCatalog.Defaults = {
	flashlight = "lanterna_padrao",
	uniform = "farda_padrao",
	filter = "filtro_padrao",
	title = "titulo_estagiario",
}

function StoreCatalog.defaultFor(kind: ItemKind): string
	return (StoreCatalog.Defaults :: any)[kind]
end

local function item(def: Item): Item
	return def
end

StoreCatalog.Items = {
	-- ===== Lanternas (só o dono vê, na mão) =====
	item({
		id = "lanterna_padrao",
		kind = "flashlight",
		name = "LANTERNA DA EMPRESA",
		rarity = "common",
		source = "default",
		body = { 38, 40, 44 },
		head = { 52, 54, 58 },
		beam = { 255, 232, 196 },
		material = "Metal",
	}),
	item({
		id = "lanterna_militar",
		kind = "flashlight",
		name = "LANTERNA MILITAR",
		rarity = "common",
		source = "store",
		fichas = 400,
		body = { 72, 80, 52 },
		head = { 58, 64, 44 },
		beam = { 255, 236, 200 },
		material = "Metal",
	}),
	item({
		id = "lanterna_laranja",
		kind = "flashlight",
		name = "LANTERNA DE SEGURANÇA",
		rarity = "common",
		source = "level",
		body = { 220, 110, 30 },
		head = { 40, 40, 40 },
		beam = { 255, 230, 190 },
		material = "SmoothPlastic",
	}),
	item({
		id = "lanterna_cromo",
		kind = "flashlight",
		name = "LANTERNA CROMADA",
		rarity = "rare",
		source = "store",
		fichas = 1000,
		creditos = 150,
		body = { 180, 186, 192 },
		head = { 210, 214, 220 },
		beam = { 230, 240, 255 },
		material = "Foil",
	}),
	item({
		id = "lanterna_retro",
		kind = "flashlight",
		name = "LANTERNA 1987",
		rarity = "rare",
		source = "store",
		fichas = 1000,
		creditos = 150,
		body = { 196, 180, 150 },
		head = { 120, 100, 80 },
		beam = { 255, 214, 150 },
		material = "SmoothPlastic",
	}),
	item({
		id = "lanterna_neon",
		kind = "flashlight",
		name = "LANTERNA NEON",
		rarity = "epic",
		source = "store",
		creditos = 350,
		body = { 30, 34, 30 },
		head = { 60, 255, 120 },
		beam = { 220, 255, 225 },
		material = "Neon",
	}),
	item({
		id = "lanterna_uv",
		kind = "flashlight",
		name = "LANTERNA UV",
		rarity = "epic",
		source = "store",
		creditos = 350,
		body = { 50, 30, 70 },
		head = { 150, 80, 255 },
		beam = { 235, 220, 255 },
		material = "SmoothPlastic",
	}),
	item({
		id = "lanterna_ouro",
		kind = "flashlight",
		name = "LANTERNA DE OURO",
		rarity = "legendary",
		source = "store",
		creditos = 750,
		body = { 212, 170, 60 },
		head = { 240, 200, 90 },
		beam = { 255, 226, 170 },
		material = "Metal",
	}),
	item({
		id = "lanterna_vigia",
		kind = "flashlight",
		name = "LANTERNA DO SEU ADEMIR",
		rarity = "legendary",
		source = "tapes",
		body = { 96, 60, 40 },
		head = { 140, 32, 28 },
		beam = { 255, 222, 200 },
		material = "Metal",
	}),
	item({
		id = "lanterna_supervisor",
		kind = "flashlight",
		name = "LANTERNA DO SUPERVISOR",
		rarity = "exclusive",
		source = "vip",
		body = { 20, 20, 22 },
		head = { 220, 180, 70 },
		beam = { 255, 240, 215 },
		material = "Metal",
	}),

	-- ===== Fardas (os colegas veem) =====
	item({
		id = "farda_padrao",
		kind = "uniform",
		name = "FARDA TÉCNICA",
		rarity = "common",
		source = "default",
		shirt = { 46, 58, 84 },
		pants = { 34, 40, 52 },
		helmet = { 230, 190, 40 },
	}),
	item({
		id = "farda_laranja",
		kind = "uniform",
		name = "MACACÃO LARANJA",
		rarity = "common",
		source = "store",
		fichas = 400,
		shirt = { 210, 100, 30 },
		pants = { 190, 90, 26 },
		helmet = { 240, 240, 236 },
		stripe = { 220, 220, 200 },
	}),
	item({
		id = "farda_cinza",
		kind = "uniform",
		name = "FARDA DE MANUTENÇÃO",
		rarity = "common",
		source = "level",
		shirt = { 110, 112, 108 },
		pants = { 70, 72, 70 },
		helmet = { 230, 190, 40 },
	}),
	item({
		id = "farda_noturna",
		kind = "uniform",
		name = "TURNO DA NOITE",
		rarity = "rare",
		source = "store",
		fichas = 1000,
		creditos = 150,
		shirt = { 24, 26, 30 },
		pants = { 20, 22, 26 },
		helmet = { 40, 42, 46 },
		stripe = { 200, 255, 120 },
	}),
	item({
		id = "farda_brigada",
		kind = "uniform",
		name = "BRIGADA DE INCÊNDIO",
		rarity = "rare",
		source = "store",
		fichas = 1000,
		creditos = 150,
		shirt = { 150, 30, 28 },
		pants = { 40, 40, 44 },
		helmet = { 160, 30, 28 },
		stripe = { 240, 220, 60 },
	}),
	item({
		id = "farda_hazmat",
		kind = "uniform",
		name = "TRAJE HAZMAT",
		rarity = "epic",
		source = "store",
		creditos = 350,
		shirt = { 220, 200, 40 },
		pants = { 210, 190, 36 },
		helmet = { 220, 200, 40 },
		stripe = { 30, 30, 30 },
	}),
	item({
		id = "farda_eletricista",
		kind = "uniform",
		name = "ELETRICISTA CHEFE",
		rarity = "epic",
		source = "level",
		shirt = { 30, 70, 180 },
		pants = { 24, 40, 90 },
		helmet = { 250, 250, 250 },
		stripe = { 255, 210, 40 },
	}),
	item({
		id = "farda_vigia",
		kind = "uniform",
		name = "FARDA DE VIGIA",
		rarity = "legendary",
		source = "store",
		creditos = 750,
		shirt = { 40, 46, 58 },
		pants = { 26, 30, 38 },
		cap = true,
		stripe = { 190, 160, 70 },
	}),
	item({
		id = "farda_supervisor",
		kind = "uniform",
		name = "SUPERVISOR DE TURNO",
		rarity = "exclusive",
		source = "vip",
		shirt = { 235, 235, 230 },
		pants = { 60, 64, 70 },
		helmet = { 250, 250, 250 },
		stripe = { 220, 180, 70 },
	}),

	-- ===== Filtros de câmera (gradação local) =====
	item({
		id = "filtro_padrao",
		kind = "filter",
		name = "FITA VERDE",
		rarity = "common",
		source = "default",
		tint = { 214, 228, 210 },
		saturation = -0.32,
		contrast = 0.16,
		brightness = -0.01,
	}),
	item({
		id = "filtro_sepia",
		kind = "filter",
		name = "SÉPIA 1987",
		rarity = "rare",
		source = "level",
		tint = { 236, 214, 180 },
		saturation = -0.55,
		contrast = 0.18,
		brightness = 0,
	}),
	item({
		id = "filtro_azul",
		kind = "filter",
		name = "NOITE AZUL",
		rarity = "rare",
		source = "store",
		fichas = 1000,
		creditos = 150,
		tint = { 196, 212, 240 },
		saturation = -0.3,
		contrast = 0.2,
		brightness = -0.01,
	}),
	item({
		id = "filtro_cctv",
		kind = "filter",
		name = "CÂMERA DE SEGURANÇA",
		rarity = "epic",
		source = "store",
		creditos = 350,
		tint = { 225, 230, 225 },
		saturation = -1,
		contrast = 0.28,
		brightness = 0,
	}),
	item({
		id = "filtro_infra",
		kind = "filter",
		name = "INFRAVERMELHO",
		rarity = "legendary",
		source = "store",
		creditos = 750,
		tint = { 255, 200, 200 },
		saturation = -0.7,
		contrast = 0.3,
		brightness = 0.01,
	}),

	-- ===== Títulos (só se ganham jogando) =====
	item({
		id = "titulo_estagiario",
		kind = "title",
		name = "ESTAGIÁRIO",
		rarity = "common",
		source = "default",
		color = { 180, 180, 170 },
	}),
	item({
		id = "titulo_tecnico",
		kind = "title",
		name = "TÉCNICO",
		rarity = "common",
		source = "level",
		color = { 200, 210, 200 },
	}),
	item({
		id = "titulo_sobrevivente",
		kind = "title",
		name = "SOBREVIVENTE",
		rarity = "rare",
		source = "escape",
		color = { 120, 220, 140 },
	}),
	item({
		id = "titulo_senior",
		kind = "title",
		name = "TÉCNICO SÊNIOR",
		rarity = "rare",
		source = "level",
		color = { 110, 170, 240 },
	}),
	item({
		id = "titulo_arquivista",
		kind = "title",
		name = "ARQUIVISTA",
		rarity = "epic",
		source = "tapes",
		color = { 190, 120, 240 },
	}),
	item({
		id = "titulo_lenda",
		kind = "title",
		name = "LENDA DA SUBESTAÇÃO",
		rarity = "legendary",
		source = "level",
		color = { 250, 200, 70 },
	}),
	item({
		id = "titulo_supervisor",
		kind = "title",
		name = "SUPERVISOR",
		rarity = "exclusive",
		source = "vip",
		color = { 230, 190, 80 },
	}),
} :: { Item }

-- Índice por id.
StoreCatalog.ItemById = {} :: { [string]: Item }
for _, entry in StoreCatalog.Items do
	StoreCatalog.ItemById[entry.id] = entry
end

StoreCatalog.Chests = {
	{
		id = "bau_ferramentas",
		name = "BAÚ DE FERRAMENTAS",
		currency = "fichas",
		price = 250,
		odds = { common = 62, rare = 28, epic = 8, legendary = 2 },
		paidRandom = false,
	},
	{
		id = "bau_lacrado",
		name = "BAÚ LACRADO",
		currency = "creditos",
		price = 120,
		odds = { rare = 60, epic = 32, legendary = 8 },
		paidRandom = true,
	},
} :: { Chest }

StoreCatalog.ChestById = {} :: { [string]: Chest }
for _, chest in StoreCatalog.Chests do
	StoreCatalog.ChestById[chest.id] = chest
end

-- Recompensa de cada dia do calendário (ciclo de 7; perder um dia volta ao dia 1).
StoreCatalog.Daily = {
	{ fichas = 40 },
	{ fichas = 60 },
	{ fichas = 80 },
	{ fichas = 100 },
	{ fichas = 150 },
	{ fichas = 200 },
	{ fichas = 300, creditos = 25 },
} :: { Reward }

-- Roleta diária grátis (1 giro/dia; VIP ganha +1). Não envolve Robux: é sorteio gratuito,
-- mas as chances aparecem do mesmo jeito (transparência).
StoreCatalog.Spin = {
	{ id = "f25", label = "25 FICHAS", weight = 30, reward = { fichas = 25 } },
	{ id = "f50", label = "50 FICHAS", weight = 25, reward = { fichas = 50 } },
	{ id = "xp150", label = "150 XP", weight = 12, reward = { xp = 150 } },
	{ id = "f100", label = "100 FICHAS", weight = 16, reward = { fichas = 100 } },
	{ id = "f250", label = "250 FICHAS", weight = 10, reward = { fichas = 250 } },
	{ id = "c15", label = "15 CRÉDITOS", weight = 7, reward = { creditos = 15 } },
} :: { SpinSegment }

-- Progressão: XP para passar do nível n para n+1 = LevelBase + LevelStep * (n - 1).
StoreCatalog.LevelBase = 300
StoreCatalog.LevelStep = 100
StoreCatalog.LevelCap = 50
-- Fichas a cada nível novo = LevelFichasBase + LevelFichasStep * nível. Marcos dão itens.
StoreCatalog.LevelFichasBase = 60
StoreCatalog.LevelFichasStep = 15
StoreCatalog.LevelMilestones = {
	[3] = { item = "filtro_sepia" },
	[5] = { item = "titulo_tecnico", fichas = 200 },
	[8] = { item = "lanterna_laranja" },
	[10] = { item = "titulo_senior", creditos = 50 },
	[13] = { item = "farda_cinza" },
	[20] = { item = "farda_eletricista", creditos = 100 },
	[30] = { item = "titulo_lenda", creditos = 200 },
} :: { [number]: Reward }

-- Recompensa de uma partida (antes do multiplicador VIP).
StoreCatalog.RunRewards = {
	participation = { fichas = 30, xp = 60 },
	perStage = { fichas = 25, xp = 50 },
	perFuse = { fichas = 10, xp = 25 },
	breakers = { fichas = 20, xp = 40 },
	escaped = { fichas = 60, xp = 120 },
	perContribution = { fichas = 4, xp = 8 },
	contributionCap = 15,
	tape = { fichas = 50, xp = 40 },
}
StoreCatalog.VipMultiplier = 1.5

-- Fitas VHS colecionáveis (uma aparece por partida; a equipe toda ganha ao achar).
StoreCatalog.Tapes = {
	{ id = "fita_01", title = "PLANTÃO 03:12", line = "Quem apagou as luzes não foi a tempestade." },
	{ id = "fita_02", title = "RONDA DO ADEMIR", line = "Passos no corredor. Sempre no mesmo ritmo." },
	{ id = "fita_03", title = "TREINAMENTO 1987", line = "Nunca religue os disjuntores fora de ordem." },
	{ id = "fita_04", title = "ALARME FALSO", line = "O rádio chiou e ninguém respondeu." },
	{ id = "fita_05", title = "GALERIA DE CABOS", line = "Tem algo arranhando dentro do duto." },
	{ id = "fita_06", title = "ANIVERSÁRIO", line = "Bolo na recepção. Uma cadeira vazia." },
	{ id = "fita_07", title = "QUEDA DE TENSÃO", line = "Três fusíveis queimados na mesma noite." },
	{ id = "fita_08", title = "ARQUIVO MORTO", line = "Fichas de ponto até 2003. Depois, nada." },
	{ id = "fita_09", title = "O PORTÃO", line = "Ele nunca deixa o portão aberto por muito tempo." },
	{ id = "fita_10", title = "SALA DE CONTROLE", line = "Os monitores mostram alguém parado. Não há ninguém." },
	{ id = "fita_11", title = "ÚLTIMO TURNO", line = "Assinou o livro e continuou a ronda." },
	{ id = "fita_12", title = "SUBESTAÇÃO 9", line = "Se ouvir os passos, apague a lanterna." },
} :: { Tape }

StoreCatalog.TapeById = {} :: { [string]: Tape }
for _, tape in StoreCatalog.Tapes do
	StoreCatalog.TapeById[tape.id] = tape
end

-- Marcos da coleção (quantidade de fitas -> recompensa).
StoreCatalog.TapeMilestones = {
	[4] = { fichas = 400 },
	[8] = { item = "lanterna_vigia" },
	[12] = { item = "titulo_arquivista", creditos = 150 },
} :: { [number]: Reward }

-- Primeira fuga da conta dá o título "Sobrevivente".
StoreCatalog.FirstEscapeItem = "titulo_sobrevivente"

-- Compras com Robux (crie no Creator Hub e cole os IDs; ver docs/MONETIZATION.md).
StoreCatalog.Products = {
	{
		key = "creditos_100",
		kind = "product",
		name = "100 CRÉDITOS",
		description = "Para baús lacrados e itens da loja.",
		id = 0,
		robux = 75,
		grant = { creditos = 100 },
	},
	{
		key = "creditos_550",
		kind = "product",
		name = "550 CRÉDITOS",
		description = "+10% de bônus.",
		id = 0,
		robux = 375,
		grant = { creditos = 550 },
	},
	{
		key = "creditos_1200",
		kind = "product",
		name = "1200 CRÉDITOS",
		description = "+20% de bônus.",
		id = 0,
		robux = 750,
		grant = { creditos = 1200 },
	},
	{
		key = "creditos_2800",
		kind = "product",
		name = "2800 CRÉDITOS",
		description = "+40% de bônus.",
		id = 0,
		robux = 1500,
		grant = { creditos = 2800 },
	},
	{
		key = "pacote_inicial",
		kind = "product",
		name = "PACOTE INICIAL",
		description = "300 Créditos + Lanterna 1987 + Turno da Noite. Uma vez por conta.",
		id = 0,
		robux = 149,
		grant = { creditos = 300 },
		once = true,
	},
	{
		key = "vip",
		kind = "pass",
		name = "CRACHÁ DE SUPERVISOR (VIP)",
		description = "+50% Fichas e XP, +1 giro diário, lanterna, farda e título exclusivos.",
		id = 0,
		robux = 299,
		grant = {},
	},
} :: { Product }

-- Itens extras do Pacote Inicial (além do `grant`).
StoreCatalog.StarterItems = { "lanterna_retro", "farda_noturna" }

StoreCatalog.ProductByKey = {} :: { [string]: Product }
for _, product in StoreCatalog.Products do
	StoreCatalog.ProductByKey[product.key] = product
end

return StoreCatalog
