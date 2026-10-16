--!strict
-- Só membros fora de jogo acompanham colegas. Derrubados mantêm a visão do próprio resgate.
local Rules = {}

function Rules.allowed(phase: string, status: string?): boolean
	return (phase == "Playing" or phase == "Extracting") and (status == "Waiting" or status == "Escaped")
end

-- IDs ordenados tornam troca/desconexão determinísticas, incluindo IDs negativos do Studio.
function Rules.choose(ids: { number }, current: number?, direction: number): number?
	if #ids == 0 then
		return nil
	end
	local sorted = table.clone(ids)
	table.sort(sorted)
	local index = if current then table.find(sorted, current) else nil
	if not index then
		return sorted[1]
	end
	return sorted[((index - 1 + direction) % #sorted) + 1]
end

return table.freeze(Rules)
