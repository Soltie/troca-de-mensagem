--!strict
--[[
	Floresta v2 (docs/FLORESTA_V2.md): constrói o mapa de um capítulo a partir de Shared/Game/ForestMaps.
	Terreno de verdade (grama, trilha de terra, morros e rocha nas bordas, ravina com rio), pinheiros 3D
	(Assets/MansionProps ForestFirA/ForestFirB, com um tronco invisível sólido para bloquear e para o pathfinding),
	capim alto, lanternas do guarda (apagam no blackout, ForestBuilder.pressure), marcas amarelas e o acampamento.
	Ravina (cap. 6): a ponte começa com o meio caído; o guincho (evento forest_winch) ergue as tábuas.
	Os abrigos são feitos pelo ForestBuilder (mesma regra dos antigos).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local Build = require("./Build")

local V2 = {}

local Terrain = workspace.Terrain
local REGION = CFrame.new(0, 20, 730)
local REGION_SIZE = Vector3.new(336, 160, 440)
local WOOD = Color3.fromRGB(67, 54, 39)
local ROPE = Color3.fromRGB(122, 104, 74)
local YELLOW = Color3.fromRGB(214, 176, 52)

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: Build.PartOptions?
)
	return Build.part(parent, name, size, cframe, color, options or { material = Enum.Material.Wood })
end

-- Apaga todo o terreno da área da floresta (troca de capítulo ou volta para a casa).
function V2.clearTerrain()
	Terrain:FillBlock(REGION, REGION_SIZE, Enum.Material.Air)
end

local function asset(name: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local props = assets and assets:FindFirstChild("MansionProps")
	local found = props and props:FindFirstChild(name)
	return if found and found:IsA("Model") then found else nil
end

local function groundY(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { Terrain }
	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -160, 0), params)
	return if hit then hit.Position.Y else 0
end

local function terrain(map: ForestMaps.Map, rng: Random)
	V2.clearTerrain()
	-- Cores da mata à noite: rocha cinza-escura, terra marrom, rio escuro (o padrão é claro e arroxeado).
	Terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(78, 76, 72))
	Terrain:SetMaterialColor(Enum.Material.Slate, Color3.fromRGB(64, 66, 64))
	Terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(74, 58, 42))
	Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(58, 74, 44))
	Terrain.WaterColor = Color3.fromRGB(22, 38, 40)
	Terrain.WaterTransparency = 0.35
	Terrain.WaterReflectance = 0.15
	Terrain.WaterWaveSize = 0.12
	-- Chão da mata (topo em y = 0) e manchas de folhagem.
	Terrain:FillBlock(CFrame.new(0, -20, 730), Vector3.new(320, 40, 420), Enum.Material.Grass)
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-140, 140), rng:NextNumber(545, 915)
		Terrain:FillBlock(
			CFrame.new(x, -2, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			Vector3.new(rng:NextNumber(10, 22), 4, rng:NextNumber(10, 22)),
			Enum.Material.LeafyGrass
		)
	end
	-- Morros e pedras nas bordas: a mata parece continuar e esconde o limite.
	for z = 530, 930, 18 do
		for _, side in { -1, 1 } do
			Terrain:FillBall(
				Vector3.new(side * rng:NextNumber(148, 162), rng:NextNumber(-10, 4), z),
				rng:NextNumber(18, 28),
				Enum.Material.Grass
			)
			if rng:NextNumber() < 0.45 then
				Terrain:FillBall(
					Vector3.new(side * rng:NextNumber(138, 150), rng:NextNumber(-3, 3), z + rng:NextNumber(-6, 6)),
					rng:NextNumber(5, 9),
					Enum.Material.Rock
				)
			end
		end
	end
	-- Trilha de terra sinuosa.
	for i = 2, #map.trail do
		local a, b = map.trail[i - 1], map.trail[i]
		local from, to = Vector3.new(a.x, -2, a.z), Vector3.new(b.x, -2, b.z)
		local length = (to - from).Magnitude
		Terrain:FillBlock(
			CFrame.lookAt((from + to) / 2, to),
			Vector3.new(ForestMaps.TrailWidth, 4, length + ForestMaps.TrailWidth),
			Enum.Material.Ground
		)
	end
	-- Ravina: buraco de leste a oeste, paredes de rocha e rio lá embaixo.
	local r = map.ravine
	if r then
		local mid = (r.z0 + r.z1) / 2
		local width = r.z1 - r.z0
		Terrain:FillBlock(CFrame.new(0, -r.depth / 2 + 1, mid), Vector3.new(330, r.depth + 2, width), Enum.Material.Air)
		for _, z in { r.z0 - 2, r.z1 + 2 } do
			Terrain:FillBlock(CFrame.new(0, -r.depth / 2, z), Vector3.new(330, r.depth, 4), Enum.Material.Rock)
		end
		Terrain:FillBlock(CFrame.new(0, -r.depth - 2, mid), Vector3.new(330, 4, width + 4), Enum.Material.Rock)
		Terrain:FillBlock(CFrame.new(0, -r.depth + 2, mid), Vector3.new(330, 4, width), Enum.Material.Water)
		-- Pedras soltas nas paredes.
		for _ = 1, 30 do
			local z = if rng:NextNumber() < 0.5 then r.z0 + 1 else r.z1 - 1
			Terrain:FillBall(
				Vector3.new(rng:NextNumber(-150, 150), rng:NextNumber(-r.depth + 4, -4), z),
				rng:NextNumber(2, 4),
				Enum.Material.Slate
			)
		end
	end
end

local function trees(root: Folder, map: ForestMaps.Map, rng: Random)
	local firs = { asset("ForestFirA"), asset("ForestFirB") }
	local grove: Folder? = nil
	local count = 0
	for z = 545, 915, 10 do
		for x = -138, 138, 10 do
			local px, pz = x + rng:NextNumber(-3.5, 3.5), z + rng:NextNumber(-3.5, 3.5)
			if rng:NextNumber() > 0.72 or not ForestMaps.treeAllowed(map, px, pz) then
				continue
			end
			if not grove or count % 60 == 0 then
				if grove then
					grove.Parent = root
					task.wait()
				end
				local folder = Instance.new("Folder")
				folder.Name = "Grove"
				grove = folder
			end
			local holder = grove :: Folder
			count += 1
			local y = groundY(px, pz)
			local template = firs[rng:NextInteger(1, 2)]
			local scale = rng:NextNumber(0.75, 1.3)
			if template then
				local tree = template:Clone()
				tree:ScaleTo(tree:GetScale() * scale)
				tree:PivotTo(CFrame.new(px, y - 0.3, pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				for _, d in tree:GetDescendants() do
					if d:IsA("BasePart") then
						d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
					end
				end
				tree.Parent = holder
			end
			-- Tronco invisível sólido (o modelo não colide): bloqueia, esconde e entra no pathfinding.
			local near = ForestMaps.trailDistance(map, px, pz) < 40
			local trunk = part(
				holder,
				"Trunk",
				Vector3.new(2.2 * scale, 18, 2.2 * scale),
				CFrame.new(px, y + 9, pz),
				WOOD,
				{ transparency = 1, collide = true, query = near }
			)
			trunk:SetAttribute("ForestTree", true)
			trunk:SetAttribute("NearTrail", near)
		end
	end
	if grove then
		grove.Parent = root
	end
end

local function grass(root: Folder, map: ForestMaps.Map, rng: Random)
	local kinds = { asset("TallGrassA"), asset("TallGrassB"), asset("TallGrassClump") }
	local folder = Build.folder(root, "TallGrass")
	local placed = 0
	for _ = 1, 900 do
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(548, 912)
		local d = ForestMaps.trailDistance(map, x, z)
		-- Mais denso na beira da trilha; nunca no meio dela nem na ravina.
		if d < ForestMaps.TrailWidth / 2 + 0.5 or ForestMaps.inRavine(map, x, z) then
			continue
		end
		local r = map.ravine
		if r and z > r.z0 - 2 and z < r.z1 + 2 then
			continue
		end
		if d > 22 and rng:NextNumber() < 0.6 then
			continue
		end
		local template = kinds[rng:NextInteger(1, #kinds)]
		if template then
			local clump = template:Clone()
			clump:ScaleTo(clump:GetScale() * rng:NextNumber(1.1, 1.8))
			clump:PivotTo(CFrame.new(x, groundY(x, z) - 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
			for _, part_ in clump:GetDescendants() do
				if part_:IsA("BasePart") then
					part_.CanCollide, part_.CanQuery, part_.CanTouch = false, false, false
					part_.CastShadow = false
					part_:SetAttribute("VisualDetail", true)
				end
			end
			clump.Parent = folder
			placed += 1
		end
		if placed % 150 == 0 then
			task.wait()
		end
	end
end

-- Lanternas do guarda ao longo da trilha (apagam no blackout) e marcas amarelas.
local function guide(root: Folder, map: ForestMaps.Map)
	local walked, nextLamp, nextMark = 0, 20, 10
	for i = 2, #map.trail do
		local a, b = map.trail[i - 1], map.trail[i]
		local from, to = Vector3.new(a.x, 0, a.z), Vector3.new(b.x, 0, b.z)
		local length = (to - from).Magnitude
		local dir = (to - from).Unit
		local side = Vector3.new(dir.Z, 0, -dir.X)
		local r = map.ravine
		while nextLamp <= walked + length do
			local p = from + dir * (nextLamp - walked) + side * (ForestMaps.TrailWidth / 2 + 1.5)
			if not (r and p.Z > r.z0 - 3 and p.Z < r.z1 + 3) then
				local lamp = Build.block(root, "TrailLantern", p, Vector3.new(0.7, 4, 0.7), 0, WOOD)
				Build.light(lamp, "ForestGuide", Color3.fromRGB(192, 155, 100), 14, 0.35, true)
				Build.block(
					root,
					"LanternGlass",
					p + Vector3.new(0, 3, 0),
					Vector3.new(0.9, 0.7, 0.9),
					0,
					Color3.fromRGB(223, 177, 103),
					{ material = Enum.Material.Glass, transparency = 0.22, collide = false, query = false }
				)
			end
			nextLamp += 42
		end
		while nextMark <= walked + length do
			local p = from + dir * (nextMark - walked) - side * (ForestMaps.TrailWidth / 2 + 1)
			if not (r and p.Z > r.z0 - 3 and p.Z < r.z1 + 3) then
				-- Estaca com a ponta pintada de amarelo (o guarda marcou a trilha).
				Build.block(
					root,
					"RangerStake",
					p,
					Vector3.new(0.5, 3, 0.5),
					0,
					WOOD,
					{ material = Enum.Material.Wood, collide = false, query = false }
				)
				Build.block(
					root,
					"RangerMark",
					p + Vector3.new(0, 2.4, 0),
					Vector3.new(0.56, 0.6, 0.56),
					0,
					YELLOW,
					{ material = Enum.Material.SmoothPlastic, collide = false, query = false }
				)
			end
			nextMark += 26
		end
		walked += length
	end
end

-- Ponte de corda: tábuas de ponta a ponta; o meio começa caído na ravina até o guincho erguer.
local function bridge(root: Folder, map: ForestMaps.Map)
	local r = map.ravine
	if not r then
		return
	end
	local model = Build.model(root, "RopeBridge")
	local half = r.bridgeWidth / 2
	for _, z in { r.z0 - 3, r.z1 + 3 } do
		for _, x in { -half - 0.6, half + 0.6 } do
			Build.block(model, "BridgePost", Vector3.new(x, -1, z), Vector3.new(0.9, 6, 0.9), 0, WOOD)
		end
	end
	local planks = Build.folder(model, "Planks")
	local index = 0
	for z = r.z0 - 3, r.z1 + 3, 1.6 do
		index += 1
		local rest = CFrame.new(0, 0.05, z) * CFrame.Angles(0, math.rad((index % 3 - 1) * 1.5), 0)
		local plank = part(planks, "Plank", Vector3.new(r.bridgeWidth, 0.5, 1.35), rest, Color3.fromRGB(92, 74, 52))
		plank:SetAttribute("RestCFrame", rest)
		plank:SetAttribute("Index", index)
		-- Meio caído: pendurado para dentro da ravina, sem colisão.
		local fromEdge = math.min(z - r.z0, r.z1 - z)
		if fromEdge > 5 then
			local sag = CFrame.new(0, -6 - fromEdge * 0.35, z)
				* CFrame.Angles(math.rad(70), 0, math.rad((index % 2) * 18 - 9))
			plank.CFrame = sag
			plank.CanCollide = false
			plank:SetAttribute("Dropped", true)
		end
	end
	for _, x in { -half - 0.6, half + 0.6 } do
		Build.cylinder(
			model,
			"BridgeRope",
			Vector3.new(x, 2.6, (r.z0 + r.z1) / 2),
			Vector3.zAxis,
			r.z1 - r.z0 + 6,
			0.25,
			ROPE,
			{ material = Enum.Material.Fabric, collide = false, query = false }
		)
	end
	-- Até o guincho, uma barreira invisível na cabeceira sul (ninguém cai no vão).
	part(
		model,
		"BridgeGate",
		Vector3.new(r.bridgeWidth + 2, 10, 1),
		CFrame.new(0, 5, r.z0 - 5),
		WOOD,
		{ transparency = 1, collide = true, query = true }
	)
	-- Bordas da ravina: barreiras invisíveis dos dois lados, com vão só na ponte.
	for _, z in { r.z0 - 1.5, r.z1 + 1.5 } do
		for _, sign in { -1, 1 } do
			local inner = half + 1
			local length = 150 - inner
			part(
				root,
				"RavineGuard",
				Vector3.new(length, 10, 1),
				CFrame.new(sign * (inner + length / 2), 5, z),
				WOOD,
				{ transparency = 1, collide = true, query = true }
			)
		end
	end
end

-- Guincho consertado: as tábuas do meio sobem rangendo e a cabeceira libera.
function V2.raiseBridge(forest: Instance)
	local model = forest:FindFirstChild("RopeBridge")
	if not model then
		return
	end
	local planks = model:FindFirstChild("Planks")
	if planks then
		local list = planks:GetChildren()
		table.sort(list, function(a, b)
			return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
		end)
		for order, plank in list do
			local rest = plank:GetAttribute("RestCFrame")
			if plank:IsA("BasePart") and plank:GetAttribute("Dropped") == true and typeof(rest) == "CFrame" then
				plank:SetAttribute("Dropped", false)
				local tween = TweenService:Create(
					plank,
					TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, order * 0.06),
					{ CFrame = rest }
				)
				tween.Completed:Once(function()
					plank.CanCollide = true
				end)
				tween:Play()
			end
		end
	end
	local gate = model:FindFirstChild("BridgeGate")
	if gate then
		task.delay(2.5, function()
			gate:Destroy()
		end)
	end
end

local function camp(root: Folder, map: ForestMaps.Map)
	local c = map.camp
	if not c then
		return
	end
	local folder = Build.folder(root, "Camp")
	for index, offset in { Vector3.new(-12, 0, -9), Vector3.new(-13, 0, 9) } do
		local base = Vector3.new(c.x, 0, c.z) + offset
		local tent = Build.model(folder, "AbandonedTent")
		for _, side in { -1, 1 } do
			local panel = Build.block(
				tent,
				"Canvas",
				base + Vector3.new(side * 3.2, 0, 0),
				Vector3.new(0.4, 10, 14),
				0,
				if index == 1 then Color3.fromRGB(95, 94, 62) else Color3.fromRGB(110, 70, 52),
				{ material = Enum.Material.Fabric }
			)
			panel.CFrame *= CFrame.Angles(0, 0, math.rad(side * 32))
		end
		Build.block(
			tent,
			"Bedroll",
			base,
			Vector3.new(4, 0.6, 9),
			0,
			WOOD,
			{ material = Enum.Material.Fabric, collide = false }
		)
	end
	-- Fogueira apagada com pedras em volta.
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		Build.block(
			folder,
			"FireStone",
			Vector3.new(c.x + 4 + math.cos(a) * 2, 0, c.z + math.sin(a) * 2),
			Vector3.new(1, 0.7, 1),
			math.deg(a),
			Color3.fromRGB(70, 68, 64),
			{ material = Enum.Material.Slate, collide = false }
		)
	end
	for i = 1, 3 do
		local log = Build.block(
			folder,
			"BurntLog",
			Vector3.new(c.x + 4, 0.2, c.z),
			Vector3.new(0.6, 0.6, 3),
			i * 60,
			Color3.fromRGB(30, 26, 22),
			{ material = Enum.Material.Wood, collide = false }
		)
		log.CFrame *= CFrame.Angles(math.rad(12), 0, 0)
	end
	Build.sign(
		folder,
		"RangerWarning",
		Vector3.new(c.x - 2, 5, c.z + 16),
		Vector3.zAxis,
		Vector2.new(12, 3),
		"POSTO 09 / ÚLTIMA EQUIPE: 6\nRECEBIDOS NA ESTRADA: 0",
		{ textColor = Color3.fromRGB(188, 171, 120) }
	)
end

-- Monta o mapa do capítulo dentro de `root` (pasta Forest).
function V2.build(root: Folder, map: ForestMaps.Map, seed: number)
	local rng = Random.new(seed + map.chapter * 104729)
	root:SetAttribute("Biome", map.biome)
	root:SetAttribute("ForestV2", true)
	terrain(map, rng)
	task.wait()
	trees(root, map, rng)
	grass(root, map, rng)
	guide(root, map)
	bridge(root, map)
	camp(root, map)
	-- Limites físicos (os morros já escondem).
	for _, x in { -145, 145 } do
		part(root, "TreeLineBoundary", Vector3.new(2, 80, 400), CFrame.new(x, 30, 730), WOOD, { transparency = 1 })
	end
	for _, z in { 535, 915 } do
		part(root, "TrailBoundary", Vector3.new(300, 80, 2), CFrame.new(0, 30, z), WOOD, { transparency = 1 })
	end
	Build.sign(
		root,
		"Warning",
		Vector3.new(16, 5, 596),
		-Vector3.zAxis,
		Vector2.new(11, 3),
		"SE A MATA FICAR EM SILÊNCIO\nAPAGUE A LUZ. NÃO CORRA.",
		{ textColor = Color3.fromRGB(203, 188, 135), lit = true }
	)
end

return V2
