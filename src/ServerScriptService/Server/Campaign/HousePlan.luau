--!strict
-- O plano privado mantém códigos e pontos reproduzíveis sem replicar soluções no HUD.
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Generator = require("./CampaignGenerator")
local Layout = require("../World/ProceduralLayout")
local Random = require("./SeededRandom")
local Levels = require("./HouseLevelPlan")
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
	for index, objective in House.Chapters[chapter].objectives do
		local room: House.Room? = nil
		for _, candidate in House.Rooms do
			if candidate.id == objective.room then
				room = candidate
			end
		end
		assert(room, "Unknown house room")
		local solution = if objective.kind == "puzzle" then rng.shuffle({ 1, 2, 3, 4 }) else { 1 }
		-- Variação dentro da sala preserva todos os pré-requisitos e os corredores.
		local offset = if mode == "Standard" and room.id ~= "Hall" then rng.integer(-2, 2) else 0
		roomUses[room.id] = (roomUses[room.id] or 0) + 1
		local use = roomUses[room.id]
		local dx = if use % 2 == 1 then -5 else 5
		local dz = if use <= 2 then -3 else 6
		if room.id == "Hall" then
			dx, dz = 0, -(use - 1) * 14
		end
		if objective.kind == "hide" or objective.kind == "breath" then
			dx, dz = if room.x < 0 then -11 else 11, 11
			offset = 0
		end
		local spot = Levels.relocate(level, index)
		local repair = mode == "Standard" and objective.event == "power"
		table.insert(activities, {
			id = `task_{index}`,
			slot = `{objective.room}_{index}`,
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
			or activity.room ~= (if spot then spot.room else objective.room)
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
