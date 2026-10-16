--!strict
-- Sorteia conteúdo e conexões secundárias; nunca remove a espinha de circulação validada.
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Layout = require("../World/Layout")
local ProceduralLayout = require("../World/ProceduralLayout")
local SeededRandom = require("./SeededRandom")

export type Activity = {
	id: string,
	slot: string,
	room: string,
	kind: string,
	order: { number },
	x: number,
	z: number,
	title: string?,
}
export type Plan = {
	mode: string?,
	seed: number,
	stage: number,
	title: string,
	threat: string,
	players: number,
	activities: { Activity },
	closedLinks: { string },
	sector: ProceduralLayout.Plan,
}

local Generator = {}

function Generator.create(seed: number, stage: number, players: number): Plan
	assert(stage % 1 == 0 and stage >= 1 and stage <= #Catalog.Stages, "Invalid campaign stage")
	assert(players % 1 == 0 and players >= 1 and players <= 8, "Invalid party size")
	local rng = SeededRandom.new(seed + stage * 7919)
	local definition = Catalog.Stages[stage]
	local sector = ProceduralLayout.create(seed, stage)
	local oldSlots = rng.shuffle(Catalog.Slots)
	local newSlots = rng.shuffle(ProceduralLayout.slots(sector))
	local count = math.max(3, players) + stage - 1
	local slots = {}
	-- A maioria das estações explora a ala sorteada; mantém tarefas no núcleo e o retorno à saída.
	local newCount = math.ceil(count * 0.6)
	for i = 1, count do
		table.insert(slots, if i <= newCount then newSlots[i] else oldSlots[i - newCount])
	end
	slots = rng.shuffle(slots)
	local activities: { Activity } = {}
	for i = 1, count do
		local slot = slots[i]
		local kind = definition.kinds[(i - 1) % #definition.kinds + 1]
		table.insert(activities, {
			id = `task_{i}`,
			slot = slot.id,
			room = slot.room,
			kind = kind,
			order = rng.shuffle({ 1, 2, 3 }),
			x = slot.x,
			z = slot.z,
		})
	end
	local optional: { string } = {}
	for _, link in Catalog.Links do
		if link.optional then
			table.insert(optional, link.id)
		end
	end
	optional = rng.shuffle(optional)
	local closed: { string } = {}
	for i = 1, rng.integer(0, 2) do
		table.insert(closed, optional[i])
	end
	return {
		seed = seed,
		stage = stage,
		title = definition.title,
		threat = definition.threat,
		players = players,
		activities = activities,
		closedLinks = closed,
		sector = sector,
	}
end

function Generator.validate(plan: Plan): (boolean, string?)
	local valid, reason = ProceduralLayout.validate(plan.sector)
	if not valid then
		return false, reason
	end
	if plan.sector.seed ~= plan.seed or plan.sector.stage ~= (if plan.mode == "Story" then 1 else plan.stage) then
		return false, "map_identity_mismatch"
	end
	local slots = table.clone(Catalog.Slots)
	for _, slot in ProceduralLayout.slots(plan.sector) do
		table.insert(slots, slot)
	end
	local closed: { [string]: boolean } = {}
	for _, id in plan.closedLinks do
		local found = false
		for _, link in Catalog.Links do
			if link.id == id and link.optional then
				found = true
			end
		end
		if not found or closed[id] then
			return false, "invalid_closure"
		end
		closed[id] = true
	end
	local reached: { [string]: boolean } = { Courtyard = true }
	local changed = true
	while changed do
		changed = false
		for _, link in Catalog.Links do
			if not closed[link.id] and (reached[link.a] or reached[link.b]) then
				if not reached[link.a] or not reached[link.b] then
					changed = true
				end
				reached[link.a], reached[link.b] = true, true
			end
		end
	end
	for _, room in Layout.Rooms do
		if not reached[room.id] then
			return false, "unreachable_room"
		end
	end
	local occupied: { [string]: boolean } = {}
	local ids: { [string]: boolean } = {}
	for _, activity in plan.activities do
		if occupied[activity.slot] or ids[activity.id] then
			return false, "duplicate_activity"
		end
		occupied[activity.slot], ids[activity.id] = true, true
		local known = false
		for _, slot in slots do
			if
				slot.id == activity.slot
				and slot.x == activity.x
				and slot.z == activity.z
				and slot.room == activity.room
			then
				known = true
			end
		end
		if not known then
			return false, "unknown_slot"
		end
		if activity.kind ~= "repair" and activity.kind ~= "sequence" and activity.kind ~= "relay" then
			return false, "unknown_activity"
		end
		local seen: { [number]: boolean } = {}
		for _, n in activity.order do
			if n % 1 ~= 0 or n < 1 or n > 3 or seen[n] then
				return false, "invalid_sequence"
			end
			seen[n] = true
		end
		if #activity.order ~= 3 then
			return false, "invalid_sequence"
		end
	end
	if #plan.activities < 3 then
		return false, "too_few_activities"
	end
	return true, nil
end

return Generator
