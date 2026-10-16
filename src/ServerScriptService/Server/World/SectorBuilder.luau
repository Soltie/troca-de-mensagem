--!strict
-- Ala modular física. O eixo de dez studs e o quadrante do terminal ficam livres de equipamentos.
local CollectionService = game:GetService("CollectionService")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Build = require("./Build")
local Layout = require("./ProceduralLayout")
local Palette = require("./Palette")
local Props = require("./Props")
local Exterior = require("./SectorExterior")

local Builder = {}
local V3 = Vector3.new
local HALF = Layout.RoomSize / 2
local HEIGHT = 11
local DECOR = { collide = false, query = false, material = Enum.Material.Metal }

local function surface(part: BasePart, style: string)
	part:SetAttribute("SurfaceStyle", style)
	CollectionService:AddTag(part, "ArtSurface")
end

local function sign(parent: Instance, p: Vector3, facing: Vector3, text: string, size: Vector2?)
	local part = Build.sign(parent, "SectorSign", p, facing, size or Vector2.new(8, 1.2), text, {
		textColor = Palette.Paper,
		background = Palette.WallLowerCold,
		lit = true,
		thickness = 0.04,
	})
	part.CanQuery = false
end

local function wall(parent: Instance, a: Vector3, b: Vector3, opening: boolean, outdoor: boolean?)
	local length = (b - a).Magnitude
	local horizontal = math.abs(b.X - a.X) > 1
	local function segment(offset: number, width: number, bottom: number, top: number)
		local center = (a + b) / 2 + (b - a).Unit * offset
		local size = if horizontal then V3(width, top - bottom, 1) else V3(1, top - bottom, width)
		local part = Build.part(
			parent,
			"Wall_Sector",
			size,
			CFrame.new(center + V3(0, (top + bottom) / 2, 0)),
			if bottom == 0 then Palette.WallLowerCold else Palette.WallUpperCold,
			{ material = Enum.Material.Concrete }
		)
		part:SetAttribute("SectorWall", true)
		if outdoor then
			part.Material = Enum.Material.Metal
			part.Transparency = 0.55
			part.CastShadow = false
		end
	end
	if opening then
		local side = (length - Layout.DoorWidth) / 2
		for _, direction in { -1, 1 } do
			local offset = direction * (Layout.DoorWidth / 2 + side / 2)
			segment(offset, side, 0, 3.2)
			segment(offset, side, 3.2, HEIGHT)
		end
		segment(0, Layout.DoorWidth, 9, HEIGHT)
		local threshold = Build.block(
			parent,
			"Threshold",
			(a + b) / 2 + V3(0, 0.015, 0),
			if horizontal then V3(Layout.DoorWidth, 0.025, 0.7) else V3(0.7, 0.025, Layout.DoorWidth),
			0,
			Palette.Hazard,
			{ collide = false, query = false }
		)
		threshold.Material = Enum.Material.Metal
	else
		segment(0, length, 0, 3.2)
		segment(0, length, 3.2, HEIGHT)
	end
end

-- Peças locais; todas cabem numa área 8x8, fora do cruzamento e da estação de atividade.
local function equipment(parent: Instance, kind: string, frame: CFrame)
	local model = Build.model(parent, "Equipment")
	local function block(name: string, p: Vector3, size: Vector3, color: Color3): BasePart
		return Build.block(model, name, p, size, 0, color, { material = Enum.Material.Metal })
	end
	if kind == "Cooling" or kind == "WaterTreatment" then
		for _, x in { -1.6, 1.6 } do
			Props.pumpTank(model, V3(x, 0, 0), if kind == "Cooling" then 6 else 4.8, 2.5)
		end
		Props.pipe(model, V3(-3, 7.6, 0), V3(3, 7.6, 0), 0.5, Palette.Rust, false)
		block("ValveBox", V3(0, 0, 2.5), V3(1.8, 1.4, 1), Palette.MetalDark)
	elseif kind == "RelayHall" or kind == "BatteryBank" then
		block("Rack", V3(0, 0, 0), V3(6, 6.4, 2), Palette.WallLowerCold)
		for row = 1, 3 do
			for column = -1, 1 do
				block("Cell", V3(column * 1.7, row * 1.5 - 0.7, 1.05), V3(1.3, 1, 0.5), Palette.MetalDark)
				block("Terminal", V3(column * 1.7, row * 1.5 + 0.35, 1.2), V3(0.22, 0.2, 0.3), Palette.Brass)
			end
		end
	elseif kind == "Radio" then
		block("Console", V3(0, 0, 0), V3(6, 3.2, 3), Palette.WallLowerCold)
		for _, x in { -1.7, 1.7 } do
			block("Radio", V3(x, 3.2, 0), V3(2.6, 1.7, 1.8), Palette.Metal)
			for y = 1, 3 do
				Build.block(
					model,
					"SpeakerGrille",
					V3(x, 3.4 + y * 0.3, 0.94),
					V3(1.5, 0.08, 0.04),
					0,
					Palette.Black,
					DECOR
				)
			end
		end
		local screen =
			Build.part(model, "Screen", V3(1.3, 0.7, 0.05), CFrame.new(-1.7, 4.3, -0.94), Palette.Screen, DECOR)
		CollectionService:AddTag(screen, "ArtScreen")
	elseif kind == "MachineShop" then
		block("LatheBase", V3(0, 0, 0), V3(6, 2.3, 3), Palette.WallLowerCold)
		Build.cylinder(model, "LatheSpindle", V3(0, 3.3, 0), Vector3.xAxis, 5, 1.7, Palette.Metal)
		for _, x in { -2.5, 2.5 } do
			block("LatheHead", V3(x, 2.3, 0), V3(1, 2.3, 2.5), Palette.MetalDark)
		end
	elseif kind == "Inspection" then
		Props.workbench(model, Vector3.zero, 0)
		block("TestInstrument", V3(0, 3.2, 0), V3(1.8, 1.3, 1.3), Palette.Ceramic)
	elseif kind == "CableDepot" then
		for _, x in { -1.7, 1.7 } do
			Build.cylinder(model, "ReelCable", V3(x, 1.7, 0), Vector3.zAxis, 2, 2.8, Palette.Black)
			for _, z in { -1.1, 1.1 } do
				Build.cylinder(model, "ReelSide", V3(x, 1.7, z), Vector3.zAxis, 0.25, 3.4, Palette.WoodDark)
			end
		end
	elseif kind == "Turbine" then
		block("TurbineBed", V3(0, 0, 0), V3(7, 0.6, 5), Palette.Concrete)
		Build.cylinder(model, "TurbineBody", V3(0, 3, 0), Vector3.xAxis, 6, 4, Palette.Metal)
		for x = -2, 2 do
			Build.cylinder(model, "CoolingRing", V3(x, 3, 0), Vector3.xAxis, 0.15, 4.3, Palette.MetalDark)
		end
	end
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = frame * part.CFrame
			if part.Name == "Rack" or part.Name == "Console" or part.Name == "TurbineBody" then
				surface(part, "rust")
			end
		end
	end
end

local function dressing(parent: Instance, room: Layout.Room)
	local center = V3(room.x, 0, room.z)
	local corners = { V3(-9, 0, -9), V3(9, 0, -9), V3(-9, 0, 9) }
	local corner = room.turn % #corners + 1
	equipment(parent, room.kind, CFrame.new(center + corners[corner]) * CFrame.Angles(0, room.turn * math.pi / 2, 0))
	Props.crate(parent, center + corners[corner % #corners + 1], room.turn * 90, 3)
	-- Bandeja e tubos altos reforçam a direção das passagens sem ocupar a altura do Vigia.
	Build.block(parent, "CableTray", center + V3(0, 10, 0), V3(2, 0.2, 26), 0, Palette.MetalDark, DECOR)
	Props.pipe(parent, center + V3(-3, 9.7, -13), center + V3(-3, 9.7, 13), 0.18, Palette.Rust, false)
	local lamp = Build.block(parent, "SectorLamp", center + V3(0, 9.6, 0), V3(4, 0.25, 0.7), 0, Palette.LampOff, DECOR)
	Build.light(lamp, "Lamp", Palette.Fluorescent, 24, 1.1, false, room.cell % 4 == 0)
	local emergency =
		Build.block(parent, "Emergency", center + V3(-12.8, 7.5, 0), V3(0.4, 0.6, 1), 0, Palette.Red, DECOR)
	Build.light(emergency, "Emergency", Palette.Emergency, 15, 0.65, true)
	local dust = Build.part(
		parent,
		"DustAnchor",
		V3(0.1, 0.1, 0.1),
		CFrame.new(center + V3(0, 7, 0)),
		Palette.Paper,
		{ collide = false, query = false, transparency = 1 }
	)
	CollectionService:AddTag(dust, "ArtDust")
	sign(
		parent,
		center + V3(8, 7, 13.4),
		-Vector3.zAxis,
		string.format("N-%02d / %s", room.cell, Catalog.RoomNames[room.kind]),
		Vector2.new(10, 1.8)
	)
	-- Marcações de circulação deixam legíveis os cruzamentos sob a iluminação de emergência.
	for _, offset in { -8, 8 } do
		Build.block(
			parent,
			"RouteMark",
			center + V3(0, 0.02, offset),
			V3(0.2, 0.02, 3),
			0,
			Palette.Hazard,
			{ collide = false, query = false }
		)
	end
end

local function passage(parent: Instance, spec: Layout.Passage)
	local model = Build.model(parent, spec.id)
	model:SetAttribute("Covered", spec.covered)
	local x, z = (spec.x0 + spec.x1) / 2, (spec.z0 + spec.z1) / 2
	local sx, sz = spec.x1 - spec.x0, spec.z1 - spec.z0
	Build.block(model, "PassageFloor", V3(x, -1, z), V3(sx, 1, sz), 0, Palette.MetalFloor, {
		material = Enum.Material.DiamondPlate,
	})
	if spec.covered then
		Build.block(model, "PassageRoof", V3(x, HEIGHT, z), V3(sx + 0.5, 0.5, sz + 0.5), 0, Palette.Ceiling)
	end
	if spec.id == "AccessGallery" then
		-- Fecha só os intervalos entre pavilhões, sem paredes cruzando os três acessos.
		for _, gapX in { -28, 16 } do
			wall(model, V3(gapX - 8, 0, spec.z0), V3(gapX + 8, 0, spec.z0), false)
		end
		for _, lx in { -50, -6, 38 } do
			local lamp = Build.block(model, "GalleryLamp", V3(lx, 9.8, z), V3(4, 0.2, 0.7), 0, Palette.LampOff, DECOR)
			Build.light(lamp, "Lamp", Palette.Fluorescent, 26, 1, false)
		end
		sign(model, V3(-60, 8.5, -87), Vector3.xAxis, "< VIA EXTERNA / MANUTENÇÃO")
		sign(model, V3(48, 8.5, -87), -Vector3.xAxis, "TUBULAÇÕES / PÁTIO NORTE >")
	else
		local horizontal = sx > sz
		local height = if spec.covered then HEIGHT else 1.2
		for _, side in { -1, 1 } do
			Build.block(
				model,
				if spec.covered then "PassageWall" else "WalkwayRail",
				V3(x + (if horizontal then 0 else side * sx / 2), 0, z + (if horizontal then side * sz / 2 else 0)),
				if horizontal then V3(sx, height, 0.4) else V3(0.4, height, sz),
				0,
				Palette.WallLowerCold
			)
		end
		Build.block(
			model,
			"OverheadTray",
			V3(x, 9.8, z),
			if horizontal then V3(sx, 0.2, 1) else V3(1, 0.2, sz),
			0,
			Palette.MetalDark,
			DECOR
		)
		local lamp = Build.block(model, "PassageLamp", V3(x, 8.5, z), V3(0.6, 0.3, 0.6), 0, Palette.Red, DECOR)
		Build.light(lamp, "Emergency", Palette.Emergency, 16, 0.45, true)
	end
end

function Builder.build(parent: Instance, plan: Layout.Plan): Folder
	local valid, reason = Layout.validate(plan)
	assert(valid, `[SectorBuilder] invalid layout: {reason}`)
	local root = Instance.new("Folder")
	root.Name = "ProceduralSector"
	root:SetAttribute("Seed", plan.seed)
	root:SetAttribute("Stage", plan.stage)
	local structure = Build.folder(root, "Structure")
	for _, room in plan.rooms do
		local model = Build.model(root, `Cell_{room.cell}`)
		model:SetAttribute("RoomKind", room.kind)
		model:SetAttribute("Cell", room.cell)
		local center = V3(room.x, 0, room.z)
		local floor = Build.block(
			model,
			"Floor_Sector",
			center - Vector3.yAxis,
			V3(Layout.RoomSize, 1, Layout.RoomSize),
			0,
			Palette.Concrete,
			{ material = Enum.Material.Concrete }
		)
		surface(floor, "concrete")
		local outdoor = Layout.isOutdoorRoom(room)
		model:SetAttribute("Outdoor", outdoor)
		if not outdoor then
			Build.block(model, "Roof_Sector", center + V3(0, HEIGHT, 0), V3(28.5, 1, 28.5), 0, Palette.Ceiling)
		end
		dressing(model, room)
		local x0, x1 = room.x - HALF, room.x + HALF
		local z0, z1 = room.z - HALF, room.z + HALF
		wall(
			structure,
			V3(x0, 0, z0),
			V3(x0, 0, z1),
			room.cell % 3 == 1 or Layout.connected(plan, room.cell, room.cell - 1),
			outdoor
		)
		wall(
			structure,
			V3(x1, 0, z0),
			V3(x1, 0, z1),
			room.cell % 3 == 0 or Layout.connected(plan, room.cell, room.cell + 1),
			outdoor
		)
		wall(
			structure,
			V3(x0, 0, z0),
			V3(x1, 0, z0),
			room.cell == 8 or Layout.connected(plan, room.cell, room.cell + 3),
			outdoor
		)
		wall(
			structure,
			V3(x0, 0, z1),
			V3(x1, 0, z1),
			room.cell <= 3 or Layout.connected(plan, room.cell, room.cell - 3),
			outdoor
		)
	end
	for _, spec in Layout.passages(plan) do
		passage(structure, spec)
	end
	Exterior.build(root)
	local returns = Layout.returnRoutes(plan)
	for _, link in plan.links do
		local a, b = plan.rooms[link.a], plan.rooms[link.b]
		local midpoint = V3((a.x + b.x) / 2, 9.6, (a.z + b.z) / 2)
		local toward = V3(b.x - a.x, 0, b.z - a.z).Unit
		sign(
			structure,
			midpoint - toward * 0.58,
			-toward,
			Catalog.RoomNames[b.kind] .. (if returns[a.cell] == b.cell then " / SAÍDA" else "")
		)
		sign(
			structure,
			midpoint + toward * 0.58,
			toward,
			Catalog.RoomNames[a.kind] .. (if returns[b.cell] == a.cell then " / SAÍDA" else "")
		)
	end
	for _, cell in Layout.Entrances do
		local room = plan.rooms[cell]
		local x = Layout.entranceX(cell)
		sign(root, V3(x, 9.5, -77.4), Vector3.zAxis, "GALERIA NORTE / " .. Catalog.RoomNames[room.kind])
		sign(root, V3(x, 9.5, -78.6), -Vector3.zAxis, "RETORNO / SAÍDA SUL")
	end
	-- Diretório físico acompanha a distribuição real a cada rodada.
	local lines = { "ALA NORTE / PLANTA DO TURNO", `TURNO {plan.stage} / LOTE {plan.seed}` }
	for _, room in plan.rooms do
		table.insert(lines, string.format("N-%02d / %s", room.cell, Catalog.RoomNames[room.kind]))
	end
	table.insert(lines, "v CONTROLE / ARQUIVO / SAÍDA v")
	-- Parede sul do controle: o diretório não pode ficar atrás dos monitores da parede norte.
	sign(root, V3(-3, 6.4, -50.6), -Vector3.zAxis, table.concat(lines, "\n"), Vector2.new(10, 6.5))
	-- Troca atômica: a ala anterior só sai após a nova geometria estar pronta.
	local previous = parent:FindFirstChild(root.Name)
	if previous then
		previous:Destroy()
	end
	root.Parent = parent
	return root
end

return Builder
