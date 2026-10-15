--!strict
--[[
	Lanterna (F). Luz local presa à câmera com um leve atraso (balanço da mão) e falhas
	"em passos" quando O Vigia está perto. O estado vai para o servidor (remote SetFlashlight),
	porque lanterna ligada deixa o jogador visível de mais longe.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")

local player = Players.LocalPlayer

local on = true
local rig: BasePart? = nil
local spot: SpotLight? = nil
local spill: PointLight? = nil
local smoothed: CFrame? = nil
local flickerClock = 0
local flickerFactor = 1
local rng = Random.new()
local phase: GameState.Phase = "Loading"

local function creatureDistance(position: Vector3): number
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	if root and root:IsA("BasePart") and root:GetAttribute(Tags.Attr.CreatureActive) then
		return (root.Position - position).Magnitude
	end
	return math.huge
end

local function apply()
	local visible = on and phase ~= "Won"
	if spot then
		spot.Enabled = visible
	end
	if spill then
		spill.Enabled = visible
	end
end

local function send()
	local ok, remote = pcall(Remotes.clientEvent, "SetFlashlight", 10)
	if ok then
		remote:FireServer(on)
	end
end

local FlashlightController = {
	Name = "FlashlightController",
}

function FlashlightController.isOn(): boolean
	return on
end

function FlashlightController.set(value: boolean, silent: boolean?)
	if on == value then
		return
	end
	on = value
	apply()
	if not silent then
		AudioController.play("Flashlight", 1, 1.15)
	end
	task.spawn(send)
end

function FlashlightController.Init()
	local part = Instance.new("Part")
	part.Name = "FlashlightRig"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false

	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 46
	light.Range = 48
	light.Brightness = 2.6
	light.Color = Color3.fromRGB(255, 232, 196)
	light.Shadows = false
	light.Parent = part

	local glow = Instance.new("PointLight")
	glow.Range = 7
	glow.Brightness = 0.25
	glow.Color = Color3.fromRGB(255, 232, 196)
	glow.Shadows = false
	glow.Parent = part

	part.Parent = workspace
	rig = part
	spot = light
	spill = glow
end

function FlashlightController.Start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.F then
			return
		end
		if phase == "Playing" or phase == "Intro" then
			FlashlightController.set(not on)
		end
	end)

	player.CharacterAdded:Connect(function()
		on = true
		apply()
		task.spawn(send)
	end)

	GameState.observe(function(snapshot)
		phase = snapshot.phase
		apply()
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		local part = rig
		if not camera or not part then
			return
		end
		local target = camera.CFrame * CFrame.new(0.35, -0.4, -0.5)
		-- Atraso leve na rotação = "mão" segurando a lanterna.
		smoothed = if smoothed then smoothed:Lerp(target, math.min(1, dt * 14)) else target
		part.CFrame = CFrame.new(target.Position) * (smoothed :: CFrame).Rotation

		-- Falhas em passos (12 Hz) quando O Vigia está perto.
		flickerClock += dt
		local stepTime = 1 / Config.Visual.FlickerRate
		if flickerClock >= stepTime then
			flickerClock -= stepTime
			local distance = creatureDistance(target.Position)
			local chance = if distance < 22 then (22 - distance) / 22 * 0.35 else 0
			flickerFactor = if rng:NextNumber() < chance then rng:NextNumber(0, 0.4) else 1
		end
		if spot then
			spot.Brightness = 2.6 * flickerFactor
		end
	end)
end

return FlashlightController
