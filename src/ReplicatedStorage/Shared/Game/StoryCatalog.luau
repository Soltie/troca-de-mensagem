--!strict
-- Roteiro canônico. Mesmas salas, atividades e sequências em toda sessão de história.
local TableUtil = require("../Util/TableUtil")
local Shots = require("./CinematicShots")

export type Objective = { slot: string, title: string, kind: string, order: { number }, revelation: string }
export type Chapter = { title: string, subtitle: string, objectives: { Objective } }

local function scene(name: string, points: { { number } }, labels: { string }): Shots.Sequence
	local shots: { Shots.Shot } = {}
	for i, p in points do
		local position = { x = p[1], y = p[2], z = p[3] }
		local look = { x = p[4], y = p[5], z = p[6] }
		table.insert(shots, {
			label = labels[i],
			from = position,
			to = position,
			lookFrom = look,
			lookTo = look,
			duration = 4,
			fov = 58,
			ease = "linear",
			handheld = 0,
			cut = "static",
		})
	end
	return { name = name, shots = shots }
end

local Story = {
	Title = "O ÚLTIMO TURNO",
	MapSeed = 90312,
	SceneSeconds = 12,
	Chapters = {
		{
			title = "01 · A EQUIPE QUE NÃO VOLTOU",
			subtitle = "03:12 · ACESSO À SUBESTAÇÃO 9",
			objectives = {
				{
					slot = "lobby",
					title = "Restaurar o rádio da recepção",
					kind = "repair",
					order = { 1, 2, 3 },
					revelation = "RÁDIO / 03:12: 'Equipe de manutenção, respondam. O portão foi fechado por dentro.'",
				},
				{
					slot = "office",
					title = "Recuperar o registro do turno",
					kind = "sequence",
					order = { 3, 1, 2 },
					revelation = "REGISTRO: Elias Moura, vigia noturno. Última saída registrada: nenhuma.",
				},
				{
					slot = "generator",
					title = "Religar o circuito de emergência",
					kind = "relay",
					order = { 1, 2, 3 },
					revelation = "FITA 01: 'Elias mandou apagar as lanternas. Disse que alguma coisa estava usando os olhos dele.'",
				},
			},
		},
		{
			title = "02 · NINGUÉM DEIXA O POSTO",
			subtitle = "03:26 · REGISTROS DO INCIDENTE",
			objectives = {
				{
					slot = "archive",
					title = "Reconstruir a gravação do acidente",
					kind = "sequence",
					order = { 2, 3, 1 },
					revelation = "FITA 02: Elias abriu a evacuação. A central cancelou a ordem: 'Proteja a instalação. Não abandone o posto.'",
				},
				{
					slot = "control",
					title = "Isolar o sinal da central",
					kind = "relay",
					order = { 1, 2, 3 },
					revelation = "CENTRAL: 'Funcionário 009. O turno termina quando o último circuito apagar.' A mensagem se repete há décadas.",
				},
				{
					slot = "gallery",
					title = "Reparar a linha de isolamento",
					kind = "repair",
					order = { 1, 2, 3 },
					revelation = "LAUDO: Elias ficou ligado ao circuito no acidente. Ele segue a luz porque cada lâmpada é um posto que ainda precisa guardar.",
				},
			},
		},
		{
			title = "03 · O FIM DO TURNO",
			subtitle = "03:41 · DESLIGAMENTO DEFINITIVO",
			objectives = {
				{
					slot = "pump",
					title = "Desarmar a alimentação auxiliar",
					kind = "repair",
					order = { 1, 2, 3 },
					revelation = "RÁDIO: 'O portão tem bateria própria. Desliguem a subestação; não religuem o circuito principal.'",
				},
				{
					slot = "generator",
					title = "Executar o protocolo de desligamento",
					kind = "sequence",
					order = { 3, 2, 1 },
					revelation = "ELIAS, NA FITA: 'Se alguém ouvir isto, diga à minha filha que eu tentei abrir o portão.'",
				},
				{
					slot = "yard_south",
					title = "Liberar juntos o circuito do portão",
					kind = "relay",
					order = { 1, 2, 3 },
					revelation = "O sinal da central se cala. Reúnam os sobreviventes e atravessem o portão. Ninguém fica para trás.",
				},
			},
		},
	} :: { Chapter },
	Scenes = {
		scene(
			"StoryArrival",
			{ { -27, 9, 40, 14, 3, 30 }, { 4, 5, 18, -4, 4, 0 }, { 14, 6, 26, -4, 3, 0 } },
			{ "03:12 · ACESSO", "SUBESTAÇÃO 9", "ORDEM DE SERVIÇO 009" }
		),
		scene(
			"StoryRecords",
			{ { 17, 4, -65, 24, 3, -69 }, { -8, 4, -61, -8, 3, -68 }, { -27, 9, 40, -4, 3, 0 } },
			{ "FITA DO INCIDENTE", "CENTRAL DE CONTROLE", "O POSTO DO VIGIA" }
		),
		scene(
			"StoryShutdown",
			{ { -15, 4, -31, -10, 3, -32 }, { 56, 4, -13, 62, 3, -18 }, { 8, 6, 37, 0, 3, 44 } },
			{ "ÚLTIMO CIRCUITO", "ALIMENTAÇÃO DO PORTÃO", "SAÍDA DE EMERGÊNCIA" }
		),
	},
	SceneLines = {
		{
			"A equipe anterior não voltou. Vocês receberam a mesma ordem de serviço.",
			"Na guarita, o livro de ponto continua aberto em uma única noite.",
			"RÁDIO: 'Entrem juntos. Se virem alguém no corredor, apaguem a luz.'",
		},
		{
			"O homem chamado Vigia tinha um nome: Elias Moura.",
			"Na noite do acidente, ele tentou evacuar os funcionários. A central o impediu.",
			"Desde então, a ordem nunca mudou: ninguém deixa o posto enquanto houver luz.",
		},
		{
			"Restaurar a energia só prolongou o turno. Agora vocês sabem como encerrá-lo.",
			"Isolem a alimentação principal. Usem o circuito independente para abrir a saída.",
			"Desta vez, a ordem é outra: tirem todos daqui.",
		},
	},
	Ending = "04:03. Pela primeira vez, o livro de ponto registra uma saída.\nELIAS MOURA — TURNO ENCERRADO.\nNa estrada, o rádio transmite uma última palavra: 'Obrigado.'",
}

return TableUtil.deepFreeze(Story)
