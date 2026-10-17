--!strict
-- Continuação pública da história; geometria e soluções são decididas pelo servidor.
local TableUtil = require("../Util/TableUtil")
export type Room = { id: string, title: string, x: number, y: number, z: number }
export type Objective = { room: string, title: string, kind: string, item: string?, event: string?, revelation: string }
export type Chapter = { title: string, subtitle: string, objectives: { Objective } }
local Forest = {
	FirstChapter = 6,
	LastChapter = 8,
	Spawn = { x = 0, y = 0, z = 580 },
	Exit = { x = 0, y = 0, z = 870 },
	Rooms = {
		{ id = "ForestTrail", title = "TRILHA DAS TRÊS PANCADAS", x = 0, y = 0, z = 640 },
		{ id = "ForestCamp", title = "ACAMPAMENTO ABANDONADO", x = -38, y = 0, z = 700 },
		{ id = "ForestRadio", title = "POSTO DE RÁDIO", x = 38, y = 0, z = 760 },
		{ id = "ForestTower", title = "TORRE DO ÚLTIMO SINAL", x = 38, y = 0, z = 700 },
		{ id = "ForestRoad", title = "ESTRADA DO RESGATE", x = 0, y = 0, z = 850 },
	} :: { Room },
	-- Seis abrigos físicos, um por jogador; afastados das estações e da rota central.
	Hides = {
		{ x = -24, y = 0, z = 670 },
		{ x = 24, y = 0, z = 670 },
		{ x = -24, y = 0, z = 730 },
		{ x = 24, y = 0, z = 730 },
		{ x = -24, y = 0, z = 790 },
		{ x = 24, y = 0, z = 790 },
	},
	Chapters = {
		{
			title = "06 · AS TRÊS PANCADAS",
			subtitle = "A casa ficou para trás. Ele não.",
			objectives = {
				{
					room = "ForestTrail",
					title = "Alcançar a trilha marcada",
					kind = "explore",
					revelation = "As cinzas ficaram para trás. Três pancadas respondem entre as árvores.",
				},
				{
					room = "ForestCamp",
					title = "Recolher o mapa do guarda florestal",
					kind = "collect",
					item = "forest_map",
					revelation = "O guarda desenhou uma rota até o acampamento. A margem avisa: a maldição saiu junto com vocês.",
				},
				{
					room = "ForestTrail",
					title = "Esconder-se num abrigo de madeira",
					kind = "hide",
					revelation = "Ele segue a luz e o barulho. Os abrigos escondem uma pessoa de cada vez.",
				},
				{
					room = "ForestTrail",
					title = "Ficar em silêncio por dois segundos",
					kind = "breath",
					revelation = "A batida passa pelo abrigo. Solte a respiração antes de faltar ar e siga as lanternas amarelas.",
				},
				{
					room = "ForestRoad",
					title = "Abrir a passagem para o acampamento",
					kind = "activate",
					revelation = "O rádio do guarda ainda pode funcionar. É a única forma de pedir ajuda.",
				},
			},
		},
		{
			title = "07 · O ACAMPAMENTO VAZIO",
			subtitle = "Uma voz no chiado",
			objectives = {
				{
					room = "ForestCamp",
					title = "Buscar o fusível do posto",
					kind = "collect",
					item = "forest_fuse",
					revelation = "As barracas estão vazias. No chão, pegadas humanas terminam ao lado de marcas de um bastão.",
				},
				{
					room = "ForestRadio",
					title = "Ler o diário do guarda",
					kind = "clue",
					item = "forest_diary",
					revelation = "O guarda escreveu: queimamos a casa, mas o eco ficou. A torre transmite além da floresta.",
				},
				{
					room = "ForestRadio",
					title = "Consertar o rádio de emergência",
					kind = "repair",
					revelation = "Uma voz responde: cheguem à torre e acendam o sinal. Não sigam vozes fora da trilha.",
				},
				{
					room = "ForestCamp",
					title = "Se esconder durante as pancadas",
					kind = "hide",
					revelation = "A transmissão atraiu Tung Tung. Apaguem as lanternas e procurem um abrigo livre.",
				},
				{
					room = "ForestCamp",
					title = "Segurar a respiração por dois segundos",
					kind = "breath",
					revelation = "Silêncio. O rádio voltou a chiar. Agora vocês sabem para onde correr.",
				},
				{
					room = "ForestRoad",
					title = "Destrancar a trilha da torre",
					kind = "activate",
					revelation = "A torre pisca ao longe. O resgate está esperando um sinal.",
				},
			},
		},
		{
			title = "08 · ANTES DO AMANHECER",
			subtitle = "Um último sinal. Uma última corrida.",
			objectives = {
				{
					room = "ForestCamp",
					title = "Recolher a bateria de emergência",
					kind = "collect",
					item = "forest_battery",
					revelation = "A bateria ainda tem carga. Atrás das árvores, o bastão arrasta no chão.",
				},
				{
					room = "ForestRadio",
					title = "Restaurar o gerador da torre",
					kind = "repair",
					revelation = "A torre tem energia. O rádio pede a localização. A luz também chama Tung Tung.",
				},
				{
					room = "ForestTower",
					title = "Transmitir o pedido de resgate",
					kind = "activate",
					revelation = "Recebido. A van está chegando à estrada. Mantenham-se escondidos até o sinal.",
				},
				{
					room = "ForestTower",
					title = "Esconder-se da última patrulha",
					kind = "hide",
					revelation = "Três pancadas. Ele está perto. Cada pessoa precisa de um abrigo livre.",
				},
				{
					room = "ForestTower",
					title = "Segurar a respiração por dois segundos",
					kind = "breath",
					revelation = "O motor do resgate corta o silêncio. Agora é a hora.",
				},
				{
					room = "ForestRoad",
					title = "Acender o sinal e correr para a van",
					kind = "activate",
					event = "forest_rescue",
					revelation = "O farol verde marca a van. Corram juntos; ajudem quem cair. Não olhem para trás.",
				},
			},
		},
	} :: { Chapter },
}
return TableUtil.deepFreeze(Forest)
