--!strict
--[[
	Todos os textos do jogo (PT-BR) num lugar só. A UI e o servidor usam as chaves daqui.
	Tudo que aparece em fonte pixel passa por PixelText.normalize (ver PixelText.luau);
	os bilhetes (Notes) usam outra fonte e mantêm a acentuação completa.
]]

local PixelText = require("./PixelText")

local Text = {
	Title = "SUBESTAÇÃO 9",

	Intro = {
		"03:12 - QUEDA TOTAL DE ENERGIA.",
		"TROQUE OS 3 FUSÍVEIS DO QUADRO PRINCIPAL.",
		"DEPOIS, SAIA PELO PORTÃO ELÉTRICO.",
		"O RÁDIO DO VIGIA NÃO RESPONDE DESDE A MEIA-NOITE.",
	},
	IntroControls = "WASD MOVER  ·  SHIFT CORRER  ·  F LANTERNA  ·  E INTERAGIR  ·  H AJUDA",

	Objectives = {
		enter = "ENTRE NA SUBESTAÇÃO",
		fuses = "ENCONTRE OS FUSÍVEIS",
		insert = "LEVE OS FUSÍVEIS AO QUADRO (SALA DO GERADOR)",
		escape = "A ENERGIA VOLTOU. ABRA O PORTÃO!",
		run = "FUJA PELO PORTÃO!",
	},
	ObjectiveHeld = "VOCÊ TEM %d - LEVE AO QUADRO",

	Prompts = {
		Fuse = "PEGAR FUSÍVEL",
		Panel = "QUADRO DE FORÇA",
		DoorOpen = "ABRIR PORTA",
		DoorClose = "FECHAR PORTA",
		Gate = "ABRIR PORTÃO",
		Note = "LER BILHETE",
	},

	-- Mensagens que o servidor devolve no Result (chave -> texto).
	Messages = {
		fuse_taken = "FUSÍVEL GUARDADO.",
		fuses_inserted = "FUSÍVEL ENCAIXADO NO QUADRO.",
		no_fuses = "FALTAM FUSÍVEIS. PROCURE NAS SALAS.",
		already_powered = "O QUADRO JÁ ESTÁ LIGADO.",
		power_restored = "A ENERGIA VOLTOU...",
		no_power = "SEM ENERGIA. O PORTÃO É ELÉTRICO.",
		gate_opening = "O PORTÃO ESTÁ ABRINDO!",
		already_open = "JÁ ESTÁ ABERTO.",
		door_opened = "",
		door_closed = "",
		not_available = "NADA AQUI.",
		too_far = "CHEGUE MAIS PERTO.",
		blocked = "ALGO ESTÁ NO CAMINHO.",
		not_playing = "",
		dead = "",
		unknown = "NADA AQUI.",
	},

	-- Eventos da rodada mostrados como legenda.
	Captions = {
		awaken = "ALGO SE MEXEU LÁ DENTRO.",
		spotted = "ELE TE VIU. CORRA!",
		lost = "ELE PERDEU SEU RASTRO...",
		power = "A ENERGIA VOLTOU. ELE SABE ONDE VOCÊ ESTÁ.",
		gate = "O PORTÃO ESTÁ ABRINDO!",
	},

	Notes = {
		note_order = "ORDEM DE SERVIÇO 0312\n\nQueda total na Subestação 9.\nTrocar os 3 fusíveis do quadro principal (Sala do Gerador).\nOs reservas ficaram espalhados depois da última manutenção.\n\nObs.: o rádio do vigia não responde.",
		note_office = "Seu Ademir continua fazendo a ronda.\nToda noite. Mesmo depois do enterro.\n\nSe ouvir os passos dele, apague a lanterna.\n\nELE SEGUE A LUZ.",
		note_storage = "Não corra perto dele.\nEle escuta.\n\nQuando a luz voltar, ele vai saber onde você está.\nNão pare até o portão.\n\n- J.",
	},
	NoteClose = "[E] FECHAR",

	EndWon = {
		title = "VOCÊ ESCAPOU",
		subtitle = "O VIGIA CONTINUA O TURNO.",
	},
	EndLost = {
		title = "O VIGIA TE ENCONTROU",
		subtitle = "O TURNO NÃO TERMINOU.",
	},
	EndStats = "TEMPO %s   ·   FUSÍVEIS %d/%d",
	Restart = "[R] JOGAR DE NOVO",

	Help = {
		"WASD - MOVER",
		"MOUSE - OLHAR",
		"SHIFT - CORRER (FÔLEGO)",
		"F - LANTERNA",
		"E - INTERAGIR",
		"V - FILTRO RETRÔ: %s",
		"B - BALANÇO DE CÂMERA: %s",
		"H - FECHAR AJUDA",
	},
	HelpHint = "[H] AJUDA",
	On = "LIGADO",
	Off = "DESLIGADO",
	SettingRetro = "FILTRO RETRÔ: %s",
	SettingMotion = "BALANÇO DE CÂMERA: %s",
	Flashlight = "LANTERNA",
}

-- Normaliza tudo, menos os bilhetes.
local function normalize(value: any): any
	if type(value) == "string" then
		return PixelText.normalize(value)
	elseif type(value) == "table" then
		local out = {}
		for key, item in value do
			out[key] = normalize(item)
		end
		return out
	end
	return value
end

local notes = Text.Notes
local result = normalize(Text)
result.Notes = notes

return table.freeze(result :: typeof(Text))
