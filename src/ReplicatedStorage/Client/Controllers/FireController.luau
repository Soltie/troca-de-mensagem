--!strict
--[[
	Incêndio da fuga final no cliente (regras em Shared/Game/FireSpread, calor no FireService).
	- Cada foco vira chamas + fumaça + faíscas (texturas do próprio Roblox) e uma luz que tremula; cresce ao acender.
	- Madeira em volta escurece (só neste cliente) e volta ao normal quando o incêndio acaba.
	- Vigas em chamas despencam atrás de quem foge, com estalo e tremor. O rugido do fogo sobe com a proximidade.
	- Calor (atributo FireHeat): bordas da tela em brasa e imagem esquentando.
	Só o que está perto da câmera fica ligado (luzes, partículas e estalos), para caber em celular.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local FireSpread = require("@game/ReplicatedStorage/Shared/Game/FireSpread")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local SettingsController = require("./SettingsController")

local player = Players.LocalPlayer

local FLAME = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local CHAR = Color3.fromRGB(28, 20, 16)
local GLOW = Color3.fromRGB(255, 128, 48)
local MAX_LIGHTS = 14
local MAX_CRACKLES = 4
local NEAR = 110

type Visual = {
	node: FireSpread.Node,
	anchor: BasePart,
	flames: ParticleEmitter,
	smoke: ParticleEmitter,
	sparks: ParticleEmitter,
	fire: Fire,
	light: PointLight,
	scale: number,
	lit: boolean,
}

local FireController = {
	Name = "FireController",
}

local visuals: { Visual } = {}
local folder: Folder? = nil
local activeSeed = 0
local startAt = 0
local charred: { [BasePart]: Color3 } = {}
local burning: { [BasePart]: { Instance } } = {}
local toppled: { [Model]: { pivot: CFrame, parts: { [BasePart]: boolean } } } = {}
local debrisCount = 0
local nextDebrisAt = 0
local crackles: { Sound } = {}
local roar: Sound? = nil
local grade: ColorCorrectionEffect? = nil
local edges: { Frame } = {}
local edgeGui: ScreenGui? = nil
local lodClock = 0
local nextCollapseAt = 0
local nextSplinterAt = 0
local ignited = false
local rng = Random.new()

local function world(): Instance?
	return workspace:FindFirstChild(Tags.WorldFolder)
end

local function emitter(parent: Instance, texture: string): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Enabled = false
	e.Rate = 0
	e.Parent = parent
	return e
end

local function buildVisual(parent: Instance, node: FireSpread.Node): Visual
	local scale = node.size / 7
	local anchor = Instance.new("Part")
	anchor.Name = `Blaze_{node.kind}`
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(node.size * 0.55, 0.4, node.size * 0.55)
	anchor.CFrame = CFrame.new(node.x, node.y + 0.4, node.z)
	if node.kind == "facade" then
		-- Fachada: cola o foco na parede da frente (raio a partir do quintal), com as chamas saindo dela.
		local root = world()
		if root then
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Include
			params.FilterDescendantsInstances = { root }
			local hit = workspace:Raycast(Vector3.new(node.x, node.y, 92), Vector3.new(0, 0, -40), params)
			if hit then
				anchor.CFrame = CFrame.new(hit.Position + hit.Normal * 0.8)
			end
		end
	end
	anchor.Parent = parent

	local flames = emitter(anchor, FLAME)
	flames.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 215)),
		ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 172, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 56, 18)),
	})
	flames.LightEmission, flames.LightInfluence = 1, 0
	flames.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.6 * scale),
		NumberSequenceKeypoint.new(0.45, 2.3 * scale),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	flames.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.25, 0.02),
		NumberSequenceKeypoint.new(1, 1),
	})
	flames.Lifetime = NumberRange.new(0.55, 1.05)
	flames.Speed = NumberRange.new(3 * scale, 6 * scale)
	flames.SpreadAngle = Vector2.new(14, 14)
	flames.Acceleration = Vector3.new(0, 3, 0)
	flames.Rotation = NumberRange.new(0, 360)
	flames.RotSpeed = NumberRange.new(-70, 70)
	flames.Shape = Enum.ParticleEmitterShape.Box
	-- Brilho extra do núcleo (propriedade nova; ignora em versões que não têm).
	pcall(function()
		(flames :: any).Brightness = 2.6
	end)

	local smoke = emitter(anchor, SMOKE)
	smoke.Color = ColorSequence.new(Color3.fromRGB(46, 38, 34))
	smoke.LightEmission, smoke.LightInfluence = 0, 0.7
	smoke.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 2 * scale),
		NumberSequenceKeypoint.new(1, 9 * scale),
	})
	smoke.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	smoke.Lifetime = NumberRange.new(4, 6.5)
	smoke.Speed = NumberRange.new(2.5, 4.5)
	smoke.SpreadAngle = Vector2.new(20, 20)
	smoke.Acceleration = Vector3.new(0, 1.2, 0)
	smoke.Drag = 0.6
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-20, 20)

	local sparks = emitter(anchor, SPARK)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 190, 90))
	sparks.LightEmission, sparks.LightInfluence = 1, 0
	sparks.Size = NumberSequence.new(0.14)
	sparks.Lifetime = NumberRange.new(1, 2.2)
	sparks.Speed = NumberRange.new(5, 10)
	sparks.SpreadAngle = Vector2.new(35, 35)
	sparks.Acceleration = Vector3.new(0, 1.5, 0)
	sparks.Drag = 1.2

	-- Labareda clássica do Roblox por baixo das partículas: dá corpo e movimento ao fogo.
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 118, 36)
	fire.SecondaryColor = Color3.fromRGB(255, 214, 110)
	fire.Heat = 12
	fire.Size = 2
	fire.Enabled = false
	fire.Parent = anchor

	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Range = 10 + node.size * 1.3
	light.Brightness = 0
	light.Shadows = false
	light.Enabled = false
	light.Parent = anchor

	return {
		node = node,
		anchor = anchor,
		flames = flames,
		smoke = smoke,
		sparks = sparks,
		fire = fire,
		light = light,
		scale = scale,
		lit = false,
	}
end

-- Pastas do mundo com móveis e objetos soltos (o que pega fogo e tomba). Esconderijos e itens de missão ficam fora.
local BURNABLE = { Furniture = true, Props = true, Furnishings = true, Dressing = true }
local KEEP = { "wardrobe", "locker", "closet", "armario", "hide", "door", "task", "activity" }

local function topFolder(root: Instance, part: Instance): string?
	local node: Instance? = part
	while node and node.Parent ~= root do
		node = node.Parent
	end
	return if node then node.Name else nil
end

local function keep(instance: Instance): boolean
	local name = string.lower(instance.Name)
	for _, word in KEEP do
		if string.find(name, word, 1, true) then
			return true
		end
	end
	return false
end

-- Móvel em chamas: labareda e brasas no próprio objeto.
local function ignite(part: BasePart)
	if burning[part] then
		return
	end
	local size = math.max(part.Size.X, part.Size.Y, part.Size.Z)
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(255, 118, 36)
	fire.SecondaryColor = Color3.fromRGB(255, 210, 100)
	fire.Heat = 9
	fire.Size = math.clamp(size * 0.9, 2, 7)
	fire.Parent = part
	local embers = emitter(part, SPARK)
	embers.Color = ColorSequence.new(Color3.fromRGB(255, 180, 80))
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.12)
	embers.Lifetime = NumberRange.new(0.8, 1.8)
	embers.Speed = NumberRange.new(3, 6)
	embers.SpreadAngle = Vector2.new(40, 40)
	embers.Rate = 6
	embers.Enabled = true
	burning[part] = { fire :: Instance, embers }
end

-- Móvel tombando de lado (gira sobre a borda de baixo); sem colisão depois, para nunca fechar o caminho.
local function topple(model: Model)
	if toppled[model] then
		return
	end
	local _, extents = model:GetBoundingBox()
	if math.max(extents.X, extents.Y, extents.Z) > 10 or extents.Y < 1.5 then
		return
	end
	local start = model:GetPivot()
	local parts: { [BasePart]: boolean } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts[d] = d.CanCollide
			d.CanCollide = false
		end
	end
	toppled[model] = { pivot = start, parts = parts }
	local box = model:GetBoundingBox()
	local sideways = rng:NextNumber() < 0.5
	local sign = if rng:NextNumber() < 0.5 then -1 else 1
	local half = if sideways then extents.X / 2 else extents.Z / 2
	local hingeLocal = if sideways
		then Vector3.new(half * sign, -extents.Y / 2, 0)
		else Vector3.new(0, -extents.Y / 2, half * sign)
	local hinge = box * CFrame.new(hingeLocal)
	local axis = if sideways
		then CFrame.Angles(0, 0, -sign * math.rad(84))
		else CFrame.Angles(sign * math.rad(84), 0, 0)
	local relative = hinge:ToObjectSpace(start)
	task.spawn(function()
		task.wait(rng:NextNumber(0.5, 3))
		AudioController.playAtPosition("WoodSplinter", hinge.Position, 0.8, rng:NextNumber(0.9, 1.1))
		local t0 = os.clock()
		while model.Parent and toppled[model] do
			local a = math.clamp((os.clock() - t0) / 0.75, 0, 1)
			model:PivotTo(hinge * CFrame.new():Lerp(axis, a * a) * relative)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if model.Parent and toppled[model] then
			AudioController.playAtPosition("Fall_box", hinge.Position, 1, rng:NextNumber(0.75, 0.9))
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - hinge.Position).Magnitude < 16 then
				CameraController.addTrauma(0.3)
			end
		end
	end)
end

-- Madeira e móveis em volta do foco escurecem, alguns pegam fogo e outros tombam (só neste cliente; tudo volta
-- ao normal no fim).
local function char(visual: Visual)
	local root = world()
	if not root or visual.node.kind == "facade" then
		return
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { root }
	params.MaxParts = 80
	local center = Vector3.new(visual.node.x, visual.node.y + 3, visual.node.z)
	local flammable: { BasePart } = {}
	local models: { Model } = {}
	for _, part in workspace:GetPartBoundsInRadius(center, visual.node.size * 0.9, params) do
		if part.Transparency < 0.9 and part.Material ~= Enum.Material.Neon and not charred[part] then
			charred[part] = part.Color
			part.Color = part.Color:Lerp(CHAR, 0.55)
		end
		local folderName = topFolder(root, part)
		if folderName and BURNABLE[folderName] and not keep(part) then
			local parent = part.Parent
			if parent and parent:IsA("Model") and not keep(parent) then
				if not table.find(models, parent) then
					table.insert(models, parent)
				end
			elseif math.max(part.Size.X, part.Size.Y, part.Size.Z) < 9 then
				table.insert(flammable, part)
			end
		end
	end
	for _ = 1, math.min(2, #flammable) do
		ignite(table.remove(flammable, rng:NextInteger(1, #flammable)) :: BasePart)
	end
	if #models > 0 then
		local model = models[rng:NextInteger(1, #models)]
		local main = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		if main then
			ignite(main)
		end
		if rng:NextNumber() < 0.55 then
			topple(model)
		end
	end
end

local function restoreChar()
	for part, color in charred do
		if part.Parent then
			part.Color = color
		end
	end
	table.clear(charred)
	for _, list in burning do
		for _, instance in list do
			instance:Destroy()
		end
	end
	table.clear(burning)
	for model, saved in toppled do
		if model.Parent then
			model:PivotTo(saved.pivot)
		end
		for part, collide in saved.parts do
			part.CanCollide = collide
		end
	end
	table.clear(toppled)
end

-- Pedaço do teto em chamas despencando perto de um foco (física local: quica e para; depois vira enfeite).
local function debris(visual: Visual)
	local container = folder
	if not container or debrisCount >= 40 then
		return
	end
	local node = visual.node
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { container, player.Character :: Instance }
	local base = Vector3.new(node.x + rng:NextNumber(-4, 4), node.y + 2, node.z + rng:NextNumber(-4, 4))
	local ceiling = workspace:Raycast(base, Vector3.new(0, 14, 0), params)
	local top = if ceiling then ceiling.Position.Y - 0.5 else base.Y + 8
	local plank = Instance.new("Part")
	plank.Name = "Debris"
	plank.Size = if rng:NextNumber() < 0.6
		then Vector3.new(0.3, 0.25, rng:NextNumber(1.5, 3.2))
		else Vector3.new(rng:NextNumber(0.8, 1.6), 0.2, rng:NextNumber(0.8, 1.4))
	plank.Material = Enum.Material.WoodPlanks
	plank.Color = Color3.fromRGB(40, 27, 20)
	plank.CanQuery, plank.CanTouch = false, false
	plank.CFrame = CFrame.new(base.X, top, base.Z)
		* CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
	plank.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6))
	local trail = emitter(plank, FLAME)
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 180, 70), Color3.fromRGB(180, 40, 12))
	trail.LightEmission = 1
	trail.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = NumberRange.new(0.3, 0.6)
	trail.Speed = NumberRange.new(0.5, 1.5)
	trail.Rate = 30
	trail.Enabled = true
	plank.Parent = container
	debrisCount += 1
	-- Baque de madeira quando o pedaço bate no chão.
	task.delay(0.75, function()
		local camera = workspace.CurrentCamera
		if plank.Parent and camera and (camera.CFrame.Position - plank.Position).Magnitude < 40 then
			AudioController.playAtPosition("StepWood", plank.Position, 1.2, rng:NextNumber(0.6, 0.9))
		end
	end)
	task.delay(2.5, function()
		if plank.Parent then
			plank.Anchored = true
			plank.CanCollide = false
			trail.Rate = 4
		end
	end)
end

local function buildEdges()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FireHeat"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = -2
	gui.Enabled = false
	for _, spec in
		{
			{ size = UDim2.fromScale(1, 0.32), pos = UDim2.fromScale(0, 0), rot = 90 },
			{ size = UDim2.fromScale(1, 0.32), pos = UDim2.fromScale(0, 0.68), rot = -90 },
			{ size = UDim2.fromScale(0.26, 1), pos = UDim2.fromScale(0, 0), rot = 0 },
			{ size = UDim2.fromScale(0.26, 1), pos = UDim2.fromScale(0.74, 0), rot = 180 },
		}
	do
		local frame = Instance.new("Frame")
		frame.Size, frame.Position = spec.size, spec.pos
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.fromRGB(255, 92, 30)
		frame.BackgroundTransparency = 1
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec.rot
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		frame.Parent = gui
		table.insert(edges, frame)
	end
	gui.Parent = player:WaitForChild("PlayerGui")
	edgeGui = gui
end

-- Gasolina pegando fogo: estouro com clarão e tranco na câmera para quem está perto.
local function gasFlare(visual: Visual)
	local position = visual.anchor.Position
	AudioController.playAtPosition("GasWhoosh", position, 1.2, rng:NextNumber(0.9, 1.05))
	local light = visual.light
	light.Enabled = true
	light.Brightness = 9
	local camera = workspace.CurrentCamera
	if camera then
		local distance = (camera.CFrame.Position - position).Magnitude
		if distance < 35 then
			local k = 1 - distance / 35
			CameraController.punch(0.5 * k)
			CameraController.addTrauma(0.45 * k)
		end
	end
end

-- Pedaços da casa que já despencaram (só neste cliente): a original some e uma cópia cai em chamas.
local crumbled: { [BasePart]: { transparency: number, collide: boolean } } = {}
local crumbleCount = 0
local crumblePool: { BasePart }? = nil
local mainQueued, basementQueued, wasBelow = false, false, false
local nextCrumbleAt = 0
local nextRumbleAt = 0
local CRUMBLE_FROM = { Architecture = true, Finish = true, Furnishings = true, Dressing = true, PrimitiveFinish = true }
local SOLID = { "floor", "stair", "step", "deck", "door", "gate", "barrier", "ground", "foundation" }

local function solid(part: BasePart): boolean
	local name = string.lower(part.Name)
	for _, word in SOLID do
		if string.find(name, word, 1, true) then
			return true
		end
	end
	return part:GetAttribute(Tags.Attr.InteractId) ~= nil
end

-- Uma peça da casa despenca (só neste cliente): a original some (sem colisão) e uma cópia chamuscada cai, bate no
-- chão com som e fica queimando. `floorY` fixa onde ela para; `flat` deita a peça (portas); `quiet` só faz o baque.
type FallOptions = { floorY: number?, delay: number?, flat: boolean?, quiet: boolean?, burn: boolean? }
local function fallPiece(piece: BasePart, options: FallOptions)
	local container = folder
	if not container or crumbled[piece] then
		return
	end
	crumbled[piece] = { transparency = piece.Transparency, collide = piece.CanCollide }
	local copy = piece:Clone()
	for _, child in copy:GetChildren() do
		if child:IsA("Light") or child:IsA("Sound") or child:IsA("ProximityPrompt") or child:IsA("SurfaceGui") then
			child:Destroy()
		end
	end
	copy.Anchored, copy.CanCollide, copy.CanQuery, copy.CanTouch = true, false, false, false
	copy.Color = copy.Color:Lerp(CHAR, 0.55)
	copy.Parent = container
	piece.Transparency, piece.CanCollide = 1, false
	crumbleCount += 1

	local from = piece.CFrame
	local floorY = options.floorY
	if not floorY then
		local rays = RaycastParams.new()
		rays.FilterType = Enum.RaycastFilterType.Exclude
		rays.FilterDescendantsInstances = { container, piece, player.Character :: Instance }
		local hit = workspace:Raycast(from.Position, Vector3.new(0, -24, 0), rays)
		floorY = if hit then hit.Position.Y else from.Position.Y - 10
	end
	local low = math.min(piece.Size.X, piece.Size.Y, piece.Size.Z)
	local to: CFrame
	if options.flat then
		-- Porta tomba de cara no chão, para a frente ou para trás.
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		to = CFrame.new(from.Position.X, (floorY :: number) + low / 2 + 0.05, from.Position.Z)
			* from.Rotation
			* CFrame.new(0, 0, side * piece.Size.Y / 2)
			* CFrame.Angles(side * math.rad(88), 0, rng:NextNumber(-0.1, 0.1))
	else
		to = CFrame.new(
			from.Position.X + rng:NextNumber(-1, 1),
			(floorY :: number) + low / 2 + 0.05,
			from.Position.Z + rng:NextNumber(-1, 1)
		) * from.Rotation * CFrame.Angles(
			rng:NextNumber(-0.5, 0.5),
			rng:NextNumber(-0.4, 0.4),
			rng:NextNumber(-0.5, 0.5)
		)
	end
	local height = math.max(from.Position.Y - to.Position.Y, 1)
	local duration = if options.flat then 0.7 else math.clamp(math.sqrt(height / 40), 0.35, 0.8)
	local dust = emitter(copy, SMOKE)
	dust.Color = ColorSequence.new(Color3.fromRGB(90, 80, 72))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1, 2)
	dust.Speed = NumberRange.new(1, 3)
	dust.Rate = 0
	dust.Enabled = true
	task.spawn(function()
		task.wait(options.delay or 0)
		if not copy.Parent then
			return
		end
		if not options.quiet then
			AudioController.playAtPosition("BeamCrack", from.Position, 1.1, rng:NextNumber(0.8, 1.05))
		end
		dust.Rate = 25
		task.wait(0.3)
		local t0 = os.clock()
		while copy.Parent do
			local a = math.clamp((os.clock() - t0) / duration, 0, 1)
			copy.CFrame = from:Lerp(to, a * a)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if not copy.Parent then
			return
		end
		dust.Rate = 0
		AudioController.playAtPosition(
			if options.flat then "DoorBang" else "Fall_box",
			to.Position,
			if options.quiet then 0.7 else 1.3,
			rng:NextNumber(0.6, 0.85)
		)
		local camera = workspace.CurrentCamera
		if camera then
			local distance = (camera.CFrame.Position - to.Position).Magnitude
			if distance < 30 then
				CameraController.addTrauma((if options.quiet then 0.25 else 0.6) * (1 - distance / 30) + 0.05)
			end
		end
		if options.burn ~= false then
			local fire = Instance.new("Fire")
			fire.Color = Color3.fromRGB(255, 118, 36)
			fire.SecondaryColor = Color3.fromRGB(255, 210, 100)
			fire.Heat = 8
			fire.Size = math.clamp(math.max(copy.Size.X, copy.Size.Z) * 0.5, 2, 8)
			fire.Parent = copy
		end
	end)
end

-- Peças da casa por pasta (lista montada uma vez por incêndio: a maioria não responde a consultas de física).
local function pool(): { BasePart }
	if crumblePool then
		return crumblePool
	end
	local list: { BasePart } = {}
	local root = world()
	if root then
		for name in CRUMBLE_FROM do
			local source = root:FindFirstChild(name :: string)
			if source then
				for _, part in source:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(list, part)
					end
				end
			end
		end
	end
	crumblePool = list
	return list
end

-- A casa desmorona: forro, vigas, molduras e lustres acima de um foco aceso despencam e ficam queimando no chão.
local function crumble(visual: Visual): boolean
	if not folder or crumbleCount >= 260 then
		return false
	end
	local node = visual.node
	local center = Vector3.new(node.x, node.y + 12, node.z)
	local candidates: { BasePart } = {}
	for _, part in pool() do
		local size = part.Size
		if
			part.Parent
			and (part.Position - center).Magnitude < 11
			and not crumbled[part]
			and part.Transparency < 0.5
			and part.Position.Y > node.y + 6
			and part.Position.Y < node.y + 17
			and math.max(size.X, size.Y, size.Z) <= 22
			and not solid(part)
		then
			table.insert(candidates, part)
		end
	end
	if #candidates == 0 then
		return false
	end
	-- Uma peça e às vezes mais uma ou duas em seguida.
	for index = 1, math.min(#candidates, rng:NextInteger(1, 3)) do
		local piece = table.remove(candidates, rng:NextInteger(1, #candidates)) :: BasePart
		fallPiece(piece, { delay = (index - 1) * rng:NextNumber(0.3, 0.8), quiet = index > 1 })
	end
	return true
end

-- Escada inteira desabando: degraus, corrimão e balaústres caem de cima para baixo com estrondo.
local stairsDown: { [string]: boolean } = {}
local function collapseStairs(name: string, x: number, y0: number, y1: number)
	if stairsDown[name] or not folder then
		return
	end
	stairsDown[name] = true
	local pieces: { BasePart } = {}
	for _, part in pool() do
		local p = part.Position
		if
			part.Parent
			and not crumbled[part]
			and part.Transparency < 0.9
			and part.Name ~= "StairDeck"
			and math.abs(p.X - x) < 7.5
			and p.Z > 19
			and p.Z < 57
			and p.Y > y0 - 0.5
			and p.Y < y1 + 1.5
		then
			table.insert(pieces, part)
		end
	end
	table.sort(pieces, function(a, b)
		return a.Position.Y > b.Position.Y
	end)
	local center = Vector3.new(x, (y0 + y1) / 2, 38)
	AudioController.playAtPosition("BeamCrack", center, 1.6, 0.7)
	AudioController.playAtPosition("WoodSplinter", center, 1.4, 0.8)
	AudioController.play("AmbThunder", 1.5, 0.5)
	CameraController.addTrauma(0.5)
	for index, piece in pieces do
		fallPiece(piece, {
			floorY = y0,
			delay = 0.15 + index * 0.035 + rng:NextNumber(0, 0.25),
			quiet = index % 6 ~= 1,
			burn = index % 3 == 1,
		})
	end
	task.delay(0.9, function()
		AudioController.playAtPosition("Fall_box", center, 1.6, 0.55)
		AudioController.playAtPosition("BeamCrack", center, 1.3, 0.6)
		CameraController.addTrauma(0.55)
	end)
end

-- Portas dos cômodos perto do fogo despencam do batente (o vão fica livre, nunca prende ninguém).
local function collapseDoors(visual: Visual)
	local root = world()
	local doors = root and root:FindFirstChild("Doors")
	if not doors then
		return
	end
	local node = visual.node
	local center = Vector3.new(node.x, node.y + 5, node.z)
	for _, door in doors:GetChildren() do
		if not door:IsA("BasePart") or (door.Position - center).Magnitude > 12 or crumbled[door] then
			continue
		end
		crumbled[door] = { transparency = door.Transparency, collide = door.CanCollide }
		door.CanCollide = false
		local delay = rng:NextNumber(0.5, 2.5)
		for _, leaf in door:GetChildren() do
			if leaf:IsA("BasePart") then
				fallPiece(leaf, { floorY = node.y, delay = delay, flat = true })
				delay += rng:NextNumber(0.2, 0.6)
			end
		end
	end
end

local function restoreCrumble()
	for part, saved in crumbled do
		if part.Parent then
			part.Transparency, part.CanCollide = saved.transparency, saved.collide
		end
	end
	table.clear(crumbled)
	table.clear(stairsDown)
	mainQueued, basementQueued, wasBelow = false, false, false
	crumbleCount = 0
	crumblePool = nil
end

-- Gasolina sendo espalhada (a poça da tarefa aparece): som de líquido e respingos.
local function watchPuddle(part: Instance)
	if not part:IsA("BasePart") or part.Name ~= "GasPuddle" then
		return
	end
	part:GetPropertyChangedSignal("Transparency"):Connect(function()
		-- Três manchas por poça: o som toca uma vez só por pilha.
		local pile = part.Parent
		if part.Transparency < 0.5 and pile and pile:GetAttribute("PourHeard") ~= true then
			pile:SetAttribute("PourHeard", true)
			AudioController.playAtPosition("GasPour", part.Position + Vector3.new(0, 1, 0), 1)
		end
	end)
end

local function stop()
	-- Estalos ficam pendurados nos focos: tirar antes de apagar a pasta (senão somem junto e travam a troca).
	for _, sound in crackles do
		sound:Stop()
		sound.Parent = SoundService
	end
	if folder then
		folder:Destroy()
		folder = nil
	end
	table.clear(visuals)
	restoreChar()
	restoreCrumble()
	activeSeed, startAt, ignited, debrisCount = 0, 0, false, 0
	if roar then
		roar:Stop()
	end
	if grade then
		grade.Enabled = false
	end
	if edgeGui then
		edgeGui.Enabled = false
	end
end

local function begin(seed: number, at: number)
	stop()
	activeSeed, startAt = seed, at
	local container = Instance.new("Folder")
	container.Name = "Blaze"
	container.Parent = workspace
	folder = container
	for _, node in
		FireSpread.build(seed, FireSpread.decodeFuel(world() and (world() :: Instance):GetAttribute("BlazeFuel")))
	do
		table.insert(visuals, buildVisual(container, node))
	end
	nextCollapseAt = FireSpread.HeadStart + 5
	nextSplinterAt = FireSpread.HeadStart + 2
	nextDebrisAt = FireSpread.HeadStart + 3
	nextCrumbleAt = FireSpread.HeadStart + 5
	nextRumbleAt = FireSpread.HeadStart + 2
end

local function refresh()
	local root = world()
	local seed = root and root:GetAttribute("BlazeSeed")
	local at = root and root:GetAttribute("BlazeStart")
	if type(seed) == "number" and type(at) == "number" then
		if seed ~= activeSeed then
			begin(seed, at)
		end
	elseif activeSeed ~= 0 then
		stop()
	end
end

-- Viga em chamas despencando do teto atrás de quem foge (só visual).
local function collapse(camera: Camera, character: Model)
	local body = character:FindFirstChild("HumanoidRootPart")
	if not body or not body:IsA("BasePart") or not folder then
		return
	end
	local velocity = body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local back = if velocity.Magnitude > 2 then -velocity.Unit else -camera.CFrame.LookVector * Vector3.new(1, 0, 1)
	if back.Magnitude < 0.1 then
		return
	end
	back = back.Unit
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, folder :: Instance, camera }
	local ground = body.Position + back * 6
	local floor = workspace:Raycast(ground + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), params)
	local ceiling = workspace:Raycast(ground + Vector3.new(0, 2, 0), Vector3.new(0, 12, 0), params)
	if not floor then
		return
	end
	local top = if ceiling then ceiling.Position.Y - 0.6 else floor.Position.Y + 10
	local yaw = math.atan2(back.X, back.Z) + math.rad(90 + rng:NextNumber(-25, 25))
	local beam = Instance.new("Part")
	beam.Name = "FallingBeam"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
	beam.Size = Vector3.new(0.9, 0.9, 8)
	beam.Material = Enum.Material.WoodPlanks
	beam.Color = Color3.fromRGB(46, 30, 22)
	local from = CFrame.new(ground.X, top, ground.Z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-35), 0, 0)
	local to = CFrame.new(ground.X, floor.Position.Y + 0.45, ground.Z)
		* CFrame.Angles(0, yaw, 0)
		* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8)))
	beam.CFrame = from
	beam.Parent = folder
	local flames = emitter(beam, FLAME)
	flames.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(170, 40, 12))
	flames.LightEmission = 1
	flames.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.1) })
	flames.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	flames.Lifetime = NumberRange.new(0.4, 0.8)
	flames.Speed = NumberRange.new(2, 4)
	flames.Shape = Enum.ParticleEmitterShape.Box
	flames.Rate = 40
	flames.Enabled = true
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = GLOW, 14, 2, false
	light.Parent = beam
	AudioController.playAtPosition("BeamCrack", ground, 1.2, rng:NextNumber(0.85, 1))
	task.spawn(function()
		local t0 = os.clock()
		while beam.Parent do
			local a = math.clamp((os.clock() - t0) / 0.42, 0, 1)
			beam.CFrame = from:Lerp(to, a * a)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if not beam.Parent then
			return
		end
		AudioController.playAtPosition("Fall_box", ground, 1.1, 0.7)
		local distance = (camera.CFrame.Position - ground).Magnitude
		if distance < 18 then
			CameraController.addTrauma(0.65 * (1 - distance / 18) + 0.15)
		end
		task.delay(12, function()
			flames.Rate = 12
		end)
	end)
end

local function update(dt: number)
	refresh()
	if activeSeed == 0 then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local t = workspace:GetServerTimeNow() - startAt
	local eye = camera.CFrame.Position
	local now = os.clock()
	local budget = SettingsController.visualBudget().particles

	-- Primeiro foco: a casa explode em chamas no mecanismo.
	if not ignited and t >= FireSpread.HeadStart then
		ignited = true
		CameraController.punch(0.6)
		CameraController.addTrauma(0.45)
		local origin = FireSpread.Route[1]
		AudioController.playAtPosition("BeamCrack", Vector3.new(origin[1], origin[2] + 3, origin[3]), 1.4, 0.8)
	end

	-- Acende e cresce (todo quadro: barato). Ligar/desligar por distância só a cada 0,25 s.
	lodClock += dt
	local lod = lodClock >= 0.25
	if lod then
		lodClock = 0
	end
	local nearest = math.huge
	local candidates: { { visual: Visual, distance: number } } = {}
	local nearLit: { Visual } = {}
	for _, visual in visuals do
		local node = visual.node
		local intensity = FireSpread.intensity(node, t)
		if intensity <= 0 then
			continue
		end
		if not visual.lit then
			visual.lit = true
			char(visual)
			if node.kind == "gas" then
				gasFlare(visual)
			end
			-- Tudo desmorona atrás do fogo: o que está em cima do foco e as portas perto caem pouco depois.
			if node.kind ~= "facade" and (visual.anchor.Position - eye).Magnitude < 90 then
				task.delay(rng:NextNumber(2.5, 7), crumble, visual)
				task.delay(rng:NextNumber(1.5, 4), collapseDoors, visual)
			end
		end
		local distance = (visual.anchor.Position - eye).Magnitude
		if node.kind ~= "facade" then
			nearest = math.min(nearest, distance)
			if distance < 28 then
				table.insert(nearLit, visual)
			end
		end
		if lod then
			local range = if node.kind == "facade" then 260 else NEAR
			local on = distance < range
			visual.flames.Enabled, visual.smoke.Enabled, visual.sparks.Enabled = on, on, on
			visual.fire.Enabled = on
			table.insert(candidates, { visual = visual, distance = distance })
		end
		local flicker = 0.75
			+ 0.25 * math.noise(now * 7, node.x * 0.1, node.z * 0.1)
			+ 0.1 * math.sin(now * 19 + node.x)
		visual.light.Brightness = (if node.kind == "facade" then 1 else 2.4) * intensity * flicker
		visual.flames.Rate = 60 * visual.scale * intensity * budget
		visual.smoke.Rate = 5 * visual.scale * intensity * budget
		visual.sparks.Rate = 7 * visual.scale * intensity * budget
		visual.fire.Size = math.clamp(node.size * 0.75 * intensity, 2, 12)
	end

	if lod then
		table.sort(candidates, function(a, b)
			return a.distance < b.distance
		end)
		for index, entry in candidates do
			entry.visual.light.Enabled = index <= MAX_LIGHTS and entry.distance < 140
				or (entry.visual.node.kind == "facade" and entry.distance < 260 and index <= MAX_LIGHTS + 6)
		end
		-- Estalos de fogo nos focos mais perto.
		for index, sound in crackles do
			local entry = candidates[index]
			if entry and entry.distance < 45 and entry.visual.node.kind ~= "facade" then
				if sound.Parent ~= entry.visual.anchor then
					sound.Parent = entry.visual.anchor
					sound.TimePosition = rng:NextNumber(0, 10)
				end
				if not sound.IsPlaying then
					sound:Play()
				end
			elseif sound.IsPlaying then
				sound:Stop()
			end
		end
	end

	-- Rugido geral e imagem esquentando conforme o fogo chega perto.
	local near = if nearest < math.huge then math.clamp(1 - nearest / 40, 0, 1) else 0
	local r = roar
	if r then
		if not r.IsPlaying and t >= FireSpread.HeadStart then
			r:Play()
		end
		r.Volume = (0.12 + 0.7 * near) * 0.5
	end
	local heat = player:GetAttribute("FireHeat")
	local scorch = if type(heat) == "number" then heat else 0
	local g = grade
	if g then
		g.Enabled = near > 0 or scorch > 0
		local warm = math.max(near * 0.35, scorch)
		g.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 196, 150), warm)
		g.Brightness = 0.04 * near + 0.08 * scorch
		g.Contrast = 0.08 * warm
		g.Saturation = 0.1 * near - 0.2 * scorch
	end
	if edgeGui then
		edgeGui.Enabled = scorch > 0.02
		for _, frame in edges do
			frame.BackgroundTransparency = 1 - scorch * 0.85
		end
	end
	if scorch > 0.3 and SettingsController.get("shake") then
		CameraController.addTrauma(dt * scorch * 0.8)
	end

	-- Pedaços do teto em chamas caindo perto dos focos à sua volta.
	if #nearLit > 0 and t >= nextDebrisAt then
		nextDebrisAt = t + rng:NextNumber(0.9, 2.2)
		debris(nearLit[rng:NextInteger(1, #nearLit)])
	end

	-- A casa desmorona aos poucos em volta de quem foge e geme inteira de tempos em tempos.
	if #nearLit > 0 and t >= nextCrumbleAt and crumbleCount < 30 then
		nextCrumbleAt = t + rng:NextNumber(3.5, 7)
		for _ = 1, 3 do
			if crumble(nearLit[rng:NextInteger(1, #nearLit)]) then
				break
			end
		end
	end
	if t >= nextRumbleAt and t >= FireSpread.HeadStart then
		nextRumbleAt = t + rng:NextNumber(7, 12)
		AudioController.play("AmbThunder", 1.4, rng:NextNumber(0.5, 0.65))
		AudioController.play("CreakWood", 1.2, rng:NextNumber(0.5, 0.7))
		CameraController.addTrauma(0.22)
	end

	-- Vigas caindo atrás de quem ainda está dentro de casa.
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local status = player:GetAttribute("CampaignStatus")
	-- Escadas: a principal (e a do sótão) desabam quando você chega no hall ou o hall pega fogo perto de você;
	-- a do porão cai atrás de você depois que você saiu dela (o caminho de volta some).
	if body and body:IsA("BasePart") and t >= FireSpread.HeadStart then
		local p = body.Position
		if p.Y < -8 then
			wasBelow = true
		end
		local inHall = p.Y > -2 and p.Y < 12 and p.Z > 12 and p.Z < 63
		local hallBurning = t >= FireSpread.frontTime(170) - FireSpread.HallLead
			and (eye - Vector3.new(16, 8, 38)).Magnitude < 70
		if not mainQueued and (inHall or hallBurning) then
			mainQueued = true
			task.delay(1.2, collapseStairs, "MainStairs", 16, 0, 16)
			task.delay(4, collapseStairs, "AtticStairs", 32, 16, 32)
		end
		if not basementQueued and wasBelow and p.Y > -1 and (math.abs(p.X + 16) > 8 or p.Z > 57) then
			basementQueued = true
			task.delay(1.5, collapseStairs, "BasementStairs", -16, -16, 0)
		end
	end
	if character and body and body:IsA("BasePart") and status == "Active" and body.Position.Z < 62 then
		if t >= nextCollapseAt then
			nextCollapseAt = t + rng:NextNumber(8, 13)
			collapse(camera, character)
		end
		if t >= nextSplinterAt and nearest < 30 then
			nextSplinterAt = t + rng:NextNumber(3, 7)
			AudioController.playAtPosition(
				"WoodSplinter",
				eye + Vector3.new(rng:NextNumber(-10, 10), 4, rng:NextNumber(-10, 10)),
				0.9
			)
		end
	end
end

function FireController.Init()
	for _ = 1, MAX_CRACKLES do
		local sound = Instance.new("Sound")
		sound.Name = "FireCrackle"
		AudioController.configure(sound, "FireCrackle")
		sound.Looped = true
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = 45
		sound.Parent = SoundService
		table.insert(crackles, sound)
	end
	local loud = Instance.new("Sound")
	loud.Name = "FireRoar"
	AudioController.configure(loud, "AmbFireRoar")
	loud.Looped = true
	loud.Parent = SoundService
	roar = loud
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "FireGrade"
	cc.Enabled = false
	cc.Parent = Lighting
	grade = cc
end

function FireController.Start()
	buildEdges()
	for _, part in workspace:GetDescendants() do
		watchPuddle(part)
	end
	workspace.DescendantAdded:Connect(watchPuddle)
	RunService.Heartbeat:Connect(update)
end

-- Depuração (Studio): quantos focos acesos e o tempo do incêndio.
function FireController.debugState(): { [string]: any }
	local lit = 0
	for _, visual in visuals do
		if visual.lit then
			lit += 1
		end
	end
	return {
		active = activeSeed ~= 0,
		t = if activeSeed ~= 0 then workspace:GetServerTimeNow() - startAt else 0,
		nodes = #visuals,
		lit = lit,
		charred = 0,
	}
end

return FireController
