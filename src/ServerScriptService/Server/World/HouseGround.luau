--!strict
--[[
	Chão PBR e mato alto do jardim e da floresta (lote 6 do ambiente). Só visual:
	- grama, terra batida e areia com texturas Poly Haven (MaterialVariant) nas peças de chão existentes;
	- touceiras 3D de mato (cartões com transparência) em manchas, nunca em caminhos, pisos ou construções.
	O mato não colide, não recebe raycast nem toque e tem o atributo VisualDetail: o WorldFxController
	esconde o que está longe conforme a qualidade escolhida (48/90/145 studs), então pesa pouco no celular.
	A floresta dos capítulos 6–8 é refeita a cada capítulo; o chão dela é vestido de novo quando aparece.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require("./Build")

local Ground = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local SEED = 66021

type Skin = { variant: string, material: Enum.Material, color: Color3 }

-- Com textura, Color só tinge: valores claros mantêm o detalhe do Poly Haven à noite.
local LAWN: Skin = { variant = "GardenLawn", material = Enum.Material.Grass, color = rgb(168, 176, 158) }
local FOREST: Skin = { variant = "ForestFloor", material = Enum.Material.Grass, color = rgb(150, 150, 140) }
local DIRT: Skin = { variant = "DirtTrail", material = Enum.Material.Ground, color = rgb(178, 168, 158) }
local SAND: Skin = { variant = "SandPath", material = Enum.Material.Sand, color = rgb(186, 176, 160) }

local function skin(part: BasePart, look: Skin)
	part.Material = look.material
	part.MaterialVariant = look.variant
	part.Color = look.color
end

local LAWN_PARTS = {
	Garden = true,
	SideGarden = true,
	BackGarden = true,
	FrontCourtGround = true,
	ExitGround = true,
	EstateGround = true,
	EstateSoil = true,
}

--[[ Mato ]]

local GRASS = { "TallGrassClump", "TallGrassA", "TallGrassB", "TallGrassA" }

local function library(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("MansionProps")
end

local function tuft(folder: Instance, source: Instance, name: string, at: Vector3, scale: number, yaw: number)
	local template = source:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return
	end
	local model = template:Clone()
	model:ScaleTo(model:GetScale() * scale)
	model:PivotTo(CFrame.new(at) * CFrame.Angles(0, yaw, 0))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.CastShadow = false
			part:SetAttribute("VisualDetail", true)
		end
	end
	model.Parent = folder
end

-- Manchas de mato: algumas touceiras juntas parecem natural; espalhar uma por uma parece plantado.
local function patches(
	folder: Instance,
	rng: Random,
	count: number,
	pick: (Random) -> Vector3?,
	blocked: (number, number) -> boolean,
	y: number
)
	local source = library()
	if not source then
		return
	end
	for _ = 1, count do
		local center = pick(rng)
		if not center then
			continue
		end
		for index = 1, rng:NextInteger(3, 6) do
			local angle = rng:NextNumber(0, math.pi * 2)
			local radius = rng:NextNumber(0, 3.4)
			local x, z = center.X + math.cos(angle) * radius, center.Z + math.sin(angle) * radius
			if not blocked(x, z) then
				local name = GRASS[(index + rng:NextInteger(0, 3)) % #GRASS + 1]
				tuft(folder, source, name, V3(x, y, z), rng:NextNumber(1.7, 2.9), rng:NextNumber(0, math.pi * 2))
			end
		end
	end
end

local function rect(x: number, z: number, x0: number, x1: number, z0: number, z1: number): boolean
	return x > x0 and x < x1 and z > z0 and z < z1
end

-- Jardim: nada sobre a casa, varanda, caminhos, pátio, pavilhões, mirante ou túmulos.
local function gardenBlocked(x: number, z: number): boolean
	local ax = math.abs(x)
	return rect(x, z, -47, 48, -88, 79) -- casa, varanda e degrau
		or (ax < 7 and z > 60) -- caminho de pedra até a floresta
		or (ax < 80 and z > 70 and z < 82) -- passeio da frente e cerca
		or (ax > 51 and ax < 65) -- passeio lateral
		or rect(ax, z, 59, 93, 7, 41) -- pavilhões
		or rect(ax, z, 59, 93, -61, -27)
		or rect(ax, z, 83, 105, -5, 51) -- mirante e escada (o lado muda com o nível)
		or rect(ax, z, -1, 55, -119, -85) -- pátio dos fundos
		or rect(x, z, -104, -91, 50, 74) -- lápides
		or ax > 105 -- muro
		or z < -116
		or z > 130
end

local GARDEN_AREAS = {
	{ -104, -66, -112, 76 }, -- jardim oeste
	{ 66, 104, -112, 76 }, -- jardim leste
	{ -104, -48, 83, 96 }, -- pátio da frente, junto ao muro
	{ 48, 104, 83, 96 },
	{ -46, -9, 83, 96 },
	{ 9, 46, 83, 96 },
	{ -104, -56, -114, -88 }, -- fundos
	{ 56, 104, -114, -88 },
	{ -104, -12, 100, 128 }, -- saída para a floresta
	{ 12, 104, 100, 128 },
}

--[[
	Campo de mato denso (referência do humano: The Mimic): tapetes de 8 × 8 studs com 900 lâminas finas
	(GrassField, uma face por lâmina, degradê oliva da base à ponta) numa grade com desvio e giro aleatórios.
	Só onde o centro e as quatro quinas estão livres. Cada tapete é um VisualDetail: some de longe no celular.
]]
local FIELD_STEP = 7.5
local function field(folder: Instance, rng: Random): boolean
	local source = library()
	local template = source and source:FindFirstChild("GrassField")
	if not template or not template:IsA("Model") or not template:GetAttribute("PivotIsBase") then
		return false
	end
	for _, area in GARDEN_AREAS do
		for x = area[1] + FIELD_STEP / 2, area[2], FIELD_STEP do
			for z = area[3] + FIELD_STEP / 2, area[4], FIELD_STEP do
				local px, pz = x + rng:NextNumber(-1.2, 1.2), z + rng:NextNumber(-1.2, 1.2)
				local free = not gardenBlocked(px, pz)
				for _, corner in { { -3.6, -3.6 }, { 3.6, -3.6 }, { -3.6, 3.6 }, { 3.6, 3.6 } } do
					free = free and not gardenBlocked(px + corner[1], pz + corner[2])
				end
				if free then
					local patch = template:Clone()
					patch:ScaleTo(patch:GetScale() * rng:NextNumber(0.85, 1.15))
					local yaw = rng:NextInteger(0, 3) * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
					patch:PivotTo(CFrame.new(px, 0.05, pz) * CFrame.Angles(0, yaw, 0))
					for _, part in patch:GetDescendants() do
						if part:IsA("BasePart") then
							part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
							part.CastShadow = false
							part:SetAttribute("VisualDetail", true)
						end
					end
					patch.Parent = folder
				end
			end
		end
	end
	return true
end

local function garden(root: Instance)
	local folder = Build.folder(root, "GardenGrass")
	local rng = Random.new(SEED)
	if field(folder, rng) then
		return
	end
	local total = 0
	for _, area in GARDEN_AREAS do
		total += (area[2] - area[1]) * (area[4] - area[3])
	end
	-- Uma mancha a cada ~170 studs² de gramado livre.
	for _, area in GARDEN_AREAS do
		local share = (area[2] - area[1]) * (area[4] - area[3]) / total
		patches(folder, rng, math.max(2, math.floor(share * 30 + 0.5)), function(r: Random): Vector3?
			local x, z = r:NextNumber(area[1], area[2]), r:NextNumber(area[3], area[4])
			return if gardenBlocked(x, z) then nil else V3(x, 0, z)
		end, gardenBlocked, 0)
	end
end

--[[
	Terrain com a grama 3D do Roblox (Terrain.Decoration, ligada no place por places/world/Workspace/Terrain.model.json).
	O topo fica 0,1 stud acima do chão de peças: a colisão das peças continua igual, e o motor desenha
	e otimiza os tufos (somem sozinhos em qualidade gráfica baixa). Caminhos e pisos viram terreno do material certo.
]]
local TOP = 0.1
local DEPTH = 4

local function fill(t: Terrain, x0: number, x1: number, z0: number, z1: number, material: Enum.Material)
	t:FillBlock(CFrame.new((x0 + x1) / 2, TOP - DEPTH / 2, (z0 + z1) / 2), V3(x1 - x0, DEPTH, z1 - z0), material)
end

local function terrainColors(t: Terrain)
	t:SetMaterialColor(Enum.Material.Grass, rgb(84, 110, 62))
	t:SetMaterialColor(Enum.Material.LeafyGrass, rgb(70, 96, 54))
	t:SetMaterialColor(Enum.Material.Ground, rgb(96, 78, 58))
	t:SetMaterialColor(Enum.Material.Sand, rgb(150, 132, 104))
	t:SetMaterialColor(Enum.Material.Cobblestone, rgb(112, 108, 100))
	t:SetMaterialColor(Enum.Material.Slate, rgb(100, 98, 96))
end

local function lawnTerrain()
	local t = workspace.Terrain
	terrainColors(t)
	local far = 200
	-- Tudo fora da casa (com 1 stud de folga das paredes, para o terreno nunca vazar para o porão).
	fill(t, -far, far, 65.5, far, Enum.Material.Grass)
	fill(t, -far, far, -far, -86.5, Enum.Material.Grass)
	fill(t, -far, -45.5, -86.5, 65.5, Enum.Material.Grass)
	fill(t, 46.5, far, -86.5, 65.5, Enum.Material.Grass)
	fill(t, -45.5, -25.5, 13.5, 65.5, Enum.Material.Grass)
	-- Manchas de grama mais escura e folhosa quebram a repetição do gramado.
	local rng = Random.new(SEED + 7)
	for _ = 1, 26 do
		local x, z = rng:NextNumber(-100, 100), rng:NextNumber(-112, 126)
		if not gardenBlocked(x, z) then
			local r = rng:NextNumber(4, 9)
			fill(t, x - r, x + r, z - r * 0.7, z + r * 0.7, Enum.Material.LeafyGrass)
		end
	end
	-- Pisos do jardim (mesmas medidas do HouseLevelBuilder e do caminho da HouseExterior).
	for _, side in { -1, 1 } do
		fill(t, side * 58 - 5, side * 58 + 5, -120, 80, Enum.Material.Sand)
		local x0, x1 = if side < 0 then -78 else 0, if side < 0 then 0 else 78
		fill(t, x0, x1, 71.5, 80.5, Enum.Material.Cobblestone)
		for _, z in { 24, -44 } do
			fill(t, side * 76 - 14, side * 76 + 14, z - 14, z + 14, Enum.Material.Slate)
		end
	end
	fill(t, -53, 53, -117, -87, Enum.Material.Cobblestone)
	fill(t, -4, 4, 78, 131.5, Enum.Material.Cobblestone)
	fill(t, -17, 17, 65.5, 78, Enum.Material.Ground) -- sob o deck da varanda
end

local forestPainted = false

local function forestTerrain(trails: { BasePart })
	local t = workspace.Terrain
	terrainColors(t)
	-- A área jogável e uma folga cobertas pela névoa; além disso o chão de peças continua.
	if not forestPainted then
		forestPainted = true
		t:FillBlock(CFrame.new(0, TOP - DEPTH / 2, 720), V3(420, DEPTH, 440), Enum.Material.Grass)
	else
		t:ReplaceMaterial(
			Region3.new(V3(-210, TOP - DEPTH, 500), V3(210, TOP, 940)):ExpandToGrid(4),
			4,
			Enum.Material.Sand,
			Enum.Material.Grass
		)
	end
	for _, trail in trails do
		-- Trilha principal de terra batida; ramais de areia (mudam a cada capítulo).
		local material = if trail.Name == "MainTrail" then Enum.Material.Ground else Enum.Material.Sand
		t:FillBlock(
			CFrame.new(trail.Position.X, TOP - DEPTH / 2, trail.Position.Z) * trail.CFrame.Rotation,
			V3(trail.Size.X, DEPTH, trail.Size.Z),
			material
		)
	end
end

--[[ Floresta dos capítulos 6–8 ]]

--[[
	Pinheiros 3D (tronco com casca + galhos em cartões do atlas fir_tree_01, ~190 triângulos) no lugar das
	árvores-bloco. O tronco-bloco continua lá, invisível, com a mesma colisão e o mesmo raycast;
	as copas-bloco (sem colisão) só ficam invisíveis. Mesmo modelo repetido: o motor desenha em lote.
]]
local FIRS = { { name = "ForestFirA", height = 55 }, { name = "ForestFirB", height = 44 } }

local function firs(forest: Instance)
	local source = library()
	if not source or not source:FindFirstChild("ForestFirA") then
		return
	end
	local folder = Build.folder(forest, "ForestFirs")
	local rng = Random.new(SEED + 31)
	local placed = 0
	for _, part in forest:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Canopy" then
			part.Transparency = 1
			part.CastShadow = false
		elseif part.Name == "Trunk" and part:GetAttribute("ForestTree") == true then
			local pick = FIRS[rng:NextInteger(1, #FIRS)]
			local template = source:FindFirstChild(pick.name)
			if not template or not template:IsA("Model") then
				continue
			end
			part.Transparency = 1
			part.CastShadow = false
			local model = template:Clone()
			model:ScaleTo(model:GetScale() * part.Size.Y / pick.height * rng:NextNumber(1, 1.12))
			local base = part.Position - Vector3.yAxis * part.Size.Y / 2
			model:PivotTo(CFrame.new(base) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			model.Parent = folder
			placed += 1
			if placed % 150 == 0 then
				task.wait()
			end
		end
	end
end

local function dressForest(forest: Instance)
	if forest:FindFirstChild("ForestGrass") then
		return
	end
	local trails: { BasePart } = {}
	local trunks: { Vector3 } = {}
	for _, part in forest:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "ForestGround" then
			skin(part, FOREST)
		elseif part.Name == "MainTrail" then
			skin(part, DIRT)
			table.insert(trails, part)
		elseif part.Name == "BranchTrail" then
			-- Ramais de areia batida: o caminho principal continua de terra e fica fácil de seguir.
			skin(part, SAND)
			table.insert(trails, part)
		elseif part.Name == "Trunk" then
			table.insert(trunks, part.Position)
		end
	end
	local main = forest:FindFirstChild("MainTrail")
	if not main or not main:IsA("BasePart") then
		return
	end
	forestTerrain(trails)
	firs(forest)
	local function blocked(x: number, z: number): boolean
		for _, trail in trails do
			local offset = trail.CFrame:PointToObjectSpace(V3(x, trail.Position.Y, z))
			if math.abs(offset.X) < trail.Size.X / 2 + 1.5 and math.abs(offset.Z) < trail.Size.Z / 2 + 1.5 then
				return true
			end
		end
		for _, trunk in trunks do
			if (V3(trunk.X, 0, trunk.Z) - V3(x, 0, z)).Magnitude < 2.6 then
				return true
			end
		end
		return false
	end
	local folder = Build.folder(forest, "ForestGrass")
	local rng = Random.new(SEED + (tonumber(forest:GetAttribute("Chapter")) or 0))
	local top = TOP
	local z0, z1 = main.Position.Z - main.Size.Z / 2, main.Position.Z + main.Size.Z / 2
	-- Touceiras altas só como destaque: a grama do Terrain cobre o chão; mais perto das bordas da trilha.
	patches(folder, rng, 44, function(r: Random): Vector3?
		local side = if r:NextNumber() < 0.5 then -1 else 1
		local x = main.Position.X + side * (main.Size.X / 2 + 2 + r:NextNumber() ^ 1.8 * 40)
		local z = r:NextNumber(z0, z1)
		return if blocked(x, z) then nil else V3(x, top - 0.08, z)
	end, blocked, top - 0.08)
end

function Ground.build(root: Instance)
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and LAWN_PARTS[part.Name] and part.Material == Enum.Material.Grass then
			skin(part, LAWN)
		end
	end
	lawnTerrain()
	garden(root)
	local function estate(folder: Instance)
		for _, part in folder:GetChildren() do
			if part:IsA("BasePart") then
				if part.Name == "EstateGround" then
					skin(part, LAWN)
				elseif part.Name == "GardenWalk" then
					-- Passeio lateral de areia batida.
					skin(part, SAND)
				end
			end
		end
	end
	local current = root:FindFirstChild("GeneratedEstate")
	if current then
		estate(current)
	end
	local forest = root:FindFirstChild("Forest")
	if forest then
		dressForest(forest)
	end
	root.ChildAdded:Connect(function(child)
		-- Os dois são montados inteiros na mesma execução; vestir depois que terminar.
		if child.Name == "GeneratedEstate" then
			task.defer(estate, child)
		elseif child.Name == "Forest" then
			-- A floresta publica árvores em lotes; espera os troncos para não plantar mato dentro deles.
			task.delay(2, function()
				if child.Parent then
					dressForest(child)
				end
			end)
		end
	end)
end

return Ground
