--!strict
--[[
	Personagem em primeira pessoa (a trava de câmera vem do servidor: Player.CameraMode).
	- Corrida com fôlego (Shift). O servidor percebe a corrida pela velocidade (barulho).
	- Balanço de câmera ao andar e tremores (desligáveis com B, opção de conforto).
	- Esconde a UI padrão do Roblox e desativa o botão de reset.
	A simulação/controle do Roblox não é alterada: só WalkSpeed e CameraOffset.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local SettingsController = require("./SettingsController")

local P = Config.Player
local player = Players.LocalPlayer

local stamina = P.StaminaMax
local exhausted = false
local sprinting = false
local phase: GameState.Phase = "Loading"
local bobTime = 0
local shakeAmount = 0
local shakeUntil = 0
local rng = Random.new()

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function disableCoreUi()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

local function update(dt: number)
	local h = humanoid()
	local camera = workspace.CurrentCamera
	if camera then
		camera.FieldOfView = P.FieldOfView
	end
	if not h then
		return
	end

	local moving = h.MoveDirection.Magnitude > 0.1
	local wantsSprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	if stamina <= 0 then
		exhausted = true
	elseif stamina >= P.StaminaMinToSprint then
		exhausted = false
	end
	sprinting = phase == "Playing" and wantsSprint and moving and not exhausted

	if sprinting then
		stamina = math.max(0, stamina - dt)
	else
		stamina = math.min(P.StaminaMax, stamina + dt * P.StaminaRegen)
	end
	if phase == "Playing" then
		h.WalkSpeed = if sprinting then P.SprintSpeed else P.WalkSpeed
	end

	-- Balanço de câmera + tremor (opção de conforto: B).
	local offset = Vector3.zero
	if SettingsController.get("motion") then
		if moving and phase == "Playing" then
			local speedFactor = h.WalkSpeed / P.WalkSpeed
			bobTime += dt * 7 * speedFactor
			local amount = Config.Effects.HeadBobAmount * speedFactor
			offset = Vector3.new(math.sin(bobTime) * amount * 0.6, math.abs(math.cos(bobTime)) * amount, 0)
		end
		if os.clock() < shakeUntil then
			offset += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) * shakeAmount
		end
	end
	h.CameraOffset = h.CameraOffset:Lerp(offset, math.min(1, dt * 12))
end

local CharacterController = {
	Name = "CharacterController",
}

function CharacterController.Init()
	-- Primeira pessoa travada (definido no cliente: no servidor não replica de forma confiável).
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	player.CameraMinZoomDistance = 0.5
	disableCoreUi()
	UserInputService.MouseIconEnabled = false
end

function CharacterController.Start()
	GameState.observe(function(snapshot)
		if snapshot.phase ~= phase and snapshot.phase == "Intro" then
			stamina = P.StaminaMax
			exhausted = false
		end
		phase = snapshot.phase
	end)
	RunService.RenderStepped:Connect(update)
end

function CharacterController.getStamina(): (number, number)
	return stamina, P.StaminaMax
end

function CharacterController.isSprinting(): boolean
	return sprinting
end

-- Tremor de câmera (ignorado se o jogador desligou o movimento de câmera).
function CharacterController.shake(amount: number, duration: number)
	shakeAmount = math.max(if os.clock() < shakeUntil then shakeAmount else 0, amount)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
end

return CharacterController
