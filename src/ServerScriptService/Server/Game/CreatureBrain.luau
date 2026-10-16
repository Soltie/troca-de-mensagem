--!strict
--[[
	Cérebro do Vigia: máquina de estados pura (testada no Lune). Não move nada e não faz
	raycast — o CreatureService calcula a percepção e executa o comando devolvido.

	Modos:
	  Dormant     parado/escondido até ativar
	  Patrol      segue a rota de patrulha (o service escolhe o próximo nó)
	  Investigate vai até um ponto (barulho, último lugar visto, "faro")
	  Search      parado olhando em volta por SearchTime, depois volta a patrulhar
	  Chase       persegue o jogador
	  Capture     pegou o jogador (fim de rodada)

	Posições são opacas (o service usa Vector3; os testes usam tabelas).
]]

local Config = require("@game/ReplicatedStorage/Shared/Config")

export type Mode = "Dormant" | "Patrol" | "Investigate" | "Search" | "Chase" | "Capture"

export type Perception = {
	now: number,
	-- Linha de visão + alcance + campo de visão (o service já combinou tudo).
	canSee: boolean,
	-- Só linha de visão (sem considerar alcance/ângulo); usada para a captura.
	lineOfSight: boolean,
	distance: number?,
	targetPos: any?,
	noisePos: any?,
	-- Energia ligada: ele sempre sabe onde o jogador está.
	hunt: boolean,
	-- O service avisa quando chegou ao destino atual.
	arrived: boolean,
}

export type Command = {
	mode: Mode,
	target: any?,
	speed: number,
	-- Evento para efeitos/legendas: "spotted" | "lost" | "capture" | nil
	event: string?,
}

export type Brain = {
	mode: Mode,
	fuses: number,
	lastKnownPos: any?,
	lastSeenAt: number,
	investigatePos: any?,
	searchUntil: number,
}

local C = Config.Creature

local CreatureBrain = {}

function CreatureBrain.new(): Brain
	return {
		mode = "Dormant",
		fuses = 0,
		lastKnownPos = nil,
		lastSeenAt = -math.huge,
		investigatePos = nil,
		searchUntil = 0,
	}
end

function CreatureBrain.activate(brain: Brain)
	if brain.mode == "Dormant" then
		brain.mode = "Patrol"
	end
end

function CreatureBrain.speedFor(mode: Mode, fuses: number, hunt: boolean): number
	if mode == "Chase" then
		if hunt then
			return C.HuntSpeed
		end
		return C.ChaseSpeed + fuses * C.ChaseSpeedPerFuse
	elseif mode == "Investigate" then
		return C.InvestigateSpeed
	elseif mode == "Patrol" then
		return C.PatrolSpeed + fuses * C.PatrolSpeedPerFuse
	end
	return 0
end

local function command(brain: Brain, target: any?, hunt: boolean, event: string?): Command
	return {
		mode = brain.mode,
		target = target,
		speed = CreatureBrain.speedFor(brain.mode, brain.fuses, hunt),
		event = event,
	}
end

function CreatureBrain.step(brain: Brain, p: Perception): Command
	if brain.mode == "Dormant" or brain.mode == "Capture" then
		return command(brain, nil, p.hunt, nil)
	end

	-- Captura: perto o bastante e sem parede no meio.
	if p.distance and p.distance <= C.CaptureRange and p.lineOfSight then
		brain.mode = "Capture"
		return command(brain, nil, p.hunt, "capture")
	end

	-- Viu (ou a energia voltou e ele caça): persegue.
	if (p.canSee or p.hunt) and p.targetPos ~= nil then
		local event = if brain.mode ~= "Chase" and p.canSee then "spotted" else nil
		brain.mode = "Chase"
		brain.lastKnownPos = p.targetPos
		brain.lastSeenAt = p.now
		return command(brain, p.targetPos, p.hunt, event)
	end

	if brain.mode == "Chase" then
		local unseen = p.now - brain.lastSeenAt
		if unseen <= C.GraceTime and p.targetPos ~= nil then
			-- "Intuição" curta: ainda segue o jogador logo após virar uma esquina.
			return command(brain, brain.lastKnownPos, p.hunt, nil)
		end
		if unseen <= C.LoseSightTime and not p.arrived then
			return command(brain, brain.lastKnownPos, p.hunt, nil)
		end
		brain.mode = "Search"
		brain.searchUntil = p.now + C.SearchTime
		return command(brain, nil, p.hunt, "lost")
	end

	-- Barulho interrompe patrulha/procura (não a perseguição, tratada acima).
	if p.noisePos ~= nil then
		brain.mode = "Investigate"
		brain.investigatePos = p.noisePos
		return command(brain, p.noisePos, p.hunt, nil)
	end

	if brain.mode == "Investigate" then
		if p.arrived then
			brain.mode = "Search"
			brain.searchUntil = p.now + C.SearchTime
			return command(brain, nil, p.hunt, nil)
		end
		return command(brain, brain.investigatePos, p.hunt, nil)
	end

	if brain.mode == "Search" then
		if p.now >= brain.searchUntil then
			brain.mode = "Patrol"
		end
		return command(brain, nil, p.hunt, nil)
	end

	-- Patrol: o service escolhe o próximo nó da rota.
	return command(brain, nil, p.hunt, nil)
end

return CreatureBrain
