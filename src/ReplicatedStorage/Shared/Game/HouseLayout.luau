--!strict
-- Contrato único dos pisos da escadaria: só o vão da escada que chega fica aberto.
local Layout = {}
export type Rect = { x0: number, x1: number, z0: number, z1: number }
Layout.Floors = { -16, 0, 16, 32 }
Layout.Bounds = { x0 = -24, x1 = 45, z0 = 12, z1 = 64 }
Layout.Stairs = {
	{ name = "BasementStairs", x = -16, z0 = 22, z1 = 54, y0 = -16, y1 = 0 },
	{ name = "MainStairs", x = 16, z0 = 22, z1 = 54, y0 = 0, y1 = 16 },
	{ name = "AtticStairs", x = 32, z0 = 54, z1 = 22, y0 = 16, y1 = 32 },
}
function Layout.opening(y: number): Rect?
	for _, stair in Layout.Stairs do
		if stair.y1 == y then
			return { x0 = stair.x - 6, x1 = stair.x + 6, z0 = 22, z1 = 54 }
		end
	end
	return nil
end
function Layout.decks(y: number): { Rect }
	local b, hole = Layout.Bounds, Layout.opening(y)
	if not hole then
		return { table.clone(b) }
	end
	return {
		{ x0 = b.x0, x1 = b.x1, z0 = b.z0, z1 = hole.z0 },
		{ x0 = b.x0, x1 = b.x1, z0 = hole.z1, z1 = b.z1 },
		{ x0 = b.x0, x1 = hole.x0, z0 = hole.z0, z1 = hole.z1 },
		{ x0 = hole.x1, x1 = b.x1, z0 = hole.z0, z1 = hole.z1 },
	}
end
--[[
	Janelas reais das fachadas laterais (pedido do humano: janelas translúcidas). Cada cômodo acima do porão, menos os
	que têm móveis altos na fachada, ganha um vão na parede (Facade e casca externa) alinhado com a janela de fora
	(z = cômodo − 10; linhas da fachada em z −14/−46/−78). O vão fica entre `y0` e `y1` acima do piso.
]]
Layout.NoWindow = { Kitchen = true, Bath = true, Library = true, AtticBook = true, Machine = true }
Layout.Window = { oz = -10, halfWidth = 2, y0 = 4.6, y1 = 10.4 }
export type FacadeWindow = { id: string, side: number, y: number, z: number }
-- `rooms`: HouseCatalog.Rooms (id, x, y, z); tabela genérica para não acoplar este contrato ao catálogo.
function Layout.facadeWindows(rooms: { any }): { FacadeWindow }
	local out = {}
	for _, room in rooms do
		if room.y >= 0 and room.x ~= 0 and not Layout.NoWindow[room.id] and math.abs(room.x) > 20 then
			table.insert(
				out,
				{ id = room.id, side = if room.x < 0 then -1 else 1, y = room.y, z = room.z + Layout.Window.oz }
			)
		end
	end
	return out
end

return table.freeze(Layout)
