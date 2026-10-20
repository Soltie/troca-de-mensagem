--!strict
-- O plano privado mantém códigos e pontos reproduzíveis sem replicar soluções no HUD.
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Generator = require("./CampaignGenerator")
local Layout = require("../World/ProceduralLayout")
local Random = require("./SeededRandom")
local Levels = require("./HouseLevelPlan")
local Catacomb = require("@game/ReplicatedStorage/Shared/Game/CatacombLayout")
local PuzzleStyles = require("@game/ReplicatedStorage/Shared/Game/PuzzleStyles")
local Plan = {}
function Plan.create(seed: number, chapter: number, players: number, mode: string): Generator.Plan
	if chapter >= 6 then
		return require("./ForestPlan").create(seed, chapter, players, mode)
	end
	assert(chapter >= 1 and chapter <= #House.Chapters and chapter % 1 == 0, "Invalid house chapter")
	assert(players >= 1 and players <= 6 and players % 1 == 0, "Invalid house party")
	local rng = Random.new(seed + chapter * 7919)
	local level = Levels.create(seed, chapter, mode)
	local activities: { Generator.Activity } = {}
	local roomUses: { [string]: number } = {}
	-- Sorteio do cômodo dos itens com `pool` (gerador separado: não muda o resto do plano).
	local pick = Random.new(seed + chapter * 15485863)
	local taken: { [string]: boolean } = {}
	for index, objective in House.Chapters[chapter].objectives do
		local roomId = objective.room
		if objective.pool then
			local free = {}
			for _, id in objective.pool do
				if not taken[id] then
					table.insert(free, id)
				end
			end
			if #free > 0 then
				roomId = free[pick.integer(1, #free)]
			end
			taken[roomId] = true
		end
		local room: House.Room? = nil
		for _, candidate in House.Rooms do
			if candidate.id == roomId then
				room = candidate
			end
		end
		assert(room, "Unknown house room")
		local solution = if objective.kind == "puzzle" then rng.shuffle({ 1, 2, 3, 4 }) else { 1 }
		-- O relógio do escritório sempre marca 03:12 (o sorteio acima continua, para não mudar o resto do plano).
		local style = if objective.kind == "puzzle" then PuzzleStyles.forTask(chapter, index, seed) else nil
		local fixed = if style then style.fixed else nil
		if fixed then
			solution = table.clone(fixed)
		end
		-- Variação dentro da sala preserva todos os pré-requisitos e os corredores.
		local offset = if mode == "Standard" and room.id ~= "Hall" then rng.integer(-2, 2) else 0
		roomUses[room.id] = (roomUses[room.id] or 0) + 1
		local use = roomUses[room.id]
		local dx = if use % 2 == 1 then -5 else 5
		local dz = if use <= 2 then -3 else 6
		if room.id == "Hall" then
			dx, dz = 0, -(use - 1) * 14
		elseif room.id == "Machine" then
			-- A máquina de marceneiro (World/HouseMachine) ocupa o meio da sala: as tarefas vão para a parede do
			-- fundo, entre a mesa antiga e a caldeira, com a frente livre.
			-- Segunda tarefa na mesma sala (o quadro de luz do cap. 2): canto da porta, também com a frente livre.
			dx, dz, offset = if use == 1 then 10 else -14, if use == 1 then -10 else -6, 0
		end
		if objective.kind == "hide" or objective.kind == "breath" then
			-- Frente do guarda-roupa (HouseBuilder: encostado na fachada, de frente para a porta do cômodo).
			dx, dz = if room.x < 0 then -11.4 else 11.4, 12.6
			offset = 0
		end
		local spot = Levels.relocate(level, index)
		-- Embaixo do jardim: a pista do cofre (cap. 4) na catacumba e o altar (cap. 5) na capela; o cômodo continua o
		-- mesmo do catálogo (a validação e os rótulos não mudam), só o ponto desce.
		local below = if spot then nil else Catacomb.relocate(chapter, objective.item, objective.event, index)
		if below then
			offset, dx, dz = 0, below.x - room.x, below.z - room.z
		end
		local repair = mode == "Standard" and objective.event == "power"
		table.insert(activities, {
			id = `task_{index}`,
			slot = `{roomId}_{index}`,
			room = if spot then spot.room else room.id,
			x = if spot then spot.x else room.x + dx + offset,
			y = if spot then spot.y else room.y,
			z = if spot then spot.z else room.z + dz,
			kind = if repair then "repair" else objective.kind,
			order = if repair then { 1, 2, 3 } else solution,
			title = if spot then `{objective.title} / {spot.room}` else objective.title,
			item = objective.item,
			event = objective.event,
			house = true,
			forgiving = if style and style.forgiving then true else nil,
		})
	end
	return {
		house = true,
		mode = mode,
		seed = seed,
		stage = chapter,
		players = players,
		title = if level.outdoor
			then string.format("%02d · %s", chapter, level.theme)
			else House.Chapters[chapter].title,
		threat = if chapter < 3 then "watcher" else "echo",
		activities = activities,
		closedLinks = {},
		sector = Layout.create(seed, 1),
	}
end
local function roomAllowed(room: string, objective: House.Objective): boolean
	return room == objective.room or (objective.pool ~= nil and table.find(objective.pool, room) ~= nil)
end
function Plan.validate(plan: Generator.Plan): (boolean, string?)
	if plan.stage >= 6 then
		return require("./ForestPlan").validate(plan)
	end
	if not plan.house or plan.stage < 1 or plan.stage > #House.Chapters or plan.players < 1 or plan.players > 6 then
		return false, "invalid_house_plan"
	end
	local expected = House.Chapters[plan.stage].objectives
	local level = Levels.create(plan.seed, plan.stage, plan.mode or "Story")
	if #plan.activities ~= #expected then
		return false, "missing_objectives"
	end
	local ids: { [string]: boolean } = {}
	for index, activity in plan.activities do
		local objective = expected[index]
		local spot = Levels.relocate(level, index)
		local repair = plan.mode == "Standard" and objective.event == "power"
		if
			ids[activity.id]
			or not (if spot then activity.room == spot.room else roomAllowed(activity.room, objective))
			or activity.kind ~= (if repair then "repair" else objective.kind)
			or activity.item ~= objective.item
			or activity.event ~= objective.event
		then
			return false, "invalid_dependency"
		end
		ids[activity.id] = true
		if spot and (activity.x ~= spot.x or activity.y ~= spot.y or activity.z ~= spot.z) then
			return false, "invalid_exterior_position"
		end
		if
			repair
			and (#activity.order ~= 3 or activity.order[1] ~= 1 or activity.order[2] ~= 2 or activity.order[3] ~= 3)
		then
			return false, "invalid_repair"
		end
		if activity.kind == "puzzle" and #activity.order ~= 4 then
			return false, "missing_solution"
		end
	end
	return true, nil
end
return Plan
