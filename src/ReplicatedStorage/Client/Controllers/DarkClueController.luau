--!strict
--[[
	Pistas que só aparecem no escuro (enigma do relógio, World/HouseClocks): os mostradores marcados com a tag
	"DarkClue" acendem, piscando como um aparelho que perdeu a hora, enquanto a lanterna deste jogador está apagada.
	Com a lanterna acesa, o reflexo apaga o mostrador. Só visual e local.
]]

local CollectionService = game:GetService("CollectionService")

local FlashlightController = require("./FlashlightController")

local TAG = "DarkClue"

local DarkClueController = {
	Name = "DarkClueController",
}

function DarkClueController.Start()
	task.spawn(function()
		local clock = 0
		while true do
			clock += task.wait(0.1)
			-- 0,7 s aceso e 0,3 s apagado: pisca como um videocassete depois de uma queda de energia.
			local lit = not FlashlightController.isOn() and clock % 1 < 0.7
			for _, display in CollectionService:GetTagged(TAG) do
				local gui = display:FindFirstChildOfClass("SurfaceGui")
				if gui then
					gui.Enabled = lit
				end
			end
		end
	end)
end

return DarkClueController
