--!strict
--[[
	Perigos da floresta v2 (docs/FLORESTA_V2.md), no servidor:
	- Folhas secas (LeafZone): passo normal ou corrida em cima estala e faz barulho (o Tung Tung vem ver);
	  agachado passa em silêncio.
	- Corvos (Flock): quem chega perto (perto de verdade se estiver agachado) espanta o bando; eles grasnam,
	  levantam voo e o barulho entrega a posição.
	- Ponte (evento forest_bridge_fall, ao chegar do outro lado): o Tung Tung vem atrás pela ponte, as tábuas cedem
	  e ele cai no rio. Some por um tempo e volta pelo norte. A ponte não volta: ninguém retorna.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CreatureService = require("./CreatureService")

local ForestHazardService = {
	Name = "ForestHazardService",
}

local TICK = 0.15
local LEAF_COOLDOWN = 1.4
local CROW_RANGE, CROW_RANGE_CROUCH = 11, 4.5
local RETURN_AFTER = 22

local log = Logger.new("ForestHazardService")
local rng = Random.new()
local leafCooldown: { [Player]: number } = {}
local bridgeState: { [Instance]: string } = {}

local function sound(
	parent: Instance,
	clip: { id: string, volume: number },
	volume: number,
	speed: number?,
	from: number?
)
	local s = Instance.new("Sound")
	s.SoundId = clip.id
	s.Volume = clip.volume * volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = 140
	s.TimePosition = from or 0
	s.Parent = parent
	s:Play()
	task.delay(6, function()
		s:Destroy()
	end)
	return s
end

local function activeBodies(): { { player: Player, at: Vector3, crouch: boolean, speed: number } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local hidden = player:GetAttribute("Hidden")
		if
			body
			and body:IsA("BasePart")
			and player:GetAttribute("CampaignStatus") == "Active"
			and not (type(hidden) == "string" and hidden ~= "")
		then
			local v = body.AssemblyLinearVelocity
			table.insert(out, {
				player = player,
				at = body.Position,
				crouch = player:GetAttribute("Stance") == "Crouch",
				speed = Vector3.new(v.X, 0, v.Z).Magnitude,
			})
		end
	end
	return out
end

local function crunch(zone: BasePart, bodies)
	local now = os.clock()
	for _, b in bodies do
		local localP = zone.CFrame:PointToObjectSpace(b.at)
		if math.abs(localP.X) < zone.Size.X / 2 and math.abs(localP.Z) < zone.Size.Z / 2 and math.abs(localP.Y) < 6 then
			if not b.crouch and b.speed > 2.5 and now >= (leafCooldown[b.player] or 0) then
				leafCooldown[b.player] = now + LEAF_COOLDOWN
				sound(zone, Audio.LeavesCrunch, if b.speed > 12 then 1.4 else 1, rng:NextNumber(0.9, 1.15))
				CreatureService.makeNoise(b.at, if b.speed > 12 then 46 else 32)
			end
		end
	end
end

-- O bando levanta voo: sobe em espiral para longe batendo as asas e some.
local function scare(flock: Model, from: Vector3)
	flock:SetAttribute("Flown", true)
	local first = flock:FindFirstChildWhichIsA("Model")
	local anchor = first and first:FindFirstChild("Body")
	if anchor then
		sound(anchor, Audio.BirdsTakeoff, 1.2, 1)
		sound(anchor, Audio.CrowCaw, 1.3, rng:NextNumber(0.95, 1.1), rng:NextNumber(2, 40))
	end
	CreatureService.makeNoise(from, 48)
	for index, bird in flock:GetChildren() do
		if not bird:IsA("Model") then
			continue
		end
		task.spawn(function()
			local start = bird:GetPivot()
			local away = (start.Position - from) * Vector3.new(1, 0, 1)
			away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
			away = CFrame.Angles(0, rng:NextNumber(-0.7, 0.7), 0):VectorToWorldSpace(away)
			local t0 = os.clock()
			local delay = index * 0.12
			while bird.Parent and os.clock() - t0 < 3.2 do
				local t = math.max(0, os.clock() - t0 - delay)
				local position = start.Position + away * (t * 14) + Vector3.new(0, t * t * 6 + t * 5, 0)
				bird:PivotTo(CFrame.lookAt(position, position + away + Vector3.new(0, 0.4, 0)))
				-- Asas batendo.
				local flap = math.sin(t * 28) * 0.9
				for _, wing in bird:GetChildren() do
					local side = wing:GetAttribute("Side")
					if wing:IsA("BasePart") and type(side) == "number" then
						local base = bird:GetPivot()
						wing.CFrame = base * CFrame.new(side * 0.45, 0.75, 0.05) * CFrame.Angles(0, 0, side * flap)
					end
				end
				task.wait()
			end
			bird:Destroy()
		end)
	end
end

-- Ponte: o Tung Tung atravessa atrás do grupo e cai quando chega no meio.
local function collapse(forest: Instance, map: ForestMaps.Map)
	local r = map.ravine
	local model = forest:FindFirstChild("RopeBridge")
	if not r or not model then
		return
	end
	bridgeState[forest] = "fallen"
	local planks = model:FindFirstChild("Planks")
	if planks then
		for _, plank in planks:GetChildren() do
			if plank:IsA("BasePart") then
				task.delay(math.abs(plank.Position.Z - (r.z0 + r.z1) / 2) * 0.02, function()
					plank.Anchored = false
					-- Colide para empilhar no rio (sem colisão atravessava o terreno e sumia no vazio).
					plank.CanCollide = true
					plank.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-2, 2), 0)
					plank.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-5, 5), 0, rng:NextNumber(-5, 5))
				end)
			end
		end
	end
	for _, rope in model:GetChildren() do
		if rope.Name == "BridgeRope" then
			rope:Destroy()
		end
	end
	local center = Vector3.new(0, 0, (r.z0 + r.z1) / 2)
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.Transparency = true, false, false, 1
	anchor.Size = Vector3.one
	anchor.Position = center
	anchor.Parent = model
	sound(anchor, Audio.BeamCrack, 1.6, 0.8)
	-- Tranco na tela de quem está perto (ForestFxController).
	forest:SetAttribute("ShakeAt", center)
	forest:SetAttribute("ShakeSerial", ((forest:GetAttribute("ShakeSerial") :: number?) or 0) + 1)
	sound(anchor, Audio.WoodSplinter, 1.4, 0.9)
	-- Cabeceiras fechadas: a ponte não existe mais.
	for _, z in { r.z0 - 2, r.z1 + 2 } do
		local gate = Instance.new("Part")
		gate.Name = "BridgeGone"
		gate.Anchored, gate.CanCollide, gate.CanQuery, gate.Transparency = true, true, true, 1
		gate.Size = Vector3.new(r.bridgeWidth + 3, 10, 1)
		gate.Position = Vector3.new(0, 5, z)
		gate.Parent = model
	end
	-- O Tung Tung cai até o rio.
	local feet = CreatureService.feetPosition() or center
	CreatureService.setFrozen(true)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.9 do
			local k = (os.clock() - t0) / 0.9
			CreatureService.debugPlace(Vector3.new(feet.X, feet.Y - (r.depth - 2) * k * k, feet.Z))
			task.wait()
		end
		local splash = Instance.new("Part")
		splash.Anchored, splash.CanCollide, splash.CanQuery, splash.Transparency = true, false, false, 1
		splash.Size = Vector3.new(6, 1, 6)
		splash.Position = Vector3.new(feet.X, -r.depth + 3, feet.Z)
		splash.Parent = model
		sound(splash, Audio.BigSplash, 2, 0.8)
		forest:SetAttribute("ShakeAt", splash.Position)
		forest:SetAttribute("ShakeSerial", ((forest:GetAttribute("ShakeSerial") :: number?) or 0) + 1)
		local spray = Instance.new("ParticleEmitter")
		spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
		spray.Color = ColorSequence.new(Color3.fromRGB(200, 220, 230))
		spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
		spray.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		spray.Speed = NumberRange.new(10, 22)
		spray.SpreadAngle = Vector2.new(35, 35)
		spray.EmissionDirection = Enum.NormalId.Top
		spray.Lifetime = NumberRange.new(0.8, 1.6)
		spray.Acceleration = Vector3.new(0, -30, 0)
		spray.Rate = 0
		spray.Parent = splash
		spray:Emit(60)
		-- Escondido no fundo do rio; volta pelo norte depois de um tempo.
		CreatureService.debugPlace(Vector3.new(feet.X, -r.depth - 20, feet.Z))
		task.wait(RETURN_AFTER)
		if bridgeState[forest] ~= "fallen" or not forest.Parent then
			return
		end
		CreatureService.reset()
		CreatureService.activate(Vector3.new(rng:NextNumber(-20, 20), 0, 905))
		log.info("came back from the river")
	end)
end

local function stepBridge(forest: Instance, map: ForestMaps.Map)
	local r = map.ravine
	if not r or bridgeState[forest] ~= nil or forest:GetAttribute("LastEvent") ~= "forest_bridge_fall" then
		return
	end
	-- Cena roteirizada: ele surge na cabeceira sul e dispara pela ponte atrás de quem passou; no meio, a ponte cede.
	bridgeState[forest] = "chasing"
	if not CreatureService.isActive() then
		CreatureService.activate(Vector3.new(0, 0, r.z0 - 18))
	end
	CreatureService.setFrozen(true)
	local north = Vector3.zAxis
	local start = Vector3.new(0, 0, r.z0 - 18)
	local breakAt = r.z0 + 8
	task.spawn(function()
		CreatureService.scriptPlace(start, north)
		-- Um instante parado olhando a ponte (dá tempo de quem está do outro lado virar e ver).
		task.wait(1.2)
		local t0 = os.clock()
		local speed = 17
		while forest.Parent and bridgeState[forest] == "chasing" do
			local z = start.Z + (os.clock() - t0) * speed
			if z >= breakAt then
				collapse(forest, map)
				return
			end
			CreatureService.scriptPlace(Vector3.new(0, 0, z), north)
			task.wait()
		end
	end)
end

local function step()
	local campaign = game:GetService("ReplicatedStorage"):FindFirstChild("CampaignState")
	if not campaign or campaign:GetAttribute("Phase") == "Intermission" then
		return
	end
	local world = workspace:FindFirstChild("CursedHouse")
	local forest = world and world:FindFirstChild("Forest")
	if not forest or forest:GetAttribute("ForestV2") ~= true then
		return
	end
	local chapter = forest:GetAttribute("Chapter")
	local map = if type(chapter) == "number" then ForestMaps.get(chapter) else nil
	if not map then
		return
	end
	local bodies = activeBodies()
	local leaves = forest:FindFirstChild("DryLeaves")
	if leaves then
		for _, zone in leaves:GetChildren() do
			if zone:IsA("BasePart") then
				crunch(zone, bodies)
			end
		end
	end
	local crows = forest:FindFirstChild("Crows")
	if crows then
		for _, flock in crows:GetChildren() do
			if flock:IsA("Model") and flock:GetAttribute("Flock") == true and flock:GetAttribute("Flown") ~= true then
				local pivot = flock:GetBoundingBox().Position
				for _, b in bodies do
					local d = (Vector3.new(b.at.X, 0, b.at.Z) - Vector3.new(pivot.X, 0, pivot.Z)).Magnitude
					if d < (if b.crouch then CROW_RANGE_CROUCH else CROW_RANGE) then
						scare(flock, b.at)
						break
					end
				end
			end
		end
	end
	stepBridge(forest, map)
end

function ForestHazardService.Start()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < TICK then
			return
		end
		clock = 0
		local ok: boolean, err: any = pcall(step)
		if not ok then
			log.warn("step failed: %s", tostring(err))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		leafCooldown[player] = nil
	end)
end

return ForestHazardService
