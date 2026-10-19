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
	-- Lago: bacia em elipse (fatias de 8 studs), fundo de areia, água até 2 studs abaixo da margem, praia em volta da
	-- ilha, ilha de grama e banco de areia seco rente à água (a 4 studs de voxel, água rasa já faz nadar) até o norte.
	local l = map.lake
	if l then
		for x = -l.rx, l.rx, 8 do
			local half = l.rz * math.sqrt(math.max(0, 1 - (x / l.rx) ^ 2))
			if half < 4 then
				continue
			end
			local slice = Vector3.new(8, 12, half * 2)
			Terrain:FillBlock(CFrame.new(l.cx + x, -6, l.cz), slice, Enum.Material.Air)
			Terrain:FillBlock(CFrame.new(l.cx + x, -14, l.cz), Vector3.new(8, 4, half * 2), Enum.Material.Sand)
			Terrain:FillBlock(CFrame.new(l.cx + x, -6, l.cz), Vector3.new(8, 8, half * 2), Enum.Material.Water)
			-- Barranco de lama na borda (fica natural em vez de degrau de grama).
			-- Bolas de tamanho e recuo variados: margem irregular, sem cara de piscina.
			for _, side in { -1, 1 } do
				local radius = rng:NextNumber(3, 6)
				local inset = rng:NextNumber(-1.5, 2)
				Terrain:FillBall(Vector3.new(l.cx + x, -2.5, l.cz + side * (half - inset)), radius, Enum.Material.Mud)
				if rng:NextNumber() < 0.45 then
					Terrain:FillBall(
						Vector3.new(l.cx + x + rng:NextNumber(-4, 4), -1.5, l.cz + side * (half + rng:NextNumber(1, 4))),
						rng:NextNumber(2.5, 4.5),
						Enum.Material.Ground
					)
				end
			end
		end
		local i = l.island
		Terrain:FillCylinder(CFrame.new(i.x, -4, i.z), 8, i.r + 4, Enum.Material.Sand)
		Terrain:FillCylinder(CFrame.new(i.x, -6, i.z), 12, i.r, Enum.Material.Grass)
		for n = 2, #l.sandbar do
			local a, b = l.sandbar[n - 1], l.sandbar[n]
			local from, to = Vector3.new(a.x, -4, a.z), Vector3.new(b.x, -4, b.z)
			Terrain:FillBlock(
				CFrame.lookAt((from + to) / 2, to),
				Vector3.new(10, 8, (to - from).Magnitude + 10),
				Enum.Material.Sand
			)
		end
		-- Rampas suaves nas pontas do banco (sem degrau para subir na margem norte nem para descer da ilha).
		local first, last = l.sandbar[1], l.sandbar[#l.sandbar]
		for _, p in { first, last } do
			Terrain:FillBall(Vector3.new(p.x, -3, p.z), 7, Enum.Material.Ground)
		end
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
		if
			d < ForestMaps.TrailWidth / 2 + 0.5
			or ForestMaps.inRavine(map, x, z)
			or ForestMaps.nearLake(map, x, z, 2)
		then
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
			if not (r and p.Z > r.z0 - 3 and p.Z < r.z1 + 3) and not ForestMaps.nearLake(map, p.X, p.Z, 3) then
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
			if not (r and p.Z > r.z0 - 3 and p.Z < r.z1 + 3) and not ForestMaps.nearLake(map, p.X, p.Z, 3) then
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

-- Ponto da trilha a `distance` studs do começo, com a direção dela.
local function trailAt(map: ForestMaps.Map, distance: number): (Vector3, Vector3)
	local walked = 0
	for i = 2, #map.trail do
		local a, b = map.trail[i - 1], map.trail[i]
		local from, to = Vector3.new(a.x, 0, a.z), Vector3.new(b.x, 0, b.z)
		local length = (to - from).Magnitude
		if distance <= walked + length or i == #map.trail then
			local dir = (to - from).Unit
			return from + dir * math.clamp(distance - walked, 0, length), dir
		end
		walked += length
	end
	local last = map.trail[#map.trail]
	return Vector3.new(last.x, 0, last.z), Vector3.zAxis
end

local function trailLength(map: ForestMaps.Map): number
	local total = 0
	for i = 2, #map.trail do
		local a, b = map.trail[i - 1], map.trail[i]
		total += math.sqrt((b.x - a.x) ^ 2 + (b.z - a.z) ^ 2)
	end
	return total
end

-- Folhas secas (a mata escuta): manchas na trilha que estalam com passo normal (ForestHazardService).
local function leaves(root: Folder, map: ForestMaps.Map, rng: Random)
	local folder = Build.folder(root, "DryLeaves")
	local colors = { Color3.fromRGB(122, 78, 38), Color3.fromRGB(150, 98, 44), Color3.fromRGB(96, 62, 34) }
	local length = trailLength(map)
	for distance = 40, length - 30, 24 do
		local center, dir = trailAt(map, distance + rng:NextNumber(-5, 5))
		local side = Vector3.new(dir.Z, 0, -dir.X) * rng:NextNumber(-3, 3)
		local p = center + side
		if ForestMaps.inRavine(map, p.X, p.Z) then
			continue
		end
		local r = map.ravine
		if r and p.Z > r.z0 - 6 and p.Z < r.z1 + 6 then
			continue
		end
		local zone = part(
			folder,
			"LeafZone",
			Vector3.new(9, 1, 9),
			CFrame.new(p.X, 0.5, p.Z) * CFrame.Angles(0, math.atan2(dir.X, dir.Z), 0),
			colors[1],
			{ transparency = 1, collide = false, query = false }
		)
		zone:SetAttribute("LeafZone", true)
		for _ = 1, 16 do
			local leaf = part(
				zone,
				"Leaf",
				Vector3.new(rng:NextNumber(0.5, 0.9), 0.05, rng:NextNumber(0.35, 0.6)),
				zone.CFrame
					* CFrame.new(rng:NextNumber(-4, 4), -0.45, rng:NextNumber(-4, 4))
					* CFrame.Angles(
						rng:NextNumber(-0.2, 0.2),
						rng:NextNumber(0, math.pi * 2),
						rng:NextNumber(-0.2, 0.2)
					),
				colors[rng:NextInteger(1, #colors)],
				{ material = Enum.Material.Fabric, collide = false, query = false }
			)
			leaf.CastShadow = false
			leaf:SetAttribute("VisualDetail", true)
		end
	end
end

-- Corvo de desenho (silhueta escura, bico amarelado): pousado perto da trilha, levanta voo quando alguém chega.
local function crow(parent: Instance, at: CFrame): Model
	local model = Build.model(parent, "Crow")
	local black = Color3.fromRGB(18, 18, 22)
	local opts = { material = Enum.Material.SmoothPlastic, collide = false, query = false }
	local body = part(model, "Body", Vector3.new(1.05, 1.05, 1.05), at * CFrame.new(0, 0.55, 0), black, opts);
	(body :: Part).Shape = Enum.PartType.Ball
	local head = part(model, "Head", Vector3.new(0.6, 0.6, 0.6), at * CFrame.new(0, 1.05, -0.45), black, opts);
	(head :: Part).Shape = Enum.PartType.Ball
	part(
		model,
		"Beak",
		Vector3.new(0.18, 0.14, 0.45),
		at * CFrame.new(0, 1.0, -0.85),
		Color3.fromRGB(150, 128, 70),
		opts
	)
	for _, x in { -0.14, 0.14 } do
		local eye = part(
			model,
			"Eye",
			Vector3.new(0.12, 0.12, 0.12),
			at * CFrame.new(x, 1.12, -0.7),
			Color3.fromRGB(230, 220, 160),
			{
				material = Enum.Material.Neon,
				collide = false,
				query = false,
			}
		);
		(eye :: Part).Shape = Enum.PartType.Ball
	end
	part(
		model,
		"Tail",
		Vector3.new(0.5, 0.1, 0.8),
		at * CFrame.new(0, 0.5, 0.85) * CFrame.Angles(math.rad(-20), 0, 0),
		black,
		opts
	)
	for _, x in { -1, 1 } do
		local wing = part(
			model,
			if x < 0 then "WingL" else "WingR",
			Vector3.new(0.9, 0.08, 0.9),
			at * CFrame.new(x * 0.45, 0.75, 0.05) * CFrame.Angles(0, 0, math.rad(x * -35)),
			black,
			opts
		)
		wing:SetAttribute("Side", x)
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	return model
end

local function crows(root: Folder, map: ForestMaps.Map, rng: Random)
	local folder = Build.folder(root, "Crows")
	local length = trailLength(map)
	for distance = 55, length - 40, 38 do
		local center, dir = trailAt(map, distance)
		local r = map.ravine
		if r and center.Z > r.z0 - 10 and center.Z < r.z1 + 10 then
			continue
		end
		local sideSign = if rng:NextNumber() < 0.5 then -1 else 1
		local side = Vector3.new(dir.Z, 0, -dir.X) * sideSign
		local base = center + side * rng:NextNumber(9, 12)
		-- Toco ou pedra onde ele pousa (dois ou três corvos juntos).
		local perch = Build.cylinder(
			folder,
			"CrowPerch",
			Vector3.new(base.X, 2.25, base.Z),
			Vector3.yAxis,
			4.5,
			2.2,
			Color3.fromRGB(78, 60, 44),
			{ material = Enum.Material.Wood }
		)
		perch:SetAttribute("CrowPerch", true)
		local flock = Build.model(folder, "Flock")
		flock:SetAttribute("Flock", true)
		for _ = 1, rng:NextInteger(2, 3) do
			local offset = Vector3.new(rng:NextNumber(-0.6, 0.6), 4.5, rng:NextNumber(-0.6, 0.6))
			local look = (center - base) * Vector3.new(1, 0, 1)
			crow(
				flock,
				CFrame.lookAt(base + offset, base + offset + look.Unit) * CFrame.Angles(0, rng:NextNumber(-0.6, 0.6), 0)
			)
		end
	end
end

-- Cais de tábuas sobre a água, de `from` até `to` (no chão), com estacas.
local function dock(parent: Instance, name: string, from: Vector3, to: Vector3)
	local model = Build.model(parent, name)
	local dir = (to - from) * Vector3.new(1, 0, 1)
	local length = dir.Magnitude
	local frame = CFrame.lookAt(Vector3.new(from.X, 0, from.Z), Vector3.new(to.X, 0, to.Z))
	for d = 0, length, 1.5 do
		part(model, "DockPlank", Vector3.new(6, 0.4, 1.3), frame * CFrame.new(0, 0, -d), Color3.fromRGB(88, 70, 50))
	end
	for d = 0, length, 6 do
		for _, x in { -2.8, 2.8 } do
			part(
				model,
				"DockPile",
				Vector3.new(0.6, 6, 0.6),
				frame * CFrame.new(x, -2.8, -d),
				Color3.fromRGB(60, 46, 34)
			)
		end
	end
	return model
end

-- Lago (cap. 7): cais sul e da ilha, jangada (física: AlignPosition, levada pela ForestHazardService) e o posto de
-- rádio na ilha.
local function lakeProps(root: Folder, map: ForestMaps.Map)
	local l = map.lake
	if not l then
		return
	end
	local folder = Build.folder(root, "Lake")
	local south = Vector3.new(l.southDock.x, 0, l.southDock.z)
	local southEnd = south + Vector3.new(0, 0, 22)
	dock(folder, "SouthDock", south, southEnd)
	local isle = Vector3.new(l.islandDock.x, 0, l.islandDock.z)
	local toIsland = Vector3.new(l.island.x, 0, l.island.z)
	local isleEnd = isle - (toIsland - isle).Unit * 10
	dock(folder, "IslandDock", isle, isleEnd)
	-- Jangada: troncos amarrados, flutua parada na ponta do cais sul até o evento forest_raft.
	local raft = Build.model(folder, "Raft")
	local deck = Instance.new("Part")
	deck.Name = "Deck"
	deck.Size = Vector3.new(9, 0.8, 9)
	deck.Material = Enum.Material.Wood
	deck.Color = Color3.fromRGB(96, 74, 50)
	deck.CFrame = CFrame.new(southEnd + Vector3.new(0, -1.3, 5.5))
	deck.CustomPhysicalProperties = PhysicalProperties.new(0.6, 1, 0, 1, 1)
	deck.Parent = raft
	for x = -3.6, 3.6, 1.8 do
		local log = Build.cylinder(
			raft,
			"Log",
			deck.Position + Vector3.new(x, 0.25, 0),
			Vector3.zAxis,
			9.4,
			1.1,
			Color3.fromRGB(84, 62, 42),
			{ material = Enum.Material.Wood, collide = false, query = false }
		)
		log.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = deck, log
		weld.Parent = log
		log.Massless = true
	end
	local attach = Instance.new("Attachment")
	attach.Parent = deck
	local align = Instance.new("AlignPosition")
	align.Mode = Enum.PositionAlignmentMode.OneAttachment
	align.Attachment0 = attach
	align.Position = deck.Position
	align.MaxForce = 4e5
	align.MaxVelocity = 7
	align.Responsiveness = 12
	align.Parent = deck
	local turn = Instance.new("AlignOrientation")
	turn.Mode = Enum.OrientationAlignmentMode.OneAttachment
	turn.Attachment0 = attach
	turn.CFrame = CFrame.new()
	turn.MaxTorque = 4e5
	turn.Responsiveness = 15
	turn.Parent = deck
	raft:SetAttribute("Home", deck.Position)
	raft:SetAttribute("Away", isleEnd + Vector3.new(0, -1.3, 0) + (isleEnd - isle).Unit * 5.5)
	-- Corda-guia esticada entre os dois cais (a jangada segue por ela).
	Build.cylinder(
		folder,
		"FerryRope",
		(southEnd + isleEnd) / 2 + Vector3.new(0, 1.6, 0),
		(isleEnd - southEnd).Unit,
		(isleEnd - southEnd).Magnitude + 10,
		0.2,
		Color3.fromRGB(122, 104, 74),
		{ material = Enum.Material.Fabric, collide = false, query = false }
	)
	-- Posto de rádio da ilha: abrigo de tábuas com antena e luz vermelha piscando.
	local station = Build.model(folder, "RadioStation")
	local c = Vector3.new(l.island.x + 6, 0, l.island.z + 2)
	for _, dx in { -7, 7 } do
		for _, dz in { -5, 5 } do
			Build.block(station, "Post", c + Vector3.new(dx, 0, dz), Vector3.new(0.8, 10, 0.8), 0, WOOD)
		end
	end
	Build.block(station, "Roof", c + Vector3.new(0, 10, 0), Vector3.new(16, 0.6, 12), 0, Color3.fromRGB(58, 52, 46), {
		material = Enum.Material.CorrodedMetal,
	})
	Build.block(
		station,
		"Antenna",
		c + Vector3.new(8, 0, 6),
		Vector3.new(0.5, 26, 0.5),
		0,
		Color3.fromRGB(90, 92, 90),
		{ material = Enum.Material.Metal }
	)
	local beacon = Build.block(
		station,
		"AntennaLight",
		c + Vector3.new(8, 26, 6),
		Vector3.new(0.8, 0.8, 0.8),
		0,
		Color3.fromRGB(255, 60, 40),
		{ material = Enum.Material.Neon, collide = false, query = false }
	)
	Build.light(beacon, "ForestGuide", Color3.fromRGB(255, 70, 50), 30, 1.2, true, true)
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
	lakeProps(root, map)
	if map.biome == "mist" then
		leaves(root, map, rng)
		crows(root, map, rng)
	end
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
