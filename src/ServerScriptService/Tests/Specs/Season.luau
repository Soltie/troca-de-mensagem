--!strict
local Season = require("@game/ReplicatedStorage/Shared/Game/Season")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/SeasonCatalog")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Schema = require("@game/ServerScriptService/Server/Data/PlayerDataSchema")
local TestKit = require("../TestKit")
local season = Catalog.Seasons[1]
local spec: TestKit.Spec = {
	name = "Season",
	run = function(t)
		t.it("uses inclusive start, exclusive end and thirty valid tiers", function()
			t.expect(Season.current(season.startsAt - 1)).toBe(nil)
			t.expect(Season.current(season.startsAt)).toBe(season)
			t.expect(Season.current(season.endsAt)).toBe(nil)
			t.expect(Season.maxTier(season)).toBe(30)
			t.expect(Season.daysLeft(season, season.endsAt - 1)).toBe(1)
			for _, tier in season.tiers do
				for _, reward in { tier.free, tier.premium } do
					if reward and reward.item then
						t.expect(StoreCatalog.ItemById[reward.item].source).toBe("season")
					end
				end
			end
		end)
		t.it("tier boundaries clamp to thirty and preserve separate account XP", function()
			t.expect((Season.tierInfo(season, -1))).toBe(1)
			t.expect((Season.tierInfo(season, 399))).toBe(1)
			t.expect((Season.tierInfo(season, 400))).toBe(2)
			t.expect((Season.tierInfo(season, 10 ^ 9))).toBe(30)
			local data = Schema.template()
			Season.addXp(data, season, 400, false)
			t.expect(data.xp).toBe(0)
			t.expect(data.season.xp).toBe(400)
		end)
		t.it("free grants and retroactive premium grants are idempotent", function()
			local data = Schema.template()
			Season.addXp(data, season, 1600, false)
			t.expect(data.owned.titulo_hora_extra).toBe(true)
			t.expect(data.owned.farda_hora_extra).toBe(nil)
			local freeBalance = data.wallet.fichas
			Season.grantReached(data, season, false)
			t.expect(data.wallet.fichas).toBe(freeBalance)
			Season.grantReached(data, season, true)
			t.expect(data.owned.farda_hora_extra).toBe(true)
			t.expect(data.owned.lanterna_ponto).toBe(true)
			local balance = data.wallet.fichas
			local creditos = data.wallet.creditos
			Season.grantReached(data, season, true)
			t.expect(data.wallet.fichas).toBe(balance)
			t.expect(data.wallet.creditos).toBe(creditos)
		end)
		t.it("new season resets progress and keeps cosmetics and currency", function()
			local data = Schema.template()
			Season.addXp(data, season, 1600, true)
			local nextSeason = table.clone(season)
			nextSeason.id = "s2"
			local balance = data.wallet.fichas
			t.expect(Season.sync(data, nextSeason)).toBe(true)
			t.expect(data.season.xp).toBe(0)
			t.expect((next(data.season.premium))).toBe(nil)
			t.expect(data.wallet.fichas).toBe(balance)
			t.expect(data.owned.lanterna_ponto).toBe(true)
		end)
		t.it("migrates v2 without losing wallet, inventory or receipts", function()
			local data = Schema.template()
			data.wallet.fichas = 900
			data.owned.lanterna_militar = true
			local raw: any = data
			raw.schemaVersion = 2
			raw.season = nil
			local migrated = Schema.migrate(raw)
			-- Sobe até a versão atual (v4 acrescentou vantagens e história; a temporada continua aqui).
			t.expect(migrated.schemaVersion >= 3).toBe(true)
			t.expect(migrated.wallet.fichas).toBe(900)
			t.expect(migrated.owned.lanterna_militar).toBe(true)
			t.expect(migrated.season.xp).toBe(0)
		end)
	end,
}
return spec
