--!strict
-- Máscaras autorais repetíveis de desgaste. Pixels RGBA locais; nenhuma imagem externa ou upload.
local Patterns = {}
Patterns.Size = 32
Patterns.Kinds = { "paint", "concrete", "rust", "wood", "tiles" }

local function noise(x: number, y: number, seed: number): number
	return ((x * 137 + y * 269 + seed * 53) * (x * 17 + y * 31 + 7)) % 251
end

function Patterns.pixels(kind: string, seed: number): buffer
	assert(table.find(Patterns.Kinds, kind), "unknown surface pattern")
	local size = Patterns.Size
	local pixels = buffer.create(size * size * 4)
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local fine = noise(x, y, seed)
			local coarse = noise(math.floor(x / 4), math.floor(y / 4), seed + 11)
			local r, g, b, alpha = 28, 30, 25, 0
			if kind == "paint" then
				-- Ilhas de tinta descascada e pequenos poros; sem borda artificial no tile.
				if coarse < 26 and fine < 160 then
					r, g, b, alpha = 139, 133, 113, 45 + fine % 35
				elseif fine < 40 then
					alpha = 90
				end
			elseif kind == "concrete" then
				local tone = 65 + fine % 65
				r, g, b, alpha = tone, tone, tone - 5, 20 + coarse % 65
				if (x + math.floor(y / 4)) % 29 == 0 then
					r, g, b, alpha = 23, 25, 23, 115
				end
			elseif kind == "rust" then
				r, g, b = 95 + fine % 42, 48 + fine % 20, 24
				alpha = if coarse < 100 then 70 + fine % 90 else 8
				if x % 13 == 0 and fine < 130 then
					r, g, b, alpha = 185, 176, 145, 90
				end
			elseif kind == "wood" then
				r, g, b = 31, 20, 12
				alpha = if (y + math.floor(x / 8)) % 7 == 0 then 110 else fine % 24
			elseif kind == "tiles" then
				r, g, b, alpha = 24, 26, 22, if x % 16 == 0 or y % 16 == 0 then 160 else fine % 36
			end
			local offset = (y * size + x) * 4
			buffer.writeu8(pixels, offset, r)
			buffer.writeu8(pixels, offset + 1, g)
			buffer.writeu8(pixels, offset + 2, b)
			buffer.writeu8(pixels, offset + 3, alpha)
		end
	end
	return pixels
end

return table.freeze(Patterns)
