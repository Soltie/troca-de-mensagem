--!strict
--[[
	Revista do armário (ideia C, Outlast/Granny). Puro, testado no Lune.
	Quando o Tung Tung chega ao armário de alguém (viu entrar ou ouviu respirar), ele não pega na hora: fica na
	porta e o jogador precisa segurar a respiração no ritmo. São `Beats` batidas; em cada uma um anel fecha sobre o
	círculo e o jogador aperta quando encosta (janela de `Window` s para cada lado). `MaxMisses` erros = ele abre a
	porta (pancada). Acertou o resto: ele desiste e vai embora. Apertar fora de hora conta como erro da próxima batida.
]]

local BreathTest = {}

BreathTest.Beats = 5
BreathTest.FirstDelay = 1.8
BreathTest.Window = 0.24
BreathTest.MaxMisses = 3
-- Intervalos possíveis entre batidas (o ritmo varia um pouco para não virar automático).
local INTERVALS = { 1.05, 1.2, 1.35, 0.95, 1.25 }

export type Result = "hit" | "miss"

-- Instantes das batidas (segundos desde o começo), a partir de uma semente.
function BreathTest.times(seed: number): { number }
	local out = {}
	local t = BreathTest.FirstDelay
	for index = 1, BreathTest.Beats do
		table.insert(out, t)
		t += INTERVALS[((seed + index * 3) % #INTERVALS) + 1]
	end
	return out
end

-- Primeira batida ainda sem resultado.
local function pending(results: { Result? }): number?
	for index = 1, BreathTest.Beats do
		if results[index] == nil then
			return index
		end
	end
	return nil
end

--[[
	Aperto do jogador em `elapsed` segundos. Acerta a batida pendente se cair na janela dela; adiantado demais
	(antes da janela) erra essa batida. Retorna o índice julgado e o resultado, ou nil se não havia batida pendente.
]]
function BreathTest.press(times: { number }, results: { Result? }, elapsed: number): (number?, Result?)
	local index = pending(results)
	if not index then
		return nil, nil
	end
	local result: Result = if math.abs(elapsed - times[index]) <= BreathTest.Window then "hit" else "miss"
	results[index] = result
	return index, result
end

-- Batidas cuja janela já passou sem aperto viram erro. Retorna quantas mudaram.
function BreathTest.expire(times: { number }, results: { Result? }, elapsed: number): number
	local changed = 0
	for index = 1, BreathTest.Beats do
		if results[index] == nil and elapsed > times[index] + BreathTest.Window then
			results[index] = "miss"
			changed += 1
		end
	end
	return changed
end

function BreathTest.misses(results: { Result? }): number
	local count = 0
	for index = 1, BreathTest.Beats do
		if results[index] == "miss" then
			count += 1
		end
	end
	return count
end

-- "fail" assim que chega a MaxMisses; "pass" quando todas as batidas foram julgadas; nil enquanto corre.
function BreathTest.outcome(results: { Result? }): ("pass" | "fail")?
	if BreathTest.misses(results) >= BreathTest.MaxMisses then
		return "fail"
	end
	if pending(results) == nil then
		return "pass"
	end
	return nil
end

-- Texto curto para replicar o placar (H acerto, M erro, - pendente).
function BreathTest.encode(results: { Result? }): string
	local out = table.create(BreathTest.Beats, "-")
	for index = 1, BreathTest.Beats do
		local result = results[index]
		out[index] = if result == "hit" then "H" elseif result == "miss" then "M" else "-"
	end
	return table.concat(out)
end

return table.freeze(BreathTest)
