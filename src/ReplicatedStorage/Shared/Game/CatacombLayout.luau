--!strict
--[[
	Catacumba e capela (opção A, docs/AVALIACAO_20-10-2026.md): espaços novos embaixo do jardim leste, no nível do
	porão (piso em y = -16). O túnel de minhoca dos jogadores sai pela parede leste do TÚNEL SECRETO.
	- Capítulo 4: túnel + catacumba abertos (a pista do cofre fica lá embaixo).
	- Capítulo 5: a capela do ritual abre ao lado (devolver o coração ao altar).
	- Capítulos 1 a 3 e floresta: tudo fechado (a parede volta inteira).
	Dados puros: o World/Catacomb escava e monta; o HousePlan põe as tarefas nos pontos daqui.
]]

export type Box = { x0: number, x1: number, y0: number, y1: number, z0: number, z1: number }
export type Point = { x: number, y: number, z: number }

local Layout = {}

Layout.Floor = -16
-- Interiores (espaço livre de andar). Altura mínima 9,5: o agente do Tung tem 7,6.
Layout.Corridor = table.freeze({ x0 = 44.5, x1 = 71, y0 = -16, y1 = -6.5, z0 = -39.5, z1 = -32.5 }) :: Box
Layout.Catacomb = table.freeze({ x0 = 71, x1 = 95, y0 = -16, y1 = -5, z0 = -50, z1 = -22 }) :: Box
Layout.Passage = table.freeze({ x0 = 80, x1 = 86, y0 = -16, y1 = -6.5, z0 = -22, z1 = -17 }) :: Box
Layout.Chapel = table.freeze({ x0 = 72, x1 = 94, y0 = -16, y1 = -3, z0 = -17, z1 = 5 }) :: Box
-- Boca do túnel na parede leste da sala TÚNEL SECRETO (fachada em x 43.5..44.5).
Layout.Mouth = table.freeze({ x0 = 43.4, x1 = 44.6, y0 = -16, y1 = -6.5, z0 = -39.5, z1 = -32.5 }) :: Box

Layout.CatacombTask = table.freeze({ x = 78, y = -16, z = -40 }) :: Point
Layout.ChapelTask = table.freeze({ x = 83, y = -16, z = -7 }) :: Point

function Layout.openCatacomb(stage: number): boolean
	return stage == 4 or stage == 5
end

function Layout.openChapel(stage: number): boolean
	return stage == 5
end

-- Reposição de tarefas: a pista do cofre (cap. 4) desce para a catacumba; o altar (cap. 5) vai para a capela.
function Layout.relocate(stage: number, item: string?, event: string?, index: number): Point?
	if stage == 4 and item == "safe_clue" then
		return Layout.CatacombTask
	end
	if stage == 5 and index == 2 and item == nil and event == nil then
		return Layout.ChapelTask
	end
	return nil
end

function Layout.inside(box: Box, p: Point, margin: number?): boolean
	local m = margin or 0
	return p.x > box.x0 + m
		and p.x < box.x1 - m
		and p.y >= box.y0 - 0.01
		and p.y < box.y1
		and p.z > box.z0 + m
		and p.z < box.z1 - m
end

return table.freeze(Layout)
