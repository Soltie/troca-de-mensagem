--!strict
-- Rotas mínimas, comuns ao gerador e ao QA; a mata pode ocupar todo o espaço restante.
local Forest = require("@game/ReplicatedStorage/Shared/Game/ForestCatalog")
local Plan = require("../Campaign/ForestPlan")
local Layout = {}
export type Rect = { x0: number, x1: number, z0: number, z1: number }
function Layout.clearings(seed: number): { Rect }
	local out: { Rect } = {
		{ x0 = -12, x1 = 12, z0 = 540, z1 = 918 },
		{ x0 = -143, x1 = 143, z0 = 858, z1 = 908 },
		{ x0 = -32, x1 = 30, z0 = 590, z1 = 614 },
	}
	for chapter = 6, 8 do
		for _, mode in { "Story", "Standard" } do
			for _, spec in Plan.create(seed, chapter, 6, mode).activities do
				if spec.kind ~= "hide" and spec.kind ~= "breath" then
					table.insert(out, {
						x0 = math.min(0, spec.x) - 8,
						x1 = math.max(0, spec.x) + 8,
						z0 = spec.z - 3,
						z1 = spec.z + 13,
					})
				end
			end
		end
	end
	for _, p in Forest.Hides do
		table.insert(out, {
			x0 = math.min(0, p.x) - 8,
			x1 = math.max(0, p.x) + 8,
			z0 = p.z - 5,
			z1 = p.z + 14,
		})
	end
	-- Barracas, posto e torre existem fora das estações e não podem conter troncos.
	table.insert(out, { x0 = -95, x1 = -65, z0 = 644, z1 = 818 })
	table.insert(out, { x0 = 63, x1 = 102, z0 = 684, z1 = 784 })
	return out
end
function Layout.reserved(x: number, z: number, clearings: { Rect }): boolean
	for _, r in clearings do
		if x >= r.x0 and x <= r.x1 and z >= r.z0 and z <= r.z1 then
			return true
		end
	end
	return false
end
return Layout
