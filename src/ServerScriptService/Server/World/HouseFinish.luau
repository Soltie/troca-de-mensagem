--!strict
--[[
	Acabamento da mansão (só visual), montado depois do HouseScenery:
	- forros e sancas no corredor e no hall, passadeiras e quadros;
	- almofadas e maçanetas nas portas (soldadas ao painel, que continua sendo o mesmo objeto interativo);
	- hall de entrada com lambri, lustre, relógio de pêndulo, aparador com espelho e banco.

	Regras: nada colide, nada recebe raycast, nada fica entre a porta de entrada, o corredor e as escadas.
	Planta, tamanhos e nomes da arquitetura não mudam (HouseLayout/HouseCatalog continuam a referência).
]]

local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Build = require("./Build")

local Finish = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local UP = Vector3.yAxis

local CEILING = rgb(146, 136, 121)
local WOOD = rgb(70, 45, 32)
local WOOD_LIGHT = rgb(92, 61, 42)
local TRIM = rgb(150, 122, 86)
local BRASS = rgb(168, 132, 70)
local RUNNER = rgb(92, 30, 34)
local RUNNER_EDGE = rgb(54, 22, 24)
local WARM = rgb(255, 196, 132)
-- Retratos escurecidos pelo tempo: legíveis como pintura, sem competir com as pistas.
local CANVASES = { rgb(104, 92, 84), rgb(118, 96, 70), rgb(78, 96, 90), rgb(120, 82, 78) }

local function deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	detail: boolean?
): BasePart
	local part = Build.part(parent, name, size, cframe, color, {
		material = material or Enum.Material.Wood,
		collide = false,
		query = false,
	})
	part.CanTouch = false
	if detail then
		part:SetAttribute("VisualDetail", true)
	end
	return part
end

local function ball(
	parent: Instance,
	name: string,
	center: Vector3,
	diameter: number,
	color: Color3,
	material: Enum.Material
)
	local part = deco(parent, name, V3(diameter, diameter, diameter), CFrame.new(center), color, material, true);
	(part :: Part).Shape = Enum.PartType.Ball
	return part
end

local function disc(
	parent: Instance,
	name: string,
	center: Vector3,
	diameter: number,
	height: number,
	color: Color3,
	material: Enum.Material
)
	local part = deco(
		parent,
		name,
		V3(height, diameter, diameter),
		CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		material
	);
	(part :: Part).Shape = Enum.PartType.Cylinder
	return part
end

-- Faixa ao longo de uma parede: `from`/`to` no pé da parede, `normal` aponta para dentro do cômodo.
local function wallRun(parent: Instance, from: Vector3, to: Vector3, normal: Vector3, panels: boolean)
	local span = to - from
	local length = span.Magnitude
	local along = span.Unit
	local middle = (from + to) / 2
	local function strip(name: string, bottom: number, height: number, depth: number, out: number, color: Color3)
		local center = middle + UP * (bottom + height / 2) + normal * (out + depth / 2)
		return deco(parent, name, V3(length, height, depth), CFrame.fromMatrix(center, along, UP), color)
	end
	strip("FinishWainscot", 0, 3.6, 0.1, 0, WOOD)
	strip("FinishSkirting", 0, 0.8, 0.12, 0.1, WOOD:Lerp(rgb(0, 0, 0), 0.25))
	strip("FinishChairRail", 3.5, 0.22, 0.2, 0.1, TRIM)
	if not panels then
		return
	end
	local count = math.max(1, math.floor(length / 3.4))
	local step = length / count
	for index = 1, count do
		local center = from + along * (step * (index - 0.5)) + UP * 2.2 + normal * 0.13
		deco(
			parent,
			"FinishPanel",
			V3(step - 0.6, 2.2, 0.06),
			CFrame.fromMatrix(center, along, UP),
			WOOD_LIGHT,
			nil,
			true
		)
	end
end

-- Quadro pendurado: `center` na face da parede, `normal` para dentro do cômodo.
local function picture(parent: Instance, center: Vector3, normal: Vector3, size: Vector2, canvas: Color3)
	local right = normal:Cross(UP)
	local frame = CFrame.fromMatrix(center + normal * 0.07, right, UP)
	deco(parent, "FinishFrame", V3(size.X, size.Y, 0.12), frame, BRASS:Lerp(WOOD, 0.35))
	deco(parent, "FinishCanvas", V3(size.X - 0.5, size.Y - 0.5, 0.14), frame, canvas, Enum.Material.SmoothPlastic, true)
end

local function chandelier(parent: Instance, ceiling: Vector3, radius: number, range: number, brightness: number)
	disc(
		parent,
		"FinishMedallion",
		ceiling - UP * 0.08,
		radius * 1.4,
		0.12,
		CEILING:Lerp(TRIM, 0.3),
		Enum.Material.Plaster
	)
	local drop = 2.6
	deco(
		parent,
		"FinishChain",
		V3(0.12, drop, 0.12),
		CFrame.new(ceiling - UP * (drop / 2)),
		rgb(40, 34, 30),
		Enum.Material.Metal
	)
	local hub = ceiling - UP * (drop + 0.4)
	local body = deco(parent, "HallChandelier", V3(0.7, 1.1, 0.7), CFrame.new(hub), BRASS, Enum.Material.Metal)
	Build.light(body, "Street", WARM, range, brightness, true, true)
	disc(parent, "FinishChandelierRing", hub - UP * 0.5, radius * 2, 0.18, BRASS, Enum.Material.Metal)
	for index = 1, 6 do
		local angle = index / 6 * math.pi * 2
		local spot = hub + V3(math.cos(angle) * radius, -0.25, math.sin(angle) * radius)
		deco(
			parent,
			"FinishCandle",
			V3(0.22, 0.55, 0.22),
			CFrame.new(spot),
			rgb(232, 222, 198),
			Enum.Material.SmoothPlastic,
			true
		)
		deco(parent, "FinishBulb", V3(0.16, 0.22, 0.16), CFrame.new(spot + UP * 0.38), WARM, Enum.Material.Neon, true)
	end
end

local function clock(parent: Instance, base: Vector3)
	-- Relógio de pêndulo encostado na parede leste (frente para -X), parado às 03:12.
	local face = -Vector3.xAxis
	local function box(name: string, size: Vector3, y: number, color: Color3, material: Enum.Material?)
		return deco(parent, name, size, CFrame.new(base + UP * (y + size.Y / 2)), color, material)
	end
	box("ClockPlinth", V3(1.3, 1.2, 2.3), 0, WOOD)
	box("ClockCase", V3(1.1, 5, 1.8), 1.2, WOOD_LIGHT)
	box("ClockHood", V3(1.3, 1.9, 2.2), 6.2, WOOD)
	box("ClockCrown", V3(1.4, 0.35, 2.5), 8.1, TRIM)
	local dial = base + UP * 7.15 + face * 0.66
	disc(parent, "ClockDial", dial, 1.5, 0.05, rgb(222, 210, 180), Enum.Material.SmoothPlastic).CFrame =
		CFrame.new(dial)
	local hands = { { angle = (3 + 12 / 60) * 30, length = 0.42 }, { angle = 12 * 6, length = 0.62 } }
	for _, hand in hands do
		local theta = math.rad(hand.angle)
		local direction = UP * math.cos(theta) + Vector3.zAxis * math.sin(theta)
		local center = dial + face * 0.05 + direction * (hand.length / 2)
		deco(
			parent,
			"ClockHand",
			V3(0.04, hand.length, 0.07),
			CFrame.new(center) * CFrame.Angles(theta, 0, 0),
			rgb(30, 26, 24),
			Enum.Material.Metal,
			true
		)
	end
	local glass = deco(
		parent,
		"ClockWindow",
		V3(0.05, 2.8, 1),
		CFrame.new(base + UP * 3.9 + face * 0.57),
		rgb(120, 130, 128),
		Enum.Material.Glass
	)
	glass.Transparency = 0.55
	local bob = base + UP * 3 + face * 0.4
	disc(parent, "ClockPendulum", bob, 0.6, 0.06, BRASS, Enum.Material.Metal).CFrame = CFrame.new(bob)
	deco(parent, "ClockRod", V3(0.04, 2, 0.06), CFrame.new(bob + UP * 1.2), BRASS, Enum.Material.Metal, true)
end

-- Painéis em relevo e maçanetas nas duas faces; soldados ao painel, acompanham a animação da porta.
local function dressDoor(panel: BasePart)
	local function attach(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?
	)
		local part = deco(panel, name, size, panel.CFrame * offset, color, material, true)
		if shape then
			(part :: Part).Shape = shape
		end
		part.Anchored, part.Massless = false, true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = panel, part, part
	end
	local half = panel.Size.X / 2
	for _, side in { -1, 1 } do
		attach(
			"DoorPanelUpper",
			V3(0.06, 3.4, panel.Size.Z - 2),
			CFrame.new(side * (half + 0.03), 2.6, 0),
			WOOD_LIGHT,
			Enum.Material.Wood
		)
		attach(
			"DoorPanelLower",
			V3(0.06, 4.6, panel.Size.Z - 2),
			CFrame.new(side * (half + 0.03), -2.3, 0),
			WOOD_LIGHT,
			Enum.Material.Wood
		)
		attach(
			"DoorKnob",
			V3(0.42, 0.42, 0.42),
			CFrame.new(side * (half + 0.22), -0.4, panel.Size.Z / 2 - 0.9),
			BRASS,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
	end
end

-- Guarda-corpo maciço dos vãos: almofadas nas duas faces e pilares nas pontas (a peça de colisão fica igual).
local function dressGuard(parent: Instance, guard: BasePart)
	local size, cf = guard.Size, guard.CFrame
	local count = math.max(1, math.floor(size.Z / 3.6))
	local step = size.Z / count
	for _, side in { -1, 1 } do
		for index = 1, count do
			local z = -size.Z / 2 + step * (index - 0.5)
			deco(
				parent,
				"GuardPanel",
				V3(0.05, size.Y - 1.2, step - 0.6),
				cf * CFrame.new(side * (size.X / 2 + 0.025), -0.1, z),
				WOOD_LIGHT,
				nil,
				true
			)
		end
	end
	for _, z in { -size.Z / 2, size.Z / 2 } do
		deco(parent, "GuardNewel", V3(0.8, size.Y + 0.8, 0.8), cf * CFrame.new(0, 0.4, z), WOOD)
		deco(parent, "GuardNewelCap", V3(1, 0.3, 1), cf * CFrame.new(0, size.Y / 2 + 0.95, z), TRIM)
	end
end

local function corridor(parent: Instance, y: number)
	local length = 96.5
	local centerZ = -36.25
	deco(
		parent,
		"CorridorCeilingPanel",
		V3(15, 0.1, length),
		CFrame.new(0, y + 14.94, centerZ),
		CEILING,
		Enum.Material.Plaster
	)
	for _, side in { -1, 1 } do
		deco(parent, "CorridorCrown", V3(0.3, 0.45, length), CFrame.new(side * 7.32, y + 14.6, centerZ), TRIM)
	end
	if y < 0 then
		return
	end
	deco(
		parent,
		"CorridorRunnerEdge",
		V3(6.6, 0.05, 94),
		CFrame.new(0, y + 0.025, -36),
		RUNNER_EDGE,
		Enum.Material.Fabric
	)
	deco(parent, "CorridorRunner", V3(5.4, 0.07, 93), CFrame.new(0, y + 0.035, -36), RUNNER, Enum.Material.Fabric)
	-- Um quadro por cômodo, no trecho de parede sem a placa do cômodo.
	for _, side in { -1, 1 } do
		for row = 1, 3 do
			local z = 28 - row * 32 - 10.5
			local canvas = CANVASES[(row + (if side > 0 then 1 else 0) + y // 16) % #CANVASES + 1]
			picture(parent, V3(side * 7.5, y + 7, z), V3(-side, 0, 0), Vector2.new(3, 3.6), canvas)
		end
	end
end

local function foyerCeiling(parent: Instance, y: number)
	local above: { Layout.Rect } = if y >= 32 then { table.clone(Layout.Bounds) } else Layout.decks(y + 16)
	for _, rect in above do
		local size = V3(rect.x1 - rect.x0 - 1, 0.1, rect.z1 - rect.z0 - 1)
		local center = V3((rect.x0 + rect.x1) / 2, y + 14.94, (rect.z0 + rect.z1) / 2)
		deco(parent, "FoyerCeilingPanel", size, CFrame.new(center), CEILING, Enum.Material.Plaster)
	end
end

local function foyerWalls(parent: Instance, y: number)
	local ground = y == 0
	local b = Layout.Bounds
	local west, east, front = b.x0 + 0.5, b.x1 - 0.5, b.z1 - 0.5
	-- Parede da frente (entrada só no térreo) e laterais da caixa da escada.
	if ground then
		wallRun(parent, V3(west, y, front), V3(-6.3, y, front), -Vector3.zAxis, true)
		wallRun(parent, V3(6.3, y, front), V3(east, y, front), -Vector3.zAxis, true)
	else
		wallRun(parent, V3(west, y, front), V3(east, y, front), -Vector3.zAxis, false)
	end
	wallRun(parent, V3(west, y, b.z0 + 0.5), V3(west, y, front), Vector3.xAxis, ground)
	wallRun(parent, V3(east, y, b.z0 + 0.5), V3(east, y, front), -Vector3.xAxis, ground)
	-- Fundo do hall: frente dos cômodos (abaixo das janelas), dos dois lados do corredor.
	wallRun(parent, V3(west, y, 12.5), V3(-8.5, y, 12.5), Vector3.zAxis, ground)
	wallRun(parent, V3(8.5, y, 12.5), V3(east, y, 12.5), Vector3.zAxis, ground)
end

local function entranceHall(parent: Instance)
	-- Passadeira da porta até o corredor e capacho na entrada.
	deco(parent, "HallRunnerEdge", V3(7.4, 0.05, 48), CFrame.new(0, 0.025, 37.5), RUNNER_EDGE, Enum.Material.Fabric)
	deco(parent, "HallRunner", V3(6.2, 0.07, 47), CFrame.new(0, 0.035, 37.5), RUNNER, Enum.Material.Fabric)
	deco(parent, "HallDoormat", V3(8, 0.09, 2.6), CFrame.new(0, 0.045, 62), rgb(66, 54, 40), Enum.Material.Fabric)
	chandelier(parent, V3(0, 15, 40), 1.9, 34, 0.75)
	-- Arandelas ao lado da porta.
	for _, x in { -8.5, 8.5 } do
		local sconce =
			deco(parent, "HallSconce", V3(0.6, 1.1, 0.5), CFrame.new(x, 7.2, 63.2), BRASS, Enum.Material.Metal)
		Build.light(sconce, "Street", WARM, 16, 0.45, true)
		deco(parent, "FinishBulb", V3(0.35, 0.45, 0.35), CFrame.new(x, 7.95, 63.05), WARM, Enum.Material.Neon, true)
	end
	-- Aparador com espelho à direita da porta (o lado esquerdo é a descida do porão).
	local consoleX = 15
	deco(parent, "ConsoleTop", V3(5.4, 0.25, 1.5), CFrame.new(consoleX, 3.1, 62.6), WOOD_LIGHT)
	deco(parent, "ConsoleApron", V3(5.2, 0.6, 1.3), CFrame.new(consoleX, 2.7, 62.65), WOOD)
	for _, dx in { -2.4, 2.4 } do
		deco(parent, "ConsoleLeg", V3(0.25, 2.4, 0.25), CFrame.new(consoleX + dx, 1.2, 62.2), WOOD)
	end
	deco(parent, "MirrorFrame", V3(3.6, 4.4, 0.15), CFrame.new(consoleX, 6.4, 63.4), BRASS:Lerp(WOOD, 0.3))
	local mirror = deco(
		parent,
		"Mirror",
		V3(3, 3.8, 0.16),
		CFrame.new(consoleX, 6.4, 63.38),
		rgb(150, 160, 162),
		Enum.Material.Glass
	)
	mirror.Reflectance = 0.25
	local lamp = deco(
		parent,
		"Candle",
		V3(0.3, 0.9, 0.3),
		CFrame.new(consoleX - 1.8, 3.7, 62.6),
		rgb(236, 226, 204),
		Enum.Material.SmoothPlastic
	)
	Build.light(lamp, "Street", WARM, 12, 0.5, true, true)
	deco(
		parent,
		"FinishBulb",
		V3(0.14, 0.24, 0.14),
		CFrame.new(consoleX - 1.8, 4.27, 62.6),
		WARM,
		Enum.Material.Neon,
		true
	)
	deco(parent, "ConsoleBox", V3(1.2, 0.5, 0.8), CFrame.new(consoleX + 1.4, 3.48, 62.6), rgb(60, 40, 34))
	-- Canto leste (ao lado da escada principal): relógio, banco, quadros e plantas.
	clock(parent, V3(43.6, 0, 30))
	deco(parent, "BenchSeat", V3(2, 0.35, 6), CFrame.new(43, 1.8, 46), WOOD_LIGHT)
	deco(parent, "BenchCushion", V3(1.8, 0.25, 5.6), CFrame.new(43, 2.1, 46), rgb(86, 40, 44), Enum.Material.Fabric)
	deco(parent, "BenchBack", V3(0.3, 2.6, 6), CFrame.new(44.2, 3.2, 46), WOOD)
	for _, dz in { -2.7, 2.7 } do
		deco(parent, "BenchLeg", V3(1.8, 1.6, 0.3), CFrame.new(43, 0.8, 46 + dz), WOOD)
	end
	for _, z in { 20, 38 } do
		picture(parent, V3(44.5, 7.5, z), -Vector3.xAxis, Vector2.new(3.4, 4.4), CANVASES[(z // 10) % #CANVASES + 1])
	end
	picture(parent, V3(44.5, 7.8, 46), -Vector3.xAxis, Vector2.new(5, 3.2), CANVASES[1])
	picture(parent, V3(-15, 7.5, 63.5), -Vector3.zAxis, Vector2.new(4, 3), CANVASES[3])
	for _, spot in { V3(41.8, 0, 56), V3(41.8, 0, 24) } do
		deco(parent, "PlanterPot", V3(1.6, 1.6, 1.6), CFrame.new(spot + UP * 0.8), rgb(84, 62, 52), Enum.Material.Slate)
		ball(parent, "PlanterLeaves", spot + UP * 2.6, 2.6, rgb(38, 62, 42), Enum.Material.Grass)
	end
	-- O canto fica atrás da escada: luz própria, senão vira mancha preta.
	deco(
		parent,
		"FloorLampPole",
		V3(0.22, 5.2, 0.22),
		CFrame.new(42.6, 2.6, 51.2),
		rgb(40, 34, 30),
		Enum.Material.Metal
	)
	deco(parent, "FloorLampBase", V3(1.2, 0.2, 1.2), CFrame.new(42.6, 0.1, 51.2), rgb(40, 34, 30), Enum.Material.Metal)
	local shade = deco(
		parent,
		"HallLampShade",
		V3(1.6, 1.3, 1.6),
		CFrame.new(42.6, 5.6, 51.2),
		rgb(196, 160, 118),
		Enum.Material.Fabric
	)
	Build.light(shade, "Street", WARM, 20, 0.6, true)
	for _, z in { 26, 34 } do
		local sconce =
			deco(parent, "HallSconce", V3(0.5, 1, 0.6), CFrame.new(44.25, 7.4, z), BRASS, Enum.Material.Metal)
		Build.light(sconce, "Street", WARM, 18, 0.45, true)
		deco(parent, "FinishBulb", V3(0.35, 0.45, 0.35), CFrame.new(44.05, 8.1, z), WARM, Enum.Material.Neon, true)
	end
	-- Cabideiro perto da porta.
	deco(parent, "CoatRackPole", V3(0.25, 6.5, 0.25), CFrame.new(41.5, 3.25, 61.5), WOOD)
	deco(parent, "CoatRackBase", V3(1.6, 0.2, 1.6), CFrame.new(41.5, 0.1, 61.5), WOOD)
	deco(parent, "Coat", V3(0.8, 2.6, 1.2), CFrame.new(41.5, 4.8, 61.9), rgb(48, 44, 52), Enum.Material.Fabric)
end

function Finish.build(root: Instance)
	local old = root:FindFirstChild("Finish")
	if old then
		old:Destroy()
	end
	local folder = Build.folder(root, "Finish")
	for _, y in Layout.Floors do
		corridor(folder, y)
		foyerCeiling(folder, y)
		if y >= 0 then
			foyerWalls(folder, y)
		end
	end
	entranceHall(folder)
	-- Pendentes nos patamares de cima e lâmpada nua no porão.
	for _, y in { 16, 32 } do
		chandelier(folder, V3(0, y + 15, 40), 1.3, 26, 0.55)
		deco(
			folder,
			"HallRunnerEdge",
			V3(7.4, 0.05, 46),
			CFrame.new(0, y + 0.025, 37),
			RUNNER_EDGE,
			Enum.Material.Fabric
		)
		deco(folder, "HallRunner", V3(6.2, 0.07, 45), CFrame.new(0, y + 0.035, 37), RUNNER, Enum.Material.Fabric)
	end
	local bulb =
		deco(folder, "BasementBulb", V3(0.6, 0.8, 0.6), CFrame.new(0, -4.5, 40), rgb(255, 214, 160), Enum.Material.Neon)
	Build.light(bulb, "Street", rgb(255, 190, 130), 24, 0.55, true, true)
	deco(folder, "FinishChain", V3(0.08, 3.5, 0.08), CFrame.new(0, -2.35, 40), rgb(40, 34, 30), Enum.Material.Metal)
	local architecture = root:FindFirstChild("Architecture")
	if architecture then
		for _, part in architecture:GetChildren() do
			if part:IsA("BasePart") and part.Name == "LandingGuard" then
				dressGuard(folder, part)
			end
		end
	end
	local doors = root:FindFirstChild("Doors")
	if doors then
		for _, panel in doors:GetChildren() do
			if panel:IsA("BasePart") and string.sub(panel.Name, 1, 11) == "house_door_" then
				dressDoor(panel)
			end
		end
	end
end

return Finish
