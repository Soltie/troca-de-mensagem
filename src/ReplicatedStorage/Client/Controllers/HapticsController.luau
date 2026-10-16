--!strict
--[[
	Vibração do controle (gamepad). O PC continua sendo a plataforma principal: sem controle
	conectado, ou com a opção de conforto "haptics" desligada, nada acontece.
	Mobile não é coberto: o HapticService só dirige motores de gamepad.

	Eventos (todos locais e pessoais, como o resto da apresentação da ameaça):
	  passos do Vigia por perto (pulso no motor grande, mais forte quanto mais perto),
	  detecção (o Vigia começou a perseguir VOCÊ), captura, batimento com medo alto, pouso.
]]

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Presentation = require("@game/ReplicatedStorage/Shared/Game/ThreatPresentation")
local CharacterController = require("./CharacterController")
local FearController = require("./FearController")
local SettingsController = require("./SettingsController")

type Pulse = { motor: Enum.VibrationMotor, strength: number, endsAt: number }

local player = Players.LocalPlayer
local INPUT = Enum.UserInputType.Gamepad1
local LARGE = Enum.VibrationMotor.Large
local SMALL = Enum.VibrationMotor.Small

local pulses: { Pulse } = {}
local applied: { [Enum.VibrationMotor]: number } = { [LARGE] = 0, [SMALL] = 0 }
local supportCache: { [Enum.VibrationMotor]: boolean } = {}
local snapshot: GameState.Snapshot? = nil
local previousMode = "Dormant"
local previousStatus: string? = nil
local previousPhase: string? = nil
local nextStepAt = 0
local nextBeatAt = 0
local accumulator = 0

local function enabled(): boolean
	return SettingsController.get("haptics") and UserInputService.GamepadEnabled
end

local function supported(motor: Enum.VibrationMotor): boolean
	local cached = supportCache[motor]
	if cached ~= nil then
		return cached
	end
	local ok, value = pcall(function()
		return HapticService:IsVibrationSupported(INPUT) and HapticService:IsMotorSupported(INPUT, motor)
	end)
	local result = ok and value == true
	supportCache[motor] = result
	return result
end

local function setMotor(motor: Enum.VibrationMotor, value: number)
	if math.abs((applied[motor] or 0) - value) < 0.02 then
		return
	end
	applied[motor] = value
	if supported(motor) then
		pcall(function()
			HapticService:SetMotor(INPUT, motor, value)
		end)
	end
end

local function creature(): (BasePart?, string)
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	if not root or not root:IsA("BasePart") or root:GetAttribute(Tags.Attr.CreatureActive) ~= true then
		return nil, "Dormant"
	end
	local status = player:GetAttribute("CampaignStatus") :: string?
	local mode = Presentation.mode(
		(root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant",
		root:GetAttribute(Tags.Attr.ThreatTargetUserId) :: number?,
		player.UserId,
		status
	)
	return root, mode
end

local HapticsController = {
	Name = "HapticsController",
}

-- Pulso avulso: força 0..1 por `duration` segundos.
function HapticsController.pulse(strength: number, duration: number, motor: Enum.VibrationMotor?)
	if not enabled() then
		return
	end
	table.insert(pulses, {
		motor = motor or LARGE,
		strength = math.clamp(strength, 0, 1),
		endsAt = os.clock() + duration,
	})
end

function HapticsController.stopAll()
	table.clear(pulses)
	setMotor(LARGE, 0)
	setMotor(SMALL, 0)
end

function HapticsController.debugState(): { [string]: any }
	return { enabled = enabled(), pulses = #pulses, large = applied[LARGE], small = applied[SMALL] }
end

function HapticsController.Start()
	GameState.observe(function(next)
		snapshot = next
	end)
	SettingsController.onChanged(function(key, value)
		if key == "haptics" and not value then
			HapticsController.stopAll()
		end
	end)
	UserInputService.GamepadDisconnected:Connect(function()
		HapticsController.stopAll()
	end)
	CharacterController.onLanded(function(intensity: number)
		HapticsController.pulse(0.25 + intensity * 0.5, 0.15)
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 / 30 then
			return
		end
		accumulator = 0
		if not enabled() then
			if applied[LARGE] > 0 or applied[SMALL] > 0 then
				HapticsController.stopAll()
			end
			return
		end
		local s = snapshot
		local now = os.clock()
		local status = player:GetAttribute("CampaignStatus") :: string?
		local playing = s ~= nil and Presentation.playing(s.phase, status)
		local root, mode = creature()

		if s and Presentation.captured(previousStatus, status, previousPhase, s.phase) then
			HapticsController.pulse(1, 0.6, LARGE)
			HapticsController.pulse(0.8, 0.45, SMALL)
		end
		previousStatus = status
		previousPhase = if s then s.phase else nil

		if playing then
			if mode == "Chase" and previousMode ~= "Chase" then
				HapticsController.pulse(0.6, 0.35, LARGE)
			end
			-- Passos do Vigia: batidas cada vez mais fortes perto de você.
			local camera = workspace.CurrentCamera
			if root and camera and mode ~= "Dormant" then
				local distance = (root.Position - camera.CFrame.Position).Magnitude
				if distance < 22 and now >= nextStepAt then
					local k = (22 - distance) / 22
					nextStepAt = now + (if mode == "Chase" then 0.42 else 0.75)
					HapticsController.pulse(0.1 + 0.35 * k * k, 0.08, LARGE)
				end
			end
			-- Batimento: dois toques curtos no motor pequeno quando o medo está alto.
			local fear = FearController.get()
			if fear > 0.7 and now >= nextBeatAt then
				nextBeatAt = now + 60 / (70 + fear * 60)
				HapticsController.pulse(0.35, 0.07, SMALL)
				task.delay(0.16, function()
					HapticsController.pulse(0.25, 0.06, SMALL)
				end)
			end
		end
		previousMode = mode

		local large, small = 0, 0
		for i = #pulses, 1, -1 do
			local p = pulses[i]
			if now >= p.endsAt then
				table.remove(pulses, i)
			elseif p.motor == LARGE then
				large = math.max(large, p.strength)
			else
				small = math.max(small, p.strength)
			end
		end
		setMotor(LARGE, large)
		setMotor(SMALL, small)
	end)
end

return HapticsController
