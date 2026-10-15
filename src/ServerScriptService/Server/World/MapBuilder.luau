--!strict
--[[
	Constrói a Subestação 9 inteira a partir de Layout.luau, no servidor, a cada boot.
	Nada do mapa vive só na place: apagar a pasta Workspace.Substation9 e rodar de novo recria tudo.

	Devolve um `World` com os handles que o WorldService usa (interagíveis, portas, portão, quadro).
]]

local CollectionService = game:GetService("CollectionService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Build = require("./Build")
local Expansion = require("./Expansion")
local Layout = require("./Layout")
local Palette = require("./Palette")
local Props = require("./Props")
local WallMath = require("./WallMath")

export type Kind = "Fuse" | "Panel" | "Door" | "Gate" | "Note"

export type Interactable = {
	id: string,
	kind: Kind,
	focus: BasePart,
	model: Instance,
	maxDistance: number,
	enabled: boolean,
}

export type DoorHandle = {
	id: string,
	panel: BasePart,
	closedCFrame: CFrame,
	openCFrame: CFrame,
	hinge: CFrame,
	openAngle: number,
	isOpen: boolean,
	startsOpen: boolean,
	busy: boolean,
	center: Vector3,
	sound: Sound,
}

export type GateHandle = {
	model: Model,
	closedPivot: CFrame,
	openPivot: CFrame,
	isOpen: boolean,
	busy: boolean,
	sound: Sound,
	beacon: BasePart,
}

export type PanelHandle = {
	focus: BasePart,
	slotFuses: { BasePart },
	status: BasePart,
	switchSound: Sound,
	hum: Sound,
}

local MapBuilder = {}

-- Grupo de colisão das regiões de navegação (registrado pelo WorldService antes do build).
MapBuilder.NAV_GROUP = "NavOnly"

export type World = {
	root: Folder,
	interactables: { [string]: Interactable },
	fuseModels: { [string]: Model },
	doors: { [string]: DoorHandle },
	gate: GateHandle,
	panel: PanelHandle,
	buzz: { Sound },
	spawnCFrame: CFrame,
}

local V3 = Vector3.new
local CEILING = Layout.CEILING
local HALF = Layout.WALL_THICKNESS / 2

local function vec(p: Layout.Point): Vector3
	return V3(p.x, p.y, p.z)
end

local function register(world: World, id: string, kind: Kind, focus: BasePart, model: Instance, prompt: string)
	local distance = Config.Game.InteractDistance
	focus:SetAttribute(Tags.Attr.InteractId, id)
	focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
	focus:SetAttribute(Tags.Attr.InteractDistance, distance)
	focus:SetAttribute(Tags.Attr.InteractEnabled, true)
	CollectionService:AddTag(focus, Tags.Interactable)
	world.interactables[id] = {
		id = id,
		kind = kind,
		focus = focus,
		model = model,
		maxDistance = distance,
		enabled = true,
	}
end

-- Cores da parede conforme a sala de cada lado (frias no gerador/depósito, quentes no resto).
local function wallColors(x: number, z: number, exteriorSide: boolean): (Color3, Color3)
	if exteriorSide then
		return Palette.FacadeLower, Palette.Facade
	end
	local room = Layout.roomAt(x, z)
	if room and (room.id == "Generator" or room.id == "Storage") then
		return Palette.WallLowerCold, Palette.WallUpperCold
	end
	return Palette.WallLower, Palette.WallUpper
end

local function buildWall(parent: Instance, wall: Layout.Wall)
	local extend = if wall.exterior then HALF else 0
	local segments = WallMath.solidSegments(wall.from - extend, wall.to + extend, 0, CEILING, wall.openings)
	local lower, upper = WallMath.splitBands(segments, Layout.BAND_HEIGHT)

	-- Lado "+": +Z (paredes X) ou +X (paredes Z). Cada lado vira uma "pele" de meia espessura.
	for _, side in { 1, -1 } do
		local exteriorSide = false
		if wall.exterior then
			if wall.axis == "X" then
				exteriorSide = (side == 1 and wall.at >= Layout.Building.z1)
					or (side == -1 and wall.at <= Layout.Building.z0)
			else
				exteriorSide = (side == 1 and wall.at >= Layout.Building.x1)
					or (side == -1 and wall.at <= Layout.Building.x0)
			end
		end
		local offset = side * HALF / 2
		for bandIndex, band in { lower, upper } do
			for _, s in band do
				local mid = (s.a + s.b) / 2
				local sampleX = if wall.axis == "X" then mid else wall.at + side
				local sampleZ = if wall.axis == "X" then wall.at + side else mid
				local lowColor, highColor = wallColors(sampleX, sampleZ, exteriorSide)
				local color = if bandIndex == 1 then lowColor else highColor
				local material = if exteriorSide then Enum.Material.Concrete else Enum.Material.SmoothPlastic
				local min, max
				if wall.axis == "X" then
					min = V3(s.a, s.y0, wall.at + offset - HALF / 2)
					max = V3(s.b, s.y1, wall.at + offset + HALF / 2)
				else
					min = V3(wall.at + offset - HALF / 2, s.y0, s.a)
					max = V3(wall.at + offset + HALF / 2, s.y1, s.b)
				end
				Build.box(parent, `Wall_{wall.id}`, min, max, color, { material = material })
			end
		end
	end

	-- Grades nas janelas.
	for _, opening in wall.openings do
		if opening.bottom > 0 then
			for i = -2, 2 do
				local along = opening.center + i * opening.width / 5
				local center = if wall.axis == "X"
					then V3(along, (opening.bottom + opening.top) / 2, wall.at)
					else V3(wall.at, (opening.bottom + opening.top) / 2, along)
				Build.cylinder(
					parent,
					"Bar",
					center,
					Vector3.yAxis,
					opening.top - opening.bottom,
					0.15,
					Palette.MetalDark
				)
			end
		end
	end
end

-- Piso em xadrez alinhado à grade global (padrão contínuo entre salas).
local function tiles(parent: Instance, rect: Layout.Rect, size: number, a: Color3, b: Color3)
	local gx0 = math.floor(rect.x0 / size)
	local gx1 = math.ceil(rect.x1 / size) - 1
	local gz0 = math.floor(rect.z0 / size)
	local gz1 = math.ceil(rect.z1 / size) - 1
	for gx = gx0, gx1 do
		for gz = gz0, gz1 do
			local x0 = math.max(rect.x0, gx * size)
			local x1 = math.min(rect.x1, (gx + 1) * size)
			local z0 = math.max(rect.z0, gz * size)
			local z1 = math.min(rect.z1, (gz + 1) * size)
			if x1 > x0 and z1 > z0 then
				local color = if (gx + gz) % 2 == 0 then a else b
				Build.box(parent, "Tile", V3(x0, -1, z0), V3(x1, 0, z1), color)
			end
		end
	end
end

local function inner(rect: Layout.Rect): Layout.Rect
	return { x0 = rect.x0 + HALF, x1 = rect.x1 - HALF, z0 = rect.z0 + HALF, z1 = rect.z1 - HALF }
end

local function buildFloors(parent: Instance)
	for _, room in Layout.Rooms do
		local r = inner(room)
		if room.id == "Lobby" or room.id == "Office" then
			tiles(parent, r, 4, Palette.TileA, Palette.TileB)
		elseif room.id == "Corridor" then
			tiles(parent, r, 4, Palette.CorridorA, Palette.CorridorB)
		elseif room.id == "Generator" then
			Build.box(parent, "Floor", V3(r.x0, -1, r.z0), V3(r.x1, 0, r.z1), Palette.MetalFloor, {
				material = Enum.Material.DiamondPlate,
			})
		else
			Build.box(parent, "Floor", V3(r.x0, -1, r.z0), V3(r.x1, 0, r.z1), Palette.Concrete, {
				material = Enum.Material.Concrete,
			})
		end
	end
	-- Soleiras nas portas (cobrem o vão entre os pisos das salas).
	for _, wall in Layout.Walls do
		for _, opening in wall.openings do
			if opening.bottom == 0 then
				local w = opening.width / 2
				if wall.axis == "X" then
					Build.box(
						parent,
						"Threshold",
						V3(opening.center - w, -1, wall.at - HALF),
						V3(opening.center + w, 0, wall.at + HALF),
						Palette.MetalDark
					)
				else
					Build.box(
						parent,
						"Threshold",
						V3(wall.at - HALF, -1, opening.center - w),
						V3(wall.at + HALF, 0, opening.center + w),
						Palette.MetalDark
					)
				end
			end
		end
	end
	-- Laje do teto/telhado + platibanda.
	local b = Layout.Building
	Build.box(
		parent,
		"Roof",
		V3(b.x0 - HALF, CEILING, b.z0 - HALF),
		V3(b.x1 + HALF, CEILING + 1, b.z1 + HALF),
		Palette.Ceiling
	)
	Build.box(
		parent,
		"Parapet",
		V3(b.x0 - HALF, CEILING + 1, b.z1 - 0.2),
		V3(b.x1 + HALF, CEILING + 1.8, b.z1 + HALF),
		Palette.Trim
	)
	Build.box(
		parent,
		"Parapet",
		V3(b.x0 - HALF, CEILING + 1, b.z0 - HALF),
		V3(b.x1 + HALF, CEILING + 1.8, b.z0 + 0.2),
		Palette.Trim
	)
	Build.box(parent, "Parapet", V3(b.x0 - HALF, CEILING + 1, b.z0), V3(b.x0 + 0.2, CEILING + 1.8, b.z1), Palette.Trim)
	Build.box(parent, "Parapet", V3(b.x1 - 0.2, CEILING + 1, b.z0), V3(b.x1 + HALF, CEILING + 1.8, b.z1), Palette.Trim)
end

local function buildDoor(world: World, parent: Instance, spec: Layout.Door)
	local wall = Layout.wallById(spec.wall)
	assert(wall and wall.axis == "X", `[MapBuilder] door {spec.id} needs an X-axis wall`)
	local height = Layout.DOOR_TOP - 0.15
	local width = spec.width - 0.2
	local closed = CFrame.new(spec.center, height / 2, wall.at)
	local hingeX = if spec.hingeAtMin then spec.center - spec.width / 2 else spec.center + spec.width / 2
	local hinge = CFrame.new(hingeX, height / 2, wall.at)
	local angle = math.rad(95) * spec.side * (if spec.hingeAtMin then -1 else 1)
	local open = hinge * CFrame.Angles(0, angle, 0) * (hinge:Inverse() * closed)

	local panel = Build.part(parent, spec.id, V3(width, height, 0.35), closed, Palette.WallLowerCold, {
		material = Enum.Material.Metal,
	})
	-- Visor e maçaneta (soldados na folha para acompanhar o giro).
	local window = Build.part(parent, "DoorWindow", V3(1.4, 1.6, 0.4), closed * CFrame.new(0, 1.8, 0), Palette.Screen, {
		collide = false,
		reflectance = 0.15,
	})
	local handle = Build.part(
		parent,
		"DoorHandle",
		V3(0.5, 0.2, 0.6),
		closed * CFrame.new((if spec.hingeAtMin then 1 else -1) * (width / 2 - 0.5), -0.6, 0),
		Palette.Metal,
		{ collide = false }
	)
	for _, piece in { window, handle } do
		piece.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = panel
		weld.Part1 = piece
		weld.Parent = panel
	end

	-- Região "atravessável" para o pathfinding: o Vigia planeja passar e abre a porta ao chegar.
	-- PassThrough exige CanQuery = true (testado); o grupo NavOnly não colide com Default,
	-- então raycasts comuns (visão, interação) ignoram esta peça invisível.
	local region = Build.part(parent, `{spec.id}_Path`, V3(spec.width, Layout.DOOR_TOP, 1.6), closed, Palette.Black, {
		transparency = 1,
		collide = false,
		query = true,
	})
	region.CanTouch = false
	region.CollisionGroup = MapBuilder.NAV_GROUP
	local modifier = Instance.new("PathfindingModifier")
	modifier.Label = "Door"
	modifier.PassThrough = true
	modifier.Parent = region

	local handleData: DoorHandle = {
		id = spec.id,
		panel = panel,
		closedCFrame = closed,
		openCFrame = open,
		hinge = hinge,
		openAngle = angle,
		isOpen = false,
		startsOpen = spec.open,
		busy = false,
		center = closed.Position,
		sound = Build.sound(panel, "Squeak", Audio.Door.id, Audio.Door.volume),
	}
	world.doors[spec.id] = handleData
	register(world, spec.id, "Door", panel, panel, Text.Prompts.DoorOpen)
end

local function buildRooms(parent: Instance)
	-- RECEPÇÃO
	-- Recepção: centro livre (passagem entre pátio, corredor, escritório e bombas).
	Props.counter(parent, V3(-8.5, 0, -3.5), 0, 5)
	Props.chair(parent, V3(2.5, 0, -2), 90)
	Props.chair(parent, V3(2.5, 0, -14.5), 90)
	Props.bench(parent, V3(-10.6, 0, -14.6), 90)
	Build.cylinder(parent, "Pot", V3(-10.5, 1, -1.5), Vector3.yAxis, 2, 1.6, Palette.Rust)
	Build.part(
		parent,
		"DeadPlant",
		V3(0.4, 3, 0.4),
		CFrame.new(-10.5, 3.2, -1.5) * CFrame.Angles(0, 0, 0.3),
		Palette.Trunk
	)
	Build.sign(
		parent,
		"Board",
		V3(-11.45, 5.5, -13),
		Vector3.xAxis,
		Vector2.new(5, 3),
		"AVISOS\nPLANTÃO 24H\nNÃO DESLIGUE O RÁDIO",
		{
			textColor = Palette.Black,
			background = Palette.Paper,
			font = Enum.Font.SpecialElite,
		}
	)

	-- ESCRITÓRIO
	Props.desk(parent, V3(-31, 0, -7), 0)
	Props.desk(parent, V3(-21, 0, -7), 0)
	Props.chair(parent, V3(-31, 0, -9.6), 0)
	Props.chair(parent, V3(-21, 0, -9.6), 0)
	Props.chair(parent, V3(-15.5, 0, -15.5), 70, true)
	Props.cabinet(parent, V3(-38.5, 0, -15), 90)
	Props.cabinet(parent, V3(-38.5, 0, -12.6), 90)
	Build.sign(
		parent,
		"Roster",
		V3(-39.45, 5.5, -6),
		Vector3.xAxis,
		Vector2.new(6, 3.2),
		"ESCALA - TURNO NOITE\nSEG  ADEMIR\nTER  ADEMIR\nQUA  ADEMIR\nQUI  ADEMIR",
		{ textColor = Palette.MetalDark, background = Palette.Ceramic, font = Enum.Font.SpecialElite }
	)

	-- BOMBAS
	Props.pumpTank(parent, V3(14, 0, -10), 7, 5)
	Props.pumpTank(parent, V3(26, 0, -10), 7, 5)
	Props.workbench(parent, V3(35, 0, -3), 0)
	Props.crate(parent, V3(9, 0, -15), 0, 2)
	Props.crate(parent, V3(37, 0, -15), 15, 3)
	Props.pipe(parent, V3(4.5, 9.4, -16.5), V3(39.5, 9.4, -16.5), 1)
	Props.pipe(parent, V3(4.5, 8.4, -1.5), V3(26, 8.4, -1.5), 0.7, Palette.MetalDark)
	Props.pipe(parent, V3(20, 0, -16.5), V3(20, 9.4, -16.5), 0.8)
	for _, x in { 18, 22 } do
		Build.part(
			parent,
			"Puddle",
			V3(3, 0.04, 2.2),
			CFrame.new(x, 0.02, -13) * CFrame.Angles(0, x, 0),
			Palette.Screen,
			{
				collide = false,
				reflectance = 0.35,
			}
		)
	end

	-- CORREDOR: artéria principal, sem obstáculos (só decoração sem colisão no teto/paredes).
	Props.pipe(parent, V3(-39.5, 10, -25), V3(39.5, 10, -25), 0.6, Palette.MetalDark)
	Build.sign(
		parent,
		"Directions",
		V3(-4, 6, -25.45),
		Vector3.zAxis,
		Vector2.new(9, 1.3),
		"< GERADOR      DEPÓSITO >",
		{
			textColor = Palette.Hazard,
			background = Palette.Black,
		}
	)

	-- SALA DO GERADOR
	Props.generator(parent, V3(-28, 0, -40), 0)
	for i = 0, 7 do
		Build.box(
			parent,
			"Hazard",
			V3(-34 + i * 1.5, 0, -44.6),
			V3(-33.25 + i * 1.5, 0.03, -43.6),
			if i % 2 == 0 then Palette.Hazard else Palette.Black,
			{ collide = false }
		)
	end
	Props.pipe(parent, V3(-22.5, 0.2, -40), V3(-16, 0.2, -40), 0.5, Palette.Black, false)
	Props.pipe(parent, V3(-16, 0.2, -40), V3(-16, 0.2, -48.6), 0.5, Palette.Black, false)
	for _, p in { V3(-37, 0, -29), V3(-35.6, 0, -29.4), V3(-37.2, 0, -31) } do
		Build.cylinder(parent, "Drum", p + V3(0, 1.6, 0), Vector3.yAxis, 3.2, 2, Palette.Red)
	end

	-- DEPÓSITO
	Props.shelf(parent, V3(31, 0, -46), 0, 8)
	Props.shelf(parent, V3(15, 0, -46), 0, 8)
	Props.shelf(parent, V3(31, 0, -38), 0, 8)
	Props.shelf(parent, V3(15, 0, -38), 0, 8)
	Props.crate(parent, V3(6, 0, -34), 10, 3)
	Props.crate(parent, V3(3, 0, -36), -15, 2)
	Props.crate(parent, V3(24, 0, -30), 0, 2) -- longe da porta aberta do depósito
	Props.locker(parent, V3(-2.3, 0, -42), 90, 3)
	Props.locker(parent, V3(-2.3, 0, -32), 90, 2)
	Build.sign(parent, "Graffiti", V3(30, 5, -26.56), -Vector3.zAxis, Vector2.new(10, 2.6), "ELE SEGUE A LUZ", {
		textColor = Palette.Red,
		font = Enum.Font.PermanentMarker,
		partColor = Palette.WallUpperCold,
		thickness = 0.05,
	})
end

local function buildLights(world: World, parent: Instance)
	for index, p in Layout.Lamps do
		local tube = Props.lampFixture(parent, vec(p))
		Build.light(tube, "Lamp", Palette.Fluorescent, 20, 1.1, false)
		if index == 1 or index == 6 or index == 10 then
			table.insert(world.buzz, Build.sound(tube, "Buzz", Audio.LampBuzz.id, Audio.LampBuzz.volume, 1, true))
		end
	end
	for index, p in Layout.EmergencyLights do
		local box = Props.emergencyLight(parent, vec(p))
		Build.light(box, "Emergency", Palette.Emergency, 13, 0.9, true, index == 1)
	end
	-- Placa de saída acesa (orientação) dentro da recepção.
	local exit = Build.sign(parent, "ExitSign", V3(-4, 9.7, -0.75), -Vector3.zAxis, Vector2.new(3, 1), "SAÍDA", {
		textColor = Palette.ExitLight,
		background = Color3.fromRGB(8, 34, 16),
		lit = true,
	})
	Build.light(exit, "Exit", Palette.ExitLight, 7, 0.5, true)
end

local function buildSigns(parent: Instance)
	Build.sign(parent, "FacadeSign", V3(-4, 10, 0.35), Vector3.zAxis, Vector2.new(14, 1.8), Text.Title, {
		textColor = Palette.Ceramic,
		background = Color3.fromRGB(26, 28, 26),
	})
	Build.sign(parent, "Danger", V3(22, 5.2, 0.35), Vector3.zAxis, Vector2.new(3.2, 2.4), "PERIGO\nALTA TENSÃO", {
		textColor = Palette.Black,
		background = Palette.Hazard,
	})
	Build.sign(parent, "Danger", V3(-14, 5.2, 0.35), Vector3.zAxis, Vector2.new(3.2, 2.4), "ACESSO\nRESTRITO", {
		textColor = Palette.Ceramic,
		background = Palette.Red,
	})
	-- Placas acima das portas, viradas para o corredor.
	local labels = {
		{ x = -27, z = -18.55, face = -1, text = "ESCRITÓRIO" },
		{ x = -4, z = -18.55, face = -1, text = "RECEPÇÃO / SAÍDA" },
		{ x = 23, z = -18.55, face = -1, text = "BOMBAS" },
		{ x = -21, z = -25.45, face = 1, text = "SALA DO GERADOR" },
		{ x = 17, z = -25.45, face = 1, text = "DEPÓSITO" },
	}
	for _, label in labels do
		Build.sign(
			parent,
			"RoomLabel",
			V3(label.x, 9.95, label.z),
			Vector3.zAxis * label.face,
			Vector2.new(6, 0.9),
			label.text,
			{ textColor = Palette.Ceramic, background = Palette.Trim }
		)
	end
	-- Na recepção, apontando o corredor.
	Build.sign(
		parent,
		"LobbyArrow",
		V3(-4, 9.95, -17.45),
		Vector3.zAxis,
		Vector2.new(6, 0.9),
		"^ GERADOR / DEPÓSITO",
		{
			textColor = Palette.Hazard,
			background = Palette.Trim,
		}
	)
	Build.sign(parent, "PanelLabel", V3(-16, 7.6, -49.42), Vector3.zAxis, Vector2.new(5, 0.8), "QUADRO PRINCIPAL", {
		textColor = Palette.Hazard,
		background = Palette.Black,
	})
end

local function buildPanel(world: World, parent: Instance)
	local p = vec(Layout.Panel)
	local model = Build.model(parent, "MainPanel")
	local box =
		Build.part(model, "Box", V3(4, 5, 0.8), CFrame.new(p), Palette.Metal, { material = Enum.Material.Metal })
	Build.part(model, "Frame", V3(4.3, 5.3, 0.6), CFrame.new(p + V3(0, 0, -0.15)), Palette.MetalDark)
	local slots: { BasePart } = {}
	for i = 1, Config.Game.FusesTotal do
		local x = p.X + (i - 2) * 1.2
		Build.part(
			model,
			"Socket",
			V3(0.8, 1.6, 0.1),
			CFrame.new(x, p.Y + 0.2, p.Z + 0.42),
			Palette.Black,
			{ collide = false }
		)
		local fuse =
			Build.cylinder(model, "SlotFuse", V3(x, p.Y + 0.2, p.Z + 0.5), Vector3.yAxis, 1.1, 0.45, Palette.Ceramic, {
				collide = false,
				transparency = 1,
			})
		table.insert(slots, fuse)
	end
	local status = Build.part(model, "Status", V3(0.6, 0.6, 0.2), CFrame.new(p + V3(0, 1.8, 0.45)), Palette.PanelOff, {
		material = Enum.Material.Neon,
		collide = false,
	})
	Build.part(
		model,
		"Lever",
		V3(0.3, 1.4, 0.3),
		CFrame.new(p + V3(1.6, -1.2, 0.6)) * CFrame.Angles(0.5, 0, 0),
		Palette.Red,
		{
			collide = false,
		}
	)
	world.panel = {
		focus = box,
		slotFuses = slots,
		status = status,
		switchSound = Build.sound(box, "Switch", Audio.Switch.id, Audio.Switch.volume),
		hum = Build.sound(box, "Hum", Audio.GeneratorHum.id, Audio.GeneratorHum.volume, 1, true),
	}
	register(world, "panel", "Panel", box, model, Text.Prompts.Panel)
end

local function buildCourtyard(world: World, parent: Instance)
	local c = Layout.Courtyard
	-- Chão: mato escuro em volta, asfalto no pátio e na estrada.
	Build.box(
		parent,
		"Ground",
		V3(-160, -2, -160),
		V3(160, -0.05, 180),
		Palette.Grass,
		{ material = Enum.Material.Ground }
	)
	Build.box(
		parent,
		"Yard",
		V3(c.x0, -1, c.z0),
		V3(c.x1, 0, c.z1),
		Palette.Asphalt,
		{ material = Enum.Material.Asphalt }
	)
	Build.box(parent, "Road", V3(-6, -1, c.z1), V3(6, 0, 170), Palette.Asphalt, { material = Enum.Material.Asphalt })
	Build.box(parent, "Gravel", V3(-40, -0.98, 0), V3(40, 0.02, 3), Palette.Gravel, { material = Enum.Material.Pebble })

	Props.van(parent, V3(26, 0, 26), 0)
	Props.booth(parent, V3(-28, 0, 37), 180)
	Build.cylinder(parent, "Drum", V3(-34, 1.6, 20), Vector3.yAxis, 3.2, 2, Palette.Rust)

	local street = Props.streetLamp(parent, V3(34, 0, 38))
	Build.light(street, "Street", Palette.Sodium, 26, 1.3, true, true)
	for _, x in { -30, 30 } do
		local head = Props.floodLight(parent, V3(x, 0, 8), V3(x * 0.5, 3, 0))
		Build.light(head, "Flood", Palette.Sodium, 34, 1.2, false)
	end

	-- Cerca: laterais e frente (com o vão do portão).
	local h = Layout.FenceHeight
	local gate = Layout.Gate
	local function fenceRun(a: Vector3, b: Vector3)
		local delta = b - a
		local length = delta.Magnitude
		local cframe = CFrame.lookAt((a + b) / 2 + V3(0, h / 2, 0), (b + V3(0, h / 2, 0)))
		Build.part(parent, "FenceMesh", V3(0.15, h, length), cframe, Palette.Fence, {
			transparency = 0.55,
			material = Enum.Material.Metal,
		})
		Build.part(parent, "FenceRail", V3(0.3, 0.3, length), cframe * CFrame.new(0, h / 2, 0), Palette.MetalDark)
		local posts = math.max(1, math.floor(length / 6))
		for i = 0, posts do
			local p = a:Lerp(b, i / posts)
			Build.block(parent, "FencePost", p, V3(0.4, h + 0.6, 0.4), 0, Palette.MetalDark)
		end
	end
	fenceRun(V3(c.x0, 0, c.z0), V3(c.x0, 0, c.z1))
	fenceRun(V3(c.x1, 0, c.z0), V3(c.x1, 0, c.z1))
	fenceRun(V3(c.x0, 0, c.z1), V3(gate.x - gate.width / 2, 0, c.z1))
	fenceRun(V3(gate.x + gate.width / 2, 0, c.z1), V3(c.x1, 0, c.z1))

	-- Portão elétrico deslizante.
	local gateModel = Build.model(parent, "Gate")
	local gz = gate.z - 0.6
	local mesh = Build.part(
		gateModel,
		"Mesh",
		V3(gate.width, gate.height, 0.2),
		CFrame.new(gate.x, gate.height / 2, gz),
		Palette.Fence,
		{
			transparency = 0.35,
			material = Enum.Material.DiamondPlate,
		}
	)
	for _, dy in { 0.3, gate.height - 0.3 } do
		local bar = Build.part(gateModel, "Bar", V3(gate.width, 0.35, 0.35), CFrame.new(gate.x, dy, gz), Palette.Hazard)
		bar.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = mesh
		weld.Part1 = bar
		weld.Parent = mesh
	end
	gateModel.PrimaryPart = mesh
	for _, x in { gate.x - gate.width / 2 - 0.4, gate.x + gate.width / 2 + 0.4 } do
		Build.block(parent, "GatePost", V3(x, 0, gate.z), V3(0.8, gate.height + 1, 0.8), 0, Palette.Hazard)
	end
	local motor = Build.block(
		parent,
		"GateMotor",
		V3(gate.x + gate.width / 2 + 1.6, 0, gate.z - 1.2),
		V3(1.6, 1.4, 1.2),
		0,
		Palette.MetalDark
	)
	local beacon = Build.part(
		parent,
		"Beacon",
		V3(0.7, 0.7, 0.7),
		CFrame.new(gate.x + gate.width / 2 + 0.4, gate.height + 1.4, gate.z),
		Palette.Red,
		{
			material = Enum.Material.Neon,
		}
	)
	Build.light(beacon, "Beacon", Palette.Emergency, 14, 1.4, false)
	Build.sign(
		parent,
		"GateSign",
		V3(gate.x + gate.width / 2 + 0.4, 5, gate.z - 0.45),
		-Vector3.zAxis,
		Vector2.new(2.4, 1.2),
		"PORTÃO\nELÉTRICO",
		{
			textColor = Palette.Black,
			background = Palette.Hazard,
		}
	)
	world.gate = {
		model = gateModel,
		closedPivot = gateModel:GetPivot(),
		openPivot = gateModel:GetPivot() * CFrame.new(gate.width + 0.8, 0, 0),
		isOpen = false,
		busy = false,
		sound = Build.sound(motor, "Motor", Audio.Door.id, 0.9, 0.55),
		beacon = beacon,
	}
	register(world, "gate", "Gate", mesh, gateModel, Text.Prompts.Gate)

	-- Mata em volta (determinístico).
	local rng = Random.new(9)
	local placed = 0
	while placed < 42 do
		local x = rng:NextNumber(-110, 110)
		local z = rng:NextNumber(-100, 130)
		local bounds = Layout.Compound
		local insideCompound = x > bounds.x0 - 5 and x < bounds.x1 + 5 and z > bounds.z0 - 5 and z < bounds.z1 + 4
		local onRoad = math.abs(x) < 10 and z > c.z1
		if not insideCompound and not onRoad then
			Props.tree(parent, V3(x, 0, z), rng:NextNumber(14, 24), rng)
			placed += 1
		end
	end
	-- Fim da estrada (a névoa esconde): ninguém anda para sempre.
	Build.box(parent, "RoadBlock", V3(-12, 0, 76), V3(12, 12, 77), Palette.Black, { transparency = 1 })
end

local function buildPickups(world: World, parent: Instance)
	local fuseFolder = Build.folder(parent, "Fuses")
	for id, spots in Layout.FuseSpots do
		local model, body = Props.fuse(fuseFolder, id, vec(spots[1]))
		world.fuseModels[id] = model
		register(world, id, "Fuse", body, model, Text.Prompts.Fuse)
	end
	local yaws = { note_order = 12, note_office = -20, note_storage = 35 }
	for id, p in Layout.Notes do
		local paper = Props.note(parent, id, vec(p), yaws[id] or 0)
		register(world, id, "Note", paper, paper, Text.Prompts.Note)
	end
end

function MapBuilder.build(parent: Instance): World
	local existing = parent:FindFirstChild(Tags.WorldFolder)
	if existing then
		existing:Destroy()
	end
	local root = Build.folder(parent, Tags.WorldFolder)
	local spawn = Layout.Spawn
	local world: World = {
		root = root,
		interactables = {},
		fuseModels = {},
		doors = {},
		gate = nil :: any,
		panel = nil :: any,
		buzz = {},
		spawnCFrame = CFrame.lookAt(vec(spawn.position), vec(spawn.lookAt)),
	}

	local structure = Build.folder(root, "Structure")
	for _, wall in Layout.Walls do
		buildWall(structure, wall)
	end
	buildFloors(structure)

	local doors = Build.folder(root, "Doors")
	for _, spec in Layout.Doors do
		buildDoor(world, doors, spec)
	end

	buildRooms(Build.folder(root, "Props"))
	buildLights(world, Build.folder(root, "Lights"))
	buildSigns(Build.folder(root, "Signs"))
	buildPanel(world, root)
	buildCourtyard(world, Build.folder(root, "Exterior"))
	Expansion.build(Build.folder(root, "Expansion"))
	buildPickups(world, Build.folder(root, "Pickups"))
	return world
end

return MapBuilder
