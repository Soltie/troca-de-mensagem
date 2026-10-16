--!strict
-- Estado puro da equipe. Só o adaptador do servidor verifica distância/visão e aplica efeitos físicos.
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Generator = require("./CampaignGenerator")
local HousePlan = require("./HousePlan")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")

export type Status = "Active" | "Downed" | "Waiting" | "Escaped"
export type Phase = "Lobby" | "Playing" | "Intermission" | "Extracting" | "Won" | "Lost"
export type Member = {
	id: number,
	role: string,
	status: Status,
	downedUntil: number,
	contributions: number,
	-- Segunda Chance (vantagem paga) em curso: até quando o caído ainda pode levantar sozinho.
	risingUntil: number?,
}
export type TaskState = {
	spec: Generator.Activity,
	progress: number,
	solved: boolean,
	relayBy: number?,
	relayUntil: number,
	contributors: { [number]: boolean },
}
export type Policy = { minPlayers: number, maxPlayers: number, downedSeconds: number, relayWindow: number }
export type State = {
	house: boolean,
	inventory: { [string]: number },
	checkpointInventory: { [string]: number },
	mode: string,
	seed: number,
	stage: number,
	phase: Phase,
	members: { [number]: Member },
	plan: Generator.Plan?,
	tasks: { [string]: TaskState },
	votes: { [number]: boolean },
	policy: Policy,
}

local Session = {}

local function finite(n: number): boolean
	return n == n and math.abs(n) < math.huge
end

function Session.new(seed: number, policy: Policy, mode: string?, house: boolean?): State
	assert(mode == nil or mode == "Standard" or mode == "Story", "Invalid game mode")
	assert(finite(seed) and seed % 1 == 0, "Invalid campaign seed")
	assert(
		policy.minPlayers >= 1 and policy.maxPlayers <= 8 and policy.minPlayers <= policy.maxPlayers,
		"Invalid party policy"
	)
	assert(policy.downedSeconds > 0 and policy.relayWindow > 0, "Invalid timer policy")
	return {
		house = house == true,
		inventory = {},
		checkpointInventory = {},
		mode = mode or "Standard",
		seed = seed,
		stage = 0,
		phase = "Lobby",
		members = {},
		plan = nil,
		tasks = {},
		votes = {},
		policy = table.clone(policy),
	}
end

function Session.count(state: State, status: Status?): number
	local n = 0
	for _, member in state.members do
		if status == nil or member.status == status then
			n += 1
		end
	end
	return n
end

function Session.join(state: State, id: number): (boolean, string?)
	if not finite(id) or id % 1 ~= 0 then
		return false, "invalid_player"
	end
	if state.members[id] then
		return false, "already_joined"
	end
	local count = Session.count(state)
	if count >= state.policy.maxPlayers then
		return false, "party_full"
	end
	local role = Catalog.Roles[count % #Catalog.Roles + 1].id
	state.members[id] = { id = id, role = role, status = "Waiting", downedUntil = 0, contributions = 0 }
	return true, nil
end

local function evaluate(state: State)
	if state.phase ~= "Playing" and state.phase ~= "Extracting" then
		return
	end
	local active = Session.count(state, "Active")
	local escaped = Session.count(state, "Escaped")
	local downed = Session.count(state, "Downed")
	-- Alguém caído vai levantar sozinho (Segunda Chance): a derrota espera a janela dele.
	for _, member in state.members do
		if member.status == "Downed" and member.risingUntil then
			return
		end
	end
	-- Evacuados não apagam instantaneamente os colegas derrubados: aguardar resgate/timeout.
	if state.phase == "Extracting" and active == 0 and escaped > 0 and downed > 0 then
		return
	end
	if state.phase == "Extracting" and active == 0 and downed == 0 and escaped > 0 then
		state.phase = "Won"
	elseif active == 0 then
		state.phase = if escaped > 0 then "Won" else "Lost"
	end
end

function Session.leave(state: State, id: number)
	state.members[id], state.votes[id] = nil, nil
	for _, activity in state.tasks do
		if activity.relayBy == id and not activity.solved then
			activity.relayBy, activity.relayUntil, activity.progress = nil, 0, 0
		end
	end
	evaluate(state)
	if Session.count(state) == 0 then
		state.phase, state.stage, state.plan, state.tasks, state.votes = "Lobby", 0, nil, {}, {}
	end
end

function Session.beginStage(state: State): (boolean, string?)
	if state.phase ~= "Lobby" and state.phase ~= "Intermission" then
		return false, "wrong_phase"
	end
	local count = Session.count(state)
	-- O mínimo vale só para iniciar a campanha. Desconexões não bloqueiam estágios posteriores.
	if count == 0 or (state.stage == 0 and count < state.policy.minPlayers) then
		return false, "need_players"
	end
	if state.stage >= (if state.house then #House.Chapters else #Catalog.Stages) then
		return false, "campaign_complete"
	end
	local plan = if state.house
		then HousePlan.create(state.seed, state.stage + 1, count, state.mode)
		else Generator.create(state.seed, state.stage + 1, count)
	local valid: boolean, reason: string? = false, nil
	if state.house then
		valid, reason = HousePlan.validate(plan)
	else
		valid, reason = Generator.validate(plan)
	end
	state.checkpointInventory = table.clone(state.inventory)
	if not valid then
		return false, reason
	end
	state.stage += 1
	state.plan, state.tasks, state.votes = plan, {}, {}
	for _, spec in plan.activities do
		state.tasks[spec.id] =
			{ spec = spec, progress = 0, solved = false, relayBy = nil, relayUntil = 0, contributors = {} }
	end
	for _, member in state.members do
		member.status, member.downedUntil = "Active", 0
	end
	state.phase = "Playing"
	return true, nil
end

function Session.solvedCount(state: State): number
	local n = 0
	for _, activity in state.tasks do
		if activity.solved then
			n += 1
		end
	end
	return n
end

function Session.act(state: State, id: number, taskId: string, button: number, now: number): (boolean, string)
	if state.phase ~= "Playing" then
		return false, "wrong_phase"
	end
	local member = state.members[id]
	if not member or member.status ~= "Active" then
		return false, "not_active"
	end
	if
		not finite(now)
		or not finite(button)
		or button % 1 ~= 0
		or button < 1
		or button > (if state.house then 4 else 3)
	then
		return false, "invalid_action"
	end
	local activity = state.tasks[taskId]
	if not activity or activity.solved then
		return false, "not_available"
	end
	if (state.house or state.mode == "Story") and state.plan then
		for _, previous in state.plan.activities do
			if previous.id == taskId then
				break
			end
			if not state.tasks[previous.id].solved then
				return false, "story_order"
			end
		end
	end
	local kind = activity.spec.kind
	local result = "progress"
	if state.house then
		if kind == "puzzle" then
			if activity.spec.order[activity.progress + 1] ~= button then
				return false, "wrong_sequence"
			end
			activity.progress += 1
			activity.solved = activity.progress >= #activity.spec.order
		else
			if button ~= 1 then
				return false, "invalid_action"
			end
			activity.progress, activity.solved = 1, true
		end
		if activity.solved and activity.spec.item then
			state.inventory[activity.spec.item] = 1
		end
	elseif kind == "repair" then
		if button ~= activity.progress + 1 then
			return false, "repair_order"
		end
		-- O técnico combina isolamento + encaixe; testar a energia continua sendo uma ação explícita.
		activity.progress += if member.role == "technician" and activity.progress == 0 then 2 else 1
		activity.solved = activity.progress >= 3
	elseif kind == "sequence" then
		if activity.spec.order[activity.progress + 1] ~= button then
			return false, "wrong_sequence"
		end
		activity.progress += 1
		activity.solved = activity.progress >= 3
	elseif kind == "relay" then
		if button ~= 1 then
			return false, "invalid_action"
		end
		if activity.relayBy == nil or activity.relayUntil <= now then
			activity.relayBy = id
			activity.relayUntil = now + state.policy.relayWindow * (if member.role == "operator" then 1.5 else 1)
			activity.progress = 1
			result = "need_partner"
		elseif activity.relayBy ~= id or Session.count(state, "Active") == 1 then
			activity.progress, activity.solved = 3, true
		else
			return false, "need_partner"
		end
	else
		return false, "unknown_activity"
	end
	-- Ajudar vale uma contribuição por estação, inclusive para o técnico. Repetir o relé não gera farm.
	if not activity.contributors[id] then
		activity.contributors[id] = true
		member.contributions += 1
	end
	if activity.solved then
		result = "solved"
	end
	local plan = state.plan
	if plan and Session.solvedCount(state) == #plan.activities then
		state.phase = if state.stage == (if state.house then #House.Chapters else #Catalog.Stages)
			then "Extracting"
			else "Intermission"
	end
	return true, result
end

-- `rising` (s): o jogador tem Segunda Chance; a derrota da equipe espera essa janela.
function Session.capture(state: State, id: number, now: number, rising: number?): boolean
	if state.phase ~= "Playing" and state.phase ~= "Extracting" then
		return false
	end
	local member = state.members[id]
	if not member or member.status ~= "Active" or not finite(now) then
		return false
	end
	member.status, member.downedUntil = "Downed", now + state.policy.downedSeconds
	member.risingUntil = if rising and rising > 0 and finite(rising) then now + rising else nil
	for _, activity in state.tasks do
		if activity.relayBy == id and not activity.solved then
			activity.relayBy, activity.relayUntil, activity.progress = nil, 0, 0
		end
	end
	evaluate(state)
	return true
end

function Session.eliminate(state: State, id: number): boolean
	local member = state.members[id]
	if not member or member.status ~= "Active" then
		return false
	end
	member.status, member.risingUntil = "Waiting", nil
	evaluate(state)
	return true
end

function Session.revive(state: State, helperId: number, targetId: number, now: number): (boolean, string?)
	if state.phase ~= "Playing" and state.phase ~= "Extracting" then
		return false, "wrong_phase"
	end
	local helper, target = state.members[helperId], state.members[targetId]
	if not finite(now) or helperId == targetId or not helper or helper.status ~= "Active" then
		return false, "not_active"
	end
	if not target or target.status ~= "Downed" or now >= target.downedUntil then
		return false, "not_available"
	end
	target.status, target.downedUntil = "Active", 0
	helper.contributions += 1
	return true, nil
end

-- Consumível "Segunda Chance" (Shared/Game/Perks): o próprio incapacitado levanta, sem ajudante.
function Session.selfRevive(state: State, id: number, now: number): (boolean, string?)
	if state.phase ~= "Playing" and state.phase ~= "Extracting" then
		return false, "wrong_phase"
	end
	local member = state.members[id]
	if not finite(now) or not member or member.status ~= "Downed" or now >= member.downedUntil then
		return false, "not_available"
	end
	member.status, member.downedUntil, member.risingUntil = "Active", 0, nil
	return true, nil
end

-- Consumível "Continuação": depois da derrota a equipe volta para o intervalo e repete a mesma etapa.
function Session.retryStage(state: State): (boolean, string?)
	if state.phase ~= "Lost" then
		return false, "wrong_phase"
	end
	if state.stage < 1 then
		return false, "not_available"
	end
	state.inventory = table.clone(state.checkpointInventory)
	state.stage -= 1
	state.phase = "Intermission"
	state.votes = {}
	return true, nil
end

function Session.tick(state: State, now: number)
	if not finite(now) then
		return
	end
	for _, activity in state.tasks do
		if not activity.solved and activity.relayBy and now >= activity.relayUntil then
			activity.relayBy, activity.relayUntil, activity.progress = nil, 0, 0
		end
	end
	for _, member in state.members do
		-- Janela da Segunda Chance vencida (jogador saiu, etapa trocou): volta a valer a derrota.
		if member.risingUntil and now >= member.risingUntil then
			member.risingUntil = nil
		end
		if member.status == "Downed" and now >= member.downedUntil then
			member.status = "Waiting"
			member.risingUntil = nil
		end
	end
	evaluate(state)
end

function Session.escape(state: State, id: number): boolean
	if state.phase ~= "Extracting" then
		return false
	end
	local member = state.members[id]
	if not member or member.status ~= "Active" then
		return false
	end
	member.status = "Escaped"
	evaluate(state)
	return true
end

function Session.voteRestart(state: State, id: number): (boolean, string?)
	if state.phase ~= "Lost" and state.phase ~= "Won" then
		return false, "wrong_phase"
	end
	if not state.members[id] then
		return false, "not_member"
	end
	state.votes[id] = true
	local votes = 0
	for voter in state.votes do
		if state.members[voter] then
			votes += 1
		end
	end
	return votes > Session.count(state) / 2, nil
end

return Session
