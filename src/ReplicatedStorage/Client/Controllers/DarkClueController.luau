--!strict
--[[
	Pistas que dependem da lanterna de quem olha (só visual e local):
	- "DarkClue": mostradores (World/HouseClocks) que acendem piscando com a lanterna apagada.
	- "DarkGlow": olhos do Retrato que Olha (Campaign/HouseMiniPuzzles); aparecem com a lanterna apagada e, com o
	  atributo FollowEyes, se viram para a câmera (seguem quem anda).
	- "FlashShadow": a sombra das engrenagens na parede (Sombra do Pêndulo); aparece só com a lanterna acesa,
	  perto (até 22 studs) e mirando na direção dela.
]]

local CollectionService = game:GetService("CollectionService")

local FlashlightController = require("./FlashlightController")

local DarkClueController = {
	Name = "DarkClueController",
}

function DarkClueController.Start()
	task.spawn(function()
		local clock = 0
		while true do
			clock += task.wait(0.1)
			local on = FlashlightController.isOn()
			-- 0,7 s aceso e 0,3 s apagado: pisca como um videocassete depois de uma queda de energia.
			local lit = not on and clock % 1 < 0.7
			for _, display in CollectionService:GetTagged("DarkClue") do
				local gui = display:FindFirstChildOfClass("SurfaceGui")
				if gui then
					gui.Enabled = lit
				end
			end
			local camera = workspace.CurrentCamera
			for _, eye in CollectionService:GetTagged("DarkGlow") do
				if not eye:IsA("BasePart") then
					continue
				end
				eye.Transparency = if on then 1 else 0.15
				local home = eye:GetAttribute("Home")
				if camera and typeof(home) == "CFrame" and eye:GetAttribute("FollowEyes") then
					-- A pupila desliza um pouco na direção de quem está olhando.
					local toCamera = home:PointToObjectSpace(camera.CFrame.Position)
					local flat = Vector3.new(toCamera.X, toCamera.Y, 0)
					local shift = if flat.Magnitude > 0.01 then flat.Unit * 0.05 else Vector3.zero
					eye.CFrame = home * CFrame.new(shift)
				end
			end
			for _, shadow in CollectionService:GetTagged("FlashShadow") do
				if not shadow:IsA("BasePart") then
					continue
				end
				local visible = false
				if on and camera then
					local offset = shadow.Position - camera.CFrame.Position
					visible = offset.Magnitude < 22 and camera.CFrame.LookVector:Dot(offset.Unit) > 0.75
				end
				shadow.Transparency = if visible then 0.25 else 1
			end
		end
	end)
end

return DarkClueController
