--!strict
-- Apresentação pura: usa só o progresso publicado, nunca revela a solução das sequências.
local Catalog = require("./CampaignCatalog")

export type Activity = {
	id: string,
	room: string,
	kind: string,
	title: string?,
	solved: boolean,
	progress: number,
	relayUntil: number?,
	x: number?,
	z: number?,
}
local Guide = {}

function Guide.current(tasks: { Activity }): (Activity?, number)
	for index, activity in tasks do
		if not activity.solved then
			return activity, index
		end
	end
	return nil, 0
end

function Guide.instruction(activity: Activity, now: number, activePlayers: number?): string
	if activity.kind == "repair" then
		local actions = { "isolar circuito", "encaixar fusível", "testar energia" }
		return `Mire no botão {activity.progress + 1} ({actions[activity.progress + 1] or "concluído"}) e aperte E. Progresso: {activity.progress}/3.`
	elseif activity.kind == "sequence" then
		return `Leia a sequência na placa da estação. Mire em cada botão numerado e aperte E na ordem. {activity.progress}/3 confirmados.`
	elseif activity.kind == "relay" then
		if activePlayers == 1 then
			return "Você é o último ativo. Aperte E e confirme de novo no mesmo relé antes do tempo acabar."
		end
		local remaining = math.max(0, math.ceil((activity.relayUntil or 0) - now))
		if activity.progress > 0 and remaining > 0 then
			return `Outro colega precisa apertar E neste mesmo relé em {remaining}s. A mesma pessoa não confirma a dupla.`
		end
		return "Venham em dupla. Uma pessoa aperta E; a outra confirma no mesmo botão antes do tempo acabar."
	end
	return "Aproxime-se, mire no botão da estação e aperte E."
end

function Guide.objective(phase: string, status: string?, activity: Activity?): (string, string)
	if phase == "Briefing" then
		return "Prepare-se para o turno",
			"Aguarde o fim da apresentação da equipe. O objetivo fica disponível após a contagem."
	elseif phase == "Won" then
		return "Equipe evacuada", "Turno encerrado. Aperte R para votar a volta ao menu com a equipe."
	elseif phase == "Lost" then
		return "O turno foi interrompido", "A equipe ficou fora de combate. Aperte R para votar uma nova tentativa."
	elseif phase == "Intermission" then
		return "Etapa concluída", "Aguarde o próximo setor. Colegas fora de combate retornam nesta transição."
	elseif status == "Downed" then
		return "Você precisa de resgate",
			"Um colega deve chegar perto, mirar em você e apertar E. Ele precisa permanecer perto e com visão."
	elseif status == "Escaped" then
		return "Você chegou à saída",
			"Aguarde os sobreviventes. A partida termina quando a equipe concluir a evacuação."
	elseif status == "Waiting" then
		return "Aguarde a equipe", "Você entra no próximo estágio. Use as setas para acompanhar os colegas ativos."
	elseif phase == "Extracting" then
		return "Reúnam a equipe no portão",
			"O portão está liberado. Resgatem os colegas caídos e atravessem a saída no pátio de entrada."
	elseif activity then
		return activity.title or `Concluir {Catalog.KindNames[activity.kind] or "estação"}`,
			`Vá até {Catalog.RoomNames[activity.room] or "o setor indicado"}.`
	end
	return "Preparando a próxima etapa", "Aguarde o carregamento do setor."
end

Guide.StageTips = {
	"Reconexão: concluam as estações para avançar. A lanterna ajuda a enxergar, mas sua luz atrai o Vigia.",
	"Sincronização: combinem quem confirma os relés. Corrida e outros ruídos podem atrair o Vigia.",
	"Evacuação: concluam as últimas estações. Depois, reúnam os sobreviventes e saiam juntos pelo portão.",
}
Guide.SurvivalTips = {
	"F alterna a lanterna. Se ouvir o Vigia, apague a luz e procure cobertura.",
	"C agacha. Shift corre e gasta fôlego; solte para recuperar. Correr faz mais barulho.",
	"Colega caído? Aproxime-se, mire nele e aperte E. Fique perto e com visão até terminar o resgate.",
	"As portas também usam E. Abra a passagem, procure as placas dos setores e acompanhe o objetivo marcado.",
}

return table.freeze(Guide)
