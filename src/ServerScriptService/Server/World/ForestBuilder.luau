--!strict
-- Construção por capítulo: horizonte cenográfico amplo, trilhas livres e abrigos autoritativos.
local CollectionService = game:GetService("CollectionService")
local Forest = require("@game/ReplicatedStorage/Shared/Game/ForestCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Build = require("./Build")
local FeatureBuilder = require("./FeatureBuilder")
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
end
function Builder.build(parent: Instance, chapter: number, seed: number, features: FeatureBuilder.Built): Folder
	Builder.clear(parent, features)
	local root = Build.folder(parent, "Forest")
	root:SetAttribute("Chapter", chapter)
	local rng = Random.new(seed + chapter * 104729)
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
	for _, z in { 640, 670, 700, 730, 760, 790, 820, 850 } do
		block(
			root,
			"BranchTrail",
			Vector3.new(0, 0.07, z),
			Vector3.new(112, 0.08, 14),
			Color3.fromRGB(78, 69, 51),
			{ material = Enum.Material.Ground, collide = false }
		)
	end
	local function tree(container: Instance, x: number, z: number, distant: boolean)
		local height = rng:NextNumber(22, 44)
		block(
			container,
			"Trunk",
			Vector3.new(x, 0, z),
			Vector3.new(3, height, 3),
			wood,
			{ material = Enum.Material.Wood, collide = not distant, query = not distant }
		)
		for level = 1, 2 do
			local crown = block(
				container,
				"Canopy",
				Vector3.new(x, height - 7 + level * 4, z),
				Vector3.new(17 - level * 3, 9, 17 - level * 3),
				leaf,
				{ material = Enum.Material.Grass, collide = false, query = false }
			)
			crown.CFrame *= CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		end
	end
	-- Subárvores pequenas são publicadas por lote; geração cede a thread para o Studio.
	for batch = 1, 8 do
		local grove = Instance.new("Folder")
		grove.Name = `Grove{batch}`
		for _ = 1, 65 do
			local near = batch <= 4
			local x = rng:NextNumber(if near then -230 else -1100, if near then 230 else 1100)
			local z = rng:NextNumber(if near then 510 else -380, if near then 960 else 1820)
			local free = math.abs(x) < 16
			for _, aisle in { 640, 670, 700, 730, 760, 790, 820, 850 } do
				free = free or (math.abs(x) < 70 and math.abs(z - aisle) < 15)
			end
			if not free then
				tree(grove, x, z, not near)
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
	for z = 600, 840, 40 do
		local lamp = block(root, "TrailLantern", Vector3.new(12, 0, z), Vector3.new(0.7, 4, 0.7), wood)
		Build.light(lamp, "Exit", Color3.fromRGB(235, 179, 88), 23, 0.65, true)
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
	Build.sign(
		root,
		"ChapterBoard",
		Vector3.new(0, 6, 610),
		Vector3.zAxis,
		Vector2.new(20, 4),
		Forest.Chapters[chapter - 5].title,
		{ textColor = Color3.fromRGB(226, 193, 130), lit = true }
	)
	for index, spot in Forest.Hides do
		local id = `hide_Forest_{index}`
		local p = Vector3.new(spot.x, 0, spot.z)
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
			Vector3.zAxis,
			Vector2.new(20, 3),
			"RESGATE / REÚNAM-SE AQUI",
			{ textColor = Color3.fromRGB(152, 255, 193), lit = true }
		)
	end
	return root
end
return Builder
