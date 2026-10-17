--!strict
-- Curvas puras: o mesmo ritmo em qualquer FPS e sem estender o relógio do servidor.
local Presentation = {}

function Presentation.ease(alpha: number): number
	local t = math.clamp(alpha, 0, 1)
	return t * t * (3 - 2 * t)
end

function Presentation.shade(elapsed: number, duration: number): number
	if duration <= 0 then
		return 0
	end
	local edge = math.min(0.38, duration / 3)
	return math.max(1 - Presentation.ease(elapsed / edge), 1 - Presentation.ease((duration - elapsed) / edge))
end

function Presentation.cut(alpha: number, duration: number, incoming: boolean, outgoing: boolean): number
	local edge = math.min(0.12, duration / 4)
	local time = math.clamp(alpha, 0, 1) * duration
	return math.max(
		if incoming then 1 - Presentation.ease(time / edge) else 0,
		if outgoing then 1 - Presentation.ease((duration - time) / edge) else 0
	)
end

return table.freeze(Presentation)
