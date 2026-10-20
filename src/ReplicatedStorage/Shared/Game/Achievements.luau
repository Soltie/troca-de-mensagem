--!strict
--[[
	Conquistas dentro do jogo (opção E). Ficam em PlayerData.house.achievements[id] = hora (mapa livre, sem mudar o
	formato salvo) e aparecem no painel de dificuldade do lobby. Badges oficiais do Roblox dependem do Creator Hub:
	passo humano (docs/PENDENCIAS_HUMANAS.md).
]]

export type Achievement = { id: string, title: string, description: string }

local Achievements = {}

Achievements.List = table.freeze({
	{ id = "escaped", title = "SOBREVIVENTE", description = "Fugir da mata na van do resgate." },
	{ id = "pesadelo", title = "NOITE DE PESADELO", description = "Vencer um capítulo no modo Pesadelo." },
	{ id = "todos", title = "SEM PIEDADE", description = "Vencer um capítulo com todos os modificadores." },
	{ id = "tabua", title = "CARPINTEIRO", description = "Pregar uma tábua num buraco do túnel." },
	{ id = "catacumba", title = "DESCIDA", description = "Entrar na catacumba embaixo do jardim." },
	{ id = "ponte", title = "ADEUS, PONTE", description = "Ver o Tung Tung cair no rio." },
	{ id = "jangada", title = "TRAVESSIA", description = "Chegar à ilha do rádio." },
	{ id = "farol", title = "SINAL NO ESCURO", description = "Acender o farol da torre." },
	{ id = "lago", title = "NÃO NADE", description = "Ser puxado de volta pela coisa do lago." },
} :: { Achievement })

local byId: { [string]: Achievement } = {}
for _, a in Achievements.List do
	byId[a.id] = a
end

function Achievements.get(id: string): Achievement?
	return byId[id]
end

-- Conquistas que um capítulo vencido libera conforme os modificadores da partida.
function Achievements.forWin(modifiers: { string }, total: number): { string }
	local out = {}
	if table.find(modifiers, "pesadelo") then
		table.insert(out, "pesadelo")
	end
	if #modifiers >= total and total > 0 then
		table.insert(out, "todos")
	end
	return out
end

return table.freeze(Achievements)
