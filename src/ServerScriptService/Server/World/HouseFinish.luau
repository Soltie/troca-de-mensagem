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
local TweenService = game:GetService("TweenService")

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

--[[
	Porta dupla (Assets/MansionProps/DoorLeaf, modelo Hyper3D escolhido pelo usuário em 19/10): o vão de 10 studs
	recebe duas folhas de 5 × 11,5, cada uma girando na sua ombreira; a folha B gira
	espelhada na outra ombreira, no mesmo ângulo do painel, e as duas abrem para o mesmo lado. Cada folha mostra a
	maçaneta numa face, junto ao encontro das duas. O painel fica invisível, mas continua sendo a colisão, o prompt,
	o som e o PathfindingModifier. Sem a folha na biblioteca, cai na porta de uma folha abaixo.
]]
local function doubleDoor(panel: BasePart): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("MansionProps")
	local template = library and library:FindFirstChild("DoorLeaf")
	local source = template and template:FindFirstChild("Leaf")
	if not template or not source or not source:IsA("MeshPart") or not template:GetAttribute("HandleAtMinusX") then
		return false
	end
	local half = panel.Size.Z / 2
	-- O painel gira em torno da ombreira −Z (ponto fixo); fechado, não tem rotação (HouseBuilder).
	local closed = CFrame.new(panel.CFrame * Vector3.new(0, 0, -half) + Vector3.new(0, 0, half))
	-- As folhas preenchem o vão da parede (HouseBuilder: 10 de largura, verga a 11,5), não só o painel de 9 × 11:
	-- sem fresta nas laterais nem em cima.
	local width = panel.Size.Z + 1
	local height = panel.Size.Y + 0.5
	local thickness = panel.Size.X + 0.06
	local function leaf(name: string): MeshPart
		local part = source:Clone()
		part.Name = name
		part.Size = Vector3.new(width / 2 - 0.04, height - 0.04, thickness)
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.Parent = panel
		return part
	end
	-- Cada folha gira na sua ombreira. Maçaneta no −X da malha: nas duas ela fica no encontro, no meio do vão.
	local lift = (height - panel.Size.Y) / 2
	local leaves: { { part: MeshPart, hinge: CFrame, rest: CFrame, sign: number } } = {}
	local function hang(name: string, side: number)
		local hinge = closed * CFrame.new(0, 0, side * width / 2)
		local rest = hinge:Inverse()
			* (closed * CFrame.new(0, lift, side * width / 4) * CFrame.Angles(0, -side * math.pi / 2, 0))
		table.insert(leaves, { part = leaf(name), hinge = hinge, rest = rest, sign = -side })
	end
	hang("DoorLeafA", -1)
	hang("DoorLeafB", 1)
	local _, yaw0 = panel.CFrame:ToEulerAnglesYXZ()
	-- O WorldService gira o painel em passos; as folhas seguem o ângulo com uma interpolação curta.
	local angle = Instance.new("NumberValue")
	angle.Name, angle.Parent = "DoorLeafAngle", leaves[2].part
	local function pose(value: number)
		for _, item in leaves do
			item.part.CFrame = item.hinge * CFrame.Angles(0, item.sign * value, 0) * item.rest
		end
	end
	angle.Changed:Connect(pose)
	angle.Value = yaw0
	pose(yaw0)
	local follow = TweenInfo.new(1 / 15, Enum.EasingStyle.Linear)
	panel:GetPropertyChangedSignal("CFrame"):Connect(function()
		local _, yaw = panel.CFrame:ToEulerAnglesYXZ()
		TweenService:Create(angle, follow, { Value = yaw }):Play()
	end)
	panel.Transparency = 1
	return true
end

-- Porta vitoriana 3D (Assets/MansionProps/MansionDoor) envolvendo o painel; soldada, acompanha a animação.
-- O painel continua sendo a peça de colisão, prompt, som e PathfindingModifier.
local function doorModel(panel: BasePart): boolean
	if doubleDoor(panel) then
		return true
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("MansionProps")
	local template = library and library:FindFirstChild("MansionDoor")
	if not template or not template:IsA("Model") then
		return false
	end
	local model = template:Clone()
	-- Malha: largura em X, espessura em Z. Painel: largura em Z, espessura em X. Centros alinhados.
	model:PivotTo(panel.CFrame * CFrame.Angles(0, -math.pi / 2, 0))
	local box = model:GetBoundingBox()
	model:PivotTo(model:GetPivot() + (panel.Position - box.Position))
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

--[[
	Escada bloqueada pela missão: o volume de colisão (HouseAccess, "upstairs") continua o mesmo, só fica
	invisível. Nas duas pontas de cada lance entra uma barricada de tábuas pregadas com placa; ela aparece
	enquanto o volume colide e some junto quando a missão libera a escada.
]]
local BOARDS = rgb(118, 94, 72)

local function barricade(parent: Instance, base: Vector3, facing: Vector3, width: number): { BasePart }
	local items: { BasePart } = {}
	local frame = CFrame.lookAt(base, base + facing)
	local function board(name: string, size: Vector3, offset: CFrame, color: Color3)
		table.insert(items, deco(parent, name, size, frame * offset, color, Enum.Material.WoodPlanks))
	end
	for _, side in { -1, 1 } do
		board("BarricadePost", V3(0.6, 7.4, 0.6), CFrame.new(side * (width / 2 - 0.3), 3.7, 0), WOOD)
	end
	for index, y in { 1.4, 3.1, 4.9, 6.5 } do
		local tilt = math.rad(if index % 2 == 0 then 7 else -5)
		board("BarricadeBoard", V3(width + 1.2, 0.85, 0.22), CFrame.new(0, y, -0.4) * CFrame.Angles(0, 0, tilt), BOARDS)
	end
	-- X de tábuas por cima: lê como "interditado" de longe.
	for _, angle in { 38, -38 } do
		board(
			"BarricadeBoard",
			V3(math.sqrt(width * width + 36), 0.8, 0.22),
			CFrame.new(0, 3.8, -0.65) * CFrame.Angles(0, 0, math.rad(angle)),
			BOARDS:Lerp(WOOD, 0.3)
		)
	end
	local sign = Build.sign(
		parent,
		"BarricadeSign",
		(frame * CFrame.new(0, 5.6, -0.85)).Position,
		facing,
		Vector2.new(4.4, 1.1),
		"INTERDITADO",
		{
			textColor = rgb(232, 214, 180),
			background = rgb(70, 26, 22),
			font = Enum.Font.SpecialElite,
		}
	)
	sign.CanCollide, sign.CanQuery, sign.CanTouch = false, false, false
	table.insert(items, sign)
	return items
end

local function stairBarriers(root: Instance, folder: Instance)
	local barriers = root:FindFirstChild("ProgressionBarriers")
	local architecture = root:FindFirstChild("Architecture")
	if not barriers or not architecture then
		return
	end
	local rays = RaycastParams.new()
	rays.FilterType = Enum.RaycastFilterType.Include
	rays.FilterDescendantsInstances = { architecture }
	for _, part in barriers:GetChildren() do
		if not part:IsA("BasePart") or part.Name ~= "upstairs" then
			continue
		end
		local items: { BasePart } = {}
		for _, side in { -1, 1 } do
			local z = part.Position.Z + side * (part.Size.Z / 2 - 0.4)
			local top = part.Position.Y + part.Size.Y / 2
			local hit = workspace:Raycast(V3(part.Position.X, top, z), V3(0, -(part.Size.Y + 2), 0), rays)
			local floor = if hit then hit.Position.Y else part.Position.Y - part.Size.Y / 2
			-- Só onde a escada encosta nesse chão: na ponta de cima o raio passa pelo vão e cai no térreo, e a
			-- barricada ficava solta no hall, na frente da porta, sem escada nenhuma.
			local step = workspace:Raycast(V3(part.Position.X, top, z - side * 2), V3(0, -(part.Size.Y + 2), 0), rays)
			if not step or step.Position.Y - floor > 3 then
				continue
			end
			for _, item in barricade(folder, V3(part.Position.X, floor, z), V3(0, 0, side), part.Size.X - 0.6) do
				table.insert(items, item)
			end
		end
		local function sync()
			if part.Transparency ~= 1 then
				part.Transparency = 1
			end
			for _, item in items do
				item.Transparency = if part.CanCollide then 0 else 1
				local gui = item:FindFirstChildWhichIsA("SurfaceGui")
				if gui then
					gui.Enabled = part.CanCollide
				end
			end
		end
		part:GetPropertyChangedSignal("CanCollide"):Connect(sync)
		part:GetPropertyChangedSignal("Transparency"):Connect(sync)
		sync()
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
	-- Forro dos cômodos logo abaixo do teto (o piso de cima e o teto antigo coincidem e piscam).
	-- Os cômodos do 1º andar no fundo (z = -68) ficam sem forro: a escada de serviço pode abrir esse teto.
	for _, y in Layout.Floors do
		for _, side in { -1, 1 } do
			for row = 1, 3 do
				local z = 28 - row * 32
				if not (y == 16 and z == -68) then
					deco(
						folder,
						"RoomCeilingPanel",
						V3(35, 0.1, 31),
						CFrame.new(side * 26, y + 14.94, z),
						CEILING,
						Enum.Material.Plaster
					)
				end
			end
		end
	end
	-- Entrada: passadeira até o corredor e capacho.
	runner(folder, "HallRunner", V3(0, 0, 37.5), 47)
	deco(folder, "HallDoormat", V3(8, 0.09, 2.6), CFrame.new(0, 0.045, 62), rgb(66, 54, 40), Enum.Material.Fabric)
	-- Final em ruínas (WorldService.houseRuins): tetos e fachadas somem; forros e revestimentos acompanham.
	local OPEN_IN_RUINS = {
		CorridorCeilingPanel = true,
		FoyerCeilingPanel = true,
		RoomCeilingPanel = true,
		FinishMedallion = true,
		WallpaperSkin = true,
	}
	local function ruins(on: boolean)
		for _, part in folder:GetDescendants() do
			if part:IsA("BasePart") and OPEN_IN_RUINS[part.Name] then
				part.Transparency = if on then 1 else 0
			end
		end
	end
	root.ChildAdded:Connect(function(child)
		if child.Name == "Ruins" then
			ruins(true)
		end
	end)
	root.ChildRemoved:Connect(function(child)
		if child.Name == "Ruins" then
			ruins(false)
		end
	end)
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
	stairBarriers(root, folder)
end

return Finish
