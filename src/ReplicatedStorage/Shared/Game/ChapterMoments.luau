--!strict
--[[
	Um momento roteirizado por capítulo da casa (veredito 20/10/2026, item 4), disparado uma vez quando uma tarefa
	certa é concluída. O servidor (ChapterMomentService) publica o momento em CampaignState; o cliente
	(MomentController) faz a parte visual. O capítulo 5 já tem o fogo e a floresta tem a ponte, o lago e a torre.
	- 1, terceira chave: APAGÃO. A casa inteira pisca e apaga por alguns segundos; uma porta bate lá no fundo.
	- 2, energia de volta: VULTO. Quando a luz volta, um vulto parado no fim do corredor some na piscada seguinte.
	- 3, máscara: TÚNEL. Ele cava o chão e sai pelo buraco mais perto de quem pegou a máscara (com aviso).
	- 4, artefato: TREMOR. A casa treme, as luzes ficam vermelhas e ele ruge lá embaixo, vindo atrás do coração.
	Puro: sem `game`; testado no Lune.
]]

export type Moment = "blackout" | "shadow" | "tunnel" | "quake"

local ChapterMoments = {}

local BY_TASK: { [number]: { index: number, moment: Moment } } = {
	[1] = { index = 6, moment = "blackout" },
	[2] = { index = 5, moment = "shadow" },
	[3] = { index = 2, moment = "tunnel" },
	[4] = { index = 5, moment = "quake" },
}

ChapterMoments.Caption = table.freeze({
	blackout = "A casa inteira apagou... alguém fechou uma porta lá no fundo.",
	shadow = "Tinha alguém no fim do corredor.",
	tunnel = "Ele está nas paredes. Saia de perto dos buracos!",
	quake = "A casa sabe que vocês pegaram o coração. CORRAM!",
} :: { [string]: string })

-- Duração da parte visual no cliente (s).
ChapterMoments.Duration = table.freeze({
	blackout = 4.5,
	shadow = 2.2,
	tunnel = 3,
	quake = 3.5,
} :: { [string]: number })

function ChapterMoments.forTask(stage: number, index: number): Moment?
	local entry = BY_TASK[stage]
	return if entry and entry.index == index then entry.moment else nil
end

return table.freeze(ChapterMoments)
