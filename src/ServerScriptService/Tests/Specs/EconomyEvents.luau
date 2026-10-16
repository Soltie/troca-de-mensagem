--!strict
local Events = require("@game/ServerScriptService/Server/Game/EconomyEvents")
local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local Schema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local TestKit = require("../TestKit")
local spec: TestKit.Spec = {
	name = "EconomyEvents",
	run = function(t)
		t.it("records gross chest spend before duplicate refund", function()
			local events = Events.build({ fichas = 150, creditos = 0 }, {
				{
					transaction = "Shop",
					sku = "chest",
					spend = { currency = "fichas", amount = 250 },
					granted = { fichas = 50, creditos = 0, xp = 0, items = {}, refunds = { item = 50 }, levels = {} },
				},
			})
			t.expect(#events).toBe(2)
			t.expect(events[1].flow).toBe("Sink")
			t.expect(events[1].amount).toBe(250)
			t.expect(events[1].balance).toBe(100)
			t.expect(events[2].sku).toBe("duplicate_refund")
			t.expect(events[2].balance).toBe(150)
		end)
		t.it("partitions account levels and multiple rewards without double counting", function()
			local data = Schema.template()
			local granted = Economy.applyReward(data, { fichas = 100, creditos = 20, xp = 1000 })
			local season = Economy.applyReward(data, { fichas = 50 })
			local events = Events.build(data.wallet, {
				{ transaction = "Gameplay", sku = "run", granted = granted },
				{ transaction = "SeasonPass", sku = "season_free", granted = season },
			})
			local totals = { fichas = 0, creditos = 0 }
			for _, event in events do
				totals[event.currency] += event.amount
			end
			t.expect(totals.fichas).toBe(data.wallet.fichas)
			t.expect(totals.creditos).toBe(data.wallet.creditos)
			t.expect(events[#events].balance).toBe(data.wallet.fichas)
		end)
	end,
}
return spec
