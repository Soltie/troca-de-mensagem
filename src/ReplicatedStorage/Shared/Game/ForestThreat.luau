--!strict
-- Pressão exclusiva da floresta: difícil, mas sem rastrear jogadores ocultos através de paredes.
local Threat = {}
function Threat.speed(chapter: number, mode: string, base: number): number
	if chapter < 6 or chapter > 8 then
		return base
	end
	local bonus = if mode == "Patrol" then 1.9 elseif mode == "Investigate" then 1.3 elseif mode == "Chase" then 1 else 0
	return base + bonus + (if base > 0 then (chapter - 6) * 0.35 else 0)
end
function Threat.interval(chapter: number): number
	return math.max(12, 24 - (chapter - 6) * 4)
end
function Threat.dark(now: number, chapter: number): boolean
	return chapter >= 6 and chapter <= 8 and now % Threat.interval(chapter) < 6
end
return table.freeze(Threat)
