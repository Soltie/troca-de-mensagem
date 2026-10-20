--!strict
--[[
	Câmera de quem foi pego no modo História (CaptureSequenceService no servidor):
	  - sendo arrastado / arremessado (BeingDragged, Thrown): terceira pessoa olhando o Tung;
	  - virou móvel (Furniture, ainda Downed): olha o móvel de fora, esperando as três batidas.
	Depois de endurecer (Waiting) o SpectatorController assume. O susto 3D (JumpscareController) tem a câmera dele.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraController = require("./CameraController")
local JumpscareController = require("./JumpscareController")
local ThreatFeedbackController = require("./ThreatFeedbackController")

local player = Players.LocalPlayer

local Controller = { Name = "CaptiveCameraController" }

local owning = false

local function furnitureFocus(): Vector3?
	local house = workspace:FindFirstChild("CursedHouse")
	local model = (house and house:FindFirstChild(`CapturedFurniture_{player.UserId}`))
		or workspace:FindFirstChild(`CapturedFurniture_{player.UserId}`)
	if model and model:IsA("Model") then
		return model:GetPivot().Position + Vector3.new(0, 2, 0)
	end
	return nil
end

function Controller.Start()
	RunService.RenderStepped:Connect(function()
		local downed = player:GetAttribute("CampaignStatus") == "Downed"
		local dragged = player:GetAttribute("BeingDragged") == true or player:GetAttribute("Thrown") == true
		local furniture = downed and player:GetAttribute("Furniture") ~= nil
		local want = (dragged or furniture) and not JumpscareController.recent(2.2)
		if want then
			if not CameraController.isCapturing() then
				CameraController.capture(if dragged then ThreatFeedbackController.creatureHead else furnitureFocus)
				owning = true
			end
		elseif owning then
			owning = false
			if CameraController.isCapturing() then
				CameraController.reset()
			end
		end
	end)
end

return Controller
