--!strict
-- Park-Miller: operações inteiras exatas em double, estável no Lune e no Roblox.
local SeededRandom = {}
export type Generator = { integer: (number, number) -> number, shuffle: <T>({ T }) -> { T } }

function SeededRandom.new(seed: number): Generator
	assert(seed == seed and math.abs(seed) < math.huge and seed % 1 == 0, "Seed must be a finite integer")
	local state = (seed % 2147483646) + 1
	local function integer(a: number, b: number): number
		assert(a % 1 == 0 and b % 1 == 0 and b >= a, "Invalid integer range")
		state = (state * 16807) % 2147483647
		return a + (state % (b - a + 1))
	end
	local function shuffle<T>(items: { T }): { T }
		local out = table.clone(items)
		for i = #out, 2, -1 do
			local j = integer(1, i)
			out[i], out[j] = out[j], out[i]
		end
		return out
	end
	return { integer = integer, shuffle = shuffle }
end

return SeededRandom
