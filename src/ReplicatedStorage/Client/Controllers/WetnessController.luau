--!strict
--[[
	Corpos molhados pela chuva (só visual, no cliente; nada replica nem muda regra):
	- cada personagem encharca ao ar livre e seca devagar sob telhado (Weather.wetness, telhado por raycast);
	- molhado, pinga: gotinhas caem do corpo de todos e da lanterna na mão do jogador;
	- dentro de casa, quem está molhado deixa pegadas (o chão escurecido, inclusive sobre tapetes) que somem aos poucos
	  em ~40 s. O servidor guarda o mesmo rastro (FootprintService) e o Tung Tung pode segui-lo.
	Pegadas em pool fixo (MAX_PRINTS); gotinhas seguem o orçamento de partículas da qualidade visual.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Weather = require("@game/ReplicatedStorage/Shared/Game/Weather")
local Settings = require("./SettingsController")

local controller = { Name = "WetnessController" }

local MAX_PRINTS = 48
local PRINT_LIFE = Weather.FootprintLife
local DRIP = Color3.fromRGB(196, 206, 220)

type Body = {
	wet: number,
	outdoor: number,
	lastStep: Vector3?,
	left: boolean,
	drips: ParticleEmitter?,
	character: Model,
}
local bodies: { [Player]: Body } = {}
type Print = { part: BasePart, heel: BasePart, born: number, alpha: number }
local prints: { Print } = {}
local nextPrint = 1
local folder: Folder? = nil
local lampDrips: ParticleEmitter? = nil
local probeClock = 0
-- Chão: só o mundo da casa (sem personagens nem as próprias pegadas).
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include

local function dripEmitter(parent: Instance, spread: Vector3): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "WetDrips"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Size = NumberSequence.new(0.05)
	emitter.Squash = NumberSequence.new(1.2)
	emitter.Transparency = NumberSequence.new(0.35, 0.8)
	emitter.Color = ColorSequence.new(DRIP)
	emitter.LightInfluence = 0.8
	emitter.LightEmission = 0.1
	emitter.Rate = 0
	local attachment = Instance.new("Attachment")
	attachment.Name = "WetDripPoint"
	attachment.Parent = parent
	emitter.Parent = attachment
	-- A caixa do emissor acompanha a peça; `spread` limita a área de onde as gotas saem.
	attachment.Position = Vector3.new(0, -spread.Y / 2, 0)
	return emitter
end

-- Tapetes, capachos e passadeiras não respondem a raycast (CanQuery desligado): ficam numa lista própria.
local rugs: { BasePart } = {}
local rugsFrom: Instance? = nil
local function collectRugs(world: Instance)
	if rugsFrom == world then
		return
	end
	rugsFrom = world
	table.clear(rugs)
	for _, item in world:GetDescendants() do
		if
			item:IsA("BasePart")
			and not item.CanQuery
			and item.Transparency < 0.9
			and item.Size.Y <= 0.35
			and item.Size.X >= 1
			and item.Size.Z >= 1
			and math.abs(item.CFrame.UpVector.Y) > 0.98
		then
			table.insert(rugs, item)
		end
	end
end

-- Superfície onde o pé pisou: o tapete mais alto sob o ponto, senão o piso do raycast.
local function surfaceAt(at: Vector3): (number, Color3, boolean)
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), groundParams)
	local top = if hit then hit.Position.Y else at.Y
	local color = if hit then (hit.Instance :: BasePart).Color else Color3.fromRGB(60, 44, 32)
	local soft = hit ~= nil and (hit.Material == Enum.Material.Fabric or hit.Material == Enum.Material.Carpet)
	for _, rug in rugs do
		if rug.Parent then
			local p = rug.CFrame:PointToObjectSpace(at)
			local rugTop = rug.Position.Y + rug.Size.Y / 2
			if
				math.abs(p.X) <= rug.Size.X / 2
				and math.abs(p.Z) <= rug.Size.Z / 2
				and rugTop >= top - 0.05
				and rugTop <= top + 0.6
			then
				top, color = rugTop, rug.Color
				soft = rug.Material == Enum.Material.Fabric or rug.Material == Enum.Material.Carpet
			end
		end
	end
	return top, color, soft
end

local function footprint(at: Vector3, facing: Vector3, alpha: number, left: boolean)
	local parent = folder
	if not parent then
		return
	end
	local slot = prints[nextPrint]
	if not slot then
		-- Sola: frente oval e calcanhar separados, finos, como o piso escurecido pela água.
		local function piece(name: string, size: Vector3): BasePart
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Size = size
			local shape = Instance.new("SpecialMesh")
			shape.MeshType = Enum.MeshType.Sphere
			shape.Parent = part
			part.Parent = parent
			return part
		end
		slot = {
			part = piece("WetFootprint", Vector3.new(0.4, 0.012, 0.64)),
			heel = piece("WetFootprintHeel", Vector3.new(0.3, 0.012, 0.32)),
			born = 0,
			alpha = 0,
		}
		prints[nextPrint] = slot
	end
	nextPrint = nextPrint % MAX_PRINTS + 1
	-- Assenta logo acima da superfície real (tapete incluso): nada de brigar com a textura do capacho.
	local top, color, soft = surfaceAt(at)
	local floor = Vector3.new(at.X, top + 0.012, at.Z)
	-- Pés levemente abertos para fora, como passo de verdade.
	local toe = CFrame.Angles(0, math.rad(if left then 6 else -6), 0)
	local base = CFrame.lookAt(floor, floor + facing) * toe
	slot.part.CFrame = base * CFrame.new(0, 0, -0.24)
	slot.heel.CFrame = base * CFrame.new(0, 0, 0.36)
	-- Cor do próprio chão, só que molhado (mais escuro); tecido não brilha, madeira e pedra brilham um pouco.
	local wet = color:Lerp(Color3.new(0, 0, 0), if soft then 0.55 else 0.68)
	for _, part in { slot.part, slot.heel } do
		part.Color = wet
		part.Reflectance = if soft then 0 else 0.1
	end
	slot.born, slot.alpha = os.clock(), alpha
	slot.part.Transparency = 1 - 0.6 * alpha
	slot.heel.Transparency = slot.part.Transparency
end

local function roofed(position: Vector3, params: RaycastParams): boolean
	return workspace:Raycast(position, Vector3.new(0, 80, 0), params) ~= nil
end

function controller.wetness(player: Player?): number
	local body = bodies[player or Players.LocalPlayer]
	return if body then body.wet else 0
end

function controller.Init()
	local created = Instance.new("Folder")
	created.Name = "ClientWetness"
	created.Parent = workspace
	folder = created
end

function controller.Start()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.RespectCanCollide = true
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local budget = Settings.visualBudget().particles
		probeClock += dt
		local probe = probeClock >= 0.4
		if probe then
			probeClock = 0
			local world = workspace:FindFirstChild(Tags.WorldFolder)
			params.FilterDescendantsInstances = if world then { world } else {}
			groundParams.FilterDescendantsInstances = params.FilterDescendantsInstances
			if world then
				collectRugs(world)
			end
		end
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not character or not root or not root:IsA("BasePart") or not humanoid then
				bodies[player] = nil
				continue
			end
			local existing = bodies[player]
			local body: Body
			if existing and existing.character == character then
				body = existing
			else
				local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
				body = {
					wet = 0,
					outdoor = 0,
					lastStep = nil,
					left = false,
					drips = if torso and torso:IsA("BasePart") then dripEmitter(torso, torso.Size) else nil,
					character = character,
				}
				bodies[player] = body
			end
			if probe then
				body.outdoor = if roofed(root.Position + Vector3.new(0, 2, 0), params) then 0 else 1
			end
			body.wet = Weather.wetness(body.wet, body.outdoor, dt)
			if body.drips then
				body.drips.Rate = 14 * body.wet * budget
			end
			-- Pegadas: só dentro de casa, no chão e andando.
			local alpha = Weather.footprintAlpha(body.wet)
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
			if alpha > 0 and body.outdoor < 0.5 and grounded then
				local feet = root.Position - Vector3.new(0, root.Size.Y / 2 + humanoid.HipHeight, 0)
				local last = body.lastStep
				if not last or (feet - last).Magnitude >= Weather.FootprintStride then
					local move = if last then (feet - last) else root.CFrame.LookVector
					local flat = Vector3.new(move.X, 0, move.Z)
					local facing = if flat.Magnitude > 0.01 then flat.Unit else Vector3.zAxis
					local side = facing:Cross(Vector3.yAxis) * (if body.left then -0.32 else 0.32)
					footprint(feet + side, facing, alpha, body.left)
					body.left = not body.left
					body.lastStep = feet
				end
			else
				body.lastStep = nil
			end
		end
		-- Lanterna na mão também pinga.
		local camera = workspace.CurrentCamera
		local lamp = camera and camera:FindFirstChild("Viewmodel")
		local lampBody = lamp and lamp:FindFirstChild("Head")
		if lampBody and lampBody:IsA("BasePart") then
			if not lampDrips or lampDrips.Parent == nil or (lampDrips.Parent :: Instance).Parent ~= lampBody then
				lampDrips = dripEmitter(lampBody, lampBody.Size)
			end
			local drips = lampDrips :: ParticleEmitter
			drips.Rate = 10 * controller.wetness() * budget
		end
		-- Pegadas secam: somem aos poucos (mais rápido no começo, como água evaporando da borda).
		for _, slot in prints do
			local age = now - slot.born
			if age < PRINT_LIFE then
				slot.part.Transparency = 1 - 0.6 * slot.alpha * (1 - age / PRINT_LIFE) ^ 1.6
				slot.heel.Transparency = slot.part.Transparency
			elseif slot.part.Transparency < 1 then
				slot.part.Transparency = 1
				slot.heel.Transparency = 1
			end
		end
	end)
end

return controller
