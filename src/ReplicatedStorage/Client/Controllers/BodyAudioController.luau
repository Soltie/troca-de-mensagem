--!strict
--[[
	Sons do corpo do jogador (cliente):
	- Passos por material do chão: concreto, madeira, metal e água (poças), com variação de
	  amostra/tom/volume e cadência pela distância andada (agachado é mais quieto e espaçado).
	  Os passos padrão do Roblox são silenciados.
	- Respiração: uma voz por vez; calmo = silêncio, ofegante (cansaço) e com medo; o ritmo acelera com a
	  intensidade. Escondido e prendendo a respiração: silêncio; soltar = expiração; arquejo
	  forçado quando o fôlego acaba.
	- Pouso: baque com volume pela queda.
	Sons são locais (só o jogador ouve); o barulho que o Vigia "ouve" é decidido no servidor.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local CharacterController = require("./CharacterController")

export type Surface = "concrete" | "wood" | "metal" | "water"

local player = Players.LocalPlayer
local rng = Random.new()

local STEP_CLIPS: { [Surface]: string } = {
	concrete = "StepConcrete",
	wood = "StepWood",
	metal = "StepMetal",
	water = "StepWater",
}
local MATERIALS: { [Enum.Material]: Surface } = {
	[Enum.Material.Wood] = "wood",
	[Enum.Material.WoodPlanks] = "wood",
	[Enum.Material.DiamondPlate] = "metal",
	[Enum.Material.Metal] = "metal",
	[Enum.Material.CorrodedMetal] = "metal",
	[Enum.Material.Foil] = "metal",
	[Enum.Material.Water] = "water",
}
local SOFT: { [Enum.Material]: boolean } = {
	[Enum.Material.Fabric] = true,
	[Enum.Material.Carpet] = true,
	[Enum.Material.Grass] = true,
	[Enum.Material.LeafyGrass] = true,
	[Enum.Material.Mud] = true,
	[Enum.Material.Ground] = true,
}
local BREATHS = { "Breath1", "Breath2", "Breath3", "Breath4" }

local phase: GameState.Phase = "Loading"
local leftFoot = false
local nextBreathAt = 0
local breathIndex = 1
local fear = 0
local lastSurface: Surface = "concrete"
local puddles: { BasePart } = {}
local holding = false
local gasps = 0

local function isHidden(): boolean
	local hidden = player:GetAttribute("Hidden")
	return type(hidden) == "string" and hidden ~= ""
end

local function inPuddle(position: Vector3): boolean
	for _, puddle in puddles do
		if puddle.Parent then
			local p = puddle.CFrame:PointToObjectSpace(position)
			if
				math.abs(p.X) <= puddle.Size.X / 2 + 0.3
				and math.abs(p.Z) <= puddle.Size.Z / 2 + 0.3
				and math.abs(p.Y) < 4
			then
				return true
			end
		end
	end
	return false
end

local function surfaceAt(motion: CharacterController.Motion, root: BasePart): Surface
	if inPuddle(root.Position - Vector3.new(0, root.Size.Y / 2 + motion.standHipHeight, 0)) then
		return "water"
	end
	local part = motion.floorPart
	if part then
		local tagged = part:GetAttribute("Surface")
		if tagged == "wood" or tagged == "metal" or tagged == "water" or tagged == "concrete" then
			return tagged :: Surface
		end
	end
	local material = motion.floorMaterial
	if material and MATERIALS[material] then
		return MATERIALS[material]
	end
	return "concrete"
end

local function step(motion: CharacterController.Motion, root: BasePart)
	local surface: Surface = surfaceAt(motion, root)
	lastSurface = surface
	leftFoot = not leftFoot
	local loudness = if motion.stance == "Crouch" then 0.4 elseif motion.sprinting then 1.15 else 0.8
	local pitch: number = rng:NextNumber(0.92, 1.08) * (if leftFoot then 1 else 0.96)
	if surface == "metal" then
		pitch *= 0.85
	end
	-- Tapete e grama abafam o passo (mais grave e baixo).
	if SOFT[motion.floorMaterial :: any] then
		loudness *= 0.5
		pitch *= 0.85
	end
	AudioController.play(STEP_CLIPS[surface], loudness * rng:NextNumber(0.85, 1.05), pitch :: number)
	-- Madeira velha range de vez em quando.
	if surface == "wood" and rng:NextNumber() < 0.12 then
		local creak = AudioController.play("CreakWood", 0.35 * loudness, rng:NextNumber(0.9, 1.15))
		creak.TimePosition = rng:NextNumber(0, 10)
		task.delay(0.6, function()
			if creak.Parent then
				creak:Destroy()
			end
		end)
	end
end

--[[
	Respiração unificada: UMA voz por vez (nunca dois áudios sobrepostos). Toda respiração passa por
	`voice()`, que corta a anterior com um fade curto. Calmo = silêncio; o som só aparece ofegante
	(cansaço) ou com medo de verdade, baixo e "dentro da cabeça".
]]
local voiceSound: Sound? = nil
local lastScareAt = -math.huge

local function fadeOut(sound: Sound, time: number)
	local start = sound.Volume
	task.spawn(function()
		local t = 0
		while t < time and sound.Parent do
			t += task.wait()
			sound.Volume = start * (1 - math.min(t / time, 1))
		end
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

local function voice(clip: string, volume: number, pitch: number): Sound
	local previous = voiceSound
	if previous and previous.Parent then
		fadeOut(previous, 0.12)
	end
	local sound = AudioController.play(clip, volume, pitch)
	voiceSound = sound
	return sound
end

local function speaking(): boolean
	local sound = voiceSound
	return sound ~= nil and sound.Parent ~= nil and sound.IsPlaying
end

local function breathe(motion: CharacterController.Motion, now: number)
	if now < nextBreathAt or speaking() then
		return
	end
	if holding then
		nextBreathAt = now + 0.3
		return
	end
	-- Cansaço (corrida/fôlego) e medo; escondido o medo pesa um pouco mais. Abaixo de 0,3 = calmo (silêncio).
	local tired = math.max(tonumber(player:GetAttribute("BreathIntensity")) or 0, motion.exhaustion)
	local scared = (fear - 0.45) / 0.55 * (if isHidden() then 1.15 else 1)
	local intensity = math.clamp(math.max(tired, scared), 0, 1)
	if intensity < 0.3 then
		nextBreathAt = now + 0.8
		return
	end
	-- Sem repetir a mesma amostra duas vezes seguidas.
	local index = rng:NextInteger(1, #BREATHS - 1)
	if index >= breathIndex then
		index += 1
	end
	breathIndex = index
	local panting = tired >= scared
	local volume = if panting then 0.2 + intensity * 0.35 else 0.14 + intensity * 0.26
	local pitch = (if panting then 1.02 else 0.94) + intensity * 0.06 + rng:NextNumber(-0.03, 0.03)
	local sound = voice(BREATHS[index], volume, pitch)
	-- Pausa depois que a respiração termina: 2,2 s (leve) até 0,35 s (ofegante/pânico).
	local gap = (2.2 - intensity * 1.85) * rng:NextNumber(0.9, 1.1)
	nextBreathAt = math.huge
	sound.Destroying:Once(function()
		nextBreathAt = math.min(nextBreathAt, os.clock() + gap)
	end)
end

-- Silencia os sons padrão do personagem (passos de plástico etc.).
local function muteDefaults(character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local function mute(child: Instance)
		if child:IsA("Sound") then
			child.Volume = 0
			child:GetPropertyChangedSignal("Volume"):Connect(function()
				if child.Volume ~= 0 then
					child.Volume = 0
				end
			end)
		end
	end
	for _, child in root:GetChildren() do
		mute(child)
	end
	root.ChildAdded:Connect(mute)
end

local BodyAudioController = {
	Name = "BodyAudioController",
}

function BodyAudioController.setFear(value: number)
	fear = math.clamp(value, 0, 1)
end

-- Susto: puxa o ar uma vez (no máximo a cada 8 s), cortando a respiração que estiver tocando.
function BodyAudioController.scare()
	local now = os.clock()
	if now - lastScareAt < 8 or holding or phase ~= "Playing" then
		return
	end
	lastScareAt = now
	voice("Breath4", 0.4, 1.3)
	nextBreathAt = now + 1.4
end

function BodyAudioController.lastSurface(): Surface
	return lastSurface
end

function BodyAudioController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)
	if player.Character then
		task.spawn(muteDefaults, player.Character)
	end
	player.CharacterAdded:Connect(muteDefaults)

	-- Poças: as do mapa (nome "Puddle") e as das novidades.
	task.spawn(function()
		local world = workspace:WaitForChild(Tags.WorldFolder, 30)
		if not world then
			return
		end
		task.wait(1)
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") and d.Name == "Puddle" then
				table.insert(puddles, d)
			end
		end
	end)
	local _ = CollectionService

	CharacterController.onLanded(function(intensity: number)
		AudioController.play("Land", 0.4 + intensity * 0.8, 0.85 + (1 - intensity) * 0.2)
	end)

	player:GetAttributeChangedSignal("HoldBreath"):Connect(function()
		local now = player:GetAttribute("HoldBreath") == true
		if holding and not now and isHidden() then
			-- Soltou: expiração longa e tremida.
			voice("Breath2", 0.45, 0.9)
			nextBreathAt = os.clock() + 1.2
		elseif now then
			voice("Breath4", 0.35, 1.3)
		end
		holding = now
	end)
	player:GetAttributeChangedSignal("Gasps"):Connect(function()
		local count = (player:GetAttribute("Gasps") :: number?) or 0
		if count > gasps then
			voice("Gasp", 0.85, 1)
			nextBreathAt = os.clock() + 1.6
		end
		gasps = count
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or phase ~= "Playing" then
			return
		end
		breathe(CharacterController.getMotion(), os.clock())
	end)
	-- Passos no mesmo relógio do balanço da câmera (CharacterController).
	CharacterController.onStep(function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (phase == "Playing" or phase == "Intro") then
			step(CharacterController.getMotion(), root)
		end
	end)
end

return BodyAudioController
