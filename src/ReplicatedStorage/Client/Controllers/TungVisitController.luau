--!strict
--[[
	A Visita do Tum Tum, no cliente (o servidor é TungVisitService; regras em Shared/Game/TungVisit). Lê
	CampaignState.VisitPhase / VisitEndsAt / VisitSerial e faz só a parte sensorial: legendas, pancadas e rangidos
	vindos da escada, luz que pisca, coração disparado. O corpo dele é o real (CreatureVisualController).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TungVisit = require("@game/ReplicatedStorage/Shared/Game/TungVisit")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local FearController = require("./FearController")
local GameUiController = require("./GameUiController")
local WorldFxController = require("./WorldFxController")

local TungVisitController = {
	Name = "TungVisitController",
}

local STAIRS = Vector3.new(8, 3, 22)
local runToken = 0

local function warning(endsAt: number)
	runToken += 1
	local mine = runToken
	GameUiController.caption(TungVisit.Captions.warning, 7)
	WorldFxController.surge(2)
	CameraController.addTrauma(0.3)
	task.spawn(function()
		local startedAt = workspace:GetServerTimeNow()
		local total = math.max(1, endsAt - startedAt)
		local whispered = false
		while runToken == mine do
			local now = workspace:GetServerTimeNow()
			if now >= endsAt then
				return
			end
			local progress = 1 - (endsAt - now) / total
			-- Quanto mais perto do fim, mais forte e mais frequente: pancada no andar de cima, rangido da escada.
			AudioController.playAtPosition("DoorBang", STAIRS, 0.5 + progress * 0.7, 0.6 + progress * 0.2)
			if progress > 0.25 then
				AudioController.playAtPosition("CreakWood", STAIRS + Vector3.new(0, -2, 0), 0.8 + progress * 0.6, 0.7)
			end
			FearController.spike(0.1 + progress * 0.2)
			if not whispered and progress > 0.35 then
				whispered = true
				GameUiController.caption('Dona Cida sussurra: "O armário, rápido... e apaguem a lanterna."', 5)
			end
			if progress > 0.7 then
				WorldFxController.surge(1)
			end
			task.wait(math.max(0.9, 3.4 - progress * 2.5))
		end
	end)
end

function TungVisitController.Start()
	local state = ReplicatedStorage:WaitForChild("CampaignState", 30)
	if not state then
		return
	end
	local lastSerial = state:GetAttribute("VisitSerial")
	state:GetAttributeChangedSignal("VisitSerial"):Connect(function()
		local serial = state:GetAttribute("VisitSerial")
		if serial == lastSerial then
			return
		end
		lastSerial = serial
		local phase = state:GetAttribute("VisitPhase")
		if phase == "warning" then
			local endsAt = state:GetAttribute("VisitEndsAt")
			warning(if typeof(endsAt) == "number" then endsAt else workspace:GetServerTimeNow() + 20)
		elseif phase == "patrol" then
			runToken += 1
			GameUiController.caption(TungVisit.Captions.hall, 4)
			FearController.spike(0.4)
		elseif phase == "caught" then
			runToken += 1
			CameraController.addTrauma(0.9)
			FearController.spike(0.8)
			GameUiController.caption(TungVisit.Captions.caught, 3)
		elseif phase == "gone" then
			runToken += 1
			GameUiController.caption(TungVisit.Captions.gone, 4)
		end
	end)
end

return TungVisitController
