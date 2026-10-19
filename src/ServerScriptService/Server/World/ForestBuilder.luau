--!strict
-- Construção por capítulo: horizonte cenográfico amplo, trilhas livres e abrigos autoritativos.
local CollectionService = game:GetService("CollectionService")
local Forest = require("@game/ReplicatedStorage/Shared/Game/ForestCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Build = require("./Build")
local FeatureBuilder = require("./FeatureBuilder")
local Layout = require("./ForestLayout")
local Threat = require("@game/ReplicatedStorage/Shared/Game/ForestThreat")
local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local V2 = require("./ForestV2")
local Builder = {}
local wood = Color3.fromRGB(67, 54, 39)
local leaf = Color3.fromRGB(28, 53, 39)
local function block(
	parent: Instance,
	name: string,
	p: Vector3,
	size: Vector3,
	color: Color3,
	options: Build.PartOptions?
): BasePart
	local defaults = {
		material = if name == "Canvas" or name == "Bedroll"
			then Enum.Material.Fabric
			elseif name == "Roof" or name == "RadioShelterRoof" then Enum.Material.Slate
			elseif name == "TowerRing" then Enum.Material.Metal
			else Enum.Material.Wood,
	}
	return Build.block(parent, name, p, size, 0, color, options or defaults)
end
function Builder.clear(parent: Instance, features: FeatureBuilder.Built)
	for id in features.lockers do
		if string.sub(id, 1, 12) == "hide_Forest_" then
			features.lockers[id], features.interactables[id] = nil, nil
		end
	end
	local old = parent:FindFirstChild("Forest")
	if old then
		old:Destroy()
	end
	-- Terreno da floresta v2 (morros, trilha, ravina) sai junto.
	V2.clearTerrain()
end
-- Abrigos do capítulo (os mesmos nos mapas antigo e novo): madeira, porta com prompt e esconderijo do servidor.
local function shelters(root: Folder, list: { { x: number, y: number, z: number } }, features: FeatureBuilder.Built)
	for index, spot in list do
		local id = `hide_Forest_{index}`
		local p = Vector3.new(spot.x, spot.y, spot.z)
		local model = Build.model(root, id)
		for _, dx in { -2.5, 2.5 } do
			block(
				model,
				"Side",
				p + Vector3.new(dx, 0, 0),
				Vector3.new(0.5, 9, 5),
				wood,
				{ material = Enum.Material.Wood }
			)
		end
		block(model, "Back", p + Vector3.new(0, 0, -2.5), Vector3.new(5, 9, 0.5), wood)
		block(model, "Roof", p + Vector3.new(0, 9, 0), Vector3.new(6, 0.5, 6), wood)
		local door = block(model, "HideDoor", p + Vector3.new(0, 0, 2.5), Vector3.new(5, 9, 0.3), wood)
		door:SetAttribute(Tags.Attr.InteractId, id)
		door:SetAttribute(Tags.Attr.InteractPrompt, "ESCONDER NO ABRIGO")
		door:SetAttribute(Tags.Attr.InteractEnabled, true)
		door:SetAttribute(Tags.Attr.InteractDistance, 8)
		CollectionService:AddTag(door, Tags.Interactable)
		local front = p + Vector3.new(0, 0, 6)
		features.lockers[id] = {
			id = id,
			model = model,
			door = door,
			doorClosed = door.CFrame,
			hinge = CFrame.new(p),
			inside = CFrame.new(p + Vector3.new(0, 3, 0)),
			eye = CFrame.lookAt(p + Vector3.new(0, 5.5, 2.7), p + Vector3.new(0, 5.5, 10)),
			exit = CFrame.new(front + Vector3.new(0, 3, 0)),
			front = front,
			sound = Build.sound(door, "Creak", Audio.DoorBang.id, 0.35),
			occupant = nil,
		}
		features.interactables[id] =
			{ id = id, kind = "Hide", focus = door, model = model, maxDistance = 8, enabled = true }
	end
end
function Builder.build(parent: Instance, chapter: number, seed: number, features: FeatureBuilder.Built): Folder
	Builder.clear(parent, features)
	local root = Build.folder(parent, "Forest")
	root:SetAttribute("Chapter", chapter)
	root:SetAttribute("HorrorForest", true)
	local rng = Random.new(seed + chapter * 104729)
	-- Floresta v2: capítulo com mapa novo (docs/FLORESTA_V2.md).
	local map = ForestMaps.get(chapter)
	if map then
		V2.build(root, map, seed)
		shelters(root, map.hides, features)
		Build.sign(
			root,
			"ChapterBoard",
			Vector3.new(-18, 6, 604),
			-Vector3.zAxis,
			Vector2.new(14, 3),
			Forest.Chapters[chapter - 5].title,
			{ textColor = Color3.fromRGB(226, 193, 130), lit = true }
		)
		return root
	end
	block(
		root,
		"ForestGround",
		Vector3.new(0, -2, 720),
		Vector3.new(2400, 2, 2400),
		Color3.fromRGB(38, 48, 34),
		{ material = Enum.Material.Grass }
	)
	-- A espinha central e ramais são largos para dois jogadores e para o pathfinding da criatura.
	block(
		root,
		"MainTrail",
		Vector3.new(0, 0.01, 720),
		Vector3.new(22, 0.08, 350),
		Color3.fromRGB(86, 73, 53),
		{ material = Enum.Material.Ground, collide = false }
	)
	local clearings = Layout.clearings(seed)
	local drawn: { [string]: boolean } = {}
	for _, r in clearings do
		if r.z1 - r.z0 > 35 then
			continue
		end
		local key = `{r.x0}/{r.x1}/{r.z0}/{r.z1}`
		if drawn[key] then
			continue
		end
		drawn[key] = true
		block(
			root,
			"BranchTrail",
			Vector3.new((r.x0 + r.x1) / 2, 0.07, (r.z0 + r.z1) / 2),
			Vector3.new(r.x1 - r.x0, 0.08, r.z1 - r.z0),
			Color3.fromRGB(78, 69, 51),
			{ material = Enum.Material.Ground, collide = false }
		)
	end
	local function tree(container: Instance, x: number, z: number, distant: boolean)
		local height = rng:NextNumber(29, 51)
		local trunk = block(
			container,
			"Trunk",
			Vector3.new(x, 0, z),
			Vector3.new(3, height, 3),
			wood,
			{ material = Enum.Material.Wood, collide = not distant, query = not distant }
		)
		trunk:SetAttribute("ForestTree", true)
		trunk:SetAttribute("NearTrail", not distant)
		for level = 1, 2 do
			local crown = block(
				container,
				"Canopy",
				Vector3.new(x, height - 7 + level * 4, z),
				Vector3.new(27 - level * 4, 13, 27 - level * 4),
				leaf,
				{ material = Enum.Material.Grass, collide = false, query = false }
			)
			crown.CFrame *= CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
			crown.CastShadow = true
		end
	end
	-- Subárvores pequenas são publicadas por lote; geração cede a thread para o Studio.
	for batch = 1, 8 do
		local grove = Instance.new("Folder")
		grove.Name = `Grove{batch}`
		if batch <= 4 then
			for row = 0, 7 do
				local z = 548 + ((batch - 1) * 8 + row) * 11
				for column = 0, 24 do
					local x = -132 + column * 11 + rng:NextNumber(-1.2, 1.2)
					local atZ = z + rng:NextNumber(-1.2, 1.2)
					if not Layout.reserved(x, atZ, clearings) then
						tree(grove, x, atZ, false)
					end
				end
			end
		else
			for _ = 1, 85 do
				local x = rng:NextNumber(-850, 850)
				local z = rng:NextNumber(300, 1250)
				if math.abs(x) > 164 or z < 520 or z > 930 then
					tree(grove, x, z, true)
				end
			end
		end
		grove.Parent = root
		task.wait()
	end
	-- Limites físicos com massas rochosas visíveis além deles, sem queda no vazio.
	for _, x in { -145, 145 } do
		block(root, "TreeLineBoundary", Vector3.new(x, 0, 720), Vector3.new(2, 70, 380), leaf, { transparency = 1 })
		for z = 550, 910, 24 do
			block(
				root,
				"RockRidge",
				Vector3.new(x + (if x < 0 then -9 else 9), 0, z),
				Vector3.new(19, rng:NextNumber(12, 25), 28),
				Color3.fromRGB(48, 55, 50),
				{ material = Enum.Material.Slate }
			)
		end
	end
	for _, z in { 535, 915 } do
		block(root, "TrailBoundary", Vector3.new(0, 0, z), Vector3.new(290, 70, 2), leaf, { transparency = 1 })
	end
	for z = 600, 840, 60 do
		local lamp = block(root, "TrailLantern", Vector3.new(12, 0, z), Vector3.new(0.7, 4, 0.7), wood)
		Build.light(lamp, "ForestGuide", Color3.fromRGB(192, 155, 100), 12, 0.3, true)
		-- Lanterna física e sua proteção: apenas visual, luz de orientação continua em todos os perfis.
		for _, side in { -1, 1 } do
			local cap = block(
				root,
				"LanternCap",
				Vector3.new(12, 3.3 + side * 0.55, z),
				Vector3.new(1.5, 0.18, 1.5),
				wood,
				{ material = Enum.Material.Metal, collide = false, query = false }
			)
			cap:SetAttribute("VisualDetail", true)
		end
		block(
			root,
			"LanternGlass",
			Vector3.new(12, 3, z),
			Vector3.new(0.9, 0.7, 0.9),
			Color3.fromRGB(223, 177, 103),
			{ material = Enum.Material.Glass, transparency = 0.22, collide = false, query = false }
		)
	end
	-- Marcas físicas continuam legíveis quando as lanternas do mundo apagam.
	for _, z in { 624, 682, 742, 812, 848 } do
		Build.sign(
			root,
			"RangerMark",
			Vector3.new(-11, 3.4, z),
			-Vector3.zAxis,
			Vector2.new(2.3, 1.1),
			if z == 848 then "ESTRADA ↑" else "TRILHA ↑",
			{ textColor = Color3.fromRGB(174, 159, 105), lit = true }
		)
	end
	local props = Build.folder(root, "RangerRemains")
	for _, z in { 608, 694, 774, 828 } do
		local stump = block(
			props,
			"SplitStump",
			Vector3.new(-15, 0, z),
			Vector3.new(4, 3, 4),
			wood,
			{ material = Enum.Material.Wood, collide = false, query = false }
		)
		stump.CFrame *= CFrame.Angles(0, math.rad(23), 0)
		block(
			props,
			"BrokenBark",
			Vector3.new(-16, 3, z),
			Vector3.new(1, 2, 0.5),
			wood,
			{ material = Enum.Material.Wood, collide = false, query = false }
		)
	end
	Build.sign(
		props,
		"Warning",
		Vector3.new(20, 5, 596),
		-Vector3.zAxis,
		Vector2.new(11, 3),
		"SE A MATA FICAR EM SILÊNCIO\nAPAGUE A LUZ. NÃO CORRA ATÉ O ABRIGO.",
		{ textColor = Color3.fromRGB(203, 188, 135), lit = true }
	)
	block(props, "CampTable", Vector3.new(-82, 0, 731), Vector3.new(11, 2.4, 5), wood)
	for i = 1, 4 do
		block(
			props,
			"EmptyPlate",
			Vector3.new(-87 + i * 2, 2.4, 731),
			Vector3.new(1.3, 0.1, 1.3),
			Color3.fromRGB(134, 137, 118),
			{ material = Enum.Material.Metal, collide = false, query = false }
		)
	end
	Build.sign(
		props,
		"RangerWarning",
		Vector3.new(-77, 5, 740),
		Vector3.zAxis,
		Vector2.new(12, 3),
		"POSTO 09 / ÚLTIMA EQUIPE: 6\nRECEBIDOS NA ESTRADA: 0",
		{ textColor = Color3.fromRGB(188, 171, 120) }
	)
	Build.sign(
		root,
		"ChapterBoard",
		Vector3.new(-22, 6, 610),
		-Vector3.zAxis,
		Vector2.new(14, 3),
		Forest.Chapters[chapter - 5].title,
		{ textColor = Color3.fromRGB(226, 193, 130), lit = true }
	)
	shelters(root, Forest.Hides, features)
	if chapter == 6 then
		for _, x in { -80, 80 } do
			local log = block(
				root,
				"FallenTree",
				Vector3.new(x, 0, 700),
				Vector3.new(8, 8, 36),
				wood,
				{ material = Enum.Material.Wood }
			)
			log.CFrame *= CFrame.Angles(0, math.rad(35), 0)
		end
	else
		for _, z in { 660, 800 } do
			local tent = Build.model(root, "AbandonedTent")
			for _, side in { -1, 1 } do
				local panel = block(
					tent,
					"Canvas",
					Vector3.new(-80 + side * 4, 0, z),
					Vector3.new(0.5, 13, 20),
					Color3.fromRGB(95, 94, 62)
				)
				panel.CFrame *= CFrame.Angles(0, 0, math.rad(side * 32))
			end
			block(tent, "Bedroll", Vector3.new(-80, 0, z), Vector3.new(5, 0.7, 10), wood)
		end
		for _, x in { 65, 95 } do
			block(root, "RadioShelterPost", Vector3.new(x, 0, 760), Vector3.new(2, 18, 2), wood)
		end
		block(root, "RadioShelterRoof", Vector3.new(80, 18, 760), Vector3.new(36, 1, 30), wood)
	end
	if chapter == 8 then
		for _, dx in { -8, 8 } do
			for _, dz in { -8, 8 } do
				block(
					root,
					"TowerLeg",
					Vector3.new(82 + dx, 0, 700 + dz),
					Vector3.new(2, 70, 2),
					Color3.fromRGB(84, 91, 85),
					{ material = Enum.Material.Metal }
				)
			end
		end
		for y = 12, 66, 12 do
			block(root, "TowerRing", Vector3.new(82, y, 700), Vector3.new(20, 1, 20), wood)
		end
		local beacon = block(
			root,
			"TowerBeacon",
			Vector3.new(82, 72, 700),
			Vector3.new(3, 3, 3),
			Color3.fromRGB(240, 68, 47),
			{ material = Enum.Material.Neon }
		)
		Build.light(beacon, "Exit", Color3.fromRGB(255, 100, 60), 45, 1, true)
		block(
			root,
			"RescueRoad",
			Vector3.new(0, 0.1, 876),
			Vector3.new(270, 0.2, 24),
			Color3.fromRGB(57, 59, 55),
			{ material = Enum.Material.Asphalt }
		)
		local van = Build.model(root, "RescueVan")
		block(van, "Body", Vector3.new(0, 2, 886), Vector3.new(12, 8, 17), Color3.fromRGB(179, 184, 159))
		block(van, "Windshield", Vector3.new(0, 7, 877.3), Vector3.new(10, 3, 0.3), Color3.fromRGB(35, 50, 51))
		for _, x in { -6, 6 } do
			for _, z in { 880, 891 } do
				Build.cylinder(van, "Wheel", Vector3.new(x, 2, z), Vector3.xAxis, 1.5, 4, Color3.fromRGB(20, 23, 20))
			end
		end
		local safe = block(
			root,
			"RescueBeacon",
			Vector3.new(0, 0, 870),
			Vector3.new(2, 9, 2),
			Color3.fromRGB(102, 222, 148),
			{ material = Enum.Material.Neon, collide = false }
		)
		Build.light(safe, "Exit", Color3.fromRGB(130, 255, 181), 45, 1.6, true)
		Build.sign(
			root,
			"RescueSign",
			Vector3.new(0, 12, 870),
			-Vector3.zAxis,
			Vector2.new(20, 3),
			"RESGATE / REÚNAM-SE AQUI",
			{ textColor = Color3.fromRGB(152, 255, 193), lit = true }
		)
	end
	return root
end
-- Eventos das tarefas que mexem no mapa novo (floresta v2).
function Builder.event(forest: Instance, event: string)
	if event == "forest_broadcast" then
		V2.lightBeacon(forest)
	elseif event == "forest_winch" then
		V2.raiseBridge(forest)
	end
end
function Builder.pressure(parent: Instance, now: number, chapter: number, playing: boolean)
	local forest = parent:FindFirstChild("Forest")
	if not forest then
		return
	end
	local forced = tonumber(forest:GetAttribute("ForcedBlackoutUntil")) or 0
	local dark = playing and (Threat.dark(now, chapter) or now < forced)
	if forest:GetAttribute("Blackout") == dark then
		return
	end
	forest:SetAttribute("Blackout", dark)
	parent:SetAttribute("ForestBlackout", dark)
	for _, part in forest:GetChildren() do
		if part:GetAttribute(Tags.Attr.LightKind) == "ForestGuide" then
			local light = part:FindFirstChildWhichIsA("PointLight")
			if light then
				light.Enabled = not dark
			end
		end
	end
end
return Builder
