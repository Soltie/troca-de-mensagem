--!strict
local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Schema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local TestKit = require("../TestKit")

local testSpec: TestKit.Spec = {
	name = "Perks",
	run = function(t)
		t.it("factors grow with level and never cross the design limits", function()
			t.expect(Perks.factor("bateria", 0)).toBeCloseTo(1)
			t.expect(Perks.factor("bateria", 5)).toBeCloseTo(1.75)
			t.expect(Perks.factor("folego", 5)).toBeCloseTo(1.75)
			t.expect(Perks.factor("socorro", 5)).toBeCloseTo(0.5)
			t.expect(Perks.factor("silencio", 5)).toBeCloseTo(0.6)
			t.expect(Perks.factor("bateria", 99)).toBeCloseTo(1.75)
			t.expect(Perks.factor("nada", 3)).toBe(1)
			for _, perk in Perks.List do
				t.expect(#perk.fichas).toBe(Perks.MAX_LEVEL)
				t.expect(#perk.creditos).toBe(Perks.MAX_LEVEL)
				-- Nenhum nível zera o resgate ou o barulho: o Vigia continua no jogo.
				t.expect(Perks.factor(perk.id, Perks.MAX_LEVEL) > 0.3).toBe(true)
			end
		end)
		t.it("upgrades charge the next level price and stop at max", function()
			local data = Schema.template()
			data.wallet.fichas = 10000
			local ok, err, level = Perks.upgrade(data, "bateria", "fichas")
			t.expect(ok).toBe(true)
			t.expect(err).toBeNil()
			t.expect(level).toBe(1)
			t.expect(data.wallet.fichas).toBe(10000 - 300)
			for _ = 2, 5 do
				t.expect((Perks.upgrade(data, "bateria", "fichas"))).toBe(true)
			end
			t.expect(Perks.level(data, "bateria")).toBe(5)
			local again, reason = Perks.upgrade(data, "bateria", "fichas")
			t.expect(again).toBe(false)
			t.expect(reason).toBe("perk_max")
			t.expect(Perks.nextCost("bateria", 5, "fichas")).toBeNil()
		end)
		t.it("refuses upgrades without money or unknown perks", function()
			local data = Schema.template()
			data.wallet.creditos = 10
			local ok, reason = Perks.upgrade(data, "folego", "creditos")
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("store_poor")
			t.expect(data.wallet.creditos).toBe(10)
			t.expect((Perks.upgrade(data, "voar", "creditos"))).toBe(false)
		end)
		t.it("consumables: bundles, stock cap, consume and loadout", function()
			local data = Schema.template()
			data.wallet.fichas = 5000
			t.expect((Perks.buyConsumable(data, "pilha_extra", "fichas"))).toBe(true)
			t.expect(Perks.count(data, "pilha_extra")).toBe(3)
			-- Continuação só sai por Créditos/Robux.
			local ok, reason = Perks.buyConsumable(data, "continuar", "fichas")
			t.expect(ok).toBe(false)
			t.expect(reason).toBe("store_no_price")
			t.expect(Perks.inLoadout(data, "pilha_extra")).toBe(false)
			t.expect((Perks.setLoadout(data, "pilha_extra", true))).toBe(true)
			t.expect(Perks.inLoadout(data, "pilha_extra")).toBe(true)
			t.expect((Perks.setLoadout(data, "continuar", true))).toBe(false)
			t.expect(Perks.consume(data, "pilha_extra")).toBe(true)
			t.expect(Perks.count(data, "pilha_extra")).toBe(2)
			t.expect(Perks.consume(data, "segunda_chance")).toBe(false)
			t.expect(Perks.add(data, "pilha_extra", 500)).toBe(Perks.MAX_STOCK - 2)
			t.expect(Perks.count(data, "pilha_extra")).toBe(Perks.MAX_STOCK)
			t.expect(Perks.add(data, "inexistente", 3)).toBe(0)
		end)
		t.it("boosts stack in time and double run rewards only while active", function()
			local data = Schema.template()
			local now = 1000000
			Perks.addBoost(data, "fichas", 60, now)
			Perks.addBoost(data, "fichas", 60, now + 10)
			t.expect(data.boosts.fichasUntil).toBe(now + 7200)
			t.expect(Perks.boostActive(data, "fichas", now + 7199)).toBe(true)
			t.expect(Perks.boostActive(data, "xp", now)).toBe(false)
			local summary: Economy.RunSummary =
				{ won = false, escaped = false, stages = 1, fuses = 0, breakers = false, contributions = 0 }
			local base = Economy.runReward(summary, false)
			local boosted = Economy.recordRun(data, summary, false, now + 5)
			t.expect(boosted.fichas).toBe((base.fichas or 0) * 2)
			t.expect(boosted.xp).toBe(base.xp or 0)
			local later = Schema.template()
			later.boosts.fichasUntil = now
			t.expect(Economy.recordRun(later, summary, false, now + 1).fichas).toBe(base.fichas or 0)
		end)
		t.it("products grant consumables and timed boosts once per receipt", function()
			local data = Schema.template()
			local pack = StoreCatalog.ProductByKey.segunda_chance_3
			local ok, _, granted = Economy.grantProduct(data, pack, "r1", 50)
			t.expect(ok).toBe(true)
			t.expect(Perks.count(data, "segunda_chance")).toBe(3)
			t.expect(granted and granted.consumables and granted.consumables.segunda_chance).toBe(3)
			t.expect((Economy.grantProduct(data, pack, "r1", 50))).toBe(false)
			t.expect(Perks.count(data, "segunda_chance")).toBe(3)
			Economy.grantProduct(data, StoreCatalog.ProductByKey.bonus_duplo_3h, "r2", 100)
			t.expect(data.boosts.fichasUntil).toBe(100 + 180 * 60)
			t.expect(data.boosts.xpUntil).toBe(100 + 180 * 60)
			local kit = StoreCatalog.ProductByKey.kit_sobrevivente
			Economy.grantProduct(data, kit, "r3", 200)
			t.expect(Perks.count(data, "continuar")).toBe(2)
			-- Segunda compra do kit (uma por conta) vira só os Créditos.
			local before = Perks.count(data, "continuar")
			local _, message = Economy.grantProduct(data, kit, "r4", 300)
			t.expect(message).toBe("once_converted")
			t.expect(Perks.count(data, "continuar")).toBe(before)
		end)
		t.it("migration to v4 sanitizes perks, stock, loadout, boosts and story", function()
			local raw: any = Schema.template()
			raw.schemaVersion = 3
			raw.perks = { bateria = 9, folego = -2, silencio = 0 / 0, [5] = 3 }
			raw.consumables = { pilha_extra = 400, segunda_chance = "x" }
			raw.loadout = { pilha_extra = true, segunda_chance = "sim" }
			raw.boosts = "quebrado"
			raw.story = { cleared = { ["1"] = 123 }, flawless = 7 }
			local data = Schema.migrate(raw)
			t.expect(data.perks.bateria).toBe(5)
			t.expect(data.perks.folego).toBeNil()
			t.expect(data.perks.silencio).toBeNil()
			t.expect(data.consumables.pilha_extra).toBe(99)
			t.expect(data.consumables.segunda_chance).toBeNil()
			t.expect(data.loadout.pilha_extra).toBe(true)
			t.expect(data.loadout.segunda_chance).toBeNil()
			t.expect(data.boosts.fichasUntil).toBe(0)
			t.expect(data.story.cleared["1"]).toBe(123)
			t.expect((next(data.story.flawless))).toBeNil()
			local fresh = Schema.migrate(nil)
			t.expect(fresh.boosts.xpUntil).toBe(0)
			t.expect((next(fresh.perks))).toBeNil()
		end)
	end,
}

return testSpec
