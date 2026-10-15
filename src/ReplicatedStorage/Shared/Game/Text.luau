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
		"TROQUE OS 3 FUSÍVEIS DO QUADRO E RELIGUE OS DISJUNTORES.",
		"DEPOIS, SAIA PELO PORTÃO ELÉTRICO.",
		"O RÁDIO DO VIGIA NÃO RESPONDE DESDE A MEIA-NOITE.",
	},
	IntroControls = "WASD MOVER  ·  SHIFT CORRER  ·  C AGACHAR  ·  F LANTERNA  ·  E INTERAGIR  ·  H AJUDA",

	Objectives = {
		enter = "ENTRE NA SUBESTAÇÃO",
		fuses = "ENCONTRE OS FUSÍVEIS",
		insert = "LEVE OS FUSÍVEIS AO QUADRO (SALA DO GERADOR)",
		breakers = "RELIGUE OS DISJUNTORES NA ORDEM DO PROCEDIMENTO",
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
		Procedure = "LER PROCEDIMENTO",
		Hide = "ESCONDER",
		Key = "PEGAR CHAVE",
		Battery = "PEGAR PILHAS",
		Breaker = "DISJUNTOR %s",
		DoorLocked = "TRANCADA",
		DoorUnlock = "DESTRANCAR",
		DoorCrack = "ENTREABRIR",
		DoorShut = "FECHAR",
	},
	-- Tecla da ação alternativa das portas.
	AltKey = "[Q]",
	HiddenHint = "[E] SAIR   ·   [ESPAÇO] PRENDER A RESPIRAÇÃO",
	HoldingBreath = "PRENDENDO A RESPIRAÇÃO...",

	-- Mensagens que o servidor devolve no Result (chave -> texto).
	Messages = {
		fuse_taken = "FUSÍVEL GUARDADO.",
		fuses_inserted = "FUSÍVEL ENCAIXADO NO QUADRO.",
		panel_ready = "QUADRO COMPLETO. AGORA OS DISJUNTORES.",
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
		key_taken = "CHAVE DO DEPÓSITO.",
		door_locked = "TRANCADA. PRECISA DE UMA CHAVE.",
		door_unlocking = "",
		already_unlocked = "JÁ ESTÁ DESTRANCADA.",
		door_cracked = "",
		battery_taken = "PILHAS NOVAS.",
		need_fuses = "ENCAIXE OS 3 FUSÍVEIS NO QUADRO ANTES.",
		breaker_ok = "",
		breaker_wrong = "ORDEM ERRADA! O QUADRO DESARMOU.",
		breakers_done = "SISTEMA RELIGADO...",
		hide_occupied = "OCUPADO.",
		hide_enter = "",
		hide_exit = "",
	},
	-- Avisos locais (cliente).
	Hints = {
		no_room = "SEM ESPAÇO PARA LEVANTAR.",
		battery_dead = "A LANTERNA APAGOU.",
		battery_empty = "SEM CARGA. DEIXE A PILHA DESCANSAR UM POUCO.",
		battery_low = "A LUZ ESTÁ FRACA.",
		checkpoint = "PROGRESSO SALVO.",
		gasp = "VOCÊ PERDEU O FÔLEGO!",
	},

	-- Eventos da rodada mostrados como legenda.
	Captions = {
		awaken = "ALGO SE MEXEU LÁ DENTRO.",
		spotted = "ELE TE VIU. CORRA!",
		lost = "ELE PERDEU SEU RASTRO...",
		power = "A ENERGIA VOLTOU. ELE SABE ONDE VOCÊ ESTÁ.",
		found = "ELE TE OUVIU.",
		gate = "O PORTÃO ESTÁ ABRINDO!",
	},

	Notes = {
		note_order = "ORDEM DE SERVIÇO 0312\n\nQueda total na Subestação 9.\nTrocar os 3 fusíveis do quadro principal (Sala do Gerador).\nOs reservas ficaram espalhados depois da última manutenção.\n\nObs.: o rádio do vigia não responde.",
		note_office = "Seu Ademir continua fazendo a ronda.\nToda noite. Mesmo depois do enterro.\n\nSe ouvir os passos dele, apague a lanterna.\n\nELE SEGUE A LUZ.",
		note_storage = "Não corra perto dele.\nEle escuta.\n\nQuando a luz voltar, ele vai saber onde você está.\nNão pare até o portão.\n\n- J.",
		-- %s = ordem da rodada (ex.: "B - C - A").
		note_breakers = "PROCEDIMENTO DE RELIGAMENTO\n\nCom os 3 fusíveis no quadro, levantar os disjuntores NESTA ORDEM:\n\n        %s\n\nFora de ordem o quadro desarma. E o barulho chama atenção.",
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
	RestartAll = "[R] REINICIAR TUDO",
	Continue = "[C] CONTINUAR DO CHECKPOINT",

	Help = {
		"WASD - MOVER",
		"MOUSE - OLHAR",
		"SHIFT - CORRER (FÔLEGO)",
		"C / CTRL - AGACHAR (ALTERNA / SEGURA)",
		"F - LANTERNA (BATERIA NOS LEDS)",
		"E - INTERAGIR   ·   Q - ENTREABRIR PORTA",
		"ESPAÇO - PRENDER A RESPIRAÇÃO (ESCONDIDO)",
		"TAB - INVENTÁRIO E OBJETIVO",
		"O - OPÇÕES DE CONFORTO",
		"H - FECHAR AJUDA",
	},
	HelpHint = "[H] AJUDA",
	On = "LIGADO",
	Off = "DESLIGADO",
	SettingRetro = "FILTRO RETRÔ: %s",
	SettingMotion = "MOVIMENTO DE CÂMERA: %s",
	Options = {
		title = "OPÇÕES DE CONFORTO",
		footer = "[1-8] ALTERNAR   ·   [O] FECHAR",
		bob = "BALANÇO AO ANDAR",
		tilt = "INCLINAÇÃO LATERAL",
		shake = "TREMORES",
		fov = "FOV DINÂMICO",
		flashes = "CLARÕES E FALHAS DE TELA",
		retro = "FILTRO RETRÔ",
		vhs = "VHS (DATA, TRACKING, CORES)",
		haptics = "VIBRAÇÃO (CONTROLE)",
	},
	Inventory = {
		title = "INVENTÁRIO",
		fuses = "FUSÍVEIS NA MÃO: %d   ·   NO QUADRO: %d/%d",
		key = "CHAVE DO DEPÓSITO",
		noKey = "SEM CHAVE",
		battery = "BATERIA: %d%%",
	},
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
