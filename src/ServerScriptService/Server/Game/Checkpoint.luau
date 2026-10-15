--!strict
--[[
	Checkpoint de sessão (puro, testado no Lune). Gravado uma vez por rodada, quando a energia
	volta. Guarda o que é preciso para continuar dali: objetivos (fusíveis, chave, disjuntores),
	portas (aberta/fresta/fechada, trancas), carga da lanterna, itens já pegos e a ordem dos
	disjuntores. Nada é persistido: some ao "reiniciar tudo" ou ao sair do jogo.

	capture/restore sempre copiam: o snapshot nunca é alterado pelo jogo depois de gravado.
]]

local TableUtil = require("@game/ReplicatedStorage/Shared/Util/TableUtil")
local Objectives = require("./Objectives")

export type DoorState = "open" | "crack" | "closed"

export type Snapshot = {
	objectives: Objectives.State,
	doors: { [string]: DoorState },
	locked: { [string]: boolean },
	battery: number,
	breakerOrder: { number },
	-- Itens do mundo já pegos (pilhas, chave), por id.
	taken: { [string]: boolean },
}

local Checkpoint = {}

function Checkpoint.capture(input: Snapshot): Snapshot
	local copy = TableUtil.deepCopy(input)
	copy.battery = math.clamp(copy.battery, 0, 1)
	return copy
end

-- Cópia independente para aplicar no jogo (o snapshot continua intacto para outra tentativa).
function Checkpoint.restore(snapshot: Snapshot): Snapshot
	return TableUtil.deepCopy(snapshot)
end

-- Só vale continuar de um checkpoint que já tem a energia ligada.
function Checkpoint.isUsable(snapshot: Snapshot?): boolean
	return snapshot ~= nil and snapshot.objectives.powerOn and not snapshot.objectives.gateOpen
end

return Checkpoint
