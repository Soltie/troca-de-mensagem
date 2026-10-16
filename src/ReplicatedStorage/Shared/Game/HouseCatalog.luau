--!strict
-- Metadados públicos; soluções e sorteio pertencem ao HousePlan no servidor.
local TableUtil = require("../Util/TableUtil")
export type Room = { id: string, title: string, x: number, y: number, z: number }
export type Objective = { room: string, title: string, kind: string, item: string?, event: string?, revelation: string }
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
				objective(
					"Living",
					"Encontrar a chave da sala",
					"collect",
					"key_living",
					nil,
					"A chave tem a mesma marca da porta na fita. A televisão já estava ligada."
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
				objective("Living", "Recolher o primeiro fusível", "collect", "fuse_1", nil),
				objective("Kitchen", "Recolher o segundo fusível", "collect", "fuse_2", nil),
				objective("Bath", "Recolher o terceiro fusível", "collect", "fuse_3", nil),
				objective("Machine", "Restaurar energia parcial", "activate", nil, "power"),
				objective(
					"Library",
					"Entrar no armário da biblioteca",
					"hide",
					nil,
					nil,
					"E: sair. Espaço escondido ou Z/LB: segurar a respiração. Solte antes de zerar o oxigênio."
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
					"03:12. O mesmo horário gravado em todas as fitas."
				),
				objective(
					"Attic",
					"Recuperar a máscara",
					"collect",
					"mask",
					nil,
					"Uma máscara de madeira. Por dentro, alguém escreveu: PARA ELE NÃO ME RECONHECER."
				),
				objective("AtticBook", "Ler o livro de símbolos", "clue", "book", nil),
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
					"Reproduzir os símbolos do livro",
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
				objective("Symbols", "Resolver os quatro símbolos", "puzzle", nil, nil),
				objective("Tunnel", "Encontrar a pista do código do cofre", "clue", "safe_clue", nil),
				objective("Safe", "Abrir o cofre usando a pista", "puzzle", nil, nil),
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
			objectives = {
				objective("Ritual", "Colocar o artefato no altar", "activate", nil, nil),
				objective("Ritual", "Ativar o primeiro símbolo", "activate", nil, nil),
				objective("Ritual", "Ativar o segundo símbolo", "activate", nil, nil),
				objective("Ritual", "Ativar o terceiro símbolo", "activate", nil, nil),
				objective(
					"Mechanism",
					"Acionar o mecanismo e fugir",
					"activate",
					nil,
					"destruction",
					"A casa está ruindo. 150 segundos: volte pelo hall e atravesse o portão da floresta."
				),
			},
		},
	} :: { Chapter },
}
return TableUtil.deepFreeze(House)
