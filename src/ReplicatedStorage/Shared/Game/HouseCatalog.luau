--!strict
-- Metadados públicos; soluções e sorteio pertencem ao HousePlan no servidor.
local TableUtil = require("../Util/TableUtil")
export type Room = { id: string, title: string, x: number, y: number, z: number }
export type Objective = {
	room: string,
	title: string,
	kind: string,
	item: string?,
	event: string?,
	revelation: string,
	-- Cômodos possíveis (sorteados por partida, sem repetir no capítulo); `room` é o padrão.
	pool: { string }?,
}
export type Chapter = { title: string, subtitle: string, objectives: { Objective } }
local function objective(
	room: string,
	title: string,
	kind: string,
	item: string?,
	event: string?,
	clue: string?
): Objective
	return {
		room = room,
		title = title,
		kind = kind,
		item = item,
		event = event,
		revelation = clue or title .. ": concluído.",
	}
end
local House = {
	Rooms = {
		{ id = "Exterior", title = "CAMINHO DA FLORESTA", x = 0, y = 0, z = 76 },
		{ id = "Hall", title = "HALL", x = 0, y = 0, z = 2 },
		{ id = "Living", title = "SALA DE ESTAR", x = -26, y = 0, z = -4 },
		{ id = "Kitchen", title = "COZINHA", x = 26, y = 0, z = -4 },
		{ id = "Dining", title = "SALA DE JANTAR", x = -26, y = 0, z = -36 },
		{ id = "Bath", title = "BANHEIRO", x = 26, y = 0, z = -36 },
		{ id = "Library", title = "BIBLIOTECA", x = -26, y = 0, z = -68 },
		{ id = "Machine", title = "SALA DE MÁQUINAS", x = 26, y = 0, z = -68 },
		{ id = "Bedroom", title = "QUARTO", x = -26, y = 16, z = -4 },
		{ id = "Child", title = "QUARTO INFANTIL", x = 26, y = 16, z = -4 },
		{ id = "Office", title = "ESCRITÓRIO", x = -26, y = 16, z = -36 },
		{ id = "Locked", title = "SALA TRANCADA", x = 26, y = 16, z = -36 },
		{ id = "Attic", title = "SÓTÃO", x = -26, y = 32, z = -4 },
		{ id = "AtticClock", title = "SÓTÃO / RELÓGIO", x = 26, y = 32, z = -4 },
		{ id = "AtticBook", title = "SÓTÃO / LIVRO", x = -26, y = 32, z = -36 },
		{ id = "AtticPhoto", title = "SÓTÃO / RETRATOS", x = 26, y = 32, z = -36 },
		{ id = "Basement", title = "PORÃO", x = -26, y = -16, z = -4 },
		{ id = "Symbols", title = "PORÃO / SÍMBOLOS", x = 26, y = -16, z = -4 },
		{ id = "Safe", title = "COFRE", x = -26, y = -16, z = -36 },
		{ id = "Tunnel", title = "TÚNEL SECRETO", x = 26, y = -16, z = -36 },
		{ id = "Ritual", title = "SALA RITUALÍSTICA", x = -26, y = -16, z = -68 },
		{ id = "Mechanism", title = "MECANISMO", x = 26, y = -16, z = -68 },
	} :: { Room },
	Chapters = {
		{
			title = "01 · A ENTRADA",
			subtitle = "Uma casa que não quer visitas",
			objectives = {
				objective("Hall", "Entrar na casa", "explore", nil, "entry"),
				objective(
					"Hall",
					"Recolher a lanterna",
					"collect",
					"flashlight",
					"flashlight",
					"F: lanterna. Luz ajuda a enxergar; depois poderá atrair a criatura."
				),
				-- Roteiro: a cadeira que balança é a Dona Cida; ela foge da lanterna. Apagar a luz e chegar devagar.
				objective(
					"Living",
					"Falar com a cadeira da Dona Cida no escuro",
					"activate",
					"cida_talk",
					nil,
					'A cadeira range e fala baixinho: "A caixinha da Lia ainda toca... mas só com a luz apagada."'
				),
				objective(
					"Living",
					"Encontrar a chave da sala",
					"collect",
					"key_living",
					nil,
					"Na caixinha de música da Lia, a chave presa na corda e a fita de cabelo dela amarrada."
				),
				objective(
					"Kitchen",
					"Encontrar a chave da cozinha",
					"collect",
					"key_kitchen",
					nil,
					"A mesa está posta. Na poeira, só há marcas recentes de um bastão."
				),
				objective(
					"Dining",
					"Encontrar a terceira chave",
					"collect",
					"key_dining",
					nil,
					"Três chaves guardadas para três pessoas que nunca voltaram."
				),
				objective("Hall", "Destrancar o corredor com as três chaves", "activate", nil, "corridor"),
				objective(
					"Library",
					"Ler a mensagem na biblioteca",
					"clue",
					"message",
					"silhouette",
					"Na margem da carta: ELE NÃO É O DONO. TAMBÉM ESTÁ PRESO. Três pancadas vêm do andar de cima."
				),
			},
		},
		{
			title = "02 · ELE ACORDOU",
			subtitle = "A casa respira com você",
			objectives = {
				-- Fusíveis da Família (banco v2): cada um no lugar favorito de alguém e enrolado em algo dele;
				-- no quadro de luz, cada encaixe tem o desenho da pessoa (HouseMiniPuzzles.fuseBoard).
				objective(
					"Living",
					"Recolher o primeiro fusível",
					"collect",
					"fuse_1",
					nil,
					"Um fusível enrolado em linha de tricô, igual ao novelo da cadeira de balanço."
				),
				objective(
					"Kitchen",
					"Recolher o segundo fusível",
					"collect",
					"fuse_2",
					nil,
					"Um fusível amarrado com uma fita de cabelo, igual à da caixinha de música."
				),
				objective(
					"Bath",
					"Recolher o terceiro fusível",
					"collect",
					"fuse_3",
					nil,
					"Um fusível enrolado no barbante de um pião, igual ao da tábua oca."
				),
				-- Óleo de máquina do Valdemar ("ÓLEO — OFICINA"): o gerador travado só volta untado.
				objective(
					"Machine",
					"Untar o gerador com o óleo da oficina",
					"activate",
					"generator_oil",
					nil,
					"As engrenagens do gerador giram de novo. No vidro do relógio do sótão há manchas desse mesmo óleo."
				),
				objective("Machine", "Encaixar cada fusível no desenho do dono", "activate", nil, "power"),
				objective(
					"Library",
					"Entrar no armário da biblioteca",
					"hide",
					nil,
					nil,
					"E: sair. Z/LB: segurar a respiração. Solte antes de zerar o oxigênio. Espaço: espiar pela fresta (sem exagerar)."
				),
				objective(
					"Library",
					"Segurar a respiração por dois segundos",
					"breath",
					nil,
					"awaken",
					"Você aprendeu a ficar em silêncio. Não segure até sufocar. Tung Tung agora está acordado."
				),
				objective("Library", "Abrir passagem para os andares superiores", "activate", nil, "upstairs"),
			},
		},
		{
			title = "03 · A MALDIÇÃO",
			subtitle = "Quatro lembranças, uma prisão",
			objectives = {
				objective(
					"AtticClock",
					"Recuperar o relógio amaldiçoado",
					"collect",
					"clock",
					nil,
					"Parado. Os outros relógios da casa também pararam, todos na mesma hora."
				),
				objective(
					"Attic",
					"Recuperar a máscara",
					"collect",
					"mask",
					nil,
					"Uma máscara de madeira. Por dentro, alguém escreveu: PARA ELE NÃO ME RECONHECER."
				),
				objective("AtticBook", "Ler o livro do relógio", "clue", "book", nil),
				objective(
					"AtticPhoto",
					"Encontrar a fotografia",
					"collect",
					"photo",
					nil,
					"Na fotografia, o vigia está ao lado da família. Antes de virar a criatura, ele tentou protegê-los."
				),
				objective(
					"Office",
					"Acertar o relógio do escritório na hora das fitas",
					"puzzle",
					nil,
					"basement",
					"A escada do porão se abre. O livro pede que devolvam o coração da casa."
				),
			},
		},
		{
			title = "04 · O PORÃO",
			subtitle = "O coração está trancado",
			objectives = {
				objective("Basement", "Inspecionar o painel do porão", "clue", "panel_clue", nil),
				objective(
					"Symbols",
					"Responder à Lia no piano com a música da caixinha",
					"puzzle",
					nil,
					nil,
					"Vocês lembraram. O Juca guardava tudo nas figurinhas."
				),
				objective("Tunnel", "Encontrar a pista do código do cofre", "clue", "safe_clue", nil),
				objective("Safe", "Abrir o cofre com as duas metades do código", "puzzle", nil, nil),
				objective(
					"Safe",
					"Recuperar o artefato",
					"collect",
					"artifact",
					nil,
					"O coração pulsa na sua mão. As pancadas cessaram. Agora a casa sabe onde vocês estão."
				),
				objective("Basement", "Destrancar a sala ritualística", "activate", nil, "ritual"),
			},
		},
		{
			title = "05 · A ÚLTIMA NOITE",
			subtitle = "Devolva o coração. Corra.",
			-- Roteiro "A Casa de Madeira" (sem gasolina): o coração sobrecarrega a máquina, que dá curto e pega fogo. O
			-- time derrama o óleo da máquina na madeira dos cômodos e leva o fogo dela na lamparina do Valdemar até o
			-- rastro (FireSpread: o óleo estoura em sequência e o fogo corre atrás de vocês). Os ids internos (gasoline,
			-- gas_pour, gas_ignite) continuam os mesmos.
			objectives = {
				objective(
					"Machine",
					"Pegar a lata de óleo da máquina",
					"collect",
					"gasoline",
					nil,
					"Óleo grosso de marceneiro. Nas engrenagens, a máquina dispara; na madeira, leva o fogo pela casa."
				),
				objective(
					"Ritual",
					"Untar as engrenagens e encaixar o coração na pausa",
					"activate",
					nil,
					nil,
					"A máquina dá curto e pega fogo; o coração pula para fora. Só o fogo acaba com esta casa."
				),
				objective("Library", "Derramar o óleo na biblioteca", "activate", "gas_pour", nil),
				objective("Dining", "Derramar o óleo na sala de jantar", "activate", "gas_pour", nil),
				objective("Living", "Derramar o óleo na sala de estar", "activate", "gas_pour", nil),
				objective(
					"Kitchen",
					"Pegar a lamparina do Valdemar",
					"collect",
					"lighter",
					nil,
					"A lamparina do Valdemar: a última luz que o Tum Tum viu antes da máquina. Ainda acende."
				),
				objective("Hall", "Derramar o óleo no corredor", "activate", "gas_pour", nil),
				objective(
					"Mechanism",
					"Levar o fogo da máquina ao rastro de óleo e fugir",
					"activate",
					"gas_ignite",
					"destruction",
					"O fogo corre pelo óleo. Saia pelo hall e atravesse o portão antes que a casa desabe!"
				),
			},
		},
	} :: { Chapter },
}
-- Itens que mudam de cômodo a cada partida (veredito 20/10: rejogar e procurar mais). Só cômodos já abertos
-- naquele capítulo; o HousePlan sorteia sem repetir dentro do capítulo.
local UPSTAIRS = { "Attic", "AtticPhoto", "Bedroom", "Child" }
local POOLS: { [string]: { string } } = {
	-- Lugares favoritos: Dona Cida na sala ou na mesa de jantar, Lia na biblioteca ou no jantar, Juca na cozinha ou
	-- no banheiro.
	fuse_1 = { "Living", "Dining" },
	fuse_2 = { "Library", "Dining" },
	fuse_3 = { "Kitchen", "Bath" },
	mask = UPSTAIRS,
	photo = UPSTAIRS,
	lighter = { "Kitchen", "Bath", "Bedroom", "Child" },
}
for _, chapter in House.Chapters do
	for _, entry in chapter.objectives do
		if entry.item and POOLS[entry.item] then
			entry.pool = table.clone(POOLS[entry.item])
		end
	end
end
local Forest = require("./ForestCatalog")
for _, chapter in Forest.Chapters do
	table.insert(House.Chapters, chapter)
end
return TableUtil.deepFreeze(House)
