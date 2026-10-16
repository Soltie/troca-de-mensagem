--!strict
local Funnel = require("@game/ServerScriptService/Server/Game/StoreFunnel")
local TestKit = require("../TestKit")
local spec: TestKit.Spec = {
	name = "StoreFunnel",
	run = function(t)
		t.it("ignores unsolicited steps and repeats within a session", function()
			local state = Funnel.new()
			t.expect(#Funnel.view(state, "shop")).toBe(0)
			t.expect(#Funnel.purchase(state, "item", "fichas")).toBe(0)
			t.expect(Funnel.open(state, "a")[1].step).toBe(1)
			t.expect(#Funnel.view(state, "invalid")).toBe(0)
			t.expect(Funnel.view(state, "season")[1].step).toBe(2)
			t.expect(#Funnel.view(state, "shop")).toBe(0)
			t.expect(Funnel.purchase(state, "pass", "robux")[1].step).toBe(3)
			t.expect(#Funnel.purchase(state, "pass", "robux")).toBe(0)
			t.expect(Funnel.open(state, "b")[1].step).toBe(1)
			t.expect(state.session).toBe("b")
		end)
	end,
}
return spec
