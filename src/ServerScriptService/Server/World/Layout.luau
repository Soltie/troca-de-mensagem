--!strict
--[[
	Planta da Subestação 9 — só dados (testados no Lune). O MapBuilder transforma isto em peças.
	Diagrama abaixo: núcleo original. Alas e circuito completo: docs/MAP_EXPANSION.md.

	Eixos: X = leste(+)/oeste(-); Z = sul(+)/norte(-); piso interno e pátio com topo em y = 0.

	      N (-Z)
	  +------------------+----------------------+   z = -50
	  |  SALA DO GERADOR |       DEPÓSITO        |
	  |   (quadro)       |      (fusível)        |
	  +------[porta]-----+---------[porta]-------+   z = -26
	  |                  CORREDOR                |
	  +--[porta]---+-----[  ]-----+---[  ]-------+   z = -18
	  | ESCRITÓRIO [  ] RECEPÇÃO [  ]   BOMBAS   |
	  | (fusível)  |             |   (fusível)   |
	  +------------+----[  ]-----+---------------+   z = 0   (fachada)
	  |                  PÁTIO  (início)         |
	  +-------------------[portão]---------------+   z = 44  (cerca)
	  x=-40       x=-12        x=4             x=40
]]

export type Rect = { x0: number, x1: number, z0: number, z1: number }
export type Point = { x: number, y: number, z: number }
export type Opening = { center: number, width: number, bottom: number, top: number }
export type Wall = {
	id: string,
	-- "X": parede ao longo de X em z = at;  "Z": parede ao longo de Z em x = at.
	axis: "X" | "Z",
	at: number,
	from: number,
	to: number,
	exterior: boolean,
	openings: { Opening },
}
export type Door = {
	id: string,
	wall: string,
	center: number,
	width: number,
	-- Lado da dobradiça (true = lado de menor coordenada na parede).
	hingeAtMin: boolean,
	-- Para que lado abre: +1 = +Z (paredes "X") / +X (paredes "Z"); -1 = o contrário.
	side: number,
	-- Começa aberta?
	open: boolean,
}
export type Room = Rect & { id: string, label: string }

local CEILING = 11
local DOOR_TOP = 9
local DOOR_WIDTH = 6
local WINDOW: Opening = { center = 0, width = 5, bottom = 3.5, top = 7 }

local function door(center: number): Opening
	return { center = center, width = DOOR_WIDTH, bottom = 0, top = DOOR_TOP }
end

local function window(center: number): Opening
	return { center = center, width = WINDOW.width, bottom = WINDOW.bottom, top = WINDOW.top }
end

local Layout = {}

Layout.CEILING = CEILING
Layout.DOOR_TOP = DOOR_TOP
Layout.WALL_THICKNESS = 1
-- Faixa inferior mais escura das paredes (rodapé alto).
Layout.BAND_HEIGHT = 3.2

Layout.Building = { x0 = -40, x1 = 40, z0 = -50, z1 = 0 } :: Rect
-- Building continua sendo o núcleo original; Compound inclui as alas e o pátio técnico.
Layout.Compound = { x0 = -68, x1 = 72, z0 = -78, z1 = 44 } :: Rect
Layout.Courtyard = { x0 = -68, x1 = 72, z0 = 0, z1 = 44 } :: Rect

Layout.Rooms = {
	{ id = "Lobby", label = "RECEPÇÃO", x0 = -12, x1 = 4, z0 = -18, z1 = 0 },
	{ id = "Office", label = "ESCRITÓRIO", x0 = -40, x1 = -12, z0 = -18, z1 = 0 },
	{ id = "Pump", label = "BOMBAS", x0 = 4, x1 = 40, z0 = -18, z1 = 0 },
	{ id = "Corridor", label = "CORREDOR", x0 = -40, x1 = 40, z0 = -26, z1 = -18 },
	{ id = "Generator", label = "SALA DO GERADOR", x0 = -40, x1 = -4, z0 = -50, z1 = -26 },
	{ id = "Storage", label = "DEPÓSITO", x0 = -4, x1 = 40, z0 = -50, z1 = -26 },
	{ id = "Maintenance", label = "OFICINA", x0 = -68, x1 = -40, z0 = -50, z1 = 0 },
	{ id = "CableGallery", label = "GALERIA DE CABOS", x0 = -68, x1 = -40, z0 = -78, z1 = -50 },
	{ id = "Control", label = "SALA DE CONTROLE", x0 = -40, x1 = 4, z0 = -78, z1 = -50 },
	{ id = "Archive", label = "ARQUIVO TÉCNICO", x0 = 4, x1 = 40, z0 = -78, z1 = -50 },
	{ id = "Switchyard", label = "PÁTIO DE TRANSFORMADORES", x0 = 40, x1 = 72, z0 = -78, z1 = 0 },
} :: { Room }

Layout.Walls = {
	{
		id = "south",
		axis = "X",
		at = 0,
		from = -40,
		to = 40,
		exterior = true,
		openings = { window(-26), door(-4), window(14), window(30) },
	},
	{ id = "north", axis = "X", at = -50, from = -40, to = 40, exterior = false, openings = { door(-32), door(24) } },
	{ id = "west", axis = "Z", at = -40, from = -50, to = 0, exterior = false, openings = { door(-22), door(-4) } },
	{ id = "east", axis = "Z", at = 40, from = -50, to = 0, exterior = true, openings = { door(-22), door(-8) } },
	{ id = "annexWest", axis = "Z", at = -68, from = -78, to = 0, exterior = true, openings = {} },
	{ id = "annexSouth", axis = "X", at = 0, from = -68, to = -40, exterior = true, openings = { door(-54) } },
	{ id = "annexNorth", axis = "X", at = -78, from = -68, to = 40, exterior = true, openings = {} },
	{ id = "gallerySouth", axis = "X", at = -50, from = -68, to = -40, exterior = false, openings = { door(-54) } },
	{ id = "controlWest", axis = "Z", at = -40, from = -78, to = -50, exterior = false, openings = { door(-64) } },
	{ id = "archiveWest", axis = "Z", at = 4, from = -78, to = -50, exterior = false, openings = { door(-64) } },
	{ id = "archiveEast", axis = "Z", at = 40, from = -78, to = -50, exterior = true, openings = { door(-64) } },
	{
		id = "southRow",
		axis = "X",
		at = -18,
		from = -40,
		to = 40,
		exterior = false,
		openings = { door(-27), door(-4), door(23) },
	},
	{
		id = "northRow",
		axis = "X",
		at = -26,
		from = -40,
		to = 40,
		exterior = false,
		openings = { door(-21), door(17) },
	},
	{
		id = "officeLobby",
		axis = "Z",
		at = -12,
		from = -18,
		to = 0,
		exterior = false,
		openings = { { center = -9, width = 5, bottom = 0, top = DOOR_TOP } },
	},
	{
		id = "lobbyPump",
		axis = "Z",
		at = 4,
		from = -18,
		to = 0,
		exterior = false,
		openings = { { center = -9, width = 5, bottom = 0, top = DOOR_TOP } },
	},
	-- Vão baixo de cabos (só agachado; o Vigia não cabe). Moldura em World/FeatureBuilder (Features.Crawl).
	{
		id = "generatorStorage",
		axis = "Z",
		at = -4,
		from = -50,
		to = -26,
		exterior = false,
		openings = { { center = -47.4, width = 3.4, bottom = 0, top = 3.9 } },
	},
} :: { Wall }

-- Portas com folha (o resto das aberturas é vão livre).
Layout.Doors = {
	{
		id = "door_office",
		wall = "southRow",
		center = -27,
		width = DOOR_WIDTH,
		hingeAtMin = true,
		side = 1,
		open = false,
	},
	{
		id = "door_generator",
		wall = "northRow",
		center = -21,
		width = DOOR_WIDTH,
		hingeAtMin = false,
		side = -1,
		open = false,
	},
	{
		id = "door_storage",
		wall = "northRow",
		center = 17,
		width = DOOR_WIDTH,
		hingeAtMin = true,
		side = -1,
		open = true,
	},
} :: { Door }

-- Portão elétrico na cerca do pátio (abre deslizando para +X).
Layout.Gate = { x = 0, z = 44, width = 12, height = 8 }
Layout.FenceHeight = 8

-- Passar daqui com o portão aberto = vitória.
Layout.ExitZone = { x0 = -6, x1 = 6, z0 = 46, z1 = 64 } :: Rect

-- Início: no pátio, perto da van, olhando para a porta da recepção.
Layout.Spawn = { position = { x = 14, y = 3.2, z = 34 } :: Point, lookAt = { x = -4, y = 3.2, z = 0 } :: Point }

-- Dois pontos possíveis por fusível (sorteado a cada rodada). y = altura do centro do fusível.
Layout.FuseSpots = {
	fuse_pump = {
		{ x = 35, y = 3.45, z = -3 }, -- bancada
		{ x = 9, y = 2.25, z = -15 }, -- caixote ao lado da bomba
	},
	fuse_office = {
		{ x = -29.8, y = 3.25, z = -7.6 }, -- mesa (ao lado do monitor)
		{ x = -38.5, y = 5.25, z = -15 }, -- topo do arquivo
	},
	fuse_storage = {
		{ x = 31, y = 4.65, z = -46 }, -- prateleira alta
		{ x = 6, y = 3.25, z = -34 }, -- pilha de caixotes
	},
} :: { [string]: { Point } }

-- Onde ficar de pé para pegar cada fusível (mesmo índice de FuseSpots; no chão, livre de móveis).
Layout.FuseStands = {
	fuse_pump = { { x = 35, y = 0, z = -6.5 }, { x = 9, y = 0, z = -11.5 } },
	fuse_office = { { x = -29.8, y = 0, z = -3.2 }, { x = -35, y = 0, z = -15 } },
	fuse_storage = { { x = 31, y = 0, z = -42 }, { x = 9.5, y = 0, z = -31 } },
} :: { [string]: { Point } }

-- Onde ficar de pé para usar o quadro, o portão e ler os bilhetes.
Layout.Stands = {
	panel = { x = -16, y = 0, z = -46 },
	gate = { x = 0, y = 0, z = 40 },
	note_order = { x = -8.5, y = 0, z = -7 },
	note_office = { x = -19.8, y = 0, z = -3.5 },
	note_storage = { x = 24, y = 0, z = -33 },
} :: { [string]: Point }

-- Quadro de força (centro da caixa) na parede norte da sala do gerador.
Layout.Panel = { x = -16, y = 4.5, z = -49.1 } :: Point

-- Bilhetes (centro do papel).
Layout.Notes = {
	note_order = { x = -8.5, y = 3.43, z = -3.5 }, -- balcão da recepção
	note_office = { x = -19.8, y = 3.03, z = -7.4 }, -- segunda mesa
	note_storage = { x = 24, y = 2.03, z = -30 }, -- caixote perto da porta
} :: { [string]: Point }

-- Rota de patrulha (no chão).
Layout.PatrolNodes = {
	{ x = -34, y = 0, z = -22 },
	{ x = -8, y = 0, z = -22 },
	{ x = 8, y = 0, z = -22 },
	{ x = 34, y = 0, z = -22 },
	{ x = -4, y = 0, z = -10 },
	{ x = -26, y = 0, z = -11 },
	{ x = 20, y = 0, z = -4 },
	{ x = 24, y = 0, z = -42 },
	{ x = 34, y = 0, z = -31 },
	{ x = -14, y = 0, z = -34 },
	{ x = -34, y = 0, z = -30 },
	{ x = -54, y = 0, z = -22 },
	{ x = -54, y = 0, z = -64 },
	{ x = -20, y = 0, z = -64 },
	{ x = 24, y = 0, z = -64 },
	{ x = 56, y = 0, z = -64 },
	{ x = 56, y = 0, z = -22 },
} :: { Point }

-- Onde ele aparece ao acordar (o mais longe do jogador).
Layout.CreatureSpawns = {
	{ x = 36, y = 0, z = -40 },
	{ x = -36, y = 0, z = -46 },
	{ x = 37, y = 0, z = -14 },
	{ x = -36, y = 0, z = -3 },
} :: { Point }

-- Luminárias de teto (acendem com a energia).
Layout.Lamps = {
	{ x = -4, y = 10.6, z = -9 },
	{ x = -26, y = 10.6, z = -9 },
	{ x = 14, y = 10.6, z = -5 },
	{ x = 32, y = 10.6, z = -12 },
	{ x = -30, y = 10.6, z = -22 },
	{ x = -6, y = 10.6, z = -22 },
	{ x = 18, y = 10.6, z = -22 },
	{ x = 36, y = 10.6, z = -22 },
	{ x = 8, y = 10.6, z = -38 },
	{ x = 28, y = 10.6, z = -38 },
	{ x = -22, y = 10.6, z = -38 },
	{ x = -54, y = 10.6, z = -12 },
	{ x = -54, y = 10.6, z = -38 },
	{ x = -54, y = 10.6, z = -64 },
	{ x = -24, y = 10.6, z = -64 },
	{ x = -4, y = 10.6, z = -64 },
	{ x = 24, y = 10.6, z = -64 },
} :: { Point }

-- Luzes de emergência vermelhas (bateria: acesas desde o início, para orientação).
Layout.EmergencyLights = {
	{ x = -8.5, y = 8.5, z = -17.3 },
	{ x = -39.3, y = 8, z = -22 },
	{ x = 39.3, y = 8, z = -22 },
	{ x = -11, y = 7.5, z = -49.3 },
	{ x = 0, y = 8.5, z = -26.7 },
	{ x = -67.3, y = 8.5, z = -22 },
	{ x = -54, y = 8.5, z = -77.3 },
	{ x = -20, y = 8.5, z = -77.3 },
	{ x = 24, y = 8.5, z = -77.3 },
} :: { Point }

function Layout.roomAt(x: number, z: number): Room?
	for _, room in Layout.Rooms do
		if x >= room.x0 and x <= room.x1 and z >= room.z0 and z <= room.z1 then
			return room
		end
	end
	return nil
end

function Layout.inRect(rect: Rect, x: number, z: number): boolean
	return x >= rect.x0 and x <= rect.x1 and z >= rect.z0 and z <= rect.z1
end

function Layout.isIndoor(x: number, z: number): boolean
	local room = Layout.roomAt(x, z)
	return room ~= nil and room.id ~= "Switchyard"
end

function Layout.wallById(id: string): Wall?
	for _, wall in Layout.Walls do
		if wall.id == id then
			return wall
		end
	end
	return nil
end

return Layout
