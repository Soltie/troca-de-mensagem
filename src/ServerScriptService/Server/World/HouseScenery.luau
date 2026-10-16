--!strict
--[[
	Cenário da casa do Tung Tung, montado depois do HouseBuilder (só visual, sem regras de jogo):
	- Terreno: gramado ao redor da casa, colinas no horizonte, pedras e uma trilha de terra até o portão.
	- Floresta: árvores arredondadas em tons de verde/azulado, arbustos e cogumelos que brilham.
	- Clima "assustador divertido": abóboras acesas, postes com luz quente, vaga-lumes, lápides fofas.
	- Casa repintada (lilás, telhado roxo, janelas acesas) e luzes noturnas coloridas em cada cômodo.

	Regras de convivência com a navegação (testes HouseNavigation):
	- Nada colide dentro da casa (tapetes, quadros e luzes têm CanCollide = false e CanQuery = false).
	- Fora da casa, obstáculos ficam longe da trilha central (|x| < 22) e da saída (z 90..130).
	- O terreno nunca entra na projeção da casa (inclusive o porão).
]]

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Build = require("./Build")
local Furniture = require("./HouseFurniture")

local Scenery = {}

local rgb = Color3.fromRGB
local SEED = 90312

-- Projeção da casa (com folga): o terreno não entra aqui.
local HOUSE_MIN = Vector2.new(-48, -88)
local HOUSE_MAX = Vector2.new(48, 68)
-- Área livre de obstáculos: trilha da entrada até a saída da floresta.
local PATH_HALF_WIDTH = 22
local EXIT_Z = Vector2.new(60, 135)

local GRASS = rgb(74, 128, 72)
local WALL = rgb(132, 112, 158)
local WALL_DARK = rgb(96, 78, 122)
local ROOF = rgb(70, 44, 96)
local TRIM = rgb(236, 210, 150)
local FLOOR = rgb(126, 82, 52)
local WINDOW = rgb(255, 200, 110)

local WALL_NAMES = {
	Facade = true,
	DoorWall = true,
	RoomPartition = true,
	RearWall = true,
	StairFacade = true,
	EntrySide = true,
	EntryLintel = true,
	DoorLintel = true,
	WindowSide = true,
}
local TRIM_NAMES = { FacadeSill = true, FacadeTop = true }
local FLOOR_NAMES = {
	CorridorFloor = true,
	ReturnWalkway = true,
	SouthLanding = true,
	NorthLanding = true,
	RoomFloor = true,
}
local GROUND_NAMES = { Garden = true, SideGarden = true, BackGarden = true }

local function inside(x: number, z: number, margin: number): boolean
	return x > HOUSE_MIN.X - margin
		and x < HOUSE_MAX.X + margin
		and z > HOUSE_MIN.Y - margin
		and z < HOUSE_MAX.Y + margin
end

local function onPath(x: number, z: number): boolean
	return math.abs(x) < PATH_HALF_WIDTH and z > EXIT_Z.X and z < EXIT_Z.Y
end

local function decor(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local part = Build.part(parent, name, size, cframe, color, {
		material = material or Enum.Material.SmoothPlastic,
		collide = false,
		query = false,
	})
	part.CanTouch = false
	return part
end

local function ball(
	parent: Instance,
	name: string,
	center: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material?
)
	local part = decor(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(center), color, material)
	local sphere = part :: Part
	sphere.Shape = Enum.PartType.Ball
	return part
end

local function glow(part: BasePart, color: Color3, range: number, brightness: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = part
	return light
end

-- Repinta a arquitetura existente sem mudar tamanho, posição ou colisão.
local function restyle(root: Instance)
	for _, part in root:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if WALL_NAMES[part.Name] then
			part.Color = if part.Name == "RoomPartition" then WALL_DARK else WALL
			part.Material = Enum.Material.WoodPlanks
		elseif TRIM_NAMES[part.Name] then
			part.Color = TRIM
			part.Material = Enum.Material.Wood
		elseif FLOOR_NAMES[part.Name] then
			part.Color = FLOOR
		elseif part.Name == "HouseRoof" or part.Name == "StairRoof" then
			part.Color = ROOF
			part.Material = Enum.Material.Slate
		elseif part.Name == "WindowGlass" then
			-- Janelas acesas por dentro: a casa "chama" o jogador de longe.
			part.Color = WINDOW
			part.Material = Enum.Material.Neon
			part.Transparency = 0.35
		elseif GROUND_NAMES[part.Name] then
			part.Color = GRASS
			part.Material = Enum.Material.Grass
		elseif part.Name == "ForestGround" then
			part.Transparency = 1
		elseif part.Name == "Plaque" then
			local text = part:FindFirstChildWhichIsA("TextLabel", true)
			if text then
				text.Font = Enum.Font.FredokaOne
				text.TextColor3 = rgb(255, 214, 80)
				text.BackgroundColor3 = rgb(60, 24, 80)
			end
			part.Color = rgb(60, 24, 80)
		elseif part.Name == "TreeTrunk" or part.Name == "TreeCrown" then
			-- As árvores-caixa antigas dão lugar às árvores novas (mesmo lugar, mesmo tronco).
			part:Destroy()
		end
	end
end

local function terrain()
	local t = workspace.Terrain
	t:Clear()
	t:SetMaterialColor(Enum.Material.Grass, GRASS)
	t:SetMaterialColor(Enum.Material.LeafyGrass, rgb(62, 112, 76))
	t:SetMaterialColor(Enum.Material.Ground, rgb(108, 82, 58))
	t:SetMaterialColor(Enum.Material.Rock, rgb(104, 100, 120))
	local top, depth = -0.7, 8
	local y = top - depth / 2
	local extent = 230
	-- Quatro placas em volta da projeção da casa (nada de terreno dentro do porão).
	local slabs = {
		{ Vector2.new(-extent, HOUSE_MAX.Y), Vector2.new(extent, extent) },
		{ Vector2.new(-extent, -extent), Vector2.new(extent, HOUSE_MIN.Y) },
		{ Vector2.new(-extent, HOUSE_MIN.Y), Vector2.new(HOUSE_MIN.X, HOUSE_MAX.Y) },
		{ Vector2.new(HOUSE_MAX.X, HOUSE_MIN.Y), Vector2.new(extent, HOUSE_MAX.Y) },
	}
	for _, slab in slabs do
		local min, max = slab[1], slab[2]
		local size = Vector3.new(max.X - min.X, depth, max.Y - min.Y)
		local center = Vector3.new((min.X + max.X) / 2, y, (min.Y + max.Y) / 2)
		t:FillBlock(CFrame.new(center), size, Enum.Material.Grass)
	end
	-- Trilha de terra da chegada até a floresta.
	t:FillBlock(CFrame.new(0, top - 1.9, 104), Vector3.new(14, 4, 76), Enum.Material.Ground)
	local rng = Random.new(SEED)
	-- Colinas no horizonte: escondem a borda do mundo e emolduram a casa.
	for index = 1, 46 do
		local angle = (index / 46) * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local radius = rng:NextNumber(185, 215)
		local center = Vector3.new(math.cos(angle) * radius, rng:NextNumber(-22, -8), 10 + math.sin(angle) * radius)
		t:FillBall(
			center,
			rng:NextNumber(30, 46),
			if index % 3 == 0 then Enum.Material.LeafyGrass else Enum.Material.Grass
		)
	end
	-- Pedras espalhadas fora da área de jogo.
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-170, 170), rng:NextNumber(-160, 180)
		if not inside(x, z, 20) and not onPath(x, z) and (math.abs(x) > 112 or z > 134 or z < -124) then
			t:FillBall(Vector3.new(x, top, z), rng:NextNumber(2.5, 5), Enum.Material.Rock)
		end
	end
end

local LEAF_COLORS = { rgb(46, 104, 70), rgb(58, 122, 82), rgb(40, 92, 96), rgb(70, 112, 60) }

local function tree(parent: Instance, position: Vector3, height: number, rng: Random)
	local model = Build.model(parent, "Tree")
	local trunk = Build.cylinder(
		model,
		"Trunk",
		position + Vector3.new(0, height / 2, 0),
		Vector3.yAxis,
		height,
		2.6,
		rgb(92, 60, 40),
		{ material = Enum.Material.Wood }
	)
	trunk.CanQuery = false
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local crown = position + Vector3.new(0, height, 0)
	ball(model, "Crown", crown, rng:NextNumber(12, 16), color, Enum.Material.Grass)
	for _ = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-3, 3), rng:NextNumber(-5, 5))
		ball(
			model,
			"Crown",
			crown + offset,
			rng:NextNumber(7, 11),
			color:Lerp(rgb(20, 40, 30), 0.15),
			Enum.Material.Grass
		)
	end
end

local function forest(parent: Instance)
	local folder = Build.folder(parent, "Forest")
	local rng = Random.new(SEED + 1)
	-- Mesmos lugares das árvores antigas do jardim lateral (a navegação já conhecia esses troncos).
	for i = 1, 28 do
		local x = if i % 2 == 0 then -67 - i % 4 * 8 else 67 + i % 4 * 8
		local z = -105 + i * 8
		tree(folder, Vector3.new(x, -0.5, z), 20 + i % 4 * 2, rng)
	end
	-- Floresta externa, além dos jardins.
	local placed = 0
	while placed < 70 do
		local x, z = rng:NextNumber(-175, 175), rng:NextNumber(-165, 185)
		local outside = math.abs(x) > 112 or z > 134 or z < -124
		if outside and not inside(x, z, 24) and not onPath(x, z) then
			tree(folder, Vector3.new(x, -0.7, z), rng:NextNumber(18, 30), rng)
			placed += 1
		end
	end
	-- Arbustos e cogumelos que brilham (pontos de cor no escuro).
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-104, 104), rng:NextNumber(-116, 126)
		if not inside(x, z, 6) and not onPath(x, z) then
			if rng:NextNumber() < 0.6 then
				ball(
					folder,
					"Bush",
					Vector3.new(x, 0.6, z),
					rng:NextNumber(3, 5),
					LEAF_COLORS[rng:NextInteger(1, 4)],
					Enum.Material.Grass
				)
			else
				local hue = if rng:NextNumber() < 0.5 then rgb(120, 255, 210) else rgb(255, 120, 230)
				local cap = decor(
					folder,
					"GlowShroom",
					Vector3.new(1.6, 0.7, 1.6),
					CFrame.new(x, 1.2, z),
					hue,
					Enum.Material.Neon
				)
				local capShape = cap :: Part
				capShape.Shape = Enum.PartType.Cylinder
				cap.CFrame = CFrame.new(x, 1.2, z) * CFrame.Angles(0, 0, math.rad(90))
				decor(folder, "Stem", Vector3.new(0.5, 1, 0.5), CFrame.new(x, 0.4, z), rgb(236, 226, 210))
			end
		end
	end
end

local function pumpkin(parent: Instance, position: Vector3, size: number)
	local center = position + Vector3.new(0, size / 2, 0)
	local body = ball(parent, "Pumpkin", center, size, rgb(236, 104, 24), Enum.Material.SmoothPlastic)
	-- Gomos laterais deixam a silhueta de abóbora (e não de bola).
	for _, dx in { -1, 1 } do
		ball(
			parent,
			"PumpkinLobe",
			center + Vector3.new(dx * size * 0.28, -size * 0.05, 0),
			size * 0.82,
			rgb(222, 92, 20)
		)
	end
	decor(
		parent,
		"Stem",
		Vector3.new(0.4, 0.8, 0.4),
		CFrame.new(position + Vector3.new(0, size + 0.2, 0)),
		rgb(70, 110, 50)
	)
	-- Rosto aceso virado para a trilha (placa transparente: SurfaceGui não desenha bem em esferas).
	local toward = Vector3.new(-math.sign(position.X), 0, 0)
	local facePosition = body.Position + toward * size * 0.58
	local facePart = decor(
		parent,
		"PumpkinFace",
		Vector3.new(size * 0.8, size * 0.6, 0.05),
		CFrame.lookAt(facePosition, facePosition + toward),
		rgb(0, 0, 0)
	)
	facePart.Transparency = 1
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.LightInfluence = 0
	face.Brightness = 2
	face.CanvasSize = Vector2.new(100, 80)
	face.Parent = facePart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "▲ ▲\n◡"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = rgb(255, 236, 120)
	label.Parent = face
	glow(body, rgb(255, 150, 60), 12, 0.8)
	return body
end

local function lampPost(parent: Instance, position: Vector3)
	local model = Build.model(parent, "LampPost")
	Build.cylinder(model, "Pole", position + Vector3.new(0, 4, 0), Vector3.yAxis, 8, 0.5, rgb(40, 34, 50), {
		material = Enum.Material.Metal,
		collide = false,
		query = false,
	})
	local lamp = decor(
		model,
		"Lamp",
		Vector3.new(0.9, 1.2, 0.9),
		CFrame.new(position + Vector3.new(0, 8.6, 0)),
		rgb(255, 170, 80),
		Enum.Material.Neon
	)
	lamp.Transparency = 0.15
	decor(
		model,
		"LampCap",
		Vector3.new(1.6, 0.4, 1.6),
		CFrame.new(position + Vector3.new(0, 9.4, 0)),
		rgb(40, 34, 50),
		Enum.Material.Metal
	)
	decor(
		model,
		"LampBase",
		Vector3.new(1.3, 0.25, 1.3),
		CFrame.new(position + Vector3.new(0, 7.95, 0)),
		rgb(40, 34, 50),
		Enum.Material.Metal
	)
	glow(lamp, rgb(255, 186, 110), 24, 1.2)
end

local function fireflies(parent: Instance, center: Vector3, spread: Vector3)
	local anchor = decor(parent, "Fireflies", spread, CFrame.new(center), rgb(0, 0, 0))
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	emitter.Rate = 7
	emitter.Lifetime = NumberRange.new(4, 7)
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Color = ColorSequence.new(rgb(230, 255, 120))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.22),
		NumberSequenceKeypoint.new(0.8, 0.22),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = anchor
end

local function grave(parent: Instance, position: Vector3, yaw: number)
	local stone = decor(
		parent,
		"Gravestone",
		Vector3.new(3, 4, 0.8),
		CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(yaw), math.rad(yaw % 7 - 3)),
		rgb(150, 146, 170),
		Enum.Material.Slate
	)
	local top = decor(
		parent,
		"GraveTop",
		Vector3.new(0.8, 3, 3),
		stone.CFrame * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
		stone.Color,
		Enum.Material.Slate
	)
	local topShape = top :: Part
	topShape.Shape = Enum.PartType.Cylinder
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0.6
	gui.CanvasSize = Vector2.new(120, 160)
	gui.Parent = stone
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "TUM\nTUM"
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = rgb(80, 70, 100)
	label.Parent = gui
end

local function fence(parent: Instance, from: Vector3, to: Vector3)
	local direction = to - from
	local length = direction.Magnitude
	local frame = CFrame.lookAt(from, to)
	for step = 0, math.floor(length / 3) do
		local position = frame * CFrame.new(0, 1.6, -step * 3)
		decor(parent, "Picket", Vector3.new(0.6, 3.2, 0.3), position, rgb(236, 230, 246), Enum.Material.Wood)
	end
	for _, height in { 1, 2.4 } do
		decor(
			parent,
			"Rail",
			Vector3.new(0.3, 0.3, length),
			frame * CFrame.new(0, height, -length / 2),
			rgb(220, 212, 236),
			Enum.Material.Wood
		)
	end
end

local function exterior(parent: Instance)
	local folder = Build.folder(parent, "Yard")
	-- Trilha de terra por cima do gramado do jardim, da varanda até a saída.
	decor(folder, "Trail", Vector3.new(10, 0.06, 66), CFrame.new(0, -0.46, 97), rgb(118, 88, 60), Enum.Material.Ground)
	-- Abóboras acesas dos dois lados da trilha.
	for _, z in { 70, 80, 90 } do
		for _, x in { -9, 9 } do
			pumpkin(folder, Vector3.new(x, -0.5, z), 2.6)
		end
	end
	for _, z in { 74, 94, 112 } do
		lampPost(folder, Vector3.new(-14, -0.5, z))
		lampPost(folder, Vector3.new(14, -0.5, z))
	end
	-- Varanda: duas lanternas quentes na porta.
	for _, x in { -8, 8 } do
		local lamp = decor(
			folder,
			"PorchLight",
			Vector3.new(1, 1.6, 1),
			CFrame.new(x, 8, 65.2),
			rgb(255, 214, 140),
			Enum.Material.Neon
		)
		glow(lamp, rgb(255, 190, 110), 20, 1.3)
	end
	fireflies(folder, Vector3.new(0, 4, 100), Vector3.new(60, 6, 50))
	fireflies(folder, Vector3.new(-80, 4, 0), Vector3.new(30, 6, 160))
	fireflies(folder, Vector3.new(80, 4, 0), Vector3.new(30, 6, 160))
	-- Cemitériozinho fofo no jardim lateral (fora da trilha).
	for index = 0, 5 do
		grave(folder, Vector3.new(-96 + (index % 3) * 7, -0.5, 30 + math.floor(index / 3) * 8), index * 13)
	end
	-- Cerca baixa marcando o limite do quintal (com o vão da trilha livre).
	fence(folder, Vector3.new(-108, -0.5, -121), Vector3.new(-108, -0.5, 131))
	fence(folder, Vector3.new(108, -0.5, -121), Vector3.new(108, -0.5, 131))
	fence(folder, Vector3.new(-108, -0.5, -121), Vector3.new(108, -0.5, -121))
	fence(folder, Vector3.new(-108, -0.5, 131), Vector3.new(-PATH_HALF_WIDTH, -0.5, 131))
	fence(folder, Vector3.new(PATH_HALF_WIDTH, -0.5, 131), Vector3.new(108, -0.5, 131))
	-- Letreiro grande e iluminado na fachada.
	Build.sign(folder, "BigTitle", Vector3.new(10, 40, 65.6), Vector3.zAxis, Vector2.new(34, 6), "TUNG TUNG SAHUR", {
		textColor = rgb(255, 214, 80),
		background = rgb(60, 20, 70),
		lit = true,
		font = Enum.Font.FredokaOne,
	})
end

local function window(parent: Instance, center: Vector3, normal: Vector3, width: number, height: number)
	local frame = CFrame.lookAt(center, center + normal)
	decor(parent, "WindowFrame", Vector3.new(width + 1, height + 1, 0.3), frame, TRIM, Enum.Material.Wood)
	local pane = decor(
		parent,
		"WindowPane",
		Vector3.new(width, height, 0.3),
		frame * CFrame.new(0, 0, -0.1),
		WINDOW,
		Enum.Material.Neon
	)
	pane.Transparency = 0.25
	decor(
		parent,
		"WindowBar",
		Vector3.new(0.3, height, 0.35),
		frame * CFrame.new(0, 0, -0.15),
		TRIM,
		Enum.Material.Wood
	)
	decor(parent, "WindowBar", Vector3.new(width, 0.3, 0.35), frame * CFrame.new(0, 0, -0.15), TRIM, Enum.Material.Wood)
end

local function facade(parent: Instance)
	local folder = Build.folder(parent, "Facade")
	-- Frente (parede da escadaria, z = 64): três andares de janelas, livre em volta da porta.
	for _, y in { 6, 18, 30, 40 } do
		for _, x in { -18, -8, 8, 18, 30, 40 } do
			if not (math.abs(x) < 12 and y < 14) then
				window(folder, Vector3.new(x, y, 64.7), Vector3.zAxis, 4, 5)
			end
		end
	end
	-- Laterais (fachadas x = ±44): uma janela por cômodo e andar.
	for _, side in { -1, 1 } do
		for _, y in { 6, 22, 38 } do
			for _, z in { -4, -36, -68 } do
				window(folder, Vector3.new(side * 44.7, y, z), Vector3.new(side, 0, 0), 6, 5)
			end
		end
	end
	-- Varanda com telhadinho sobre a porta.
	decor(folder, "PorchRoof", Vector3.new(22, 0.8, 7), CFrame.new(0, 12.6, 68), ROOF, Enum.Material.Slate)
	for _, x in { -10, 10 } do
		decor(folder, "PorchPost", Vector3.new(0.8, 13, 0.8), CFrame.new(x, 6, 71), TRIM, Enum.Material.Wood)
	end
	decor(folder, "Doormat", Vector3.new(8, 0.06, 4), CFrame.new(0, -0.45, 67), rgb(170, 60, 70), Enum.Material.Fabric)
end

-- Portão da floresta: grades de ferro dentro do mesmo Model (sobem junto quando o portão abre)
-- e pilares de pedra fixos. A placa original continua sendo a colisão, só que invisível.
local function forestGate(root: Instance)
	local model = root:FindFirstChild("ForestGate")
	local panel = model and model:FindFirstChild("Gate")
	if not model or not panel or not panel:IsA("BasePart") then
		return
	end
	panel.Transparency = 1
	local base = panel.CFrame
	local iron = rgb(46, 40, 58)
	for step = -8, 8, 1.6 do
		decor(model, "GateBar", Vector3.new(0.35, 10, 0.35), base * CFrame.new(step, 0, 0), iron, Enum.Material.Metal)
		decor(
			model,
			"GateSpike",
			Vector3.new(0.5, 0.8, 0.5),
			base * CFrame.new(step, 5.3, 0),
			rgb(255, 200, 70),
			Enum.Material.Metal
		)
	end
	for _, y in { -3.5, 3.5 } do
		decor(model, "GateRail", Vector3.new(18, 0.5, 0.5), base * CFrame.new(0, y, 0), iron, Enum.Material.Metal)
	end
	local folder = Build.folder(root, "GatePillars")
	for _, x in { -12.5, 12.5 } do
		local pillar =
			Build.part(folder, "GatePillar", Vector3.new(3, 13, 3), base * CFrame.new(x, 1.5, 0), rgb(120, 116, 140), {
				material = Enum.Material.Cobblestone,
			})
		pillar.CanQuery = false
		local orb = decor(
			folder,
			"GateLamp",
			Vector3.new(1.6, 1.6, 1.6),
			pillar.CFrame * CFrame.new(0, 7.4, 0),
			rgb(120, 255, 170),
			Enum.Material.Neon
		)
		local orbShape = orb :: Part
		orbShape.Shape = Enum.PartType.Ball
		glow(orb, rgb(120, 255, 170), 22, 1.2)
	end
end

local NIGHT_COLORS = { rgb(120, 200, 255), rgb(255, 150, 220), rgb(150, 255, 190), rgb(255, 210, 120) }
local RUG_COLORS = { rgb(160, 52, 72), rgb(52, 88, 150), rgb(64, 120, 84), rgb(130, 76, 150) }

local function interior(parent: Instance)
	local folder = Build.folder(parent, "Dressing")
	for index, room in House.Rooms do
		if room.id == "Exterior" or room.id == "Hall" then
			continue
		end
		local floor = room.y - 0.45
		local side = if room.x < 0 then -1 else 1
		-- Tapete no meio do cômodo.
		decor(
			folder,
			"Rug",
			Vector3.new(14, 0.08, 10),
			CFrame.new(room.x + side * 2, floor, room.z + 1),
			RUG_COLORS[(index % #RUG_COLORS) + 1],
			Enum.Material.Fabric
		)
		-- Quadros na parede do fundo do cômodo (lado oposto à porta).
		for slot = -1, 1, 2 do
			local frame = decor(
				folder,
				"PictureFrame",
				Vector3.new(0.3, 3.4, 2.8),
				CFrame.new(room.x + side * 17.3, room.y + 7, room.z + slot * 6),
				rgb(196, 150, 70),
				Enum.Material.Wood
			)
			decor(
				folder,
				"Picture",
				Vector3.new(0.32, 2.6, 2),
				frame.CFrame,
				NIGHT_COLORS[((index + slot) % #NIGHT_COLORS) + 1]:Lerp(rgb(40, 30, 60), 0.5),
				Enum.Material.SmoothPlastic
			)
		end
		-- Luz noturna colorida: o cômodo é legível mesmo sem energia (sem tela preta).
		local color = NIGHT_COLORS[(index % #NIGHT_COLORS) + 1]
		local hang = Vector3.new(room.x + side * 3, room.y + 12, room.z + 3)
		decor(folder, "Cord", Vector3.new(0.1, 2.5, 0.1), CFrame.new(hang + Vector3.new(0, 1.9, 0)), rgb(40, 34, 50))
		local orb = decor(folder, "NightLight", Vector3.new(1.4, 1.4, 1.4), CFrame.new(hang), color, Enum.Material.Neon)
		local orbShape = orb :: Part
		orbShape.Shape = Enum.PartType.Ball
		glow(orb, color, 26, 0.75)
	end
end

function Scenery.build(root: Instance)
	restyle(root)
	terrain()
	forest(root)
	exterior(root)
	facade(root)
	forestGate(root)
	interior(root)
	Furniture.build(root)
	local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
	if sky then
		sky.MoonAngularSize = 18
		sky.StarCount = 3000
	end
end

return Scenery
