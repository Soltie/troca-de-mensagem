--!strict
--[[
	Corpos molhados pela chuva (só visual, no cliente; nada replica nem muda regra):
	- cada personagem encharca ao ar livre e seca devagar sob telhado (Weather.wetness, telhado por raycast);
	- molhado, pinga: gotinhas caem do corpo de todos e da lanterna na mão do jogador;
	- dentro de casa, quem está molhado deixa pegadas escuras e brilhantes no piso, que somem em ~30 s.
	Pegadas em pool fixo (MAX_PRINTS); gotinhas seguem o orçamento de partículas da qualidade visual.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Weather = require("@game/ReplicatedStorage/Shared/Game/Weather")
local Settings = require("./SettingsController")

local controller = { Name = "WetnessController" }

local MAX_PRINTS = 48
local PRINT_LIFE = 30
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

local function footprint(at: Vector3, facing: Vector3, alpha: number)
	local parent = folder
	if not parent then
		return
	end
	local slot = prints[nextPrint]
	if not slot then
		-- Sola de sapato: frente larga e calcanhar separados, como marca molhada escurecendo o piso.
		local function piece(name: string, size: Vector3): BasePart
			local part = Instance.new("Part")
			part.Name = name
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(10, 6, 5)
			part.Reflectance = 0.03
			part.Size = size
			local shape = Instance.new("SpecialMesh")
			shape.MeshType = Enum.MeshType.Sphere
			shape.Parent = part
			part.Parent = parent
			return part
		end
		slot = {
			part = piece("WetFootprint", Vector3.new(0.34, 0.02, 0.56)),
			heel = piece("WetFootprintHeel", Vector3.new(0.26, 0.02, 0.28)),
			born = 0,
			alpha = 0,
		}
		prints[nextPrint] = slot
	end
	nextPrint = nextPrint % MAX_PRINTS + 1
	-- Assenta na superfície real (passadeira, tapete, piso), não na altura calculada dos pés.
	local hit = workspace:Raycast(at + Vector3.new(0, 2, 0), Vector3.new(0, -4, 0), groundParams)
	local floor = if hit then hit.Position else at
	-- 0,085 acima do piso: passadeiras e tapetes (sem raycast) ficam até 0,07 acima dele.
	local base = CFrame.lookAt(floor, floor + facing) * CFrame.new(0, 0.085, 0)
	slot.part.CFrame = base * CFrame.new(0, 0, -0.2)
	slot.heel.CFrame = base * CFrame.new(0, 0, 0.33)
	slot.born, slot.alpha = os.clock(), alpha
	slot.part.Transparency = 1 - 0.5 * alpha
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
					footprint(feet + side, facing, alpha)
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
		-- Pegadas secam: somem aos poucos.
		for _, slot in prints do
			local age = now - slot.born
			if age < PRINT_LIFE then
				slot.part.Transparency = 1 - 0.5 * slot.alpha * (1 - age / PRINT_LIFE)
				slot.heel.Transparency = slot.part.Transparency
			elseif slot.part.Transparency < 1 then
				slot.part.Transparency = 1
				slot.heel.Transparency = 1
			end
		end
	end)
end

return controller
