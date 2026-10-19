--!strict
--[[
	Corrida roteirizada da fuga (ideia M; regras em Shared/Game/EscapeRun, servidor em EscapeRunService). Desenha o
	que o servidor solta em Workspace.EscapeRun:
	- vigas (EscapeBeam*): pegam fogo, e ao bater no chão estalam, levantam poeira e sacodem a tela de quem está perto;
	- desabamento (atributo CollapseAt): pedaços do teto despencam na frente do desabamento, com estrondo e poeira,
	  e a tela treme mais quanto mais perto ele está.
]]

local RunService = game:GetService("RunService")

local EscapeRun = require("@game/ReplicatedStorage/Shared/Game/EscapeRun")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local SettingsController = require("./SettingsController")

local EscapeRunController = {
	Name = "EscapeRunController",
}

local FLAME = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local CEILING_Y = -1.5
local FLOOR_Y = -16

local beams: { [BasePart]: boolean } = {}
local collapseAt: number? = nil
local droppedUpTo = 0
local nextCrackAt = 0
local rng = Random.new()
local roar: Sound? = nil

local function soundAt(clip: string, position: Vector3, volume: number, speed: number?)
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = workspace.Terrain
	local sound = AudioController.playAt(clip, anchor, volume, speed)
	sound.RollOffMaxDistance = 120
	task.delay(8, function()
		anchor:Destroy()
	end)
end

local function shakeFrom(position: Vector3, strength: number, reach: number)
	local camera = workspace.CurrentCamera
	if not camera or not SettingsController.get("shake") then
		return
	end
	local distance = (camera.CFrame.Position - position).Magnitude
	if distance < reach then
		CameraController.addTrauma(strength * (1 - distance / reach))
	end
end

local function dust(position: Vector3, amount: number)
	local holder = Instance.new("Part")
	holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
	holder.Transparency = 1
	holder.Size = Vector3.new(6, 0.2, 6)
	holder.CFrame = CFrame.new(position)
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = ColorSequence.new(Color3.fromRGB(120, 110, 100))
	e.LightInfluence = 0.6
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 7) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(3, 8)
	e.SpreadAngle = Vector2.new(80, 80)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = holder
	e:Emit(amount)
	task.delay(4, function()
		holder:Destroy()
	end)
end

local function decorate(beam: BasePart)
	if beams[beam] then
		return
	end
	beams[beam] = true
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 9
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 10)
	fire.Parent = beam
	local flames = Instance.new("ParticleEmitter")
	flames.Texture = FLAME
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.EmissionDirection = Enum.NormalId.Top
	flames.LightEmission = 1
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(255, 70, 20))
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) })
	flames.Lifetime = NumberRange.new(0.4, 0.8)
	flames.Rate = 60
	flames.Speed = NumberRange.new(2, 5)
	flames.Parent = beam
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Range = 16
	glow.Brightness = 2.2
	glow.Parent = beam
	local landAt = beam:GetAttribute("LandAt")
	local wait = if type(landAt) == "number" then math.max(0, landAt - workspace:GetServerTimeNow()) else 0
	task.delay(wait, function()
		if not beam.Parent then
			return
		end
		-- Chão em chamas dos dois lados (a faixa que queima quem não pula).
		local band = Instance.new("Part")
		band.Name = "BurnBand"
		band.Anchored, band.CanCollide, band.CanQuery, band.CanTouch = true, false, false, false
		band.Transparency = 1
		band.Size = Vector3.new(beam.Size.X, 0.2, EscapeRun.BurnBand * 2)
		band.CFrame = CFrame.new(beam.Position.X, FLOOR_Y + 0.1, beam.Position.Z)
		band.Parent = beam
		local floorFlames = flames:Clone()
		floorFlames.Rate = 140
		floorFlames.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3), NumberSequenceKeypoint.new(1, 0.1) })
		floorFlames.Parent = band
		local embers = Instance.new("PointLight")
		embers.Color = Color3.fromRGB(255, 110, 30)
		embers.Range = 12
		embers.Brightness = 1.6
		embers.Parent = band
		soundAt("BeamCrack", beam.Position, 1.6)
		soundAt("WoodSplinter", beam.Position, 1.2, 0.8)
		dust(Vector3.new(beam.Position.X, FLOOR_Y + 0.3, beam.Position.Z), 40)
		shakeFrom(beam.Position, 0.7, 40)
	end)
end

-- Pedaço do teto despencando (física só no cliente; não bloqueia ninguém: o entulho sólido é do servidor).
local function chunk(position: Vector3)
	local piece = Instance.new("Part")
	piece.Name = "CollapseChunk"
	piece.Material = if rng:NextNumber() < 0.6 then Enum.Material.Slate else Enum.Material.Wood
	piece.Color = if piece.Material == Enum.Material.Slate
		then Color3.fromRGB(70, 66, 60)
		else Color3.fromRGB(44, 30, 22)
	piece.Size = Vector3.new(rng:NextNumber(1.5, 4), rng:NextNumber(0.6, 1.6), rng:NextNumber(1.5, 4))
	piece.CFrame = CFrame.new(position)
		* CFrame.Angles(rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi), rng:NextNumber(0, math.pi))
	piece.CanQuery, piece.CanTouch = false, false
	piece.CollisionGroup = "FireDebris"
	piece.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-3, 3), -rng:NextNumber(4, 10), rng:NextNumber(-3, 3))
	piece.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))
	piece.Parent = workspace
	task.delay(5, function()
		piece:Destroy()
	end)
end

local function update(dt: number)
	local folder = workspace:FindFirstChild("EscapeRun")
	if not folder then
		if next(beams) then
			table.clear(beams)
		end
		if collapseAt then
			collapseAt = nil
			if roar then
				roar:Destroy()
				roar = nil
			end
		end
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 10) == "EscapeBeam" then
			decorate(child)
		end
	end
	local at = folder:GetAttribute("CollapseAt")
	if type(at) ~= "number" then
		return
	end
	if collapseAt ~= at then
		collapseAt = at
		droppedUpTo = EscapeRun.Collapse.from - 2
		local x, y, z = EscapeRun.point(EscapeRun.Collapse.from)
		soundAt("BeamCrack", Vector3.new(x, y + 8, z), 2, 0.6)
		if roar then
			roar:Destroy()
		end
		roar = AudioController.play("AmbFireRoar", 1.4, 0.7)
	end
	local now = workspace:GetServerTimeNow()
	-- O servidor para o desabamento quando ele pega alguém (CollapseStop).
	local stop = folder:GetAttribute("CollapseStop")
	local limit = if type(stop) == "number" then stop else EscapeRun.Collapse.to
	local front = math.min(EscapeRun.collapseFront(now - at), limit)
	-- Teto caindo na frente do desabamento: dois pedaços a cada 2 studs.
	while droppedUpTo + 2 <= front and droppedUpTo < limit do
		droppedUpTo += 2
		local x, _, z = EscapeRun.point(droppedUpTo)
		for _ = 1, 2 do
			chunk(Vector3.new(x + rng:NextNumber(-6, 6), CEILING_Y - rng:NextNumber(0.5, 2), z + rng:NextNumber(-1, 1)))
		end
		if droppedUpTo % 6 == 0 then
			dust(Vector3.new(x, FLOOR_Y + 0.3, z), 20)
		end
	end
	local x, y, z = EscapeRun.point(front)
	local position = Vector3.new(x, y + 6, z)
	if front < limit then
		if now >= nextCrackAt then
			nextCrackAt = now + rng:NextNumber(0.3, 0.6)
			soundAt(
				if rng:NextNumber() < 0.5 then "BeamCrack" else "WoodSplinter",
				position,
				1.4,
				rng:NextNumber(0.7, 1)
			)
		end
		shakeFrom(position, dt * 2.2, 45)
	end
end

function EscapeRunController.Start()
	RunService.Heartbeat:Connect(update)
end

return EscapeRunController
