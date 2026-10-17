--!strict
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local StoryRewards = require("@game/ReplicatedStorage/Shared/Game/StoryRewards")
local Schema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local TestKit = require("../TestKit")

local testSpec: TestKit.Spec = {
	name = "StoryRewards",
	run = function(t)
		t.it("every chapter reward points to real items and consumables", function()
			for _, chapter in StoryRewards.Chapters do
				for _, reward in { chapter.first, chapter.again, chapter.flawless } do
					if reward.item then
						t.expect(StoreCatalog.ItemById[reward.item] ~= nil).toBe(true)
					end
					local consumables: { [string]: number } = reward.consumables or {}
					for id in consumables do
						t.expect(Perks.ConsumableById[id] ~= nil).toBe(true)
					end
				end
			end
			t.expect(StoreCatalog.ItemById[StoryRewards.CompletionItem] ~= nil).toBe(true)
			for _, id in StoreCatalog.StoryPassItems do
				t.expect(StoreCatalog.ItemById[id].source).toBe("storypass")
			end
		end)
		t.it("first clear pays big once, repeats pay less", function()
			local data = Schema.template()
			local granted, outcome = StoryRewards.award(data, 1, false, false, 100)
			t.expect(outcome and outcome.first).toBe(true)
			-- Fichas do capítulo + as dos níveis que o XP do capítulo pode ter subido.
			local firstFichas = if granted then granted.fichas else 0
			t.expect(firstFichas >= 400).toBe(true)
			t.expect(data.house.cleared["1"]).toBe(100)
			local again, second = StoryRewards.award(data, 1, false, false, 200)
			t.expect(second and second.first).toBe(false)
			local againFichas = if again then again.fichas else 0
			t.expect(againFichas >= 120 and againFichas < firstFichas).toBe(true)
			t.expect(data.house.cleared["1"]).toBe(100)
			local kind = StoryRewards.preview(data, 1)
			t.expect(kind).toBe("again")
		end)
		t.it("flawless bonus pays once and grants consumables", function()
			local data = Schema.template()
			StoryRewards.award(data, 2, true, false, 10)
			t.expect(data.owned.farda_ronda).toBe(true)
			t.expect(Perks.count(data, "segunda_chance")).toBe(1)
			local _, outcome = StoryRewards.award(data, 2, true, false, 20)
			t.expect(outcome and outcome.flawless).toBe(false)
			t.expect(Perks.count(data, "segunda_chance")).toBe(1)
		end)
		t.it("story pass doubles currencies but not items", function()
			local data = Schema.template()
			local granted = StoryRewards.award(data, 3, false, true, 5)
			t.expect((if granted then granted.fichas else 0) >= 1600).toBe(true)
			t.expect((if granted then granted.creditos else 0) >= 100).toBe(true)
			t.expect(data.owned.lanterna_elias).toBe(true)
		end)
		t.it("clearing all chapters unlocks the completion title once", function()
			local data = Schema.template()
			StoryRewards.award(data, 1, false, false, 1)
			StoryRewards.award(data, 2, false, false, 2)
			t.expect(data.owned[StoryRewards.CompletionItem]).toBeNil()
			StoryRewards.award(data, 3, false, false, 3)
			StoryRewards.award(data, 4, false, false, 4)
			StoryRewards.award(data, 5, false, false, 5)
			t.expect(data.owned[StoryRewards.CompletionItem]).toBeNil()
			StoryRewards.award(data, 6, false, false, 6)
			StoryRewards.award(data, 7, false, false, 7)
			local _, outcome = StoryRewards.award(data, 8, false, false, 8)
			t.expect(outcome and outcome.completed).toBe(true)
			t.expect(data.owned[StoryRewards.CompletionItem]).toBe(true)
			local _, again = StoryRewards.award(data, 3, false, false, 4)
			t.expect(again and again.completed).toBe(false)
			t.expect(StoryRewards.clearedCount(data)).toBe(8)
		end)
		t.it("unknown chapter grants nothing", function()
			local data = Schema.template()
			local granted, outcome = StoryRewards.award(data, 9, true, true, 1)
			t.expect(granted).toBeNil()
			t.expect(outcome).toBeNil()
			t.expect(data.wallet.fichas).toBe(0)
		end)
	end,
}

return testSpec
