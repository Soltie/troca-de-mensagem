--!strict
--[[
	Rastro de pegadas molhadas (puro, testado no Lune). O servidor guarda as pegadas de cada jogador molhado;
	se o Tung Tung passar perto de uma pegada fresca, ele "fareja" e vai até a pegada mais nova do rastro.
	Coordenadas em números (x, y, z) para rodar fora do Roblox.
]]

export type Print = { x: number, y: number, z: number, born: number }
export type Trail = { prints: { Print } }

local FootTrail = {}

FootTrail.MaxPrints = 40

function FootTrail.new(): Trail
	return { prints = {} }
end

function FootTrail.add(trail: Trail, x: number, y: number, z: number, now: number)
	table.insert(trail.prints, { x = x, y = y, z = z, born = now })
	while #trail.prints > FootTrail.MaxPrints do
		table.remove(trail.prints, 1)
	end
end

-- Remove as pegadas que já secaram.
function FootTrail.prune(trail: Trail, now: number, life: number)
	local kept = {}
	for _, print in trail.prints do
		if now - print.born < life then
			table.insert(kept, print)
		end
	end
	trail.prints = kept
end

-- Há pegada fresca a até `range` de (x, y, z)? Retorna a mais nova do rastro (para onde o jogador foi).
function FootTrail.scent(
	trail: Trail,
	x: number,
	y: number,
	z: number,
	now: number,
	range: number,
	life: number
): Print?
	local found = false
	for _, print in trail.prints do
		local dx, dy, dz = print.x - x, print.y - y, print.z - z
		if now - print.born < life and dx * dx + dy * dy + dz * dz <= range * range then
			found = true
			break
		end
	end
	if not found then
		return nil
	end
	local newest = trail.prints[#trail.prints]
	return if newest and now - newest.born < life then newest else nil
end

return table.freeze(FootTrail)
