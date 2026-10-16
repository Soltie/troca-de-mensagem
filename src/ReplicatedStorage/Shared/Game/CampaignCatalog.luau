--!strict
-- Conteúdo da campanha; os pontos foram escolhidos fora dos corredores e dos objetivos legados.
local TableUtil = require("../Util/TableUtil")

export type Slot = { id: string, room: string, x: number, z: number }
export type Link = { id: string, a: string, b: string, x: number, z: number, axis: string, optional: boolean }

local Catalog = {
	RoomNames = {
		Lobby = "RECEPÇÃO",
		Office = "ESCRITÓRIO",
		Pump = "BOMBAS",
		Generator = "GERADOR",
		Storage = "DEPÓSITO",
		Maintenance = "OFICINA",
		CableGallery = "GALERIA",
		Control = "CONTROLE",
		Archive = "ARQUIVO",
		Switchyard = "PÁTIO TÉCNICO",
	},
	KindNames = { repair = "REPARO", sequence = "SEQUÊNCIA", relay = "RELÉ COOPERATIVO" },
	Stages = {
		{ id = "reconnect", title = "RECONEXÃO", kinds = { "repair", "sequence" }, threat = "watcher" },
		{ id = "synchronize", title = "SINCRONIZAÇÃO", kinds = { "relay", "sequence", "repair" }, threat = "echo" },
		{ id = "evacuate", title = "EVACUAÇÃO", kinds = { "relay", "repair", "sequence" }, threat = "blackout" },
	},
	Roles = {
		{ id = "technician", title = "TÉCNICO", description = "Repara circuitos com menos etapas." },
		{ id = "medic", title = "SOCORRISTA", description = "Resgata colegas mais rápido." },
		{ id = "scout", title = "BATEDOR", description = "Enxerga estações próximas no painel de equipe." },
		{ id = "operator", title = "OPERADOR", description = "Mantém relés ativos por mais tempo." },
	},
	Threats = {
		watcher = { title = "O VIGIA", description = "Patrulha e persegue a luz." },
		echo = { title = "ECO", description = "Eventos de ruído atraem o Vigia." },
		blackout = { title = "APAGÃO", description = "Interrupções de energia pressionam a equipe." },
	},
	Slots = {
		{ id = "lobby", room = "Lobby", x = -4, z = -12 },
		{ id = "office", room = "Office", x = -25, z = -13 },
		{ id = "pump", room = "Pump", x = 30, z = -16 },
		{ id = "generator", room = "Generator", x = -10, z = -32 },
		{ id = "storage", room = "Storage", x = 24, z = -36.2 },
		{ id = "workshop_south", room = "Maintenance", x = -59, z = -10 },
		{ id = "workshop_north", room = "Maintenance", x = -59, z = -40 },
		{ id = "gallery", room = "CableGallery", x = -48, z = -71 },
		{ id = "control", room = "Control", x = -8, z = -68 },
		{ id = "archive", room = "Archive", x = 20, z = -69 },
		{ id = "yard_north", room = "Switchyard", x = 56, z = -54 },
		{ id = "yard_south", room = "Switchyard", x = 62, z = -18 },
	} :: { Slot },
	Links = {
		{ id = "entry", a = "Courtyard", b = "Lobby", x = -4, z = 0, axis = "X", optional = false },
		{ id = "lobby_office", a = "Lobby", b = "Office", x = -12, z = -9, axis = "Z", optional = false },
		{ id = "lobby_pump", a = "Lobby", b = "Pump", x = 4, z = -9, axis = "Z", optional = false },
		{ id = "lobby_corridor", a = "Lobby", b = "Corridor", x = -4, z = -18, axis = "X", optional = false },
		{ id = "office_corridor", a = "Office", b = "Corridor", x = -27, z = -18, axis = "X", optional = false },
		{ id = "pump_corridor", a = "Pump", b = "Corridor", x = 23, z = -18, axis = "X", optional = false },
		{ id = "generator_corridor", a = "Generator", b = "Corridor", x = -21, z = -26, axis = "X", optional = false },
		{ id = "storage_corridor", a = "Storage", b = "Corridor", x = 17, z = -26, axis = "X", optional = false },
		{ id = "workshop_entry", a = "Courtyard", b = "Maintenance", x = -54, z = 0, axis = "X", optional = false },
		{ id = "yard_entry", a = "Courtyard", b = "Switchyard", x = 56, z = 0, axis = "X", optional = false },
		{ id = "workshop_corridor", a = "Maintenance", b = "Corridor", x = -40, z = -22, axis = "Z", optional = false },
		{ id = "yard_corridor", a = "Switchyard", b = "Corridor", x = 40, z = -22, axis = "Z", optional = false },
		{
			id = "workshop_gallery",
			a = "Maintenance",
			b = "CableGallery",
			x = -54,
			z = -50,
			axis = "X",
			optional = false,
		},
		{ id = "gallery_control", a = "CableGallery", b = "Control", x = -40, z = -64, axis = "Z", optional = false },
		{ id = "control_archive", a = "Control", b = "Archive", x = 4, z = -64, axis = "Z", optional = false },
		{ id = "archive_yard", a = "Archive", b = "Switchyard", x = 40, z = -64, axis = "Z", optional = false },
		{ id = "office_workshop", a = "Office", b = "Maintenance", x = -40, z = -4, axis = "Z", optional = true },
		{ id = "pump_yard", a = "Pump", b = "Switchyard", x = 40, z = -8, axis = "Z", optional = true },
		{ id = "generator_control", a = "Generator", b = "Control", x = -32, z = -50, axis = "X", optional = true },
		{ id = "storage_archive", a = "Storage", b = "Archive", x = 24, z = -50, axis = "X", optional = true },
	} :: { Link },
}

return TableUtil.deepFreeze(Catalog)
