--!strict
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local TestKit = require("../TestKit")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")

local spec: TestKit.Spec = {
	name = "PixelText",
	run = function(t)
		t.it("drops accents the pixel font cannot draw, keeps Ã and Ç", function()
			t.expect(PixelText.normalize("FUSÍVEIS ELÉTRICO PORTÃO AÇÃO VOCÊ"))
				.toBe("FUSIVEIS ELETRICO PORTÃO AÇÃO VOCE")
			t.expect(PixelText.normalize("sem acento")).toBe("sem acento")
		end)

		t.it("UI texts keep full accents (interface fonts draw them)", function()
			t.expect(Text.Prompts.Fuse).toBe("PEGAR FUSÍVEL")
			t.expect(Text.Store.tabs.chests).toBe("BAÚS")
			t.expect(string.find(Text.Notes.note_order, "fusíveis", 1, true) ~= nil).toBe(true)
		end)
	end,
}

return spec
