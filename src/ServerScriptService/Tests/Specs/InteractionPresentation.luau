--!strict
local Rules = require("@game/ReplicatedStorage/Shared/Game/InteractionPresentation")
local TestKit = require("../TestKit")
return {
	name = "InteractionPresentation",
	run = function(t)
		t.it("inactive players cannot target or send gameplay requests", function()
			t.expect(Rules.allowed("Playing", nil)).toBe(true)
			t.expect(Rules.allowed("Playing", "Active")).toBe(true)
			for _, status in { "Downed", "Waiting", "Escaped" } do
				t.expect(Rules.allowed("Playing", status)).toBe(false)
			end
			t.expect(Rules.allowed("Lost", "Active")).toBe(false)
		end)
		t.it("solo locks use the key and alternative actions stay unavailable in coop", function()
			t.expect(Rules.prompt("ABRIR", "ENTREABRIR", true, false, false)).toBe("[E] TRANCADA")
			t.expect(Rules.prompt("ABRIR", "ENTREABRIR", true, true, false)).toBe("[E] DESTRANCAR")
			t.expect(Rules.prompt("ABRIR", "ENTREABRIR", false, false, false)).toBe("[E] ABRIR\n[Q] ENTREABRIR")
			t.expect(Rules.prompt("ABRIR", "ENTREABRIR", true, true, true)).toBe("[E] ABRIR")
		end)
		t.it("only approved item kinds receive pickup animation", function()
			for _, kind in { "Fuse", "Battery", "Key", "Tape" } do
				t.expect(Rules.pickup(kind)).toBe(true)
			end
			t.expect(Rules.pickup("BreakerWrong")).toBe(false)
			t.expect(Rules.pickup(nil)).toBe(false)
		end)
	end,
} :: TestKit.Spec
