--!strict
local Icons = require("@game/ReplicatedStorage/Client/UI/Icons")
local MenuLayout = require("@game/ReplicatedStorage/Client/UI/MenuLayout")
local TestKit = require("../TestKit")

-- Ícones que o menu remasterizado desenha; um nome faltando quebraria a tela em runtime.
local MENU_ICONS = {
	"Play",
	"Perks",
	"Store",
	"Season",
	"Daily",
	"Servers",
	"Friends",
	"Settings",
	"More",
	"Coin",
	"Gem",
	"Backpack",
	"House",
	"Tree",
	"Lock",
	"Check",
	"Star",
	"Plus",
	"Close",
	"Drum",
}

return {
	name = "MenuUi",
	run = function(t)
		t.it("every menu icon exists and stays inside the 12x12 grid", function()
			local known = {}
			for _, kind in Icons.kinds() do
				known[kind] = true
			end
			for _, kind in MENU_ICONS do
				t.expect(known[kind]).toBe(true)
				local runs = Icons.runs(kind)
				t.expect(#runs > 0).toBe(true)
				for _, run in runs do
					t.expect(run[1] >= 0 and run[1] + run[3] <= 12).toBe(true)
					t.expect(run[2] >= 0 and run[2] < 12).toBe(true)
					t.expect(run[3] >= 1).toBe(true)
				end
			end
		end)
		t.it("runs merge contiguous pixels into one segment", function()
			-- Linha 6 do "More": ".##..##..##." vira três trechos de 2 px.
			local row = {}
			for _, run in Icons.runs("More") do
				if run[2] == 5 then
					table.insert(row, run)
				end
			end
			t.expect(#row).toBe(3)
			t.expect(row[1][1]).toBe(1)
			t.expect(row[1][3]).toBe(2)
		end)
		t.it("desktop scales from 1280x720 and touch is always compact", function()
			local desktop = MenuLayout.mode(1920, 1080, false)
			t.expect(desktop.compact).toBe(false)
			t.expect(desktop.scale).toBe(1.5)
			t.expect(desktop.key).toBe("desktop")
			local phone = MenuLayout.mode(844, 390, true)
			t.expect(phone.compact).toBe(true)
			t.expect(phone.short).toBe(true)
			t.expect(phone.scale).toBe(1)
			local tablet = MenuLayout.mode(1024, 768, true)
			t.expect(tablet.compact).toBe(true)
			t.expect(tablet.short).toBe(false)
			t.expect(MenuLayout.mode(1366, 768, false).compact).toBe(false)
			t.expect(MenuLayout.mode(900, 700, false).compact).toBe(true)
		end)
		t.it("cards use two columns only when they fit", function()
			t.expect(MenuLayout.columns(900)).toBe(2)
			t.expect(MenuLayout.columns(619)).toBe(1)
		end)
		t.it("compact rail keeps four destinations plus MAIS", function()
			local items = { "play", "perks", "store", "season", "daily", "servers", "friends", "settings" }
			local visible, overflow = MenuLayout.split(items, true)
			t.expect(#visible).toBe(4)
			t.expect(#overflow).toBe(4)
			t.expect(visible[1]).toBe("play")
			t.expect(overflow[1]).toBe("daily")
			local all, none = MenuLayout.split(items, false)
			t.expect(#all).toBe(8)
			t.expect(#none).toBe(0)
		end)
		t.it("chapter states mark flawless, cleared and exactly one next", function()
			local states = MenuLayout.chapters({ [1] = true, [2] = true, [4] = true }, { [2] = true }, 8)
			t.expect(states[1]).toBe("cleared")
			t.expect(states[2]).toBe("flawless")
			t.expect(states[3]).toBe("next")
			t.expect(states[4]).toBe("cleared")
			t.expect(states[5]).toBe("open")
			local nexts = 0
			for _, state in states do
				if state == "next" then
					nexts += 1
				end
			end
			t.expect(nexts).toBe(1)
			local done = MenuLayout.chapters({ [1] = true, [2] = true }, {}, 2)
			t.expect(done[1]).toBe("cleared")
			t.expect(done[2]).toBe("cleared")
		end)
	end,
} :: TestKit.Spec
