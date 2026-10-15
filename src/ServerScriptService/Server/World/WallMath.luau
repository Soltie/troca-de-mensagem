--!strict
--[[
	Geometria pura de paredes com aberturas (portas e janelas). Testado no Lune.

	Uma parede vai de `from` a `to` ao longo do seu eixo e de y0 a y1 na altura.
	Cada abertura retira um retângulo [center ± width/2] x [bottom, top].
	O resultado são retângulos sólidos { a, b, y0, y1 } no espaço da parede.
]]

export type Opening = { center: number, width: number, bottom: number, top: number }
export type Segment = { a: number, b: number, y0: number, y1: number }

local EPSILON = 1e-6

local WallMath = {}

function WallMath.solidSegments(from: number, to: number, y0: number, y1: number, openings: { Opening }): { Segment }
	local sorted = table.clone(openings)
	table.sort(sorted, function(left, right)
		return left.center < right.center
	end)

	local segments: { Segment } = {}
	local function add(a: number, b: number, low: number, high: number)
		if b - a > EPSILON and high - low > EPSILON then
			table.insert(segments, { a = a, b = b, y0 = low, y1 = high })
		end
	end

	local cursor = from
	for _, opening in sorted do
		local oa = math.max(from, opening.center - opening.width / 2)
		local ob = math.min(to, opening.center + opening.width / 2)
		add(cursor, oa, y0, y1)
		add(oa, ob, y0, math.min(y1, opening.bottom)) -- peitoril (janelas)
		add(oa, ob, math.max(y0, opening.top), y1) -- verga acima da abertura
		cursor = math.max(cursor, ob)
	end
	add(cursor, to, y0, y1)
	return segments
end

-- Divide segmentos na altura `split` (faixa inferior / superior com cores diferentes).
function WallMath.splitBands(segments: { Segment }, split: number): ({ Segment }, { Segment })
	local lower: { Segment } = {}
	local upper: { Segment } = {}
	for _, s in segments do
		if s.y1 <= split + EPSILON then
			table.insert(lower, s)
		elseif s.y0 >= split - EPSILON then
			table.insert(upper, s)
		else
			table.insert(lower, { a = s.a, b = s.b, y0 = s.y0, y1 = split })
			table.insert(upper, { a = s.a, b = s.b, y0 = split, y1 = s.y1 })
		end
	end
	return lower, upper
end

-- Área total (útil para testes: sólido + aberturas = parede inteira).
function WallMath.area(segments: { Segment }): number
	local total = 0
	for _, s in segments do
		total += (s.b - s.a) * (s.y1 - s.y0)
	end
	return total
end

return WallMath
