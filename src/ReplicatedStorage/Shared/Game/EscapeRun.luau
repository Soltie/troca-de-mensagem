--!strict
--[[
	Corrida roteirizada da fuga do capítulo 5 (ideia M, DOORS/Seek). Puro, testado no Lune.
	Tudo é medido pela distância ao longo do caminho de fuga (FireSpread.Route) de quem vai na frente:
	- Portas dos cômodos ao lado do caminho batem sozinhas logo depois que alguém passa por elas.
	- Duas vigas em chamas despencam do teto do corredor do porão À FRENTE de quem corre: é preciso pular.
	- O corredor desaba: o teto vem caindo atrás do grupo a `Collapse.speed` studs/s (mais rápido que andar,
	  mais lento que correr). Quem fica para trás do desabamento leva pancada.
]]

local FireSpread = require("./FireSpread")

local EscapeRun = {}

export type Beam = { trigger: number, at: number }

-- Corredor do porão: s de 26 (saída do mecanismo) a 106 (pé da escada).
EscapeRun.Beams = {
	{ trigger = 34, at = 50 },
	{ trigger = 66, at = 82 },
} :: { Beam }
EscapeRun.BeamFall = 0.45
-- Faixa de chão em chamas para cada lado da viga (studs) e calor por segundo de quem pisa nela.
EscapeRun.BurnBand = 2.2
EscapeRun.BurnRate = 3
EscapeRun.Collapse = { trigger = 74, from = 30, to = 106, speed = 15 }
-- Distância lateral máxima para alguém contar como "no caminho".
EscapeRun.OnPath = 10
-- Portas: batem quando quem vai na frente passou `SlamBehind` studs delas; só portas ao lado do caminho
-- (entre OnRoute e SlamReach de distância), nunca uma porta no próprio caminho.
EscapeRun.SlamBehind = 4
EscapeRun.SlamReach = 12
EscapeRun.OnRoute = 3.5

--[[
	Projeta um ponto no caminho: retorna a distância percorrida até o ponto mais próximo (s) e a distância até o
	caminho (com a altura pesando o dobro, para não confundir andares).
]]
function EscapeRun.project(x: number, y: number, z: number): (number, number)
	local route = FireSpread.Route
	local best, bestS, walked = math.huge, 0, 0
	for i = 2, #route do
		local a, b = route[i - 1], route[i]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		local k = math.clamp(((x - a[1]) * dx + (y - a[2]) * dy + (z - a[3]) * dz) / (length * length), 0, 1)
		local px, py, pz = a[1] + dx * k, a[2] + dy * k, a[3] + dz * k
		local d = (x - px) ^ 2 + ((y - py) * 2) ^ 2 + (z - pz) ^ 2
		if d < best then
			best, bestS = d, walked + length * k
		end
		walked += length
	end
	return bestS, math.sqrt(best)
end

-- Ponto do caminho a `s` studs do começo.
function EscapeRun.point(s: number): (number, number, number)
	local route = FireSpread.Route
	local walked = 0
	for i = 2, #route do
		local a, b = route[i - 1], route[i]
		local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		local length = math.sqrt(dx * dx + dy * dy + dz * dz)
		if s <= walked + length or i == #route then
			local k = math.clamp((s - walked) / length, 0, 1)
			return a[1] + dx * k, a[2] + dy * k, a[3] + dz * k
		end
		walked += length
	end
	local last = route[#route]
	return last[1], last[2], last[3]
end

-- Onde está a frente do desabamento `elapsed` s depois de começar.
function EscapeRun.collapseFront(elapsed: number): number
	local c = EscapeRun.Collapse
	return math.min(c.to, c.from + math.max(0, elapsed) * c.speed)
end

-- O desabamento pegou quem está em `s` (dentro do corredor e atrás da frente)?
function EscapeRun.caught(front: number, s: number, offPath: number): boolean
	local c = EscapeRun.Collapse
	return offPath <= EscapeRun.OnPath and s >= c.from - 1 and s <= c.to and s < front - 1
end

-- A porta (projetada em doorS, a doorOff do caminho) deve bater agora que a frente do grupo está em `leader`?
function EscapeRun.shouldSlam(doorS: number, doorOff: number, leader: number): boolean
	return doorOff >= EscapeRun.OnRoute and doorOff <= EscapeRun.SlamReach and leader >= doorS + EscapeRun.SlamBehind
end

return table.freeze(EscapeRun)
