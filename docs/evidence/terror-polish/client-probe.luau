--!strict
-- Fixture temporário de QA, criado como Script RunContext=Client SOMENTE durante Play.
-- Compartilha a VM normal dos controllers; execute_luau Client sozinho tem cache de require separado.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local controllers = game:GetService("ReplicatedStorage").Client.Controllers
local tension = require(controllers.TensionController)
local screen = require(controllers.ScreenFxController)
local feedback = require(controllers.ThreatFeedbackController)
local camera = require(controllers.CameraController)
local fear = require(controllers.FearController)
local settings = require(controllers.SettingsController)
local audio = require(controllers.AudioController)
local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
gui:WaitForChild("FearOverlay")
local samples = {}
local bridge = Instance.new("BindableFunction")
bridge.Name = "TerrorQA"
bridge.OnInvoke = function(command: string, value: any)
	if command == "sample" then
		table.clear(samples)
		task.spawn(function()
			for i = 1, 40 do
				local feedbackState = feedback.debugState()
				table.insert(samples, { at = i * 0.05, mode = camera.debugState().mode, captures = feedbackState.captures,
					impact = screen.debugState().impact, blur = screen.debugState().blur })
				task.wait(0.05)
			end
		end)
		return "sampling armed"
	elseif command == "settings" then
		for _, key in settings.KEYS do settings.set(key, value) end
		return "ok"
	elseif command == "setting" then
		settings.set(value.key, value.value)
		return "ok"
	elseif command == "preview" then
		return tension.preview(value)
	elseif command == "spike" then
		fear.spike(value)
		return "ok"
	elseif command == "state" then
		local errors = {}
		for _, item in LogService:GetLogHistory() do
			if (item.messageType == Enum.MessageType.MessageError or item.messageType == Enum.MessageType.MessageWarning)
				and not string.find(item.message, "UIBlox", 1, true) and not string.find(item.message, "CorePackages", 1, true)
				and not string.find(item.message, "sabuiltin_Assistant", 1, true) then
				table.insert(errors, item.message)
			end
		end
		local cam = camera.debugState()
		cam.offset = tostring(cam.offset)
		return HttpService:JSONEncode({ tension = tension.debugState(), screen = screen.debugState(),
			feedback = feedback.debugState(), camera = cam, fear = fear.debugState(), music = audio.musicState(), samples = samples,
			errors = errors, options = gui.ComfortOptions.Options.Visible })
	end
	return "unknown command"
end
bridge.Parent = gui
