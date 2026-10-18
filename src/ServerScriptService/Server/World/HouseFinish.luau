--!strict
--[[
	Acabamento arquitetônico da mansão (só visual), montado depois do HouseScenery:
	- forros e sancas no corredor e no hall, passadeiras, lambris com almofadas e rodapés;
	- almofadas e maçanetas nas portas (soldadas ao painel, que continua sendo o mesmo objeto interativo);
	- guarda-corpos maciços vestidos com almofadas e pilares.
	Móveis e luminárias com modelos 3D ficam em HouseProps; materiais PBR em HouseMaterials.

	Regras: nada colide, nada recebe raycast, nada fica entre a porta de entrada, o corredor e as escadas.
	Planta, tamanhos e nomes da arquitetura não mudam (HouseLayout/HouseCatalog continuam a referência).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local RUNNER_EDGE = rgb(40, 18, 20)

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

-- Porta vitoriana 3D (Assets/MansionProps/MansionDoor) envolvendo o painel; soldada, acompanha a animação.
-- O painel continua sendo a peça de colisão, prompt, som e PathfindingModifier.
local function doorModel(panel: BasePart): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("MansionProps")
	local template = library and library:FindFirstChild("MansionDoor")
	if not template or not template:IsA("Model") then
		return false
	end
	local model = template:Clone()
	-- Malha: largura em X, espessura em Z, origem no pé. Painel: largura em Z, espessura em X.
	model:PivotTo(panel.CFrame * CFrame.new(0, -panel.Size.Y / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.Massless = false, true
			part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = panel, part, part
		end
	end
	model.Parent = panel
	return true
end

-- Painéis em relevo e maçanetas nas duas faces; soldados ao painel, acompanham a animação da porta.
local function dressDoor(panel: BasePart)
	if doorModel(panel) then
		return
	end
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

local function runner(parent: Instance, name: string, center: Vector3, length: number)
	deco(
		parent,
		name .. "Edge",
		V3(7, 0.05, length + 1),
		CFrame.new(center + UP * 0.025),
		RUNNER_EDGE,
		Enum.Material.Fabric
	)
	deco(parent, name, V3(5.8, 0.07, length), CFrame.new(center + UP * 0.035), RUNNER, Enum.Material.Fabric)
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
	if y >= 0 then
		runner(parent, "CorridorRunner", V3(0, y, -36), 93)
	end
end

local function foyerCeiling(parent: Instance, y: number)
	local above: { Layout.Rect } = if y >= 32 then { table.clone(Layout.Bounds) } else Layout.decks(y + 16)
	for _, rect in above do
		local size = V3(rect.x1 - rect.x0 - 1, 0.1, rect.z1 - rect.z0 - 1)
		local center = V3((rect.x0 + rect.x1) / 2, y + 14.94, (rect.z0 + rect.z1) / 2)
		deco(parent, "FoyerCeilingPanel", size, CFrame.new(center), CEILING, Enum.Material.Plaster)
	end
	-- Medalhão de gesso onde pende o lustre.
	local medallion = deco(
		parent,
		"FinishMedallion",
		V3(0.12, 3.6, 3.6),
		CFrame.new(0, y + 14.83, 40),
		CEILING,
		Enum.Material.Plaster
	)
	medallion.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	local disc = medallion :: Part
	disc.Shape = Enum.PartType.Cylinder
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
	if y > 0 then
		runner(parent, "HallRunner", V3(0, y, 37), 45)
	end
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
	-- Entrada: passadeira até o corredor e capacho.
	runner(folder, "HallRunner", V3(0, 0, 37.5), 47)
	deco(folder, "HallDoormat", V3(8, 0.09, 2.6), CFrame.new(0, 0.045, 62), rgb(66, 54, 40), Enum.Material.Fabric)
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
