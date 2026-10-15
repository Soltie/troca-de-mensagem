--!strict
--[[
	Regras puras do objetivo (fusíveis -> quadro -> energia -> portão). Sem APIs do Roblox:
	o RoundService chama estas funções e aplica o resultado no mundo. Testado no Lune.

	Fluxo: coletar fusíveis (cada um uma vez) -> inserir no quadro os que estão na mão ->
	com todos inseridos a energia pode ser ligada -> com energia o portão pode abrir.
]]

export type State = {
	total: number,
	collected: { [string]: boolean },
	held: number,
	inserted: number,
	powerOn: boolean,
	gateOpen: boolean,
	enteredBuilding: boolean,
}

export type ObjectiveKey = "enter" | "fuses" | "insert" | "escape" | "run"

local Objectives = {}

function Objectives.new(total: number): State
	assert(total >= 1, "Objectives.new: total must be >= 1")
	return {
		total = total,
		collected = {},
		held = 0,
		inserted = 0,
		powerOn = false,
		gateOpen = false,
		enteredBuilding = false,
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

function Objectives.powerOn(state: State): boolean
	if not Objectives.isPanelComplete(state) or state.powerOn then
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
	if Objectives.collectedCount(state) >= state.total then
		return "insert"
	end
	return "fuses"
end

return Objectives
