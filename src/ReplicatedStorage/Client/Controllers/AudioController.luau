--!strict
--[[
	Áudio no cliente:
	- Camadas em loop (ambiência externa/interna, música, batimento) com volume suave por contexto:
	  dentro/fora do prédio (raycast para o teto), Vigia ativo, distância e perseguição.
	- Stingers nos eventos da rodada (Vigia acorda, captura, vitória).
	- Grupo "Lofi": EQ cortando agudos + reverb de corredor = som "PS1". Sons 3D do mundo
	  (portas, zumbido, gerador) criados pelo servidor também entram no grupo, localmente.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")

local player = Players.LocalPlayer

local group: SoundGroup? = nil
local loops: { [string]: Sound } = {}
local targets: { [string]: number } = {}
local speeds: { [string]: number } = {}
local snapshot: GameState.Snapshot? = nil
local inside = false
local lastInsideCheck = 0

local function getGroup(): SoundGroup
	assert(group, "[AudioController] used before Init")
	return group
end

local function make(name: string, clipName: string, parent: Instance, looped: boolean): Sound
	local clip = Audio[clipName]
	assert(clip, `[AudioController] unknown clip "{clipName}"`)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = clip.id
	sound.Volume = clip.volume
	sound.PlaybackSpeed = clip.speed or 1
	sound.Looped = looped
	sound.SoundGroup = getGroup()
	sound.Parent = parent
	return sound
end

local function creatureRoot(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

local function checkInside(position: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	return workspace:Raycast(position, Vector3.new(0, 25, 0), params) ~= nil
end

local AudioController = {
	Name = "AudioController",
}

-- Som 2D de uma vez (UI, stingers). Retorna o Sound (destruído ao terminar).
function AudioController.play(clipName: string, volumeScale: number?, speed: number?): Sound
	local sound = make(clipName, clipName, SoundService, false)
	sound.Volume *= volumeScale or 1
	if speed then
		sound.PlaybackSpeed = speed
	end
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(30, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
	return sound
end

-- Som 3D de uma vez preso a uma peça/attachment.
function AudioController.playAt(clipName: string, parent: Instance, volumeScale: number?, speed: number?): Sound
	local sound = make(clipName, clipName, parent, false)
	sound.Volume *= volumeScale or 1
	if speed then
		sound.PlaybackSpeed = speed
	end
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	return sound
end

-- Loop 3D controlado por quem chamou (ex.: rosnado de perseguição na criatura).
function AudioController.loopAt(clipName: string, parent: Instance): Sound
	local sound = make(clipName, clipName, parent, true)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = 90
	return sound
end

function AudioController.isInside(): boolean
	return inside
end

function AudioController.Init()
	local g = Instance.new("SoundGroup")
	g.Name = "Lofi"
	g.Volume = 1
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain = -9
	eq.MidGain = -1
	eq.LowGain = 1
	eq.Parent = g
	g.Parent = SoundService
	group = g
	SoundService.AmbientReverb = Enum.ReverbType.StoneCorridor

	for _, name in { "AmbExterior", "AmbInterior", "Music", "Heartbeat" } do
		local sound = make(name, name, SoundService, true)
		targets[name] = 0
		speeds[name] = sound.PlaybackSpeed
		sound.Volume = 0
		loops[name] = sound
	end
end

function AudioController.Start()
	for _, sound in loops do
		sound:Play()
	end

	-- Sons 3D do mundo (servidor) também passam pelo filtro lo-fi.
	local function adopt(instance: Instance)
		if instance:IsA("Sound") then
			instance.SoundGroup = getGroup()
		end
	end
	task.spawn(function()
		local world = workspace:WaitForChild(Tags.WorldFolder, 30)
		if world then
			for _, d in world:GetDescendants() do
				adopt(d)
			end
			world.DescendantAdded:Connect(adopt)
		end
	end)

	GameState.observe(function(next: GameState.Snapshot)
		local previous = snapshot
		snapshot = next
		if previous == nil then
			return
		end
		if next.creatureActive and not previous.creatureActive and next.phase == "Playing" then
			AudioController.play("StingerAwaken")
		end
		if next.phase ~= previous.phase then
			if next.phase == "Lost" then
				AudioController.play("StingerCapture")
				AudioController.play("Roar", 1.1, 0.8)
			elseif next.phase == "Won" then
				AudioController.play("StingerWin")
			end
		end
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local camera = workspace.CurrentCamera
		local s = snapshot
		if not camera or not s then
			return
		end
		local now = os.clock()
		if now - lastInsideCheck > 0.3 then
			lastInsideCheck = now
			inside = checkInside(camera.CFrame.Position)
		end

		local playing = s.phase == "Playing" or s.phase == "Intro"
		local root = creatureRoot()
		local mode = if root then root:GetAttribute(Tags.Attr.CreatureMode) else nil
		local chasing = mode == "Chase"
		local distance = if root and s.creatureActive
			then (root.Position - camera.CFrame.Position).Magnitude
			else math.huge

		targets.AmbExterior = if playing then (if inside then 0.06 else Audio.AmbExterior.volume) else 0.04
		targets.AmbInterior = if playing and inside then Audio.AmbInterior.volume else 0
		targets.Music = if s.phase == "Playing" and s.creatureActive
			then Audio.Music.volume * (if chasing then 1.4 else 1)
			else 0
		local near = math.clamp((30 - distance) / 30, 0, 1)
		targets.Heartbeat = if s.phase == "Playing" then near * 0.55 + (if chasing then 0.3 else 0) else 0
		loops.Heartbeat.PlaybackSpeed = speeds.Heartbeat * (if chasing then 1.35 else 1 + near * 0.2)

		for name, sound in loops do
			sound.Volume += (targets[name] - sound.Volume) * math.min(1, dt * 1.5)
		end
	end)
end

return AudioController
