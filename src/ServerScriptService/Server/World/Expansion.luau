--!strict
-- Alas técnicas: cenário estático, sem objetivos/remotes; usa as luzes e a energia do mundo existente.
local Build = require("./Build")
local Layout = require("./Layout")
local Palette = require("./Palette")
local Props = require("./Props")

local V3 = Vector3.new
local Expansion = {}

local function sign(parent: Instance, name: string, p: Vector3, facing: Vector3, text: string)
	Build.sign(parent, name, p, facing, Vector2.new(8, 1.6), text, {
		textColor = Palette.Hazard,
		background = Palette.Trim,
	})
end

local function fence(parent: Instance, a: Vector3, b: Vector3)
	local h = Layout.FenceHeight
	local length = (b - a).Magnitude
	local frame = CFrame.lookAt((a + b) / 2 + V3(0, h / 2, 0), b + V3(0, h / 2, 0))
	Build.part(parent, "TechnicalFence", V3(0.2, h, length), frame, Palette.Fence, {
		material = Enum.Material.Metal,
		transparency = 0.55,
	})
	for _, y in { -h / 2 + 0.4, h / 2 } do
		Build.part(parent, "FenceRail", V3(0.3, 0.3, length), frame * CFrame.new(0, y, 0), Palette.MetalDark)
	end
	local count = math.ceil(length / 6)
	for i = 0, count do
		Build.block(parent, "FencePost", a:Lerp(b, i / count), V3(0.4, h + 0.6, 0.4), 0, Palette.MetalDark)
	end
end

local function roofs(parent: Instance)
	for _, room in Layout.Rooms do
		if room.id == "Maintenance" or room.id == "CableGallery" or room.id == "Control" or room.id == "Archive" then
			Build.box(
				parent,
				`Roof_{room.id}`,
				V3(room.x0 - 0.5, Layout.CEILING, room.z0 - 0.5),
				V3(room.x1 + 0.5, Layout.CEILING + 1, room.z1 + 0.5),
				Palette.Ceiling
			)
		end
	end
end

local function workshop(parent: Instance)
	local room = Build.model(parent, "Workshop")
	Props.workbench(room, V3(-62, 0, -44), 0)
	Props.shelf(room, V3(-64.5, 0, -14), 90, 9)
	Props.locker(room, V3(-44, 0, -14), -90, 3)
	Props.bench(room, V3(-62, 0, -4), 0)
	Props.crate(room, V3(-64, 0, -36), 12, 3)
	Props.crate(room, V3(-44, 0, -35), -8, 3)
	-- Divisória interrompe a visão longa, mantendo um vão de oito studs no eixo de circulação.
	Build.box(room, "WorkshopDivider", V3(-68, 0, -30.5), V3(-58, 8, -29.5), Palette.WallLowerCold)
	Build.box(room, "WorkshopDivider", V3(-50, 0, -30.5), V3(-40, 8, -29.5), Palette.WallLowerCold)
	sign(room, "WorkshopEntry", V3(-54, 9.6, 0.6), Vector3.zAxis, "OFICINA / ACESSO TÉCNICO")
	sign(room, "WorkshopRoute", V3(-54, 9.5, -29.3), Vector3.zAxis, "^ CONTROLE / ARQUIVO")
	sign(room, "CoreReturn", V3(-40.6, 9.5, -22), -Vector3.xAxis, "CORREDOR / GERADOR")
	Props.pipe(room, V3(-65.5, 9.5, -48), V3(-65.5, 9.5, -2), 0.5, Palette.Rust, false)
end

local function gallery(parent: Instance)
	local room = Build.model(parent, "CableGallery")
	for _, x in { -65, -62 } do
		Props.pipe(room, V3(x, 9, -76), V3(x, 9, -52), 0.8, Palette.MetalDark, false)
	end
	for _, z in { -73, -55 } do
		Build.block(room, "CableReel", V3(-63, 0, z), V3(4, 3, 3), 0, Palette.WoodDark)
		Build.cylinder(room, "ReelCable", V3(-63, 1.5, z), Vector3.zAxis, 2.6, 2.4, Palette.Black)
	end
	sign(room, "GalleryLabel", V3(-54, 7, -77.4), Vector3.zAxis, "GALERIA DE CABOS\nSETOR 09-B")
	sign(room, "GalleryReturn", V3(-54, 9.6, -50.6), -Vector3.zAxis, "OFICINA / SAÍDA v")
end

local function control(parent: Instance)
	local room = Build.model(parent, "ControlRoom")
	-- Console baixo e monitores na parede; a passagem leste-oeste fica livre em z=-64.
	for _, x in { -32, -24, -16 } do
		Build.block(room, "ControlConsole", V3(x, 0, -74), V3(7.6, 3.2, 3), 0, Palette.MetalDark)
		Build.part(room, "DeadMonitor", V3(3.6, 2.2, 0.2), CFrame.new(x, 5, -76.8), Palette.Screen, { collide = false })
		for i = -1, 1 do
			Build.part(
				room,
				"ConsoleSwitch",
				V3(0.3, 0.12, 0.5),
				CFrame.new(x + i, 3.25, -73.5),
				Palette.Hazard,
				{ collide = false }
			)
		end
	end
	Props.chair(room, V3(-24, 0, -70), 0)
	Props.chair(room, V3(-16, 0, -70), 15, true)
	Props.cabinet(room, V3(-36, 0, -54), 0)
	Props.counter(room, V3(-12, 0, -55), 0, 8)
	Build.sign(
		room,
		"ElectricalDiagram",
		V3(-20, 7.5, -50.6),
		-Vector3.zAxis,
		Vector2.new(14, 2),
		"SUBESTAÇÃO 9\nLINHA A --- [09] --- LINHA B",
		{
			textColor = Palette.ExitGreen,
			background = Palette.Black,
		}
	)
	sign(room, "ControlLabel", V3(-32, 9.6, -49.4), Vector3.zAxis, "CONTROLE / GALERIA")
	sign(room, "ControlEast", V3(3.4, 9.5, -64), -Vector3.xAxis, "ARQUIVO / PÁTIO TÉCNICO")
end

local function archive(parent: Instance)
	local room = Build.model(parent, "TechnicalArchive")
	-- Duas ilhas afastadas da travessia central e da conexão sul com o depósito.
	for _, x in { 12, 28 } do
		Props.shelf(room, V3(if x == 28 then 34 else x, 0, -74), 0, 9)
		Props.cabinet(room, V3(x, 0, -54), 0)
	end
	Props.desk(room, V3(34, 0, -56), 0)
	Props.chair(room, V3(34, 0, -59), 0)
	sign(room, "ArchiveLabel", V3(24, 9.6, -49.4), Vector3.zAxis, "ARQUIVO / CONTROLE")
	sign(room, "ArchiveExit", V3(39.4, 9.5, -64), -Vector3.xAxis, "PÁTIO DE TRANSFORMADORES")
	Build.sign(
		room,
		"ArchiveWarning",
		V3(10, 6, -77.4),
		Vector3.zAxis,
		Vector2.new(10, 2),
		"REGISTROS DO TURNO\nNÃO REMOVER",
		{
			textColor = Palette.Black,
			background = Palette.Paper,
			font = Enum.Font.SpecialElite,
		}
	)
end

local function transformer(parent: Instance, x: number, z: number, index: number)
	local unit = Build.model(parent, `Transformer_{index}`)
	Build.block(unit, "ConcretePad", V3(x, 0, z), V3(9, 0.15, 9), 0, Palette.Concrete)
	Build.block(
		unit,
		"TransformerBody",
		V3(x, 0.15, z),
		V3(6, 5.2, 5),
		0,
		Palette.WallLowerCold,
		{ material = Enum.Material.Metal }
	)
	for i = -3, 3 do
		for _, side in { -1, 1 } do
			Build.block(
				unit,
				"CoolingFin",
				V3(x + side * 3.3, 0.5, z + i * 0.65),
				V3(0.6, 4.5, 0.2),
				0,
				Palette.MetalDark
			)
		end
	end
	for _, dx in { -1.8, 0, 1.8 } do
		Build.cylinder(unit, "Insulator", V3(x + dx, 6.1, z), Vector3.yAxis, 1.6, 0.7, Palette.Ceramic)
		Build.cylinder(unit, "Terminal", V3(x + dx, 7.2, z), Vector3.yAxis, 0.7, 0.22, Palette.Metal)
	end
	Build.sign(
		unit,
		"TransformerNumber",
		V3(x, 3.6, z + 2.65),
		Vector3.zAxis,
		Vector2.new(3, 1.6),
		`T-0{index}\nALTA TENSÃO`,
		{
			textColor = Palette.Black,
			background = Palette.Hazard,
		}
	)
end

local function switchyard(parent: Instance)
	local yard = Build.model(parent, "Switchyard")
	local bounds = Layout.Compound
	fence(yard, V3(bounds.x1, 0, bounds.z0), V3(bounds.x1, 0, 0))
	fence(yard, V3(40, 0, bounds.z0), V3(bounds.x1, 0, bounds.z0))
	transformer(yard, 65, -61, 1)
	transformer(yard, 47, -44, 2)
	transformer(yard, 65, -33, 3)
	transformer(yard, 47, -14, 4)
	for _, z in { -70, -30, -6 } do
		for _, x in { 43, 69 } do
			Build.block(yard, "GantryPillar", V3(x, 0, z), V3(0.7, 13, 0.7), 0, Palette.MetalDark)
		end
		Build.block(yard, "GantryBeam", V3(56, 12.5, z), V3(27, 0.6, 0.6), 0, Palette.MetalDark)
	end
	for _, x in { 51, 56, 61 } do
		Props.pipe(yard, V3(x, 12, -70), V3(x, 12, -6), 0.12, Palette.Black, false)
	end
	for _, z in { -70, -42, -10 } do
		local head = Props.floodLight(yard, V3(70, 0, z), V3(54, 0, z))
		Build.light(head, "Flood", Palette.Sodium, 26, 0.9, false)
	end
	local emergency = Props.emergencyLight(yard, V3(40.7, 8, -64))
	Build.light(emergency, "Emergency", Palette.Emergency, 15, 0.8, true)
	sign(yard, "YardLabel", V3(56, 10, -6), Vector3.zAxis, "PÁTIO TÉCNICO\nTRANSFORMADORES 01-04")
	sign(yard, "YardCoreReturn", V3(40.6, 9.6, -22), Vector3.xAxis, "CORREDOR / GERADOR")
	sign(yard, "YardArchive", V3(40.6, 9.6, -64), Vector3.xAxis, "ARQUIVO / CONTROLE")
end

function Expansion.build(parent: Instance)
	roofs(parent)
	workshop(parent)
	gallery(parent)
	control(parent)
	archive(parent)
	switchyard(parent)
	-- Marcação de circulação sem colisão; não cria uma nova mecânica de interação.
	for _, x in { -54, 56 } do
		for z = -62, 26, 8 do
			Build.block(
				parent,
				"RouteMark",
				V3(x, 0.015, z),
				V3(0.25, 0.02, 2.5),
				0,
				Palette.Hazard,
				{ collide = false }
			)
		end
	end
end

return Expansion
