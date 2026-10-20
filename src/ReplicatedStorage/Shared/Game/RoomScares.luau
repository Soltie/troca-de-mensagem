--!strict
--[[
	Sustos de cenário do cap. 1 (rodada 2 do crítico: "a casa não faz nada, ninguém aparece"). Um susto por cômodo,
	disparado UMA vez por capítulo na primeira vez que alguém entra. Todos são avisos curtos e sem gore: som + um
	objeto que mexe. A casa está de olho, mas o Tum Tum ainda não aparece (isso é o gancho de presença do código).
	Puro: sem `game`; testado no Lune. Quem executa é o RoomScareService.
]]

export type Kind = "pounding" | "pans" | "chair_turn" | "book_fall" | "carving_eyes" | "rocking"
export type Scare = {
	room: string,
	kind: Kind,
	-- Atraso (s) entre entrar no cômodo e o susto, para o jogador já estar de costas ou mexendo em algo.
	delay: number,
	-- Legenda curta (pt-BR) mostrada junto; nenhuma explica a causa.
	caption: string,
}

local RoomScares = {}

-- Centro e meia-largura/meia-profundidade de cada cômodo do térreo (HouseCatalog.Rooms).
local BOUNDS: { [string]: { x: number, z: number, hx: number, hz: number } } = {
	Hall = { x = 0, z = 2, hx = 8, hz = 16 },
	Living = { x = -26, z = -4, hx = 18, hz = 15 },
	Kitchen = { x = 26, z = -4, hx = 18, hz = 15 },
	Dining = { x = -26, z = -36, hx = 18, hz = 15 },
	Library = { x = -26, z = -68, hx = 18, hz = 15 },
}

RoomScares.Chapter1 = table.freeze({
	{ room = "Hall", kind = "pounding", delay = 6, caption = "Alguém bate na parede, do outro lado." },
	{ room = "Kitchen", kind = "pans", delay = 4, caption = "As panelas balançam sozinhas." },
	{ room = "Dining", kind = "chair_turn", delay = 5, caption = "A cadeira virou para você." },
	{ room = "Library", kind = "book_fall", delay = 5, caption = "Um livro caiu da estante." },
	{ room = "Living", kind = "rocking", delay = 3, caption = "A cadeira de balanço parou de balançar." },
} :: { Scare })

-- Entalhe do corredor (depois da 2ª chave): dois olhos na parede + sussurro, some em 4 s.
RoomScares.CorridorEyes = table.freeze({
	room = "Hall",
	kind = "carving_eyes",
	delay = 0,
	caption = "O entalhe na parede abriu os olhos.",
} :: Scare)

-- Cômodo do térreo que contém (x, z) no andar térreo (y < 8), ou nil.
function RoomScares.roomAt(x: number, y: number, z: number): string?
	if y > 8 or y < -8 then
		return nil
	end
	for room, b in BOUNDS do
		if math.abs(x - b.x) <= b.hx and math.abs(z - b.z) <= b.hz then
			return room
		end
	end
	return nil
end

-- Susto desta entrada, se ainda não aconteceu (`done`: cômodos já disparados neste capítulo).
function RoomScares.pick(room: string, done: { [string]: boolean }): Scare?
	if done[room] then
		return nil
	end
	for _, scare in RoomScares.Chapter1 do
		if scare.room == room then
			return scare
		end
	end
	return nil
end

return table.freeze(RoomScares)
