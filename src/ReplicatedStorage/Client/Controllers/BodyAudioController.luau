--!strict
--[[
	Sons do corpo do jogador (cliente):
	- Passos por material do chão: concreto, madeira, metal e água (poças), com variação de
	  amostra/tom/volume e cadência pela distância andada (agachado é mais quieto e espaçado).
	  Os passos padrão do Roblox são silenciados.
	- Respiração: calma (quase nada), ofegante (exaustão) e com medo; o ritmo acelera com a
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
local BREATHS = { "Breath1", "Breath2", "Breath3", "Breath4" }

local phase: GameState.Phase = "Loading"
local stride = 0
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

local function breathe(motion: CharacterController.Motion, now: number)
	if now < nextBreathAt then
		return
	end
	local hidden = isHidden()
	if holding then
		nextBreathAt = now + 0.3
		return
	end
	-- Intensidade: o maior entre exaustão e medo (escondido o medo pesa mais).
	local intensity = math.max(
		tonumber(player:GetAttribute("BreathIntensity")) or 0,
		motion.exhaustion,
		(fear - 0.25) / 0.75 * (if hidden then 1.2 else 1)
	)
	if intensity <= 0.05 then
		nextBreathAt = now + 1
		return
	end
	intensity = math.clamp(intensity, 0, 1)
	breathIndex = breathIndex % #BREATHS + 1
	AudioController.play(BREATHS[breathIndex], 0.25 + intensity * 0.75, rng:NextNumber(1.05, 1.2) + intensity * 0.15)
	-- Intervalo entre respirações: 3.2 s (leve) até 0.75 s (pânico/ofegante).
	nextBreathAt = now + (3.2 - intensity * 2.45) * rng:NextNumber(0.9, 1.1)
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
			AudioController.play("Breath2", 0.6, 0.9)
			nextBreathAt = os.clock() + 1.2
		elseif now then
			AudioController.play("Breath4", 0.4, 1.3)
		end
		holding = now
	end)
	player:GetAttributeChangedSignal("Gasps"):Connect(function()
		local count = (player:GetAttribute("Gasps") :: number?) or 0
		if count > gasps then
			AudioController.play("Gasp", 1, 1)
			nextBreathAt = os.clock() + 1.6
		end
		gasps = count
	end)

	RunService.RenderStepped:Connect(function(dt: number)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or (phase ~= "Playing" and phase ~= "Intro") then
			return
		end
		local motion = CharacterController.getMotion()
		local now = os.clock()
		if motion.grounded and not motion.hidden and motion.speed > 1 then
			stride += motion.speed * dt
			local length = if motion.stance == "Crouch" then 2.7 elseif motion.sprinting then 5.2 else 3.9
			if stride >= length then
				stride = 0
				step(motion, root)
			end
		else
			stride = math.min(stride, 1.5)
		end
		if phase == "Playing" then
			breathe(motion, now)
		end
	end)
end

return BodyAudioController
