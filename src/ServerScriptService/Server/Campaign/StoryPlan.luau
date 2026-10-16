--!strict
local Plan = require("./HousePlan")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Generator = require("./CampaignGenerator")
local StoryPlan = {}
function StoryPlan.create(stage: number, players: number): Generator.Plan
	return Plan.create(Story.MapSeed, stage, players, "Story")
end
return StoryPlan
