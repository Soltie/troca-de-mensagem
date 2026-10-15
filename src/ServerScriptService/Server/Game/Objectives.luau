--!strict
--[[
	Regras puras do objetivo. Sem APIs do Roblox: o RoundService chama estas funções e aplica o
	resultado no mundo. Testado no Lune.

	Fluxo: coletar fusíveis (cada um uma vez) -> inserir no quadro os que estão na mão ->
	religar os disjuntores na ordem do diagrama -> a energia volta -> com energia o portão abre.
	Paralelo (atalho): pegar a chave e destrancar a porta trancada.
]]

export type State = {
	total: number,
	collected: { [string]: boolean },
	held: number,
	inserted: number,
	breakersOn: boolean,
	powerOn: boolean,
	gateOpen: boolean,
	enteredBuilding: boolean,
	hasKey: boolean,
	keyTaken: boolean,
	unlocked: { [string]: boolean },
}

export type ObjectiveKey = "enter" | "fuses" | "insert" | "breakers" | "escape" | "run"

local Objectives = {}

function Objectives.new(total: number): State
	assert(total >= 1, "Objectives.new: total must be >= 1")
	return {
		total = total,
		collected = {},
		held = 0,
		inserted = 0,
		breakersOn = false,
		powerOn = false,
		gateOpen = false,
		enteredBuilding = false,
		hasKey = false,
		keyTaken = false,
		unlocked = {},
	}
end

function Objectives.collectedCount(state: State): number
	local count = 0
	for _ in state.collected do
		count += 1
	end
	return count
end

-- Pega um fusível. Falha se já foi pego ou se já há fusíveis demais.
function Objectives.collect(state: State, fuseId: string): (boolean, string?)
	if state.collected[fuseId] then
		return false, "not_available"
	end
	if Objectives.collectedCount(state) >= state.total then
		return false, "not_available"
	end
	state.collected[fuseId] = true
	state.held += 1
	return true, nil
end

-- Insere no quadro todos os fusíveis na mão. Retorna quantos foram inseridos.
function Objectives.insert(state: State): (number, string?)
	if state.powerOn or state.inserted >= state.total then
		return 0, "already_powered"
	end
	if state.held <= 0 then
		return 0, "no_fuses"
	end
	local amount = math.min(state.held, state.total - state.inserted)
	state.held -= amount
	state.inserted += amount
	return amount, nil
end

function Objectives.isPanelComplete(state: State): boolean
	return state.inserted >= state.total
end

-- Os disjuntores só respondem com os fusíveis todos no quadro.
function Objectives.canUseBreakers(state: State): (boolean, string?)
	if state.breakersOn or state.powerOn then
		return false, "already_powered"
	end
	if not Objectives.isPanelComplete(state) then
		return false, "need_fuses"
	end
	return true, nil
end

function Objectives.solveBreakers(state: State): boolean
	if not Objectives.canUseBreakers(state) then
		return false
	end
	state.breakersOn = true
	return true
end

function Objectives.powerOn(state: State): boolean
	if not Objectives.isPanelComplete(state) or not state.breakersOn or state.powerOn then
		return false
	end
	state.powerOn = true
	return true
end

function Objectives.openGate(state: State): (boolean, string?)
	if not state.powerOn then
		return false, "no_power"
	end
	if state.gateOpen then
		return false, "already_open"
	end
	state.gateOpen = true
	return true, nil
end

function Objectives.canWin(state: State): boolean
	return state.powerOn and state.gateOpen
end

function Objectives.takeKey(state: State): (boolean, string?)
	if state.keyTaken then
		return false, "not_available"
	end
	state.keyTaken = true
	state.hasKey = true
	return true, nil
end

-- Usa a chave numa porta trancada. A chave fica na fechadura (só abre uma porta).
function Objectives.useKey(state: State, doorId: string): (boolean, string?)
	if state.unlocked[doorId] then
		return false, "already_unlocked"
	end
	if not state.hasKey then
		return false, "door_locked"
	end
	state.hasKey = false
	state.unlocked[doorId] = true
	return true, nil
end

function Objectives.objectiveKey(state: State): ObjectiveKey
	if state.gateOpen then
		return "run"
	end
	if state.powerOn then
		return "escape"
	end
	if not state.enteredBuilding then
		return "enter"
	end
	if Objectives.isPanelComplete(state) then
		return "breakers"
	end
	if Objectives.collectedCount(state) >= state.total then
		return "insert"
	end
	return "fuses"
end

return Objectives
