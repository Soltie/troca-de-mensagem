--!strict
--[[
	A Visita do Tum Tum (cap. 1, nota 9): ameaça jogável no tom DOORS. Ele dorme, mas uma vez no capítulo desce a
	escada; o aviso dura 20 s (10 s se a casa o acordou: erro da Melodia do Corredor). Ele entra no cômodo onde está
	a equipe, para no meio, olha o armário e vai embora. Quem está escondido e quieto não é visto; quem fica fora do
	armário é capturado (consequência normal do capítulo: cai e a equipe levanta, ou derrota no solo).
	Puro: sem `game`; o serviço (TungVisitService) e o controller só aplicam estas regras. Testado no Lune.
	Rotas e armários: docs/level.md ("esconderijos e rota do Tung").
]]

export type Point = { x: number, z: number }
export type Room = "Living" | "Kitchen" | "Dining"

local TungVisit = {}

TungVisit.WarningSeconds = 20
TungVisit.EarlyWarningSeconds = 10
TungVisit.MiddlePause = 3
TungVisit.ClosetPause = 2
TungVisit.Speed = 9 -- studs/s
TungVisit.GraceSeconds = 1.5 -- depois de aparecer, ninguém é visto
-- Visão: sem lanterna ele vê de perto; com a lanterna acesa vê de longe. Correr denuncia.
TungVisit.SightDark = 10
TungVisit.SightLight = 34
TungVisit.SightRunning = 22
TungVisit.RunningSpeed = 15

-- Pé da escada (onde ele aparece) e o hall.
TungVisit.StairFoot = { x = 8, z = 20 } :: Point
TungVisit.Hall = { x = 0, z = 2 } :: Point

-- Por cômodo: porta (do lado do hall), meio do cômodo e a frente do armário (frente do armário = z + 4).
local ROUTES: { [string]: { door: Point, middle: Point, closet: Point } } = {
	Living = { door = { x = -9, z = -4 }, middle = { x = -26, z = -4 }, closet = { x = -41.4, z = 12.6 } },
	Kitchen = { door = { x = 9, z = -4 }, middle = { x = 26, z = -4 }, closet = { x = 41.4, z = 12.6 } },
	Dining = { door = { x = -9, z = -36 }, middle = { x = -26, z = -36 }, closet = { x = -41.4, z = -19.4 } },
}

export type Step = { at: Point, pause: number, kind: string }

-- Cômodo pelo ponto do jogador, ou nil no hall/fora.
function TungVisit.roomOf(x: number, z: number): Room?
	if z > -52 and z < 12 then
		if x < -8 and x > -45 then
			return (if z >= -20 then "Living" else "Dining") :: Room
		elseif x > 8 and x < 45 and z >= -20 then
			return "Kitchen" :: Room
		end
	end
	return nil
end

-- Escolhe o cômodo da visita: o que tem mais jogadores fora do hall (empate: o primeiro); sem ninguém, `fallback`.
function TungVisit.pickRoom(positions: { Point }, fallback: Room): Room
	local counts: { [string]: number } = {}
	local best: Room? = nil
	for _, p in positions do
		local room = TungVisit.roomOf(p.x, p.z)
		if room then
			counts[room] = (counts[room] or 0) + 1
			if not best or counts[room] > (counts[best] or 0) then
				best = room :: Room
			end
		end
	end
	return best or fallback
end

-- Percurso completo: escada → hall → porta → meio (pausa) → armário (pausa) → porta → hall → escada.
function TungVisit.route(room: Room): { Step }
	local r = ROUTES[room]
	return {
		{ at = TungVisit.StairFoot, pause = 0, kind = "stairs" },
		{ at = TungVisit.Hall, pause = 0.5, kind = "hall" },
		{ at = r.door, pause = 0, kind = "door" },
		{ at = r.middle, pause = TungVisit.MiddlePause, kind = "middle" },
		{ at = r.closet, pause = TungVisit.ClosetPause, kind = "closet" },
		{ at = r.door, pause = 0, kind = "door" },
		{ at = TungVisit.Hall, pause = 0, kind = "hall" },
		{ at = TungVisit.StairFoot, pause = 0, kind = "leave" },
	}
end

export type Sight = {
	hidden: boolean,
	flashlight: boolean,
	speed: number, -- studs/s do jogador
	distance: number, -- até o Tum Tum
	clear: boolean, -- linha de visão livre
	atCloset: boolean, -- ele está parado diante do armário
	sinceSpawn: number, -- s desde que apareceu
}

-- O Tum Tum viu este jogador?
function TungVisit.sees(s: Sight): boolean
	if s.sinceSpawn < TungVisit.GraceSeconds or not s.clear then
		return false
	end
	-- Escondido nunca é "visto": se ele para diante do armário, é a revista (TungVisit.searches).
	if s.hidden then
		return false
	end
	local range = TungVisit.SightDark
	if s.flashlight then
		range = TungVisit.SightLight
	elseif s.speed > TungVisit.RunningSpeed then
		range = TungVisit.SightRunning
	end
	return s.distance <= range
end

-- Revista do armário: ele está parado diante do armário e este jogador está escondido perto (no armário dele).
TungVisit.SearchRange = 6
function TungVisit.searches(hidden: boolean, atCloset: boolean, distance: number): boolean
	return hidden and atCloset and distance <= TungVisit.SearchRange
end

TungVisit.Captions = table.freeze({
	warning = "Ele está descendo a escada... Escondam-se num armário. Sem lanterna!",
	hall = "Os passos chegaram ao hall.",
	gone = "Ele subiu de novo. Respirem.",
	caught = "Ele viu vocês.",
} :: { [string]: string })

return table.freeze(TungVisit)
