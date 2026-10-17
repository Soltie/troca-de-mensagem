--!strict
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local StoreView = require("@game/ReplicatedStorage/Shared/Game/StoreView")
local TestKit = require("../TestKit")

return {
	name = "StoreView",
	run = function(t)
		t.it("every item explains a concrete way to get it", function()
			for _, item in StoreCatalog.Items do
				local text = StoreView.howToGet(item)
				t.expect(text ~= "").toBe(true)
				-- Fontes com número no catálogo precisam mostrar o número (nível, fitas, capítulo, nível do passe).
				if item.source == "level" or item.source == "tapes" or item.source == "season" then
					t.expect(string.find(text, "%d") ~= nil).toBe(true)
				end
				if item.source == "story" then
					t.expect(string.find(text, "%d") ~= nil).toBe(true)
				end
			end
		end)
		t.it("every kind has a note about who sees it", function()
			for _, kind in StoreCatalog.KINDS do
				t.expect(StoreView.kindNote(kind :: StoreCatalog.ItemKind) ~= "").toBe(true)
			end
		end)
		t.it("state follows ownership, equip and store source", function()
			local retro = StoreCatalog.ItemById.lanterna_retro
			t.expect(StoreView.state(retro, {}, "lanterna_padrao", false)).toBe("buyable")
			t.expect(StoreView.state(retro, { lanterna_retro = true }, "lanterna_padrao", false)).toBe("owned")
			t.expect(StoreView.state(retro, { lanterna_retro = true }, "lanterna_retro", false)).toBe("equipped")
			local default = StoreCatalog.ItemById.lanterna_padrao
			t.expect(StoreView.state(default, {}, "lanterna_padrao", false)).toBe("equipped")
			local vip = StoreCatalog.ItemById.lanterna_supervisor
			t.expect(StoreView.state(vip, {}, "lanterna_padrao", false)).toBe("locked")
			t.expect(StoreView.state(vip, {}, "lanterna_padrao", true)).toBe("owned")
			t.expect(StoreView.state(StoreCatalog.ItemById.lanterna_vigia, {}, "x", false)).toBe("locked")
		end)
		t.it("prices come from the catalog and report what is missing", function()
			local retro = StoreCatalog.ItemById.lanterna_retro
			local options = StoreView.prices(retro, 400, 200)
			t.expect(#options).toBe(2)
			t.expect(options[1].currency).toBe("fichas")
			t.expect(options[1].price).toBe(retro.fichas)
			t.expect(options[1].affordable).toBe(false)
			t.expect(options[1].missing).toBe((retro.fichas :: number) - 400)
			t.expect(options[2].affordable).toBe(true)
			t.expect(#StoreView.prices(StoreCatalog.ItemById.lanterna_vigia, 99999, 99999)).toBe(0)
		end)
		t.it("filter grade desaturates, tints and keeps neutral filters neutral", function()
			local neutral = { kind = "filter", tint = { 255, 255, 255 } } :: any
			local same = StoreView.grade({ 200, 100, 50 }, neutral)
			t.expect(same[1]).toBe(200)
			t.expect(same[2]).toBe(100)
			t.expect(same[3]).toBe(50)
			local cctv = StoreCatalog.ItemById.filtro_cctv
			local gray = StoreView.grade({ 220, 60, 40 }, cctv)
			-- Saturação -1: canais quase iguais (só a tinta pálida separa um pouco).
			t.expect(math.abs(gray[1] - gray[2]) <= 12).toBe(true)
			local sepia = StoreView.grade({ 128, 128, 128 }, StoreCatalog.ItemById.filtro_sepia)
			t.expect(sepia[1] > sepia[3]).toBe(true)
			for _, value in StoreView.grade({ 255, 255, 255 }, StoreCatalog.ItemById.filtro_infra) do
				t.expect(value >= 0 and value <= 255).toBe(true)
			end
		end)
		t.it("items of a kind keep rarity order and cover the catalog", function()
			local total = 0
			for _, kind in StoreCatalog.KINDS do
				local list = StoreView.itemsOfKind(kind :: StoreCatalog.ItemKind)
				total += #list
				for index = 2, #list do
					local a = StoreCatalog.Rarities[list[index - 1].rarity].order
					local b = StoreCatalog.Rarities[list[index].rarity].order
					t.expect(a <= b).toBe(true)
				end
			end
			t.expect(total).toBe(#StoreCatalog.Items)
		end)
	end,
} :: TestKit.Spec
