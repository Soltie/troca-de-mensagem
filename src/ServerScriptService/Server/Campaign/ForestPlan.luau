--!strict
local Forest = require("@game/ReplicatedStorage/Shared/Game/ForestCatalog")
local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local Generator = require("./CampaignGenerator")
local Layout = require("../World/ProceduralLayout")
local Random = require("./SeededRandom")
local Plan = {}
function Plan.create(seed: number, chapter: number, players: number, mode: string): Generator.Plan
	assert(chapter >= 6 and chapter <= 8 and chapter % 1 == 0, "Invalid forest chapter")
	assert(players >= 1 and players <= 6 and players % 1 == 0, "Invalid forest party")
	local definition = Forest.Chapters[chapter - 5]
	local rng = Random.new(seed + chapter * 7919)
	local uses: { [string]: number } = {}
	local activities: { Generator.Activity } = {}
	for index, objective in definition.objectives do
		local room = Forest.Rooms[1]
		for _, candidate in Forest.Rooms do
			if candidate.id == objective.room then
				room = candidate
			end
		end
		uses[room.id] = (uses[room.id] or 0) + 1
		local offset = if mode == "Standard" then rng.integer(-3, 3) else 0
		-- Mapa antigo: esconder fica no corredor de abrigos; nos mapas novos, no próprio lugar (e na altura dele).
		local hide = (objective.kind == "hide" or objective.kind == "breath") and ForestMaps.get(chapter) == nil
		table.insert(activities, {
			id = `task_{index}`,
			slot = `{room.id}_{index}`,
			room = room.id,
			x = if hide then -24 else room.x + (if uses[room.id] % 2 == 1 then -5 else 5) + offset,
			y = if hide then 0 else room.y,
			z = if hide then 730 else room.z + (uses[room.id] - 1) * 8,
			kind = objective.kind,
			item = objective.item,
			event = objective.event,
			title = objective.title,
			order = if objective.kind == "repair"
				then { 1, 2, 3 }
				elseif objective.kind == "puzzle" then rng.shuffle({ 1, 2, 3, 4 })
				else { 1 },
			house = true,
		})
	end
	return {
		house = true,
		mode = mode,
		seed = seed,
		stage = chapter,
		players = players,
		title = definition.title,
		threat = "echo",
		activities = activities,
		closedLinks = {},
		sector = Layout.create(seed, 1),
	}
end
function Plan.validate(plan: Generator.Plan): (boolean, string?)
	if
		not plan.house
		or plan.stage < 6
		or plan.stage > 8
		or plan.stage % 1 ~= 0
		or plan.players < 1
		or plan.players > 6
	then
		return false, "invalid_forest_plan"
	end
	local expected = Plan.create(plan.seed, plan.stage, plan.players, plan.mode or "Story")
	if #plan.activities ~= #expected.activities then
		return false, "missing_forest_objectives"
	end
	for index, spec in plan.activities do
		local other = expected.activities[index]
		if
			spec.id ~= other.id
			or spec.kind ~= other.kind
			or spec.room ~= other.room
			or spec.item ~= other.item
			or spec.event ~= other.event
			or spec.x ~= other.x
			or spec.y ~= other.y
			or spec.z ~= other.z
			or #spec.order ~= #other.order
		then
			return false, "invalid_forest_dependency"
		end
		for n, button in spec.order do
			if button ~= other.order[n] then
				return false, "invalid_forest_repair"
			end
		end
	end
	return true, nil
end
return Plan
