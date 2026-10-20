--!strict
-- Mansão autoral de quatro níveis: corredores contínuos, quartos e escadaria em retornos.
local CollectionService = game:GetService("CollectionService")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Build = require("./Build")
local MapBuilder = require("./MapBuilder")
local FeatureBuilder = require("./FeatureBuilder")
local Architecture = require("./HouseArchitecture")
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Television = require("./HouseTelevision")
local Clocks = require("./HouseClocks")
local Access = require("./HouseAccess")
local Builder = {}
local wood = Color3.fromRGB(75, 48, 32)
local plaster = Color3.fromRGB(104, 94, 76)
local dark = Color3.fromRGB(30, 25, 24)
local gold = Color3.fromRGB(203, 163, 79)
local function block(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	z: number,
	sx: number,
	sy: number,
	sz: number,
	color: Color3
): BasePart
	local masonry = name == "Facade"
		or name == "DoorWall"
		or name == "DoorLintel"
		or name == "RoomPartition"
		or name == "RoomCeiling"
		or name == "RearWall"
		or name == "EntrySide"
		or name == "EntryLintel"
	local ground = name == "ForestGround" or name == "Garden" or name == "SideGarden" or name == "BackGarden"
	return Build.block(parent, name, Vector3.new(x, y, z), Vector3.new(sx, sy, sz), 0, color, {
		material = if masonry
			then Enum.Material.Plaster
			elseif ground then Enum.Material.Ground
			elseif name == "PowerPanel" or name == "PowerLamp" then Enum.Material.Metal
			else Enum.Material.WoodPlanks,
	})
end
local function sound(parent: Instance, name: string): Sound
	return Build.sound(parent, name, Audio.Door.id, 0.4)
end
local function sign(parent: Instance, text: string, position: Vector3, facing: Vector3?)
	Build.sign(
		parent,
		"Plaque",
		position,
		facing or Vector3.zAxis,
		Vector2.new(8, 1.2),
		text,
		{ textColor = gold, background = dark, lit = true, font = Enum.Font.SpecialElite }
	)
end
local function tag(part: BasePart, id: string, prompt: string)
	part:SetAttribute(Tags.Attr.InteractId, id)
	part:SetAttribute(Tags.Attr.InteractPrompt, prompt)
	part:SetAttribute(Tags.Attr.InteractDistance, 8)
	part:SetAttribute(Tags.Attr.InteractEnabled, true)
	CollectionService:AddTag(part, Tags.Interactable)
end
local function ramp(parent: Instance, name: string, x: number, fromZ: number, toZ: number, fromY: number, toY: number)
	local from, to = Vector3.new(x, fromY, fromZ), Vector3.new(x, toY, toZ)
	local direction = to - from
	local part = Build.part(
		parent,
		name,
		Vector3.new(10, 1, direction.Magnitude + 2),
		CFrame.lookAt((from + to) / 2 - Vector3.yAxis * 0.5, to - Vector3.yAxis * 0.5),
		wood,
		{ material = Enum.Material.WoodPlanks }
	)
	part:SetAttribute("StairRoute", name)
	-- Corrimões ficam fora do corredor do agente.
	for _, side in { -1, 1 } do
		-- Os balaústres são visuais; a proteção contínua impede cair entre eles ao agachar.
		Build.part(
			parent,
			"StairGuard",
			Vector3.new(0.25, 3.4, direction.Magnitude),
			part.CFrame * CFrame.new(side * 5.1, 1.6, 0),
			dark,
			{ transparency = 1, query = false }
		)
		Build.part(
			parent,
			"Railing",
			Vector3.new(0.3, 0.3, direction.Magnitude),
			part.CFrame * CFrame.new(side * 5.1, 3.2, 0),
			dark
		)
	end
end
function Builder.build(parent: Instance): (MapBuilder.World, FeatureBuilder.Built)
	local old = parent:FindFirstChild(Tags.WorldFolder)
	if old then
		old:Destroy()
	end
	local root = Build.folder(parent, Tags.WorldFolder)
	local structure = Build.folder(root, "Architecture")
	local props = Build.folder(root, "Furnishings")
	local doors = Build.folder(root, "Doors")
	local gates = Build.folder(root, "MissionGates")
	local featureRoot = Build.folder(root, "Features")
	Build.folder(featureRoot, "Pickups")
	block(structure, "ForestGround", 0, -18, 5, 230, 1, 230, Color3.fromRGB(28, 38, 29))
	-- O jardim fica no nível zero; o porão ocupa somente a projeção da casa.
	block(structure, "Garden", 0, -1, 96, 140, 1, 64, Color3.fromRGB(31, 43, 32))
	for _, x in { -76, 76 } do
		block(structure, "SideGarden", x, -1, -14, 60, 1, 190, dark)
	end
	block(structure, "BackGarden", 0, -1, -102, 140, 1, 34, dark)
	local windows = Layout.facadeWindows(House.Rooms)
	for _, y in { -16, 0, 16, 32 } do
		block(structure, "CorridorFloor", 0, y - 1, -36, 16, 1, 98, wood)
		for _, side in { -1, 1 } do
			-- Fachada lateral com vãos de janela reais (HouseLayout.facadeWindows): faixa de baixo, de cima e os
			-- trechos entre os vãos. Cada vão tem uma vidraça invisível que segura a colisão e a visão como a parede.
			local W = Layout.Window
			local cuts: { number } = {}
			for _, hole in windows do
				if hole.side == side and hole.y == y then
					table.insert(cuts, hole.z)
				end
			end
			table.sort(cuts)
			if #cuts == 0 then
				block(structure, "Facade", side * 44, y, -36, 1, 16, 98, plaster)
			else
				block(structure, "Facade", side * 44, y, -36, 1, W.y0, 98, plaster)
				block(structure, "Facade", side * 44, y + W.y1, -36, 1, 16 - W.y1, 98, plaster)
				local z = -85
				for _, at in cuts do
					local z1 = at - W.halfWidth
					block(structure, "Facade", side * 44, y + W.y0, (z + z1) / 2, 1, W.y1 - W.y0, z1 - z, plaster)
					local pane = block(
						structure,
						"WindowPane",
						side * 44,
						y + W.y0,
						at,
						1,
						W.y1 - W.y0,
						2 * W.halfWidth,
						plaster
					)
					pane.Transparency, pane.CastShadow = 1, false
					z = at + W.halfWidth
				end
				block(structure, "Facade", side * 44, y + W.y0, (z + 13) / 2, 1, W.y1 - W.y0, 13 - z, plaster)
			end
			for row = 1, 3 do
				local z = 28 - row * 32
				block(structure, "RoomFloor", side * 26, y - 1, z, 36, 1, 32, wood)
				-- Abertura de dez studs; lintel em 11,5 deixa o agente alto passar.
				for _, offset in { -10.5, 10.5 } do
					block(structure, "DoorWall", side * 8, y, z + offset, 1, 16, 11, plaster)
				end
				-- 4,45 de altura: o topo fica 0,05 abaixo do piso de cima (com 4,5 o tijolo piscava no vão da porta acima).
				block(structure, "DoorLintel", side * 8, y + 11.5, z, 1, 4.45, 10, plaster)
				block(structure, "RoomPartition", side * 26, y, z - 16, 36, 16, 1, plaster)
				-- Tetos dos quartos; o corredor/escadaria não recebe piso que corte as rampas.
				block(structure, "RoomCeiling", side * 26, y + 15, z, 36, 0.5, 32, plaster)
			end
		end
		block(structure, "RearWall", 0, y, -85, 89, 16, 1, plaster)
	end
	for _, stair in Layout.Stairs do
		ramp(structure, stair.name, stair.x, stair.z0, stair.z1, stair.y0, stair.y1)
	end
	Architecture.build(structure, props)
	Television.build(props)
	Clocks.build(props)
	block(structure, "StairRoof", 10.5, 47, 38, 70, 1, 53, dark)
	block(structure, "HouseRoof", 0, 48, -36, 94, 1, 106, dark)
	for _, side in { -1, 1 } do
		for _, y in { 0, 16, 32 } do
			local x = side * 26
			block(structure, "FacadeSill", x, y, 12, 36, 5, 1, plaster)
			block(structure, "FacadeTop", x, y + 11, 12, 36, 4, 1, plaster)
			-- Oeste: de x = −24,5 em diante a parede dá para o bloco da escadaria (reboco a poucos studs do vidro,
			-- um painel claro visto de dentro). A janela ali fica do tamanho da moldura externa (x = −28,75,
			-- 8,5 de largura) e o resto vira parede.
			local glassX = if side < 0 then -28.75 else x
			local glassW = if side < 0 then 8.5 else 14
			local left, right = glassX - glassW / 2, glassX + glassW / 2
			block(structure, "WindowSide", (x - 18 + left) / 2, y + 5, 12, left - (x - 18), 6, 1, plaster)
			block(structure, "WindowSide", (right + x + 18) / 2, y + 5, 12, x + 18 - right, 6, 1, plaster)
			local window =
				block(structure, "WindowGlass", glassX, y + 5, 12, glassW, 6, 0.3, Color3.fromRGB(62, 82, 83))
			window.Material, window.Transparency = Enum.Material.Glass, 0.55
			block(props, "WindowMullion", glassX, y + 5, 12.2, 0.3, 6, 0.4, wood)
		end
	end
	sign(root, "TUNG TUNG SAHUR / THE CURSED HOUSE", Vector3.new(8, 35, 65))
	for i = 1, 28 do
		local x = if i % 2 == 0 then -67 - i % 4 * 8 else 67 + i % 4 * 8
		local z = -105 + i * 8
		block(props, "TreeTrunk", x, 0, z, 3, 22 + i % 4, 3, wood)
		local leaves = block(props, "TreeCrown", x, 18, z, 15, 12, 15, Color3.fromRGB(18, 30, 23))
		leaves.Material = Enum.Material.Grass
	end
	local function gate(name: string, x: number, y: number, z: number, sx: number, sz: number)
		local panel = block(gates, name, x, y, z, sx, 11, sz, dark)
		sign(panel, "PASSAGEM SELADA", panel.Position + Vector3.new(0, 3, 1))
	end
	gate("entry", 0, 0, 64, 12, 1)
	block(structure, "EntrySide", -15, 0, 64, 18, 47, 1, plaster)
	block(structure, "EntrySide", 25.5, 0, 64, 39, 47, 1, plaster)
	block(structure, "EntryLintel", 0, 11.5, 64, 12, 35.5, 1, plaster)
	gate("corridor", 0, 0, -52, 16, 1)
	gate("upstairs", 16, 0, 23, 10, 1)
	gate("basement", -16, -16, 23, 10, 1)
	gate("ritual", 0, -16, -52, 16, 1)
	Access.build(root)
	local interactables: { [string]: MapBuilder.Interactable } = {}
	local doorHandles: { [string]: MapBuilder.DoorHandle } = {}
	local lockers: { [string]: FeatureBuilder.LockerHandle } = {}
	local featureItems: { [string]: FeatureBuilder.Interactable } = {}
	for index, room in House.Rooms do
		if room.id == "Exterior" or room.id == "Hall" then
			continue
		end
		local center = Vector3.new(room.x, room.y, room.z)
		sign(
			props,
			room.title,
			Vector3.new(if room.x < 0 then -7.35 else 7.35, room.y + 9, room.z + 9),
			if room.x < 0 then Vector3.xAxis else -Vector3.xAxis
		)
		local lamp = block(props, "Candle", room.x, room.y + 7, room.z - 12, 0.35, 1, 0.35, gold)
		Build.light(lamp, "Street", Color3.fromRGB(255, 188, 105), 31, 0.85, true, false)
		local light = block(props, "PowerLamp", room.x + 3, room.y + 12, room.z, 1, 0.25, 1, gold)
		Build.light(light, "Lamp", Color3.fromRGB(255, 209, 138), 27, 0.8, false, true)
		local tablePart = block(props, "AntiqueTable", room.x, room.y, room.z - 11, 9, 2.5, 3, wood)
		tablePart.Material = Enum.Material.Wood
		if room.id == "Library" or string.find(room.id, "Attic") then
			for n = 1, 5 do
				block(props, "Bookshelf", room.x - 10 + n * 4, room.y, room.z - 14, 3, 8, 1.3, wood)
			end
		elseif room.id == "Bedroom" or room.id == "Child" then
			block(props, "Bed", room.x + 9, room.y + 2, room.z - 8, 7, 1, 11, Color3.fromRGB(102, 62, 59))
		elseif room.id == "Ritual" then
			Build.cylinder(
				props,
				"RitualCircle",
				center + Vector3.new(0, 0.06, 0),
				Vector3.yAxis,
				0.1,
				16,
				Color3.fromRGB(104, 27, 28),
				{ collide = false }
			)
		end
		-- Portas normais abrem pelo mesmo WorldService; não há outro dono de interação.
		local doorId = `house_door_{index}`
		local doorCenter = Vector3.new(if room.x < 0 then -8 else 8, room.y + 5.5, room.z)
		local doorPanel = Build.part(doors, doorId, Vector3.new(0.5, 11, 9), CFrame.new(doorCenter), wood)
		doorPanel.Material = Enum.Material.Wood
		local hinge = CFrame.new(doorCenter + Vector3.new(0, 0, -4.5))
		local closed = doorPanel.CFrame
		local openAngle = math.rad(if room.x < 0 then -95 else 95)
		local opened = hinge * CFrame.Angles(0, openAngle, 0) * (hinge:Inverse() * closed)
		local passage = Instance.new("PathfindingModifier")
		passage.Label, passage.PassThrough, passage.Parent = "Door", true, doorPanel
		doorPanel.CFrame = opened
		tag(doorPanel, doorId, "ABRIR / FECHAR PORTA")
		doorHandles[doorId] = {
			id = doorId,
			panel = doorPanel,
			center = doorCenter,
			hinge = hinge,
			closedCFrame = closed,
			openCFrame = opened,
			openAngle = openAngle,
			isOpen = true,
			startsOpen = true,
			busy = false,
			sound = sound(doorPanel, "Creak"),
		}
		interactables[doorId] =
			{ id = doorId, kind = "Door", focus = doorPanel, model = doorPanel, maxDistance = 8, enabled = true }
		-- Armário com corpo opaco; a câmera olha por uma fresta, sem expor o personagem.
		local id = `hide_{room.id}`
		local cabinet = Build.model(featureRoot, id)
		-- Guarda-roupa encostado na fachada, no canto da frente (o humano pediu: não no meio do cômodo).
		-- Camas e o baú do túnel (Bedroom, Child, Tunnel) ficam onde estavam.
		local bedLike = room.id == "Bedroom" or room.id == "Child" or room.id == "Tunnel"
		local p = center
			+ if bedLike
				then Vector3.new(if room.x < 0 then -11 else 11, 0, 7)
				else Vector3.new(if room.x < 0 then -15.4 else 15.4, 0, 12.6)
		for _, dx in { -2, 2 } do
			block(cabinet, "Side", p.X + dx, p.Y, p.Z, 0.5, 8, 3, wood)
		end
		block(cabinet, "Back", p.X, p.Y, p.Z - 1.5, 4, 8, 0.5, wood)
		block(cabinet, "Top", p.X, p.Y + 8, p.Z, 4.5, 0.5, 3.5, wood)
		local door = block(cabinet, "HideDoor", p.X, p.Y, p.Z + 1.5, 4, 8, 0.35, wood)
		tag(
			door,
			id,
			if room.id == "Bedroom" or room.id == "Child" then "ESCONDER JUNTO À CAMA" else "ESCONDER NO ARMÁRIO"
		)
		local front = p + Vector3.new(0, 0, 4)
		lockers[id] = {
			id = id,
			model = cabinet,
			door = door,
			doorClosed = door.CFrame,
			hinge = CFrame.new(p),
			inside = CFrame.new(p + Vector3.new(0, 3, 0)),
			eye = CFrame.lookAt(p + Vector3.new(0, 5.5, 1.8), p + Vector3.new(0, 5.5, 8)),
			exit = CFrame.new(front + Vector3.new(0, 3, 0)),
			front = front,
			sound = sound(door, "Creak"),
			occupant = nil,
		}
		if room.id ~= "Bedroom" and room.id ~= "Child" and room.id ~= "Tunnel" then
			-- Guarda-roupa de frente para a porta do cômodo, não de lado: gira o armário inteiro (com fresta,
			-- entrada e saída) 90° em torno do próprio centro.
			local outward = if room.x < 0 then -1 else 1
			local turn = CFrame.new(p) * CFrame.Angles(0, -outward * math.pi / 2, 0) * CFrame.new(-p)
			for _, part in cabinet:GetChildren() do
				if part:IsA("BasePart") then
					part.CFrame = turn * part.CFrame
				end
			end
			local locker = lockers[id]
			locker.doorClosed = door.CFrame
			locker.inside = turn * locker.inside
			locker.eye = turn * locker.eye
			locker.exit = turn * locker.exit
			locker.front = turn * locker.front
		end
		if room.id == "Bedroom" or room.id == "Child" or room.id == "Tunnel" then
			for _, child in cabinet:GetChildren() do
				if child ~= door then
					child:Destroy()
				end
			end
			local compartment = room.id == "Tunnel"
			block(cabinet, if compartment then "ChestLid" else "BedCover", p.X, p.Y + 3, p.Z, 8, 0.7, 6, wood)
			for _, dx in { -3.7, 3.7 } do
				block(cabinet, "Leg", p.X + dx, p.Y, p.Z, 0.5, 3.5, 5, wood)
			end
			block(cabinet, "Back", p.X, p.Y, p.Z - 3, 8, 3.5, 0.5, wood)
			door.Size, door.CFrame, door.Transparency, door.CanCollide =
				Vector3.new(5, 1, 0.3), CFrame.new(p + Vector3.new(0, 1.5, 3)), 0.8, false
			tag(door, id, if compartment then "ENTRAR NO COMPARTIMENTO" else "ESCONDER SOB A CAMA")
			local locker = lockers[id]
			locker.inside = CFrame.new(p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
			locker.eye = CFrame.lookAt(p + Vector3.new(0, 1.7, 3.2), p + Vector3.new(0, 1.7, 8))
			locker.doorClosed = door.CFrame
		end
		featureItems[id] = { id = id, kind = "Hide", focus = door, model = cabinet, maxDistance = 8, enabled = true }
	end
	local gateModel = Build.model(root, "ForestGate")
	local gatePanel = block(gateModel, "Gate", 0, 0, 98, 18, 10, 1, dark)
	gateModel.PrimaryPart = gatePanel
	local gatePivot = gateModel:GetPivot()
	local beacon = block(root, "ExitBeacon", 11, 0, 98, 1, 8, 1, gold)
	Build.light(beacon, "Exit", Color3.fromRGB(90, 210, 130), 28, 1, true)
	sign(root, "SAÍDA / FLORESTA", Vector3.new(0, 10, 98))
	local utility = Build.folder(root, "Utility")
	local panel = block(utility, "PowerPanel", 36, 0, -80, 3, 4, 1, dark)
	local labelPart = Build.sign(
		utility,
		"Diagram",
		Vector3.new(36, 6, -80),
		Vector3.zAxis,
		Vector2.new(5, 2),
		"ENERGIA PARCIAL",
		{ textColor = gold }
	)
	local label = labelPart:FindFirstChildWhichIsA("TextLabel", true) :: TextLabel
	local world: MapBuilder.World = {
		root = root,
		interactables = interactables,
		fuseModels = {},
		doors = doorHandles,
		gate = {
			model = gateModel,
			closedPivot = gatePivot,
			openPivot = gatePivot + Vector3.new(0, 12, 0),
			isOpen = false,
			busy = false,
			sound = sound(gatePanel, "Gate"),
			beacon = beacon,
		},
		panel = {
			focus = panel,
			slotFuses = {},
			status = panel,
			switchSound = sound(panel, "Switch"),
			hum = sound(panel, "Hum"),
		},
		buzz = {},
		spawnCFrame = CFrame.lookAt(Vector3.new(0, 3, 77), Vector3.new(0, 3, 0)),
	}
	local features: FeatureBuilder.Built = {
		root = featureRoot,
		interactables = featureItems,
		keys = {},
		batteries = {},
		lockers = lockers,
		fallables = {},
		radio = panel,
		breakers = {
			box = panel,
			levers = {},
			down = {},
			up = {},
			lamps = {},
			diagram = label,
			toggle = sound(panel, "Toggle"),
			fail = sound(panel, "Fail"),
			solved = sound(panel, "Solved"),
		},
	}
	return world, features
end
return Builder
