--!strict
--[[
	Efeitos de tela da floresta v2 no cliente. O servidor (ForestHazardService) marca no Forest um ponto de impacto
	(ShakeAt) e incrementa ShakeSerial: a ponte cedendo, o Tung Tung batendo na água ou no cais. Quem está perto sente
	o tranco (mais forte quanto mais perto, até 90 studs), respeitando a opção de tremor.
	A Voz (cap. 7): quando o servidor marca VoiceCallAt no jogador, a legenda mostra o chamado pelo nome dele.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CameraController = require("./CameraController")
local GameUiController = require("./GameUiController")
local SettingsController = require("./SettingsController")

local ForestFxController = {
	Name = "ForestFxController",
}

local REACH = 90
local watched: Instance? = nil
local lastSerial = 0

local function impact(forest: Instance)
	local serial = forest:GetAttribute("ShakeSerial")
	if type(serial) ~= "number" or serial == lastSerial then
		return
	end
	lastSerial = serial
	local at = forest:GetAttribute("ShakeAt")
	local camera = workspace.CurrentCamera
	if typeof(at) ~= "Vector3" or not camera or not SettingsController.get("shake") then
		return
	end
	local distance = (camera.CFrame.Position - at).Magnitude
	if distance < REACH then
		local k = 1 - distance / REACH
		CameraController.addTrauma(0.25 + 0.6 * k * k)
		CameraController.punch(0.6 + 0.8 * k)
	end
end

function ForestFxController.Start()
	RunService.Heartbeat:Connect(function()
		local world = workspace:FindFirstChild("CursedHouse")
		local forest = world and world:FindFirstChild("Forest")
		if forest ~= watched then
			watched = forest
			local serial = forest and forest:GetAttribute("ShakeSerial")
			lastSerial = if type(serial) == "number" then serial else 0
		end
		if forest then
			impact(forest)
		end
	end)
	local player = Players.LocalPlayer
	player:GetAttributeChangedSignal("VoiceCallAt"):Connect(function()
		local name = string.upper(player.DisplayName)
		GameUiController.caption(string.format('Uma voz chama da mata: "%s... aqui..."', name), 5)
	end)
	-- A coisa do lago (ForestHazardService.stepLurker): aviso e puxão.
	player:GetAttributeChangedSignal("LakeWarnAt"):Connect(function()
		GameUiController.caption("Algo passou embaixo de você... SAIA DA ÁGUA!", 3)
		CameraController.addTrauma(0.25)
	end)
	player:GetAttributeChangedSignal("LakeGrabAt"):Connect(function()
		GameUiController.caption("Algo te puxou de volta! Use a jangada.", 4)
		CameraController.addTrauma(0.8)
	end)
end

return ForestFxController
