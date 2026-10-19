--!strict
--[[
	Áudio no cliente (mixagem central).

	Grupos:
	  Lofi  mundo, ambiência, música e corpo: EQ "PS1" (corta agudos) + EQ de abafamento
	        (escondido / pânico) + compressor (evita saturar quando tudo toca junto).
	  Ui    interface e stingers: fora do abafamento.

	Camadas em loop com volume suave por contexto:
	  ambiência externa/interna, vento nas frestas, máquinas (com energia), música por estado
	  (calma / tensão / perseguição / alívio), batimento (medo + proximidade), sussurros (medo alto).
	Reverb por sala (zonas criadas pelo servidor em Substation9.Features.Zones).
	silence(s): corta tudo por alguns segundos antes de certos sustos.
	Sons 3D do mundo (servidor) entram no grupo Lofi localmente.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Presentation = require("@game/ReplicatedStorage/Shared/Game/ThreatPresentation")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")

export type MusicState = "none" | "calm" | "tension" | "chase" | "relief"

local player = Players.LocalPlayer

local group: SoundGroup? = nil
local uiGroup: SoundGroup? = nil
local muffleEq: EqualizerSoundEffect? = nil
local loops: { [string]: Sound } = {}
local targets: { [string]: number } = {}
local speeds: { [string]: number } = {}
local snapshot: GameState.Snapshot? = nil
local inside = false
local lastInsideCheck = 0
local zone = "Outside"
local zones: { BasePart } = {}
local musicState: MusicState = "none"
local fear = 0
-- Aviso de ameaça 0..1 (ThreatWarningController): o Tung Tung chegando no mesmo andar.
local threat = 0
local silenceUntil = 0
local muffleOverride = 0
local nextCreakAt = 0
local nextHushAt = 0
local hushUntil = 0
local forestWasDark = false
local rng = Random.new()

local Preferences = require("@game/ReplicatedStorage/Shared/Game/HousePreferences")
local mixer: { [string]: SoundGroup } = {}
local LOOPS = {
	"AmbExterior",
	"AmbInterior",
	"WindInterior",
	"Machinery",
	"Music",
	"MusicTension",
	"MusicChase",
	"MusicRelief",
	"Heartbeat",
	"Whisper",
}

local function getGroup(): SoundGroup
	assert(group, "[AudioController] used before Init")
	return group
end

local function applyClip(sound: Sound, clipName: string)
	local clip = Audio[clipName]
	assert(clip, `[AudioController] unknown clip "{clipName}"`)
	sound.SoundId = clip.id
	sound.Volume = clip.volume
	sound.PlaybackSpeed = clip.speed or 1
	if clip.region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(clip.region[1], clip.region[2])
	end
end

local function make(name: string, clipName: string, parent: Instance, looped: boolean, ui: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	applyClip(sound, clipName)
	sound.Looped = looped
	sound.SoundGroup = if ui then uiGroup else mixer[Preferences.category(clipName)] or getGroup()
	sound.Parent = parent
	return sound
end

local function creatureRoot(): BasePart?
	local model = workspace:FindFirstChild(Tags.CreatureModel)
	local root = model and model:FindFirstChild(Tags.CreatureRoot)
	return if root and root:IsA("BasePart") then root else nil
end

local function checkInside(position: Vector3): boolean
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	if not world then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { world }
	params.RespectCanCollide = true
	return workspace:Raycast(position, Vector3.new(0, 25, 0), params) ~= nil
end

local function zoneAt(position: Vector3): (string, string)
	if Config.House.Enabled then
		for _, room in House.Rooms do
			if
				room.id ~= "Exterior"
				and math.abs(position.Y - (room.y + 5)) <= 8
				and math.abs(position.X - room.x) <= 18
				and math.abs(position.Z - room.z) <= 16
			then
				local reverb = if room.y < 0 then "StoneRoom" elseif room.id == "Bath" then "Bathroom" else "Room"
				return room.id, reverb
			end
		end
		return "Hall", "Hallway"
	end
	for _, part in zones do
		local p = part.CFrame:PointToObjectSpace(position)
		local half = part.Size / 2
		if math.abs(p.X) <= half.X and math.abs(p.Z) <= half.Z and math.abs(p.Y) <= half.Y + 2 then
			return (part:GetAttribute("Room") :: string?) or part.Name,
				(part:GetAttribute("Reverb") :: string?) or "Room"
		end
	end
	return "Outside", "Plain"
end

local function setReverb(name: string)
	local ok, value = pcall(function()
		return (Enum.ReverbType :: any)[name]
	end)
	if ok and value and SoundService.AmbientReverb ~= value then
		SoundService.AmbientReverb = value
	end
end

local AudioController = {
	Name = "AudioController",
}

-- Som 2D de uma vez. `ui` = fora do abafamento (interface/stingers).
function AudioController.play(clipName: string, volumeScale: number?, speed: number?, ui: boolean?): Sound
	local sound = make(clipName, clipName, SoundService, false, ui)
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
	sound.RollOffMaxDistance = if clipName == "CreakWood" or clipName == "CreakMetal" then 38 else 90
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

-- Som 3D numa posição do mundo (cria um ponto invisível que some ao terminar).
function AudioController.playAtPosition(
	clipName: string,
	position: Vector3,
	volumeScale: number?,
	speed: number?
): Sound
	local anchor = Instance.new("Part")
	anchor.Name = "SoundPoint"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = workspace
	local sound = AudioController.playAt(clipName, anchor, volumeScale, speed)
	sound.Destroying:Once(function()
		-- Destroying ocorre antes de terminar a remoção do filho. Destruir o pai aqui
		-- reentrava no mesmo Sound e disparava "Parent property is locked".
		task.defer(function()
			if anchor.Parent then
				anchor:Destroy()
			end
		end)
	end)
	return sound
end

-- Loop 3D controlado por quem chamou (ex.: rosnado de perseguição na criatura).
function AudioController.loopAt(clipName: string, parent: Instance): Sound
	local sound = make(clipName, clipName, parent, true)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 8
	sound.RollOffMaxDistance = if clipName == "CreakWood" or clipName == "CreakMetal" then 38 else 90
	return sound
end

-- Aplica o clip (id, volume, velocidade, trecho) a um Sound existente.
function AudioController.configure(sound: Sound, clipName: string)
	applyClip(sound, clipName)
	sound.SoundGroup = getGroup()
end

function AudioController.isInside(): boolean
	return inside
end

-- Sala atual (id do Layout) ou "Outside".
function AudioController.zone(): string
	return zone
end

function AudioController.setMusicState(state: MusicState)
	musicState = state
end

function AudioController.musicState(): MusicState
	return musicState
end

-- Ameaça 0..1 (ThreatWarningController): puxa o batimento para cima e acelera.
function AudioController.setThreat(value: number)
	threat = math.clamp(value, 0, 1)
end

-- Velocidade atual do batimento (1 = 96 bpm), para sincronizar a vinheta.
function AudioController.heartbeatSpeed(): number
	local loop = loops.Heartbeat
	return if loop then loop.PlaybackSpeed / math.max(speeds.Heartbeat, 1e-3) else 1
end

function AudioController.setFear(value: number)
	fear = math.clamp(value, 0, 1)
end

-- Corta a mixagem por `duration` s (silêncio antes de um susto).
function AudioController.silence(duration: number)
	silenceUntil = math.max(silenceUntil, os.clock() + duration)
end

-- Abafamento extra por `duration` s (ex.: depois de um impacto forte).
function AudioController.muffle(duration: number)
	muffleOverride = math.max(muffleOverride, os.clock() + duration)
end

function AudioController.debugState(): { [string]: any }
	local volumes = {}
	for name, sound in loops do
		volumes[name] = math.floor(sound.Volume * 100 + 0.5) / 100
	end
	return {
		zone = zone,
		inside = inside,
		music = musicState,
		reverb = SoundService.AmbientReverb.Name,
		muffle = if muffleEq then muffleEq.HighGain else 0,
		silenced = os.clock() < silenceUntil,
		hush = os.clock() < hushUntil,
		volumes = volumes,
	}
end

function AudioController.Init()
	local g = Instance.new("SoundGroup")
	g.Name = "Lofi"
	g.Volume = 1
	local eq = Instance.new("EqualizerSoundEffect")
	eq.Name = "Lofi"
	eq.HighGain = -9
	eq.MidGain = -1
	eq.LowGain = 1
	eq.Priority = 1
	eq.Parent = g
	local muffle = Instance.new("EqualizerSoundEffect")
	muffle.Name = "Muffle"
	muffle.HighGain = 0
	muffle.MidGain = 0
	muffle.LowGain = 0
	muffle.Priority = 2
	muffle.Parent = g
	local compressor = Instance.new("CompressorSoundEffect")
	compressor.Threshold = -14
	compressor.Ratio = 3
	compressor.Attack = 0.01
	compressor.Release = 0.2
	compressor.Priority = 3
	compressor.Parent = g
	g.Parent = SoundService
	group = g
	muffleEq = muffle

	local ui = Instance.new("SoundGroup")
	ui.Name = "Ui"
	ui.Volume = 1
	ui.Parent = SoundService
	uiGroup = ui
	SoundService.AmbientReverb = Enum.ReverbType.StoneCorridor

	for _, category in { "music", "effects", "breathing", "ambient" } do
		local channel = Instance.new("SoundGroup")
		channel.Name = category
		channel.Parent = g
		mixer[category] = channel
		local function update()
			channel.Volume = tonumber(player:GetAttribute("Mix_" .. category)) or 1
		end
		player:GetAttributeChangedSignal("Mix_" .. category):Connect(update)
		update()
	end
	local function master()
		g.Volume = tonumber(player:GetAttribute("Mix_master")) or 1
		ui.Volume = g.Volume
	end
	player:GetAttributeChangedSignal("Mix_master"):Connect(master)
	master()
	for _, name in LOOPS do
		local sound = make(name, name, SoundService, true)
		targets[name] = 0
		speeds[name] = sound.PlaybackSpeed
		sound.Volume = 0
		loops[name] = sound
	end
end

function AudioController.Start()
	local function spatial(instance: Instance)
		if instance:IsA("Sound") and not instance.SoundGroup then
			instance.SoundGroup = mixer.effects
		end
	end
	for _, instance in workspace:GetDescendants() do
		spatial(instance)
	end
	workspace.DescendantAdded:Connect(spatial)

	for _, sound in loops do
		sound:Play()
	end

	-- Sons 3D do mundo (servidor) também passam pelo filtro lo-fi.
	local function adopt(instance: Instance)
		if instance:IsA("Sound") and not instance.SoundGroup then
			instance.SoundGroup = mixer.effects
		end
	end
	task.spawn(function()
		local world = workspace:WaitForChild(Tags.WorldFolder, 30)
		if world then
			for _, d in world:GetDescendants() do
				adopt(d)
			end
			world.DescendantAdded:Connect(adopt)
			if Config.House.Enabled then
				return -- usa o catálogo da casa em vez das zonas industriais antigas.
			end
			local zoneFolder = world:WaitForChild("Features", 30)
			zoneFolder = zoneFolder and zoneFolder:WaitForChild("Zones", 30)
			if zoneFolder then
				for _, child in zoneFolder:GetChildren() do
					if child:IsA("BasePart") then
						table.insert(zones, child)
					end
				end
			end
		end
	end)

	GameState.observe(function(next: GameState.Snapshot)
		local previous = snapshot
		snapshot = next
		if previous == nil then
			return
		end
		if next.creatureActive and not previous.creatureActive and next.phase == "Playing" then
			AudioController.play("StingerAwaken", 1, nil, true)
		end
		if next.phase ~= previous.phase then
			if next.phase == "Lost" then
				AudioController.play("StingerCapture", 1, nil, true)
				AudioController.play("Roar", 1.1, 0.8, true)
			elseif next.phase == "Won" then
				AudioController.play("StingerWin", 1, nil, true)
			elseif next.phase == "Intro" then
				silenceUntil = 0
				muffleOverride = 0
				musicState = "none"
				nextHushAt, hushUntil, nextCreakAt = 0, 0, 0
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
		local position = camera.CFrame.Position
		local world = workspace:FindFirstChild(Tags.WorldFolder)
		local forest = world ~= nil and world:GetAttribute("ForestActive") == true
		local forestDark = forest and world ~= nil and world:GetAttribute("ForestBlackout") == true
		if forestDark and not forestWasDark and s.phase == "Playing" then
			AudioController.silence(2.2)
			AudioController.playAtPosition("DoorBang", position + camera.CFrame.RightVector * 20, 0.6, 0.65)
		end
		forestWasDark = forestDark
		if now - lastInsideCheck > 0.3 then
			lastInsideCheck = now
			inside = checkInside(position)
			local room, reverb = zoneAt(position)
			zone = if inside then room else "Outside"
			setReverb(if inside then reverb else "Plain")
		end

		local playing = s.phase == "Playing" or s.phase == "Intro"
		local root = creatureRoot()
		local distance = if root and s.creatureActive then (root.Position - position).Magnitude else math.huge
		local near = math.clamp((32 - distance) / 32, 0, 1)
		local silenced = now < silenceUntil
		local hidden = player:GetAttribute("Hidden")
		local isHidden = type(hidden) == "string" and hidden ~= ""

		targets.AmbExterior = if playing then (if inside then 0.05 else Audio.AmbExterior.volume) else 0.03
		targets.AmbInterior = if playing and inside then Audio.AmbInterior.volume else 0
		targets.WindInterior = if playing and inside then Audio.WindInterior.volume * (1 + fear * 0.5) else 0
		targets.Machinery = if playing and s.powerOn and not forest then Audio.Machinery.volume else 0

		local music = musicState
		local inPlay = Presentation.playing(s.phase, player:GetAttribute("CampaignStatus") :: string?)
		-- Pausas espaçadas da ambiência; passos e perseguição continuam audíveis.
		if inPlay and inside and music == "calm" and near == 0 then
			if nextHushAt == 0 then
				nextHushAt = now + rng:NextNumber(18, 32)
			elseif now >= nextHushAt then
				hushUntil = now + rng:NextNumber(3, 5)
				nextHushAt = now + rng:NextNumber(28, 46)
			end
		else
			hushUntil, nextHushAt = 0, 0
		end
		local hush = now < hushUntil
		targets.Music = if inPlay and music == "calm" and not forest then Audio.Music.volume else 0
		targets.MusicTension = if inPlay and music == "tension"
			then Audio.MusicTension.volume * (0.7 + near * 0.6)
			else 0
		if forest and inPlay and music ~= "chase" and not forestDark then
			targets.MusicTension = math.max(targets.MusicTension, Audio.MusicTension.volume * 0.5)
		end
		targets.MusicChase = if inPlay and music == "chase" then Audio.MusicChase.volume else 0
		targets.MusicRelief = if inPlay and music == "relief" then Audio.MusicRelief.volume else 0

		-- Batimento: medo + proximidade. Sussurros só com medo muito alto.
		local beat = math.clamp(math.max(fear * 0.7 + near * 0.35, threat * 0.9), 0, 1)
		targets.Heartbeat = if inPlay then math.min(1, beat * 0.7 + threat * 0.35) else 0
		loops.Heartbeat.PlaybackSpeed = speeds.Heartbeat * (0.85 + beat * 0.6 + threat * 0.5)
		targets.Whisper = if inPlay and fear > 0.72 then Audio.Whisper.volume * (fear - 0.72) / 0.28 else 0

		for name, sound in loops do
			local target = targets[name]
			if hush and (name == "Music" or name == "AmbInterior" or name == "WindInterior") then
				target *= 0.18
			end
			if silenced and name ~= "Heartbeat" then
				target = 0
			end
			local rate = if silenced then 6 elseif name == "MusicChase" and target > sound.Volume then 3 else 1.2
			sound.Volume += (target - sound.Volume) * math.min(1, dt * rate)
		end

		-- Abafamento: escondido no armário, pânico ou impacto recente.
		local eq = muffleEq
		if eq then
			local amount = 0
			if isHidden then
				amount = 1
			elseif fear > 0.82 then
				amount = (fear - 0.82) / 0.18 * 0.7
			end
			if now < muffleOverride then
				amount = math.max(amount, 0.8)
			end
			eq.HighGain += (-34 * amount - eq.HighGain) * math.min(1, dt * 4)
			eq.MidGain += (-10 * amount - eq.MidGain) * math.min(1, dt * 4)
		end

		-- Rangidos ocasionais do prédio (3D, perto do jogador, nunca durante silêncio).
		if inPlay and inside and now >= nextCreakAt and not silenced then
			nextCreakAt = now + rng:NextNumber(14, 30)
			local offset = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(3, 8), rng:NextNumber(-14, 14))
			local clip = if Config.House.Enabled or zone == "Office" then "CreakWood" else "CreakMetal"
			local sound = AudioController.playAtPosition(clip, position + offset, rng:NextNumber(0.5, 0.9))
			sound.PlaybackSpeed = rng:NextNumber(0.8, 1.1)
			sound.TimePosition = 0
			task.delay(rng:NextNumber(1.6, 3), function()
				if sound.Parent then
					sound:Stop()
					sound:Destroy()
				end
			end)
		end
	end)
end

return AudioController
