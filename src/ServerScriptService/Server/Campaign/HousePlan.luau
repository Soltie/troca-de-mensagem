--!strict
-- O plano privado mantém códigos e pontos reproduzíveis sem replicar soluções no HUD.
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Generator = require("./CampaignGenerator")
local Layout = require("../World/ProceduralLayout")
local Random = require("./SeededRandom")
local Plan = {}
function Plan.create(seed: number, chapter: number, players: number, mode: string): Generator.Plan
	assert(chapter >= 1 and chapter <= #House.Chapters and chapter % 1 == 0, "Invalid house chapter")
	assert(players >= 1 and players <= 6 and players % 1 == 0, "Invalid house party")
	local rng = Random.new(seed + chapter * 7919)
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
		table.insert(activities, {
			id = `task_{index}`,
			slot = `{objective.room}_{index}`,
			room = room.id,
			x = room.x + dx + offset,
			y = room.y,
			z = room.z + dz,
			kind = objective.kind,
			order = solution,
			title = objective.title,
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
		title = House.Chapters[chapter].title,
		threat = if chapter < 3 then "watcher" else "echo",
		activities = activities,
		closedLinks = {},
		sector = Layout.create(seed, 1),
	}
end
function Plan.validate(plan: Generator.Plan): (boolean, string?)
	if not plan.house or plan.stage < 1 or plan.stage > #House.Chapters or plan.players < 1 or plan.players > 6 then
		return false, "invalid_house_plan"
	end
	local expected = House.Chapters[plan.stage].objectives
	if #plan.activities ~= #expected then
		return false, "missing_objectives"
	end
	local ids: { [string]: boolean } = {}
	for index, activity in plan.activities do
		if ids[activity.id] or activity.room ~= expected[index].room or activity.kind ~= expected[index].kind then
			return false, "invalid_dependency"
		end
		ids[activity.id] = true
		if activity.kind == "puzzle" and #activity.order ~= 4 then
			return false, "missing_solution"
		end
	end
	return true, nil
end
return Plan
