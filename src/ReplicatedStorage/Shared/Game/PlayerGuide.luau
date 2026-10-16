--!strict
-- Apresentação pura: usa só o progresso publicado, nunca revela a solução das sequências.
-- Textos curtos e diretos, pensados para crianças lerem no meio da ação.
local Catalog = require("./CampaignCatalog")

export type Activity = {
	id: string,
	room: string,
	kind: string,
	title: string?,
	solved: boolean,
	progress: number,
	required: number?,
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
	if activity.kind == "collect" then
		return "Ache o objeto brilhando e aperte E para pegar. Vale para o time todo!"
	elseif activity.kind == "clue" then
		return "Chegue perto da pista e aperte E para ler. Ela ensina o próximo desafio."
	elseif activity.kind == "explore" then
		return "Siga a seta amarela e entre na casa."
	elseif activity.kind == "hide" then
		return "Entre no armário com E. Cabe só uma pessoa em cada esconderijo."
	elseif activity.kind == "breath" then
		return "Escondido? Segure Espaço (ou Z) para prender o ar. Solte antes do ar acabar!"
	elseif activity.kind == "puzzle" then
		return `Aperte E nos símbolos na ordem da pista: {activity.progress}/{activity.required or 4}. Errou? Os acertos ficam salvos.`
	elseif activity.kind == "activate" then
		return "Vá até o mecanismo brilhante e aperte E. O time já tem tudo o que precisa!"
	elseif activity.kind == "repair" then
		local actions = { "desligar", "trocar o fusível", "ligar de novo" }
		return `Aperte E no botão aceso {activity.progress + 1} ({actions[activity.progress + 1] or "pronto"}). Progresso: {activity.progress}/3.`
	elseif activity.kind == "sequence" then
		return `Olhe a ordem na placa e aperte E nos botões numerados. {activity.progress}/3 certos.`
	elseif activity.kind == "relay" then
		if activePlayers == 1 then
			return "Você é o último de pé: aperte E duas vezes no mesmo botão, rapidinho!"
		end
		local remaining = math.max(0, math.ceil((activity.relayUntil or 0) - now))
		if activity.progress > 0 and remaining > 0 then
			return `Chame um amigo! Ele precisa apertar E neste mesmo botão em {remaining}s.`
		end
		return "Trabalho em dupla: um aperta E e o amigo confirma no mesmo botão logo depois."
	end
	return "Chegue perto do objetivo brilhante e aperte E."
end

function Guide.objective(phase: string, status: string?, activity: Activity?): (string, string)
	if phase == "Briefing" then
		return "Prepare-se!", "A aventura começa em instantes. Fique junto do seu time."
	elseif phase == "Won" then
		return "Vocês escaparam!", "Que coragem! Aperte R para votar e voltar ao menu com o time."
	elseif phase == "Lost" then
		return "O Tung Tung pegou o time!", "Sem problema: aperte R para tentar de novo deste capítulo."
	elseif phase == "Intermission" then
		return "Capítulo concluído!", "Respire fundo. Amigos que caíram voltam no próximo capítulo."
	elseif status == "Downed" then
		return "Você caiu!", "Espere um amigo chegar perto e apertar E em você."
	elseif status == "Escaped" then
		return "Você está a salvo!", "Torça pelo seu time: a partida acaba quando todos escaparem."
	elseif status == "Waiting" then
		return "Você entra no próximo capítulo", "Use as setas para assistir aos amigos enquanto isso."
	elseif phase == "Extracting" then
		return "FUJA PARA O PORTÃO!", "O portão abriu! Ajude quem caiu e corra para a floresta."
	elseif activity then
		return activity.title or `Concluir {Catalog.KindNames[activity.kind] or "desafio"}`,
			`Vá até {Catalog.RoomNames[activity.room] or "o lugar marcado"}.`
	end
	return "Preparando o próximo capítulo", "Só um instante..."
end

Guide.StageTips = {
	"Capítulo 1: pegue a lanterna, ache as três chaves e abra a biblioteca.",
	"Capítulo 2: religue a energia e aprenda a se esconder no armário.",
	"Capítulo 3: explore o sótão. O livro mostra os quatro símbolos.",
	"Capítulo 4: leia as pistas do porão para descobrir o código do cofre.",
	"Capítulo 5: use o artefato, ative o ritual e fuja antes do tempo acabar!",
}
Guide.SurvivalTips = {
	"Ouviu TUM TUM TUM? Apague a lanterna (F) e se esconda!",
	"Shift corre, mas cansa e faz barulho. C agacha e deixa você mais silencioso.",
	"Amigo caiu? Chegue perto, mire nele e aperte E para ajudar.",
	"Moedas brilhantes valem Fichas! Pegue todas que encontrar.",
	"Portas abrem com E. Siga a seta amarela para não se perder.",
}

return table.freeze(Guide)
