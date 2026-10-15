--!strict
--[[
	PropService: objetos que caem (balde, latas, garrafas, canos, extintor, caixa).

	Passar perto deles rápido (andando/correndo) derruba: física no servidor, som de impacto e
	BARULHO que atrai o Vigia. Agachado ou devagar não derruba. Limites contra spam:
	cada objeto cai uma vez por rodada (Cooldown entre quedas, se recolocado) e há um intervalo
	global entre barulhos (GlobalCooldown). Tudo volta ao lugar a cada rodada (reset).
]]

local Players = game:GetService("Players")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local FeatureBuilder = require("../World/FeatureBuilder")
local CreatureService = require("./CreatureService")
local WorldService = require("./WorldService")

local F = Config.Fallables
local TICK = 0.1
local log = Logger.new("PropService")

local lastNoiseAt = -math.huge
local lastFallAt: { [string]: number } = {}
local generation = 0

local function fall(item: FeatureBuilder.FallableHandle, from: Vector3)
	local now = os.clock()
	item.fallen = true
	lastFallAt[item.id] = now
	item.model:SetAttribute("Fallen", true)
	local primary = item.primary
	primary.Anchored = false
	pcall(function()
		primary:SetNetworkOwner(nil)
	end)
	-- Empurrão na direção de queda (e para longe de quem esbarrou) + giro.
	local away = primary.Position - from
	away = Vector3.new(away.X, 0, away.Z)
	local direction = item.fall + (if away.Magnitude > 0.1 then away.Unit * 0.6 else Vector3.zero)
	local mass = primary.AssemblyMass
	primary:ApplyImpulse((direction.Unit * 9 + Vector3.new(0, 4, 0)) * mass)
	primary:ApplyAngularImpulse(Vector3.new(direction.Z, 0, -direction.X) * 6 * mass)

	local myGeneration = generation
	task.delay(0.35, function()
		if myGeneration ~= generation then
			return
		end
		item.sound:Play()
		if now - lastNoiseAt >= F.GlobalCooldown then
			lastNoiseAt = now
			local p = primary.Position
			CreatureService.makeNoise(Vector3.new(p.X, 0, p.Z), F.NoiseRadius)
			log.info("%s fell (noise)", item.id)
		end
	end)
	-- Depois de assentar, volta a ficar ancorado onde parou (sem física rolando para sempre).
	task.delay(F.ResetAfter, function()
		if myGeneration == generation and item.fallen then
			primary.Anchored = true
		end
	end)
end

local function tick()
	if GameState.get("Phase") ~= "Playing" then
		return
	end
	local now = os.clock()
	for _, item in WorldService.features().fallables do
		if item.fallen or now - (lastFallAt[item.id] or -math.huge) < F.Cooldown then
			continue
		end
		local position = item.primary.Position
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and not root.Anchored then
				local delta = root.Position - position
				local flat = Vector3.new(delta.X, 0, delta.Z).Magnitude
				local velocity = root.AssemblyLinearVelocity
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if flat <= F.TriggerRadius and math.abs(delta.Y) < 6 and speed >= F.TriggerSpeed then
					fall(item, root.Position)
					break
				end
			end
		end
	end
end

local PropService = {
	Name = "PropService",
}

function PropService.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local ok, err = pcall(tick :: () -> any)
			if not ok then
				log.error("tick failed: %s", tostring(err))
			end
		end
	end)
	-- Nova rodada (Intro): tudo de volta ao lugar.
	GameState.observe(function(snapshot, changed)
		if changed == "Phase" and snapshot.phase == "Intro" then
			PropService.reset()
		end
	end)
end

function PropService.reset()
	generation += 1
	lastNoiseAt = -math.huge
	table.clear(lastFallAt)
	for _, item in WorldService.features().fallables do
		item.fallen = false
		item.primary.Anchored = true
		item.primary.AssemblyLinearVelocity = Vector3.zero
		item.primary.AssemblyAngularVelocity = Vector3.zero
		for part, home in item.home do
			part.CFrame = home
		end
		item.model:SetAttribute("Fallen", false)
	end
end

-- Depuração: derruba um objeto pelo id.
function PropService.debugFall(id: string): boolean
	for _, item in WorldService.features().fallables do
		if item.id == id and not item.fallen then
			fall(item, item.primary.Position - item.fall)
			return true
		end
	end
	return false
end

return PropService
