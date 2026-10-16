--!strict
-- Planta autoral explícita: não chama gerador aleatório, nem muda entre capítulos/equipes.
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Layout = require("../World/ProceduralLayout")
local Generator = require("./CampaignGenerator")

local StoryPlan = {}
function StoryPlan.create(stage: number, players: number): Generator.Plan
	assert(stage % 1 == 0 and stage >= 1 and stage <= #Story.Chapters, "Invalid story chapter")
	assert(players % 1 == 0 and players >= 1 and players <= 8, "Invalid story party")
	local rooms: { Layout.Room } = {}
	for cell, kind in Layout.Kinds do
		local x, z = Layout.center(cell)
		table.insert(rooms, { cell = cell, kind = kind, x = x, z = z, turn = 0 })
	end
	local chapter = Story.Chapters[stage]
	local activities: { Generator.Activity } = {}
	for index, objective in chapter.objectives do
		local found: Catalog.Slot? = nil
		for _, slot in Catalog.Slots do
			if slot.id == objective.slot then
				found = slot
			end
		end
		assert(found, "Unknown story slot")
		table.insert(activities, {
			id = `task_{index}`,
			slot = found.id,
			room = found.room,
			x = found.x,
			z = found.z,
			kind = objective.kind,
			order = table.clone(objective.order),
			title = objective.title,
		})
	end
	return {
		mode = "Story",
		seed = Story.MapSeed,
		stage = stage,
		players = players,
		title = chapter.title,
		threat = if stage == 1 then "watcher" elseif stage == 2 then "echo" else "blackout",
		activities = activities,
		closedLinks = {},
		sector = {
			seed = Story.MapSeed,
			stage = 1,
			rooms = rooms,
			links = {
				{ a = 1, b = 2 },
				{ a = 2, b = 3 },
				{ a = 1, b = 4 },
				{ a = 2, b = 5 },
				{ a = 3, b = 6 },
				{ a = 4, b = 5 },
				{ a = 5, b = 6 },
				{ a = 4, b = 7 },
				{ a = 5, b = 8 },
				{ a = 6, b = 9 },
				{ a = 8, b = 9 },
			},
		},
	}
end
return StoryPlan
