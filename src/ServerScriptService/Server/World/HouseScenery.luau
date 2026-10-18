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
local Exterior = require("./HouseExterior")
local Furniture = require("./HouseFurniture")
local Finish = require("./HouseFinish")
local Materials = require("./HouseMaterials")
local Props = require("./HouseProps")

local Scenery = {}

local rgb = Color3.fromRGB
local SEED = 90312

-- Projeção da casa (com folga): o terreno não entra aqui.
local HOUSE_MIN = Vector2.new(-48, -88)
local HOUSE_MAX = Vector2.new(48, 68)
-- Área livre de obstáculos: trilha da entrada até a saída da floresta.
local PATH_HALF_WIDTH = 22
local EXIT_Z = Vector2.new(60, 135)

local GRASS = rgb(61, 88, 64)
local WALL = rgb(133, 126, 117)
local WALL_DARK = rgb(112, 111, 105)
local ROOF = rgb(55, 58, 69)
local TRIM = rgb(183, 161, 119)
local FLOOR = rgb(92, 67, 49)
local WINDOW = rgb(206, 166, 112)

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
			part.Material = if part.Position.Y < 0 then Enum.Material.Brick else Enum.Material.Plaster
		elseif TRIM_NAMES[part.Name] then
			part.Color = TRIM
			part.Material = Enum.Material.Wood
		elseif FLOOR_NAMES[part.Name] then
			part.Color = FLOOR
		elseif part.Name == "RoomCeiling" then
			part.Material = Enum.Material.Plaster
		elseif part.Name == "HouseRoof" or part.Name == "StairRoof" then
			part.Color = ROOF
			part.Material = Enum.Material.Slate
		elseif part.Name == "WindowGlass" then
			-- Janelas acesas por dentro: a casa "chama" o jogador de longe.
			part.Color = WINDOW
			part.Material = Enum.Material.Glass
			part.Transparency = 0.3
		elseif GROUND_NAMES[part.Name] then
			part.Color = GRASS
			part.Material = Enum.Material.Grass
		elseif part.Name == "ForestGround" then
			part.Transparency = 1
		elseif part.Name == "Plaque" then
			local text = part:FindFirstChildWhichIsA("TextLabel", true)
			if text then
				text.Font = Enum.Font.SpecialElite
				text.TextColor3 = rgb(255, 214, 80)
				text.BackgroundColor3 = rgb(42, 34, 29)
			end
			part.Color = rgb(42, 34, 29)
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

-- Folhagem noturna, escura e pouco saturada (silhueta contra o céu, sem cara de brinquedo).
local LEAF_COLORS = { rgb(38, 64, 48), rgb(46, 74, 54), rgb(34, 58, 60), rgb(52, 70, 44) }
local BARK = rgb(64, 50, 42)

-- Construções do GeneratedEstate e cemitério nos jardins laterais: nenhuma árvore nasce dentro delas.
local OCCUPIED = {
	{ 60, 92, 8, 40 }, -- pavilhões leste/oeste (espelhados em x)
	{ 60, 92, -60, -28 },
	{ 83, 105, -4, 50 }, -- mirante e escada do jardim (o lado muda com o nível)
	{ -106, -88, 50, 78 }, -- cemitério (só oeste)
}

local function occupied(x: number, z: number): boolean
	for index, rect in OCCUPIED do
		local px = if index <= 3 then math.abs(x) else x
		if px > rect[1] and px < rect[2] and z > rect[3] and z < rect[4] then
			return true
		end
	end
	-- Cerca da frente (z = 80) e trilha do jardim.
	return math.abs(z - 80) < 4
end

local function tree(parent: Instance, position: Vector3, height: number, rng: Random)
	local model = Build.model(parent, "Tree")
	local trunk = Build.cylinder(
		model,
		"Trunk",
		position + Vector3.new(0, height / 2, 0),
		Vector3.yAxis,
		height,
		2.6,
		BARK,
		{ material = Enum.Material.Wood }
	)
	trunk.CanQuery = false
	local color = LEAF_COLORS[rng:NextInteger(1, #LEAF_COLORS)]
	local crown = position + Vector3.new(0, height, 0)
	ball(model, "Crown", crown, rng:NextNumber(12, 16), color, Enum.Material.LeafyGrass)
	for _ = 1, 3 do
		local offset = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-3, 3), rng:NextNumber(-5, 5))
		ball(
			model,
			"Crown",
			crown + offset,
			rng:NextNumber(7, 11),
			color:Lerp(rgb(14, 24, 20), 0.2),
			Enum.Material.LeafyGrass
		)
	end
end

-- Árvore seca de galhos retorcidos (jardim da casa). Só o tronco colide, como as árvores antigas.
local function deadTree(parent: Instance, position: Vector3, height: number, rng: Random)
	local model = Build.model(parent, "Tree")
	local trunk = Build.cylinder(
		model,
		"Trunk",
		position + Vector3.new(0, height / 2, 0),
		Vector3.yAxis,
		height,
		2.2,
		BARK,
		{ material = Enum.Material.Wood }
	)
	trunk.CanQuery = false
	local function branch(from: Vector3, direction: Vector3, length: number, diameter: number, depth: number)
		local tip = from + direction * length
		local part = Build.cylinder(model, "Branch", (from + tip) / 2, direction, length, diameter, BARK, {
			material = Enum.Material.Wood,
			collide = false,
			query = false,
		})
		part.CanTouch = false
		if depth <= 0 then
			return
		end
		for _ = 1, 2 do
			local bend = Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.1, 0.7), rng:NextNumber(-0.8, 0.8))
			branch(tip, (direction + bend).Unit, length * 0.62, diameter * 0.6, depth - 1)
		end
	end
	for index = 1, 4 do
		local angle = index * math.pi / 2 + rng:NextNumber(-0.5, 0.5)
		local out = Vector3.new(math.cos(angle), rng:NextNumber(0.5, 1.1), math.sin(angle)).Unit
		branch(position + Vector3.yAxis * height * rng:NextNumber(0.55, 0.95), out, height * 0.32, 1.1, 1)
	end
end

local function forest(parent: Instance)
	-- Não pode se chamar "Forest": ForestBuilder.clear apaga essa pasta a cada capítulo.
	local folder = Build.folder(parent, "GardenTrees")
	local rng = Random.new(SEED + 1)
	-- Mesmos lugares das árvores antigas do jardim lateral, sem as que caíam dentro dos pavilhões.
	for i = 1, 28 do
		local x = if i % 2 == 0 then -67 - i % 4 * 8 else 67 + i % 4 * 8
		local z = -105 + i * 8
		if not occupied(x, z) then
			if i % 3 == 0 then
				tree(folder, Vector3.new(x, -0.5, z), 20 + i % 4 * 2, rng)
			else
				deadTree(folder, Vector3.new(x, -0.5, z), 18 + i % 4 * 2, rng)
			end
		end
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
		if not inside(x, z, 6) and not onPath(x, z) and not occupied(x, z) then
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

local function fireflies(parent: Instance, center: Vector3, spread: Vector3)
	local anchor = decor(parent, "Fireflies", spread, CFrame.new(center), rgb(0, 0, 0))
	anchor.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter:SetAttribute("VisualOptional", true)
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

local function exterior(parent: Instance)
	local folder = Build.folder(parent, "Yard")
	-- Fachada, varanda, caminho, postes, abóboras e lápides ficam em HouseExterior.
	fireflies(folder, Vector3.new(0, 4, 100), Vector3.new(60, 6, 50))
	fireflies(folder, Vector3.new(-80, 4, 0), Vector3.new(30, 6, 160))
	fireflies(folder, Vector3.new(80, 4, 0), Vector3.new(30, 6, 160))
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
			Build.part(folder, "GatePillar", Vector3.new(3, 13, 3), base * CFrame.new(x, 1.5, 0), rgb(96, 62, 52), {
				material = Enum.Material.Brick,
			})
		pillar.CanQuery = false
		-- Capitel de pedra e lanterna de ferro no topo (a luz continua na esfera, agora invisível).
		decor(
			folder,
			"GatePillarCap",
			Vector3.new(3.8, 0.7, 3.8),
			pillar.CFrame * CFrame.new(0, 6.85, 0),
			rgb(118, 114, 106),
			Enum.Material.Slate
		)
		local orb = decor(
			folder,
			"GateLamp",
			Vector3.new(1.6, 1.6, 1.6),
			pillar.CFrame * CFrame.new(0, 8.6, 0),
			rgb(219, 182, 124),
			Enum.Material.Neon
		)
		local orbShape = orb :: Part
		orbShape.Shape = Enum.PartType.Ball
		if
			Props.place(
				folder,
				"Lantern",
				(pillar.CFrame * CFrame.new(0, 7.2, 0)).Position,
				base.LookVector,
				2.2,
				"floor"
			)
		then
			orb.Transparency = 1
		end
		glow(orb, rgb(235, 193, 133), 18, 0.65)
	end
end

local NIGHT_COLORS = { rgb(148, 178, 207), rgb(193, 152, 154), rgb(153, 184, 161), rgb(221, 187, 137) }
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
		glow(orb, color:Lerp(rgb(235, 216, 188), 0.65), 23, 0.35)
	end
end

function Scenery.build(root: Instance)
	restyle(root)
	terrain()
	forest(root)
	exterior(root)
	forestGate(root)
	interior(root)
	Furniture.build(root)
	Finish.build(root)
	Props.build(root)
	Materials.build(root)
	Exterior.build(root)
	local sky = game:GetService("Lighting"):FindFirstChildOfClass("Sky")
	if sky then
		sky.MoonAngularSize = 18
		sky.StarCount = 3000
	end
end

return Scenery
