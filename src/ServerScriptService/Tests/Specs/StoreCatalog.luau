--!strict
local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "StoreCatalog",
	run = function(t)
		t.it("has unique item ids and a default for every kind", function()
			local seen = {}
			for _, item in StoreCatalog.Items do
				t.expect(seen[item.id]).toBeNil()
				seen[item.id] = true
				t.expect(StoreCatalog.Rarities[item.rarity] ~= nil).toBe(true)
			end
			for _, kind in StoreCatalog.KINDS do
				local default = StoreCatalog.ItemById[StoreCatalog.defaultFor(kind :: StoreCatalog.ItemKind)]
				t.expect(default ~= nil and default.kind == kind and default.source == "default").toBe(true)
			end
		end)

		t.it("store items have a price; titles are never sold", function()
			for _, item in StoreCatalog.Items do
				if item.source == "store" then
					t.expect(item.fichas ~= nil or item.creditos ~= nil).toBe(true)
				end
				if item.kind == "title" then
					t.expect(item.fichas == nil and item.creditos == nil).toBe(true)
				end
			end
		end)

		-- Regra de itens aleatórios pagos: chances em % de cada resultado, somando exatamente 100%.
		t.it("chest odds sum to 100% and every rarity has items", function()
			for _, chest in StoreCatalog.Chests do
				local total = 0
				local perItemTotal = 0
				for _, line in Economy.chestOdds(chest) do
					total += line.percent
					t.expect(#line.items > 0).toBe(true)
					perItemTotal += line.perItem * #line.items
				end
				t.expect(total).toBe(100)
				t.expect(perItemTotal).toBeCloseTo(100, 1e-9)
			end
		end)

		t.it("only the Robux-currency chest is flagged as paid random", function()
			for _, chest in StoreCatalog.Chests do
				t.expect(chest.paidRandom).toBe(chest.currency == "creditos")
			end
		end)

		t.it("every referenced reward item exists", function()
			local function check(reward: StoreCatalog.Reward)
				if reward.item then
					t.expect(StoreCatalog.ItemById[reward.item] ~= nil).toBe(true)
				end
			end
			for _, reward in StoreCatalog.LevelMilestones do
				check(reward)
			end
			for _, reward in StoreCatalog.TapeMilestones do
				check(reward)
			end
			for _, reward in StoreCatalog.Daily do
				check(reward)
			end
			for _, id in StoreCatalog.StarterItems do
				t.expect(StoreCatalog.ItemById[id] ~= nil).toBe(true)
			end
			t.expect(StoreCatalog.ItemById[StoreCatalog.FirstEscapeItem] ~= nil).toBe(true)
		end)

		t.it("spin weights sum to 100 and products have unique keys", function()
			local total = 0
			for _, segment in StoreCatalog.Spin do
				total += segment.weight
			end
			t.expect(total).toBe(100)
			local keys = {}
			for _, product in StoreCatalog.Products do
				t.expect(keys[product.key]).toBeNil()
				keys[product.key] = true
			end
			t.expect(#StoreCatalog.Tapes).toBe(12)
		end)
	end,
}

return spec
