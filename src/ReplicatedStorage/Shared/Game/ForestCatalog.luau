--!strict
-- Continuação da casa: pistas legíveis, mecanismos ruidosos e fuga real no servidor.
local TableUtil = require("../Util/TableUtil")
local ForestMaps = require("./ForestMaps")
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
			title = "06 · A MATA ESCUTA",
			subtitle = "A casa ficou para trás. A neblina escuta cada passo.",
			objectives = {
				{
					room = "MistTrail",
					title = "Seguir as marcas amarelas do guarda",
					kind = "explore",
					revelation = "Na árvore, em tinta amarela: A MATA ESCUTA. FOLHAS SECAS ESTALAM E OS CORVOS GRITAM. ANDEM ABAIXADOS.",
				},
				{
					room = "MistCamp",
					title = "Recolher o mapa rasgado",
					kind = "collect",
					item = "forest_map",
					revelation = "O guarda tentou levar seis pessoas até a estrada. Ninguém chegou. A ponte da ravina foi sabotada.",
				},
				{
					room = "MistTrail",
					title = "Ler o aviso sobre o caçador",
					kind = "clue",
					item = "forest_warning",
					revelation = "Ele não carrega luz nesta mata. Corridas, lanternas e mecanismos denunciam vocês. Árvores e abrigos quebram a visão.",
				},
				{
					room = "MistCamp",
					title = "Buscar a manivela do guincho",
					kind = "collect",
					item = "forest_crank",
					revelation = "A manivela está suja de lama. Ao lado, duas pegadas diferentes: uma funda e outra arrastada.",
				},
				{
					room = "RavineEdge",
					title = "Consertar o guincho e erguer a ponte",
					kind = "repair",
					event = "forest_winch",
					revelation = "As tábuas subiram rangendo e a ponte voltou ao lugar. O metal ecoou na ravina inteira. Ele ouviu.",
				},
				{
					room = "NorthBank",
					title = "Atravessar a ponte",
					kind = "explore",
					event = "forest_bridge_fall",
					revelation = "Ele veio atrás pela ponte. As tábuas não aguentaram: o caçador caiu no rio. Não há volta.",
				},
				{
					room = "MistRoad",
					title = "Soltar o cabo e abrir a próxima trilha",
					kind = "activate",
					event = "forest_passage",
					revelation = "Uma transmissão se repete no chiado: NÃO LEVEM O MAPA À MANSÃO. Quem está chamando?",
				},
			},
		},
		{
			title = "07 · NINGUÉM NO RÁDIO",
			subtitle = "A voz sabe seus nomes. O guarda não deveria saber.",
			objectives = {
				{
					room = "ForestCamp",
					title = "Buscar o fusível no acampamento",
					kind = "collect",
					item = "forest_fuse",
					revelation = "Os pratos ainda estão na mesa. Alguém saiu correndo. O rádio foi desligado por dentro.",
				},
				{
					room = "ForestRadio",
					title = "Recuperar a frequência no diário",
					kind = "clue",
					item = "forest_radio_clue",
					revelation = "O diário traz a sequência dos canais. A última linha diz: A SEGUNDA VOZ IMITA O RESGATE.",
				},
				{
					room = "ForestRadio",
					title = "Restaurar o circuito do transmissor",
					kind = "repair",
					event = "forest_blackout",
					revelation = "O transmissor voltou. As lâmpadas da trilha apagaram. Fiquem fora da linha reta.",
				},
				{
					room = "ForestRadio",
					title = "Sintonizar os quatro canais do diário",
					kind = "puzzle",
					revelation = "Uma voz humana responde com a senha do guarda. A outra continua repetindo os nomes de vocês.",
				},
				{
					room = "ForestCamp",
					title = "Recolher a fita de emergência",
					kind = "collect",
					item = "forest_tape",
					revelation = "Na fita, um motor, três pancadas e um rugido impossível. O guarda gravou DOIS perseguidores.",
				},
				{
					room = "ForestRadio",
					title = "Enviar a senha do resgate",
					kind = "activate",
					event = "forest_broadcast",
					revelation = "Resgate confirmado: ativem a torre. Se alguém oferecer abrigo numa mansão, NÃO PAREM.",
				},
				{
					room = "ForestCamp",
					title = "Sumir no abrigo durante a busca",
					kind = "hide",
					revelation = "Passos rodeiam o acampamento. A criatura não precisa brilhar para encontrar uma lanterna.",
				},
				{
					room = "ForestCamp",
					title = "Silenciar a respiração por dois segundos",
					kind = "breath",
					revelation = "O bastão raspa a porta. Depois, silêncio. Não confundam silêncio com segurança.",
				},
				{
					room = "ForestRoad",
					title = "Destravar o acesso à torre",
					kind = "activate",
					event = "forest_passage",
					revelation = "O farol da torre está morto. A estrada só será segura depois do sinal.",
				},
			},
		},
		{
			title = "08 · ELES OUVIRAM O SINAL",
			subtitle = "O resgate chega. A perseguição também.",
			objectives = {
				{
					room = "ForestCamp",
					title = "Recolher a bateria de emergência",
					kind = "collect",
					item = "forest_battery",
					revelation = "A bateria conserva a última carga. Não há energia para uma segunda chamada.",
				},
				{
					room = "ForestTrail",
					title = "Recuperar a antena caída",
					kind = "collect",
					item = "forest_antenna",
					revelation = "A antena foi arrancada. No metal, marcas de dentes. O guarda não estava inventando.",
				},
				{
					room = "ForestRadio",
					title = "Conectar bateria e antena à torre",
					kind = "repair",
					event = "forest_blackout",
					revelation = "A torre ligou. Três pancadas respondem, muito mais perto. Saiam da área iluminada.",
				},
				{
					room = "ForestTower",
					title = "Ler o código de autenticação do guarda",
					kind = "clue",
					item = "forest_tower_clue",
					revelation = "Apenas a sequência gravada confirma o resgate verdadeiro. A voz errada pede que sigam para a mansão.",
				},
				{
					room = "ForestTower",
					title = "Autenticar o sinal nos quatro canais",
					kind = "puzzle",
					revelation = "O motorista confirmou a senha. A van entra na estrada. Vocês ainda precisam chegar vivos.",
				},
				{
					room = "ForestTower",
					title = "Manter a transmissão até confirmar o resgate",
					kind = "activate",
					event = "forest_broadcast",
					revelation = "A buzina é o sinal. O rádio avisa: NÃO É SÓ O TUNG TUNG QUE ESTÁ PROCURANDO VOCÊS.",
				},
				{
					room = "ForestTower",
					title = "Esconder-se da última varredura",
					kind = "hide",
					revelation = "Não respondam à voz entre as árvores. Guardem o fôlego para a estrada.",
				},
				{
					room = "ForestTower",
					title = "Prender a respiração por dois segundos",
					kind = "breath",
					revelation = "A buzina soou. Esta é a última chance; ajudem quem cair e corram juntos.",
				},
				{
					room = "ForestRoad",
					title = "Acender o sinal e alcançar a van",
					kind = "activate",
					event = "forest_rescue",
					revelation = "O farol verde marca a saída. Vocês fugiram da mata. Mas o rádio já revelou o destino.",
				},
			},
		},
	} :: { Chapter },
}
-- Lugares dos mapas novos (floresta v2) entram junto com os antigos (ids diferentes).
for _, room in ForestMaps.allRooms() do
	table.insert(Forest.Rooms, room)
end
-- Abrigos do capítulo: o mapa novo, se existir; senão os antigos.
function Forest.hidesFor(chapter: number): { { x: number, y: number, z: number } }
	local map = ForestMaps.get(chapter)
	return if map then map.hides else Forest.Hides
end
return TableUtil.deepFreeze(Forest)
