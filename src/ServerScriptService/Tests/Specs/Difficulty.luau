--!strict
local Difficulty = require("@game/ReplicatedStorage/Shared/Game/Difficulty")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local TestKit = require("../TestKit")

local spec: TestKit.Spec = {
	name = "Difficulty",
	run = function(t)
		t.it("parses only known modifiers, once, in catalog order", function()
			t.expect(table.concat(Difficulty.parse("faro,pesadelo,faro,hack"), ",")).toBe("pesadelo,faro")
			t.expect(#Difficulty.parse(nil)).toBe(0)
			t.expect(Difficulty.toggle("", "pilha")).toBe("pilha")
			t.expect(Difficulty.toggle("pilha,veloz", "pilha")).toBe("veloz")
			t.expect(Difficulty.toggle("veloz", "nope")).toBe("veloz")
		end)

		t.it("normal changes nothing; each modifier makes it harder and pays more", function()
			local base = Difficulty.factors("")
			t.expect(base.speed).toBe(1)
			t.expect(base.bonus).toBe(0)
			for _, m in Difficulty.List do
				local f = Difficulty.factors(m.id)
				t.expect(f.bonus > 0).toBe(true)
				t.expect(f.speed >= 1 and f.hearing >= 1 and f.battery >= 1).toBe(true)
				t.expect(f.speed > 1 or f.hearing > 1 or f.battery > 1).toBe(true)
			end
			t.expect(Difficulty.boost(10, "")).toBe(10)
			t.expect(Difficulty.boost(10, "pesadelo")).toBe(15)
			t.expect(Difficulty.boost(1, "pilha") >= 1).toBe(true)
		end)

		t.it("the creature never outruns a sprinting player, even with everything on", function()
			local all = "pesadelo,pilha,faro,veloz"
			local sprint = Config.Player.SprintSpeed
			for _, base in { 6, 10, 14, 18, sprint - 1 } do
				t.expect(Difficulty.creatureSpeed(base, all, sprint) < sprint).toBe(true)
				t.expect(Difficulty.creatureSpeed(base, all, sprint) >= base).toBe(true)
			end
			t.expect(Difficulty.creatureSpeed(0, all, sprint)).toBe(0)
		end)
	end,
}

return spec
