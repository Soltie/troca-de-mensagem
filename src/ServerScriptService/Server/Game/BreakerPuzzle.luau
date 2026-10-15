--!strict
--[[
	Puzzle dos disjuntores (puro, testado no Lune). Depois dos 3 fusíveis no quadro, os
	disjuntores precisam ser religados na ordem do diagrama (sorteada por rodada).
	Ordem certa: cada alavanca sobe e acende. Errou: todas caem (faísca + barulho no mundo).
]]

export type State = {
	order: { number },
	-- Quantos acertos seguidos (alavancas já levantadas, na ordem).
	progress: number,
	solved: boolean,
}

export type Result = "progress" | "solved" | "wrong" | "already"

local BreakerPuzzle = {}

function BreakerPuzzle.new(order: { number }): State
	assert(#order >= 1, "BreakerPuzzle.new: empty order")
	local seen = {}
	for _, index in order do
		assert(not seen[index], "BreakerPuzzle.new: repeated breaker")
		seen[index] = true
	end
	return { order = table.clone(order), progress = 0, solved = false }
end

-- Ordem aleatória de 1..count. `nextInteger(a, b)` é injetado (Random:NextInteger no jogo).
function BreakerPuzzle.shuffle(count: number, nextInteger: (number, number) -> number): { number }
	local order = {}
	for i = 1, count do
		order[i] = i
	end
	for i = count, 2, -1 do
		local j = nextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	return order
end

function BreakerPuzzle.isUp(state: State, index: number): boolean
	if state.solved then
		return true
	end
	for i = 1, state.progress do
		if state.order[i] == index then
			return true
		end
	end
	return false
end

function BreakerPuzzle.press(state: State, index: number): Result
	if state.solved or BreakerPuzzle.isUp(state, index) then
		return "already"
	end
	if state.order[state.progress + 1] == index then
		state.progress += 1
		if state.progress >= #state.order then
			state.solved = true
			return "solved"
		end
		return "progress"
	end
	state.progress = 0
	return "wrong"
end

-- Letras do diagrama (1 -> "A"...). Ex.: {2,3,1} -> "B - C - A".
function BreakerPuzzle.describe(order: { number }): string
	local letters = {}
	for _, index in order do
		table.insert(letters, string.char(64 + index))
	end
	return table.concat(letters, " - ")
end

return BreakerPuzzle
