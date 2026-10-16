--!strict
local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local PlayerDataSchema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local TestKit = require("../TestKit")

local function fixed(...: number): () -> number
	local values = { ... }
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

local function summary(overrides: { [string]: any }?): Economy.RunSummary
	local s: { [string]: any } =
		{ won = false, escaped = false, stages = 0, fuses = 0, breakers = false, contributions = 0 }
	if overrides then
		for key, value in overrides do
			s[key] = value
		end
	end
	return s :: any
end

local spec: TestKit.Spec = {
	name = "Economy",
	run = function(t)
		t.it("levels follow the published curve", function()
			t.expect((Economy.levelInfo(0))).toBe(1)
			local level, into, need = Economy.levelInfo(StoreCatalog.LevelBase)
			t.expect(level).toBe(2)
			t.expect(into).toBe(0)
			t.expect(need).toBe(Economy.xpToNext(2))
			t.expect((Economy.levelInfo(10 ^ 9))).toBe(StoreCatalog.LevelCap)
		end)

		t.it("xp grants each level reward exactly once, with milestones", function()
			local data = PlayerDataSchema.template()
			local granted = Economy.applyReward(data, { xp = 10000 })
			t.expect(#granted.levels > 3).toBe(true)
			t.expect(data.owned.filtro_sepia).toBe(true) -- marco do nível 3
			local before = data.wallet.fichas
			Economy.applyReward(data, { xp = 0 })
			t.expect(data.wallet.fichas).toBe(before)
			t.expect(data.rewardedLevel).toBe((Economy.levelInfo(data.xp)))
		end)

		t.it("buys store items once, with the right currency", function()
			local data = PlayerDataSchema.template()
			local ok, err = Economy.buyItem(data, "lanterna_militar", "fichas")
			t.expect(ok).toBe(false)
			t.expect(err).toBe("store_poor")
			data.wallet.fichas = 1000
			t.expect((Economy.buyItem(data, "lanterna_militar", "fichas"))).toBe(true)
			t.expect(data.wallet.fichas).toBe(600)
			local _, again = Economy.buyItem(data, "lanterna_militar", "fichas")
			t.expect(again).toBe("store_owned")
			local _, noPrice = Economy.buyItem(data, "lanterna_neon", "fichas")
			t.expect(noPrice).toBe("store_no_price")
			local _, notSold = Economy.buyItem(data, "titulo_lenda", "fichas")
			t.expect(notSold).toBe("store_unknown")
		end)

		t.it("opens chests by the published odds; duplicates become fichas", function()
			local data = PlayerDataSchema.template()
			local chest = StoreCatalog.ChestById.bau_ferramentas
			data.wallet.fichas = chest.price * 2
			-- random() = 0 -> primeira raridade (comum), primeiro item comum da lista ordenada.
			local ok, _, result = Economy.openChest(data, chest.id, fixed(0))
			t.expect(ok).toBe(true)
			assert(result, "result")
			t.expect(result.rarity).toBe("common")
			t.expect(result.duplicate).toBe(false)
			t.expect(data.owned[result.item]).toBe(true)
			t.expect(data.wallet.fichas).toBe(chest.price)
			local _, _, again = Economy.openChest(data, chest.id, fixed(0))
			assert(again, "again")
			t.expect(again.duplicate).toBe(true)
			t.expect(again.refund).toBe(StoreCatalog.Rarities.common.refund)
			t.expect(data.wallet.fichas).toBe(StoreCatalog.Rarities.common.refund)
			t.expect(data.stats.chests).toBe(2)
		end)

		t.it("the highest roll lands on the rarest tier", function()
			local data = PlayerDataSchema.template()
			data.wallet.creditos = 1000
			local _, _, result = Economy.openChest(data, "bau_lacrado", fixed(0.9999))
			assert(result, "result")
			t.expect(result.rarity).toBe("legendary")
		end)

		t.it("paid random chest is blocked for restricted players; free chest is not", function()
			local data = PlayerDataSchema.template()
			data.wallet.creditos = 1000
			data.wallet.fichas = 1000
			local ok, err = Economy.openChest(data, "bau_lacrado", fixed(0), true)
			t.expect(ok).toBe(false)
			t.expect(err).toBe("store_restricted")
			t.expect(data.wallet.creditos).toBe(1000)
			t.expect((Economy.openChest(data, "bau_ferramentas", fixed(0), true))).toBe(true)
		end)

		t.it("daily calendar: streak grows on consecutive days and resets after a gap", function()
			local data = PlayerDataSchema.template()
			local ok, _, day1 = Economy.claimDaily(data, 100)
			t.expect(ok).toBe(true)
			t.expect(day1).toBe(1)
			local again, why = Economy.claimDaily(data, 100)
			t.expect(again).toBe(false)
			t.expect(why).toBe("daily_claimed")
			local _, _, day2 = Economy.claimDaily(data, 101)
			t.expect(day2).toBe(2)
			local _, _, reset = Economy.claimDaily(data, 105)
			t.expect(reset).toBe(1)
		end)

		t.it("daily calendar wraps after day 7", function()
			local data = PlayerDataSchema.template()
			for day = 1, 7 do
				Economy.claimDaily(data, 200 + day)
			end
			t.expect(data.daily.streak).toBe(7)
			t.expect(data.wallet.creditos).toBe(StoreCatalog.Daily[7].creditos)
			local _, _, eighth = Economy.claimDaily(data, 208)
			t.expect(eighth).toBe(1)
		end)

		t.it("one free spin per day (two with VIP)", function()
			local data = PlayerDataSchema.template()
			t.expect((Economy.spin(data, 10, false, fixed(0)))).toBe(true)
			local again, err = Economy.spin(data, 10, false, fixed(0))
			t.expect(again).toBe(false)
			t.expect(err).toBe("spin_used")
			t.expect(Economy.spinsLeft(data, 10, true)).toBe(1)
			t.expect((Economy.spin(data, 10, true, fixed(0)))).toBe(true)
			t.expect(Economy.spinsLeft(data, 11, false)).toBe(1)
		end)

		t.it("run rewards scale with progress, contributions are capped, VIP multiplies", function()
			local base = Economy.runReward(summary())
			local better = Economy.runReward(summary({ stages = 2, contributions = 5, escaped = true }))
			t.expect((better.fichas :: number) > (base.fichas :: number)).toBe(true)
			local capped = Economy.runReward(summary({ contributions = 999 }))
			local cap = Economy.runReward(summary({ contributions = StoreCatalog.RunRewards.contributionCap }))
			t.expect(capped.fichas).toBe(cap.fichas)
			local vip = Economy.runReward(summary(), true)
			t.expect(vip.fichas).toBe(math.floor((base.fichas :: number) * StoreCatalog.VipMultiplier + 0.5))
		end)

		t.it("first escape grants the survivor title once", function()
			local data = PlayerDataSchema.template()
			Economy.recordRun(data, summary({ escaped = true }))
			t.expect(data.owned[StoreCatalog.FirstEscapeItem]).toBe(true)
			t.expect(data.stats.escapes).toBe(1)
			Economy.recordRun(data, summary())
			t.expect(data.stats.captures).toBe(1)
			t.expect(data.stats.runs).toBe(2)
		end)

		t.it("tapes: only new tapes reward; milestones unlock items", function()
			local data = PlayerDataSchema.template()
			t.expect((Economy.addTape(data, "fita_01", 1))).toBe(true)
			t.expect((Economy.addTape(data, "fita_01", 2))).toBe(false)
			t.expect((Economy.addTape(data, "nope", 3))).toBe(false)
			for i = 2, 8 do
				Economy.addTape(data, string.format("fita_%02d", i), i)
			end
			t.expect(Economy.tapeCount(data)).toBe(8)
			t.expect(data.owned.lanterna_vigia).toBe(true)
		end)

		t.it("equips only owned items; VIP items depend on the pass", function()
			local data = PlayerDataSchema.template()
			local _, err = Economy.equip(data, "lanterna_ouro")
			t.expect(err).toBe("store_locked")
			t.expect((Economy.equip(data, "lanterna_supervisor", true))).toBe(true)
			-- Perdeu o VIP: volta ao padrão.
			t.expect(Economy.equipped(data, "flashlight", false)).toBe(StoreCatalog.Defaults.flashlight)
			t.expect(Economy.equipped(data, "flashlight", true)).toBe("lanterna_supervisor")
		end)

		t.it("Robux purchases are idempotent per receipt and starter pack is once", function()
			local data = PlayerDataSchema.template()
			local pack = StoreCatalog.ProductByKey.creditos_100
			t.expect((Economy.grantProduct(data, pack, "r1", 1))).toBe(true)
			t.expect((Economy.grantProduct(data, pack, "r1", 2))).toBe(false)
			t.expect(data.wallet.creditos).toBe(100)
			local starter = StoreCatalog.ProductByKey.pacote_inicial
			t.expect((Economy.grantProduct(data, starter, "r2", 3))).toBe(true)
			t.expect(data.owned.lanterna_retro).toBe(true)
			t.expect(data.owned.farda_noturna).toBe(true)
			local ok, note = Economy.grantProduct(data, starter, "r3", 4)
			t.expect(ok).toBe(true)
			t.expect(note).toBe("once_converted")
			t.expect(data.wallet.creditos).toBe(100 + 300 + 300)
		end)

		t.it("keeps only the newest receipts", function()
			local data = PlayerDataSchema.template()
			for i = 1, 10 do
				data.purchases[`r{i}`] = i
			end
			Economy.trimPurchases(data, 4)
			local count = 0
			for _ in data.purchases do
				count += 1
			end
			t.expect(count).toBe(4)
			t.expect(data.purchases.r10).toBe(10)
			t.expect(data.purchases.r1).toBeNil()
		end)
	end,
}

return spec
