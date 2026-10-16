--!strict
-- Recompensa fixa e pública: a equipe avança junta; cada colaborador recebe o mesmo bônus.
local TaskRewards = {}
export type Reward = { fichas: number, xp: number }
export type Ledger = { [string]: { [number]: boolean } }

function TaskRewards.reward(contributed: boolean): Reward
	return { fichas = if contributed then 20 else 12, xp = if contributed then 40 else 24 }
end

-- O adaptador não pode ceder execução. Falha de perfil não consome o direito ao pagamento.
-- A chave identifica campanha/etapa/estação e permanece igual ao usar Continuação.
function TaskRewards.claim(ledger: Ledger, key: string, id: number, grant: () -> boolean): boolean
	local paid = ledger[key] or {}
	ledger[key] = paid
	if paid[id] then
		return false
	end
	paid[id] = true
	if not grant() then
		paid[id] = nil
		return false
	end
	return true
end

return table.freeze(TaskRewards)
