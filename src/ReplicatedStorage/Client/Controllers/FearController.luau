--!strict
--[[
	Medo do jogador no cliente (FearModel). Não há barra: o valor dirige batimento, respiração,
	vinheta, tremor, FOV, distorção, abafamento, sussurros e alucinações.

	Por que no cliente: é só apresentação, muda a cada quadro e não deve gerar remote por quadro.
	O que é de verdade (onde o Vigia está, se te viu, a captura) continua decidido no servidor;
	aqui só lemos o que já replica (Root do Vigia, atributos, GameState).

	Entradas: distância e modo do Vigia, linha de visão até ele, escuridão (lanterna/luzes por
	perto), esconderijo e lugar seguro. Sustos somam picos (detecção, despertar, barulhos).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FearModel = require("@game/ReplicatedStorage/Shared/Game/FearModel")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local BodyAudioController = require("./BodyAudioController")
local CameraController = require("./CameraController")
local FlashlightController = require("./FlashlightController")

local player = Players.LocalPlayer
local TICK = 1 / 20

local state = FearModel.new()
local snapshot: GameState.Snapshot? = nil
local accumulator = 0
local lastVisibilityCheck = 0
local visible = false
local lastMode = "Dormant"
local lastAlert = 0
local darkness = 0
local levelCallbacks: { (number) -> () } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function creatureRoot(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

local function isHidden(): boolean
	local hidden = player:GetAttribute("Hidden")
	return type(hidden) == "string" and hidden ~= ""
end

-- Perto de uma luz acesa? (lâmpadas, emergência, holofotes do servidor)
local function nearLight(position: Vector3): boolean
	for _, part in CollectionService:GetTagged(Tags.PowerLight) do
		if part:IsA("BasePart") then
			local light = part:FindFirstChildWhichIsA("Light")
			if light and light.Enabled and light.Brightness > 0.2 then
				local range = (light :: any).Range or 0
				if (part.Position - position).Magnitude < range * 0.75 then
					return true
				end
			end
		end
	end
	return false
end

-- O Vigia está na tela e sem parede no meio?
local function checkVisible(camera: Camera, root: BasePart): boolean
	local head = root.Position + Vector3.new(0, root.Size.Y * 0.35, 0)
	local _, onScreen = camera:WorldToViewportPoint(head)
	if not onScreen then
		return false
	end
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local model = root.Parent
	if model then
		table.insert(exclude, model)
	end
	local visual = workspace:FindFirstChild("VigiaVisual")
	if visual then
		table.insert(exclude, visual)
	end
	table.insert(exclude, camera)
	rayParams.FilterDescendantsInstances = exclude
	local origin = camera.CFrame.Position
	return workspace:Raycast(origin, head - origin, rayParams) == nil
end

local FearController = {
	Name = "FearController",
}

function FearController.get(): number
	return state.value
end

function FearController.level(): number
	return state.level
end

function FearController.darkness(): number
	return darkness
end

function FearController.spike(amount: number)
	FearModel.spike(state, amount)
end

function FearController.onLevelChanged(callback: (level: number) -> ())
	table.insert(levelCallbacks, callback)
end

function FearController.debugState(): { [string]: any }
	return {
		value = math.floor(state.value * 100 + 0.5) / 100,
		base = math.floor(state.base * 100 + 0.5) / 100,
		spike = math.floor(state.spike * 100 + 0.5) / 100,
		level = state.level,
		darkness = darkness,
		visible = visible,
	}
end

function FearController.Start()
	GameState.observe(function(next: GameState.Snapshot)
		local previous = snapshot
		snapshot = next
		if previous and next.phase ~= previous.phase and next.phase == "Intro" then
			FearModel.reset(state)
		end
		if previous and next.creatureActive and not previous.creatureActive and next.phase == "Playing" then
			FearModel.spike(state, 0.25)
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		accumulator += dt
		if accumulator < TICK then
			return
		end
		local step = accumulator
		accumulator = 0
		local s = snapshot
		local camera = workspace.CurrentCamera
		if not s or not camera then
			return
		end
		local now = os.clock()
		local root = creatureRoot()
		local active = root ~= nil and s.creatureActive and root.Position.Y > -100
		local position = camera.CFrame.Position
		local distance = if active and root then (root.Position - position).Magnitude else math.huge
		local mode = if root then (root:GetAttribute(Tags.Attr.CreatureMode) :: string?) or "Dormant" else "Dormant"

		if active and root and distance < 70 and now - lastVisibilityCheck > 0.2 then
			lastVisibilityCheck = now
			visible = checkVisible(camera, root)
		elseif not active or distance >= 70 then
			visible = false
		end

		-- Picos de susto: ele te viu / te ouviu no armário.
		if mode == "Chase" and lastMode ~= "Chase" then
			FearModel.spike(state, 0.35)
		end
		lastMode = mode
		local alert = if root then (root:GetAttribute("Alert") :: number?) or 0 else 0
		if alert ~= lastAlert then
			if lastAlert ~= 0 then
				FearModel.spike(state, 0.4)
			end
			lastAlert = alert
		end

		local lit = s.powerOn or nearLight(position)
		local flashlight = FlashlightController.isOn()
		darkness = if lit then 0 elseif flashlight then 0.35 else 1
		local playing = s.phase == "Playing"
		local changed = FearModel.step(state, {
			creatureDistance = if playing then distance else math.huge,
			creatureVisible = playing and visible,
			chasing = playing and (mode == "Chase" or mode == "Capture"),
			darkness = if playing then darkness else 0,
			hidden = isHidden(),
			safe = lit and distance > 45,
		}, step)
		if changed then
			for _, callback in levelCallbacks do
				task.spawn(callback, state.level)
			end
		end

		CameraController.setFear(state.value)
		AudioController.setFear(state.value)
		BodyAudioController.setFear(state.value)
	end)
end

return FearController
