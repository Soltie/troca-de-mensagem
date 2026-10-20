--!strict
--[[
	A Porta que Troca, no cliente (o servidor está em DoorSwapService): quando este jogador atravessa uma porta
	trocada (atributo DoorSwapAt), a tela escurece por 0,2 s atrás de uma nuvem de serragem no rosto, para o salto não
	aparecer, e a Dona Cida fala logo depois.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CameraController = require("./CameraController")
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
		-- A câmera vira para a cadeira da Dona Cida (virada para a porta) por 2,4 s e devolve o controle.
		task.delay(0.5, function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local house = workspace:FindFirstChild("CursedHouse")
			if not root or not root:IsA("BasePart") or not house then
				return
			end
			for _, item in house:GetDescendants() do
				if item:IsA("Model") and item:GetAttribute("CidaChair") then
					local eye = root.Position + Vector3.new(0, 1.6, 0)
					local target = item:GetPivot().Position + Vector3.new(0, 2.2, 0)
					if CameraController.setCinema(CFrame.lookAt(eye, target), 62, target) then
						task.delay(3, CameraController.endCinema)
					end
					return
				end
			end
		end)
		task.delay(1.2, function()
			GameUiController.caption(LINE, 5)
			FurnitureMotionController.talk(4)
		end)
	end)
end

return DoorSwapController
