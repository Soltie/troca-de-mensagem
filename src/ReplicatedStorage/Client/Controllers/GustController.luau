--!strict
--[[
	Sopro que varre o corredor (ideia J; regras em Shared/Game/GustRules, servidor em GustService). Para cada trilho em
	Workspace.Gusts: durante o aviso as luzes do corredor piscam e o vento cresce no fim dele; depois uma parede de
	névoa gelada corre de uma ponta à outra com um uivo, empurrando poeira. Quem está no armário sente o armário
	sacudir quando ele passa. A pancada em quem ficou na faixa vem do servidor (fluxo da captura).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GustRules = require("@game/ReplicatedStorage/Shared/Game/GustRules")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local FlashlightController = require("./FlashlightController")
local SettingsController = require("./SettingsController")
local WorldFxController = require("./WorldFxController")

local player = Players.LocalPlayer

local GustController = {
	Name = "GustController",
}

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local MIST = Color3.fromRGB(196, 214, 236)

type Live = {
	from: Vector3,
	to: Vector3,
	dir: Vector3,
	length: number,
	startAt: number,
	front: BasePart,
	mist: ParticleEmitter,
	streaks: ParticleEmitter,
	glow: PointLight,
	warn: Sound?,
	howl: Sound?,
	passed: boolean,
}

local gusts: { [Instance]: Live } = {}

local function emitter(parent: BasePart, size: number, rate: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(MIST)
	e.LightEmission = 0.1
	e.LightInfluence = 0
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size * 0.6),
		NumberSequenceKeypoint.new(1, size * 1.4),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.6, 1)
	e.Rate = rate
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.EmissionDirection = Enum.NormalId.Front
	e.Speed = NumberRange.new(GustRules.Speed * 0.5, GustRules.Speed * 0.9)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Enabled = false
	e.Parent = parent
	return e
end

local function begin(instance: Instance)
	if gusts[instance] or not instance:IsA("BasePart") then
		return
	end
	local from = instance:GetAttribute("From")
	local to = instance:GetAttribute("To")
	local startAt = instance:GetAttribute("StartAt")
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(startAt) ~= "number" then
		return
	end
	local delta = to - from
	local dir = delta.Unit
	-- A frente: uma lâmina invisível atravessando o corredor, de onde sai a névoa.
	local front = Instance.new("Part")
	front.Name = "GustFront"
	front.Anchored, front.CanCollide, front.CanQuery, front.CanTouch = true, false, false, false
	front.Transparency = 1
	front.Size = Vector3.new(GustRules.HalfWidth * 2, 7, 0.5)
	front.CFrame = CFrame.lookAt(from, from + dir)
	front.Parent = workspace
	local glow = Instance.new("PointLight")
	glow.Color = MIST
	glow.Range = 18
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = front
	local live: Live = {
		from = from,
		to = to,
		dir = dir,
		length = delta.Magnitude,
		startAt = startAt,
		front = front,
		mist = emitter(front, 6, 180),
		streaks = emitter(front, 1.2, 60),
		glow = glow,
		warn = nil,
		howl = nil,
		passed = false,
	}
	live.streaks.Lifetime = NumberRange.new(0.2, 0.4)
	live.streaks.Speed = NumberRange.new(GustRules.Speed * 1.2, GustRules.Speed * 1.6)
	live.streaks.LightEmission = 0.6
	gusts[instance] = live
	-- Aviso: as luzes do corredor falham e o vento cresce lá no começo.
	local mid = from + delta / 2
	WorldFxController.surge(GustRules.WarnTime + live.length / GustRules.Speed + 0.5, mid, live.length / 2 + 8)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = from
	anchor.Parent = workspace.Terrain
	local warn = AudioController.playAt("WindInterior", anchor, 4, 0.7)
	warn.RollOffMaxDistance = live.length + 30
	live.warn = warn
	task.delay(GustRules.duration(live.length) + 1, function()
		anchor:Destroy()
	end)
end

local function finish(instance: Instance)
	local live = gusts[instance]
	if not live then
		return
	end
	gusts[instance] = nil
	live.mist.Enabled = false
	live.streaks.Enabled = false
	if live.warn then
		live.warn:Destroy()
	end
	task.delay(1.2, function()
		live.front:Destroy()
	end)
end

local function inLaneNow(live: Live, position: Vector3): (boolean, number)
	local offset = position - live.from
	local side = Vector3.new(-live.dir.Z, 0, live.dir.X)
	local along = offset:Dot(live.dir)
	return GustRules.inLane(along, offset:Dot(side), offset.Y, live.length), along
end

local function update()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local hidden = player:GetAttribute("Hidden")
	local inside = type(hidden) == "string" and hidden ~= ""
	local shake = SettingsController.get("shake")
	for instance, live in gusts do
		if not instance.Parent then
			finish(instance)
			continue
		end
		local elapsed = now - live.startAt
		local front = GustRules.front(elapsed)
		local lane, along = false, 0
		if body and body:IsA("BasePart") then
			lane, along = inLaneNow(live, body.Position)
		end
		if front < 0 then
			-- Aviso: vento crescendo; quem está na faixa sente o corredor tremer de leve.
			local k = 1 + front / (GustRules.WarnTime * GustRules.Speed)
			if live.warn then
				live.warn.Volume = 0.2 + 0.6 * k
				live.warn.PlaybackSpeed = 0.7 + 0.5 * k
			end
			if lane and shake then
				CameraController.addTrauma(0.012 * k)
			end
			continue
		end
		local distance = math.min(front, live.length)
		live.front.CFrame = CFrame.lookAt(live.from + live.dir * distance, live.from + live.dir * (distance + 1))
			+ Vector3.new(0, 0.5, 0)
		local moving = front <= live.length
		live.mist.Enabled = moving
		live.streaks.Enabled = moving
		live.glow.Brightness = if moving then 1.2 else 0
		if moving and not live.howl then
			-- O uivo acompanha a frente.
			local howl = AudioController.playAt("WindInterior", live.front, 8, 1.6)
			howl.RollOffMinDistance = 6
			howl.RollOffMaxDistance = 70
			live.howl = howl
			if live.warn then
				live.warn:Destroy()
				live.warn = nil
			end
		elseif not moving and live.howl then
			live.howl:Destroy()
			live.howl = nil
		end
		-- Passou por mim: no armário, o armário sacode; fora dele, a pancada vem do servidor.
		if not live.passed and lane and front >= along then
			live.passed = true
			FlashlightController.flicker(0.9)
			if inside then
				if shake then
					CameraController.addTrauma(0.45)
				end
				AudioController.play("DoorRattle", 0.9)
			end
		end
	end
end

function GustController.Start()
	local function watch(container: Instance)
		for _, child in container:GetChildren() do
			begin(child)
		end
		container.ChildAdded:Connect(function(child)
			-- Os atributos chegam junto; um quadro de folga por garantia.
			task.defer(begin, child)
		end)
		container.ChildRemoved:Connect(finish)
	end
	local existing = workspace:FindFirstChild("Gusts")
	if existing then
		watch(existing)
	else
		local connection: RBXScriptConnection? = nil
		connection = workspace.ChildAdded:Connect(function(child)
			if child.Name == "Gusts" then
				watch(child)
				if connection then
					connection:Disconnect()
				end
			end
		end)
	end
	RunService.Heartbeat:Connect(update)
end

return GustController
