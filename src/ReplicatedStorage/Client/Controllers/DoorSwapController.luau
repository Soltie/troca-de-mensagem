--!strict
--[[
	A Porta que Troca, no cliente (o servidor está em DoorSwapService): quando este jogador atravessa uma porta
	trocada (atributo DoorSwapAt), a tela escurece por 0,2 s atrás de uma nuvem de serragem no rosto, para o salto não
	aparecer, e a Dona Cida fala logo depois.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local FurnitureMotionController = require("./FurnitureMotionController")
local GameUiController = require("./GameUiController")

local DoorSwapController = {
	Name = "DoorSwapController",
}

local LINE = "Ele está brincando com vocês... a porta com o desenho dele ele não mexe."

function DoorSwapController.Start()
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "DoorSwapFade"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	local veil = Instance.new("Frame")
	veil.Size = UDim2.fromScale(1, 1)
	veil.BackgroundColor3 = Color3.fromRGB(150, 122, 84)
	veil.BackgroundTransparency = 1
	veil.BorderSizePixel = 0
	veil.Parent = gui
	player:GetAttributeChangedSignal("DoorSwapAt"):Connect(function()
		veil.BackgroundTransparency = 0.05
		task.delay(0.2, function()
			TweenService:Create(veil, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		end)
		task.delay(1.2, function()
			GameUiController.caption(LINE, 5)
			FurnitureMotionController.talk(4)
		end)
	end)
end

return DoorSwapController
