--!strict
--[[
	Diretor de tensão (puro, testado no Lune). Decide QUANDO acontece um evento de clima e QUAL;
	o TensionController (cliente) executa. Todos os eventos são de apresentação local: nenhum
	muda a simulação do servidor (o Vigia de verdade é sempre autoritativo no servidor).

	Estados explícitos:
	  Anticipation  Vigia longe ou dormindo: avisos sutis, espaçados.
	  Tension       Vigia perto, investigando ou medo alto: avisos mais frequentes.
	  Chase         perseguição: o diretor não solta nada (a perseguição já é o susto).
	  Recovery      calmaria depois da perseguição: nada por RecoveryTime segundos.

	Regras: um evento por vez (busyUntil), intervalo mínimo por estado, recarga por evento,
	filtros por sala, medo e progresso da missão. Cada decisão vai para `log` (debug).
]]

local Config = require("../Config")

export type DirectorState = "Anticipation" | "Tension" | "Chase" | "Recovery"

-- Um de ORDER ("flicker", "distant_steps", "radio_static", "vibrate", "whisper", "false_alarm",
-- "silhouette", "door_twitch", "object_shift", "eyes").
export type EventName = string

export type Context = {
	now: number,
	playing: boolean,
	creatureActive: boolean,
	creatureMode: string,
	creatureDistance: number,
	fear: number,
	darkness: number,
	-- Id da sala (Layout.Rooms) ou "Outside".
	zone: string,
	-- Fusíveis coletados + 1 se a energia voltou (0..4).
	progress: number,
	hidden: boolean,
}

export type Decision = {
	state: DirectorState,
	changed: boolean,
	event: EventName?,
	-- O evento pede silêncio antes (o controller abafa o som por SilenceBefore).
	silence: boolean,
}

export type EventSpec = {
	cooldown: number,
	weight: number,
	duration: number,
	states: { [string]: boolean },
	minFear: number?,
	minProgress: number?,
	requiresActive: boolean?,
	maxDistance: number?,
	requiresDark: boolean?,
	silence: boolean?,
	zones: { [string]: boolean }?,
}

export type Director = {
	state: DirectorState,
	stateSince: number,
	lastEventAt: number,
	busyUntil: number,
	cooldowns: { [string]: number },
	log: { string },
	random: () -> number,
}

local T = Config.Tension
local LOG_SIZE = 40

local BOTH = { Anticipation = true, Tension = true }
local CALM = { Anticipation = true }

-- Salas com corredores longos/escuros (Layout.Rooms; inclui as da ampliação do mapa).
local LONG_VIEWS = {
	Corridor = true,
	Storage = true,
	Generator = true,
	Pump = true,
	Outside = true,
	CableGallery = true,
	Archive = true,
	Maintenance = true,
	Switchyard = true,
}
local HAS_DOORS = {
	Corridor = true,
	Office = true,
	Generator = true,
	Storage = true,
	Lobby = true,
}

local EVENTS: { [string]: EventSpec } = {
	-- Lâmpadas instáveis (aviso clássico de que algo vem).
	flicker = { cooldown = 22, weight = 3, duration = 1.4, states = BOTH },
	-- Passos pesados longe, atrás de paredes.
	distant_steps = { cooldown = 34, weight = 2, duration = 3, states = BOTH },
	-- Chiado de rádio (o rádio do vigia).
	radio_static = { cooldown = 45, weight = 2, duration = 2.6, states = BOTH },
	-- Objetos vibrando: só com o Vigia realmente perto.
	vibrate = {
		cooldown = 28,
		weight = 3,
		duration = 1.6,
		states = { Tension = true },
		requiresActive = true,
		maxDistance = 30,
	},
	whisper = { cooldown = 55, weight = 1, duration = 4, states = BOTH, minFear = 0.3 },
	-- Alarme falso: silêncio, rosnado distante, luz falha... e nada.
	false_alarm = {
		cooldown = 85,
		weight = 1,
		duration = 3,
		states = CALM,
		minProgress = 1,
		silence = true,
	},
	-- Alucinações (nunca afetam o jogo de verdade).
	silhouette = {
		cooldown = 75,
		weight = 1,
		duration = 1.6,
		states = BOTH,
		minFear = 0.4,
		minProgress = 1,
		silence = true,
		zones = LONG_VIEWS,
	},
	door_twitch = { cooldown = 60, weight = 1, duration = 1.2, states = BOTH, minFear = 0.25, zones = HAS_DOORS },
	object_shift = { cooldown = 70, weight = 1, duration = 1.2, states = CALM, minFear = 0.2 },
	eyes = {
		cooldown = 95,
		weight = 1,
		duration = 2.2,
		states = BOTH,
		minFear = 0.35,
		minProgress = 1,
		requiresDark = true,
		silence = true,
		zones = LONG_VIEWS,
	},
}

-- Ordem fixa (sorteio determinístico com o mesmo gerador).
local ORDER: { string } = {
	"flicker",
	"distant_steps",
	"radio_static",
	"vibrate",
	"whisper",
	"false_alarm",
	"silhouette",
	"door_twitch",
	"object_shift",
	"eyes",
}

local TensionDirector = {}

TensionDirector.EVENTS = EVENTS
TensionDirector.ORDER = ORDER

function TensionDirector.new(random: (() -> number)?, now: number?): Director
	return {
		state = "Anticipation" :: DirectorState,
		stateSince = now or 0,
		lastEventAt = now or 0,
		busyUntil = 0,
		cooldowns = {},
		log = {},
		random = random or function()
			return math.random()
		end,
	}
end

local function record(d: Director, now: number, text: string)
	table.insert(d.log, string.format("%7.1f %s", now, text))
	if #d.log > LOG_SIZE then
		table.remove(d.log, 1)
	end
end

local function desiredState(d: Director, ctx: Context): DirectorState
	if ctx.creatureMode == "Chase" or ctx.creatureMode == "Capture" then
		return "Chase"
	end
	if d.state == "Chase" then
		return "Recovery"
	end
	if d.state == "Recovery" and ctx.now - d.stateSince < T.RecoveryTime then
		return "Recovery"
	end
	if
		ctx.creatureActive
		and (
			ctx.creatureDistance <= T.TensionRange
			or ctx.creatureMode == "Investigate"
			or ctx.creatureMode == "Search"
		)
	then
		return "Tension"
	end
	if ctx.fear >= 0.5 then
		return "Tension"
	end
	return "Anticipation"
end

-- O evento pode acontecer agora, neste contexto?
function TensionDirector.eligible(d: Director, name: EventName, ctx: Context): boolean
	local spec = EVENTS[name]
	if not spec.states[d.state] then
		return false
	end
	if ctx.now < (d.cooldowns[name] or -math.huge) then
		return false
	end
	if spec.minFear and ctx.fear < spec.minFear then
		return false
	end
	if spec.minProgress and ctx.progress < spec.minProgress then
		return false
	end
	if spec.requiresActive and not ctx.creatureActive then
		return false
	end
	if spec.maxDistance and ctx.creatureDistance > spec.maxDistance then
		return false
	end
	if spec.requiresDark and ctx.darkness < 0.6 then
		return false
	end
	if spec.zones and not spec.zones[ctx.zone] then
		return false
	end
	return true
end

-- Intervalo mínimo entre eventos no estado atual (diminui um pouco com o progresso).
function TensionDirector.gap(d: Director, progress: number): number
	local base = if d.state == "Tension" then T.GapTension else T.GapAnticipation
	return base / (1 + math.max(progress, 0) * 0.15)
end

function TensionDirector.step(d: Director, ctx: Context, dt: number): Decision
	local nextState: DirectorState = desiredState(d, ctx)
	local changed = false
	if nextState ~= d.state then
		record(d, ctx.now, `state {d.state} -> {nextState}`)
		d.state = nextState :: DirectorState
		d.stateSince = ctx.now
		changed = true
	end
	local decision: Decision = { state = d.state, changed = changed, event = nil, silence = false }

	if not ctx.playing or ctx.hidden or d.state == "Chase" or d.state == "Recovery" then
		return decision
	end
	if ctx.now < d.busyUntil or ctx.now - d.lastEventAt < TensionDirector.gap(d, ctx.progress) then
		return decision
	end
	local rate = T.ChancePerSecond * (1 + ctx.progress * 0.2)
	if d.random() >= 1 - math.exp(-rate * math.max(dt, 0)) then
		return decision
	end

	local total = 0
	local pool: { EventName } = {}
	for _, name in ORDER do
		if TensionDirector.eligible(d, name, ctx) then
			table.insert(pool, name)
			total += EVENTS[name].weight
		end
	end
	if total <= 0 then
		return decision
	end
	local roll = d.random() * total
	local chosen = pool[#pool]
	for _, name in pool do
		roll -= EVENTS[name].weight
		if roll < 0 then
			chosen = name
			break
		end
	end

	local spec = EVENTS[chosen]
	local silence = spec.silence == true
	d.lastEventAt = ctx.now
	d.cooldowns[chosen] = ctx.now + spec.cooldown
	d.busyUntil = ctx.now + spec.duration + (if silence then T.SilenceBefore else 0)
	record(
		d,
		ctx.now,
		string.format(
			"event %s (%s, zone %s, fear %.2f, progress %d)",
			chosen,
			d.state,
			ctx.zone,
			ctx.fear,
			ctx.progress
		)
	)
	decision.event = chosen
	decision.silence = silence
	return decision
end

-- Registra algo que aconteceu fora do diretor (ex.: despertar, captura) e segura sustos por `hold` s.
function TensionDirector.notify(d: Director, now: number, text: string, hold: number?)
	record(d, now, text)
	if hold then
		d.busyUntil = math.max(d.busyUntil, now + hold)
	end
end

function TensionDirector.reset(d: Director, now: number)
	d.state = "Anticipation" :: DirectorState
	d.stateSince = now
	d.lastEventAt = now
	d.busyUntil = 0
	table.clear(d.cooldowns)
	record(d, now, "reset")
end

return TensionDirector
