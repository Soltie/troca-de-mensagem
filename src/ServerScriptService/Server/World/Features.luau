--!strict
--[[
	Dados puros das novidades do polish (testados no Lune). Montados pelo FeatureBuilder depois
	do MapBuilder; não mexem em paredes nem nos dados do Layout (ver LEIA_CLAUDE.md).

	Coordenadas no chão (y = 0) salvo indicação. `front` = direção para onde a frente do objeto olha.
]]

export type Point = { x: number, y: number, z: number }

export type Spot = {
	id: string,
	-- Centro do objeto.
	position: Point,
	-- Onde o jogador fica de pé para alcançar (teste de navegação).
	stand: Point,
}

export type Locker = {
	id: string,
	-- Centro da base (no chão).
	base: Point,
	front: Point,
	stand: Point,
}

export type Fallable = {
	id: string,
	kind: "bucket" | "cans" | "bottles" | "pipes" | "extinguisher" | "box",
	-- Base do objeto (onde ele está apoiado).
	position: Point,
	-- Para onde ele tomba (direção no plano).
	fall: Point,
}

export type Rect = { x0: number, x1: number, z0: number, z1: number }

local Features = {}

-- Portas que começam trancadas (a chave abre). O Depósito também tem acesso pela ampliação do
-- mapa (Arquivo Técnico), então a chave é um atalho e a missão nunca trava.
Features.LockedDoors = { door_storage = true } :: { [string]: boolean }

-- Chave do Depósito (uma das posições por rodada).
Features.KeySpots = {
	{ id = "key_office", position = { x = -35, y = 4.6, z = -0.8 }, stand = { x = -35, y = 0, z = -3.6 } },
	{ id = "key_lobby", position = { x = -11.25, y = 4.6, z = -16.4 }, stand = { x = -8.5, y = 0, z = -16.6 } },
} :: { Spot }

-- Pilhas para a lanterna (Config.Battery.PickupsPerRound sorteadas por rodada).
Features.BatterySpots = {
	{ id = "battery_lobby", position = { x = 2.5, y = 2.1, z = -2 }, stand = { x = 0, y = 0, z = -4 } },
	{ id = "battery_office", position = { x = -38.5, y = 5.2, z = -12.6 }, stand = { x = -35.5, y = 0, z = -12.6 } },
	{ id = "battery_pump", position = { x = 33.6, y = 3.38, z = -2.4 }, stand = { x = 33.6, y = 0, z = -6.5 } },
	{
		id = "battery_generator",
		position = { x = -35.6, y = 3.38, z = -29.4 },
		stand = { x = -33, y = 0, z = -32.5 },
	},
	{ id = "battery_storage", position = { x = 17.6, y = 3.06, z = -38 }, stand = { x = 17.6, y = 0, z = -35.4 } },
} :: { Spot }

-- Armários onde dá para se esconder.
Features.Lockers = {
	{
		id = "locker_storage",
		base = { x = 37.6, y = 0, z = -27.7 },
		front = { x = 0, y = 0, z = -1 },
		stand = { x = 37.6, y = 0, z = -31.5 },
	},
	{
		id = "locker_pump",
		base = { x = 31, y = 0, z = -16.3 },
		front = { x = 0, y = 0, z = 1 },
		stand = { x = 31, y = 0, z = -12.5 },
	},
	{
		id = "locker_generator",
		base = { x = -38.3, y = 0, z = -36 },
		front = { x = 1, y = 0, z = 0 },
		stand = { x = -34.5, y = 0, z = -36 },
	},
} :: { Locker }

-- Caixa de disjuntores (A, B, C) ao lado do quadro, e o procedimento com a ordem da rodada.
Features.Breakers = {
	box = { x = -9.5, y = 4.2, z = -49.15 },
	stand = { x = -9.5, y = 0, z = -45.5 },
	spacing = 1.5,
}
Features.BreakerNote = {
	id = "note_breakers",
	position = { x = -20.6, y = 4.7, z = -49.42 },
	stand = { x = -20.6, y = 0, z = -45.5 },
}

-- Rádio do vigia (chiado nos eventos de tensão).
Features.Radio = { x = -10.2, y = 3.4, z = -3.3 } :: Point

-- Objetos que caem quando o jogador passa rápido perto (agachado/devagar não derruba).
Features.Fallables = {
	{ id = "fall_bucket", kind = "bucket", position = { x = 19.8, y = 0, z = -14.6 }, fall = { x = 1, y = 0, z = 0 } },
	{ id = "fall_cans", kind = "cans", position = { x = 3.2, y = 2, z = -36 }, fall = { x = 1, y = 0, z = 0 } },
	{
		id = "fall_bottles",
		kind = "bottles",
		position = { x = -1.6, y = 0, z = -16.6 },
		fall = { x = 0, y = 0, z = 1 },
	},
	{ id = "fall_pipes", kind = "pipes", position = { x = -12, y = 0, z = -27.1 }, fall = { x = 0, y = 0, z = -1 } },
	{
		id = "fall_extinguisher",
		kind = "extinguisher",
		position = { x = 10, y = 2.6, z = -25.25 },
		fall = { x = 0, y = 0, z = 1 },
	},
	{ id = "fall_box", kind = "box", position = { x = -23.4, y = 3, z = -6.4 }, fall = { x = 0, y = 0, z = -1 } },
} :: { Fallable }

-- Poças (passos molhados). As duas da sala de bombas já existem no mapa (nome "Puddle").
Features.Puddles = {
	{ x = -33, y = 0, z = -33, sx = 3.2, sz = 2.4 },
	{ x = 25.5, y = 0, z = -21.4, sx = 2.6, sz = 2 },
	{ x = 9, y = 0, z = -45, sx = 3, sz = 2.2 },
	{ x = 8, y = 0, z = 20, sx = 4, sz = 3 },
	{ x = -12, y = 0, z = 12, sx = 3.4, sz = 2.6 },
}

-- Goteiras (som de pingos sobre as poças).
Features.Drips = {
	{ x = 20, y = 9.5, z = -13 },
	{ x = 25.5, y = 9.6, z = -21.4 },
	{ x = -33, y = 9.6, z = -33 },
}

-- Assoalho de madeira no escritório (passos de madeira).
Features.WoodFloors = {
	{ x0 = -39.5, x1 = -12.5, z0 = -17.5, z1 = -0.5 },
} :: { Rect }

-- Vão baixo para passar agachado entre a Sala do Gerador e o Depósito (o Vigia não cabe).
-- A abertura em si está no Layout (parede generatorStorage); aqui ficam moldura e grade.
Features.Crawl = {
	wallX = -4,
	centerZ = -47.4,
	width = 3.4,
	top = 3.9,
	standGenerator = { x = -7, y = 0, z = -47.4 } :: Point,
	standStorage = { x = -1, y = 0, z = -47.4 } :: Point,
}

-- Reverb por sala (Layout.Rooms); "Outside" para o resto.
Features.Reverb = {
	Lobby = "StoneRoom",
	Office = "Room",
	Pump = "Hangar",
	Corridor = "StoneCorridor",
	Generator = "Hangar",
	Storage = "Auditorium",
	Maintenance = "StoneRoom",
	CableGallery = "SewerPipe",
	Control = "Room",
	Archive = "CarpettedHallway",
	Switchyard = "Plain",
	Outside = "Plain",
} :: { [string]: string }

-- Checkpoint: onde o jogador volta (perto do quadro, de frente para a porta do gerador).
Features.CheckpointSpawn = {
	position = { x = -16, y = 3.2, z = -44 } :: Point,
	lookAt = { x = -21, y = 3.2, z = -26 } :: Point,
}

-- Sorteia `count` itens distintos de `list` (`nextInteger(a, b)` injetado).
function Features.pick<T>(list: { T }, count: number, nextInteger: (number, number) -> number): { T }
	local pool = table.clone(list)
	local result = {}
	for _ = 1, math.min(count, #pool) do
		local index = nextInteger(1, #pool)
		table.insert(result, pool[index])
		table.remove(pool, index)
	end
	return result
end

return Features
