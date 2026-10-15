--!strict
--[[
	Props low poly feitos só com primitivas. Cada função recebe a posição da base (no chão)
	e um giro (yaw, graus). Nada aqui tem script nem dependência externa.
]]

local Build = require("./Build")
local Palette = require("./Palette")

local Props = {}

local V3 = Vector3.new

-- Converte um offset local (relativo à base girada) em posição de mundo.
local function at(base: Vector3, yaw: number, offset: Vector3): Vector3
	return (CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0)):PointToWorldSpace(offset)
end

-- CFrame de uma peça: base girada pelo yaw e deslocada pelo offset local.
local function rotated(base: Vector3, yaw: number, offset: Vector3): CFrame
	return CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(offset)
end

local function piece(
	parent: Instance,
	name: string,
	base: Vector3,
	yaw: number,
	offset: Vector3,
	size: Vector3,
	color: Color3,
	options: Build.PartOptions?
): BasePart
	return Build.part(parent, name, size, rotated(base, yaw, offset), color, options)
end

-- Mesa de escritório: tampo em y = 3.
function Props.desk(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Desk")
	piece(model, "Top", base, yaw, V3(0, 2.85, 0), V3(6, 0.3, 3), Palette.Wood)
	for _, x in { -2.7, 2.7 } do
		piece(model, "Side", base, yaw, V3(x, 1.35, 0), V3(0.3, 2.7, 2.8), Palette.WoodDark)
	end
	piece(model, "Drawers", base, yaw, V3(1.6, 1.6, 0.2), V3(2, 2.2, 2.4), Palette.WoodDark)
	-- Monitor CRT
	piece(model, "CRT", base, yaw, V3(-1.2, 3.75, 0.4), V3(1.6, 1.5, 1.4), Palette.VanBody)
	piece(model, "Screen", base, yaw, V3(-1.2, 3.8, -0.31), V3(1.25, 1.05, 0.05), Palette.Screen, { collide = false })
	return model
end

function Props.chair(parent: Instance, base: Vector3, yaw: number, fallen: boolean?)
	local model = Build.model(parent, "Chair")
	local tilt = if fallen then CFrame.Angles(math.rad(85), 0, 0) else CFrame.identity
	local origin = CFrame.new(base) * CFrame.Angles(0, math.rad(yaw), 0) * tilt
	local function p(name: string, offset: Vector3, size: Vector3, color: Color3)
		Build.part(model, name, size, origin * CFrame.new(offset), color)
	end
	p("Seat", V3(0, 1.8, 0), V3(1.8, 0.25, 1.8), Palette.Fabric)
	p("Back", V3(0, 2.9, 0.8), V3(1.8, 2, 0.2), Palette.Fabric)
	p("Leg", V3(0, 0.9, 0), V3(0.25, 1.8, 0.25), Palette.MetalDark)
	p("Base", V3(0, 0.1, 0), V3(1.4, 0.2, 1.4), Palette.MetalDark)
	return model
end

-- Arquivo de aço: topo em y = 5.
function Props.cabinet(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Cabinet")
	piece(model, "Body", base, yaw, V3(0, 2.5, 0), V3(2, 5, 2), Palette.Metal)
	for i = 0, 3 do
		piece(model, "Drawer", base, yaw, V3(0, 0.75 + i * 1.2, -1.01), V3(1.7, 0.08, 0.05), Palette.MetalDark)
		piece(model, "Handle", base, yaw, V3(0, 1.1 + i * 1.2, -1.05), V3(0.6, 0.12, 0.08), Palette.MetalDark)
	end
	return model
end

-- Caixote de madeira (cubo de lado `s`).
function Props.crate(parent: Instance, base: Vector3, yaw: number, s: number)
	local model = Build.model(parent, "Crate")
	piece(model, "Body", base, yaw, V3(0, s / 2, 0), V3(s, s, s), Palette.Wood)
	piece(model, "Band", base, yaw, V3(0, s / 2, 0), V3(s + 0.06, s * 0.18, s + 0.06), Palette.WoodDark)
	return model
end

-- Estante com 3 prateleiras (tampos em y = 1.4, 2.9, 4.4), largura ao longo do X local.
function Props.shelf(parent: Instance, base: Vector3, yaw: number, width: number)
	local model = Build.model(parent, "Shelf")
	for _, x in { -width / 2 + 0.15, width / 2 - 0.15 } do
		for _, z in { -0.85, 0.85 } do
			piece(model, "Post", base, yaw, V3(x, 3, z), V3(0.25, 6, 0.25), Palette.MetalDark)
		end
	end
	for _, y in { 1.3, 2.8, 4.3, 5.8 } do
		piece(model, "Board", base, yaw, V3(0, y, 0), V3(width, 0.2, 2), Palette.Metal)
	end
	-- Caixas de papelão
	local boxes = { { -2.2, 1.4, 1.2 }, { 0.4, 1.4, 1.6 }, { -1, 2.9, 1.3 }, { 2.4, 4.4, 1.1 } }
	for _, b in boxes do
		if math.abs(b[1]) + b[3] / 2 < width / 2 then
			piece(model, "Box", base, yaw, V3(b[1], b[2] + b[3] / 2, 0), V3(b[3], b[3], 1.4), Palette.Gravel)
		end
	end
	return model
end

function Props.locker(parent: Instance, base: Vector3, yaw: number, count: number)
	local model = Build.model(parent, "Lockers")
	for i = 0, count - 1 do
		local x = (i - (count - 1) / 2) * 1.6
		piece(model, "Locker", base, yaw, V3(x, 3.2, 0), V3(1.5, 6.4, 1.5), Palette.WallLowerCold)
		piece(model, "Vent", base, yaw, V3(x, 5.6, -0.76), V3(1, 0.5, 0.05), Palette.MetalDark)
		piece(model, "Handle", base, yaw, V3(x + 0.5, 3.2, -0.78), V3(0.12, 0.6, 0.08), Palette.Metal)
	end
	return model
end

-- Balcão da recepção (comprimento ao longo do X local): tampo em y = 3.4.
function Props.counter(parent: Instance, base: Vector3, yaw: number, length: number)
	local model = Build.model(parent, "Counter")
	piece(model, "Front", base, yaw, V3(0, 1.6, 0), V3(length, 3.2, 1.6), Palette.WoodDark)
	piece(model, "Top", base, yaw, V3(0, 3.3, 0), V3(length + 0.4, 0.2, 2), Palette.Wood)
	piece(model, "Phone", base, yaw, V3(length / 2 - 1, 3.55, 0.2), V3(0.9, 0.3, 0.6), Palette.MetalDark)
	return model
end

function Props.bench(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Bench")
	piece(model, "Seat", base, yaw, V3(0, 1.6, 0), V3(6, 0.3, 1.4), Palette.Wood)
	for _, x in { -2.6, 2.6 } do
		piece(model, "Leg", base, yaw, V3(x, 0.75, 0), V3(0.3, 1.5, 1.2), Palette.MetalDark)
	end
	return model
end

-- Bancada de trabalho: tampo em y = 3.2.
function Props.workbench(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Workbench")
	piece(model, "Top", base, yaw, V3(0, 3.05, 0), V3(8, 0.3, 2.6), Palette.WoodDark)
	for _, x in { -3.7, 3.7 } do
		piece(model, "Leg", base, yaw, V3(x, 1.45, 0), V3(0.4, 2.9, 2.4), Palette.MetalDark)
	end
	piece(model, "Shelf", base, yaw, V3(0, 0.9, 0), V3(7, 0.2, 2.2), Palette.Metal)
	piece(model, "Vise", base, yaw, V3(-3, 3.5, 0.6), V3(0.8, 0.6, 0.6), Palette.Red)
	piece(model, "Toolbox", base, yaw, V3(2.6, 3.6, -0.4), V3(1.6, 0.8, 0.8), Palette.Red)
	piece(model, "Pegboard", base, yaw, V3(0, 5.5, 1.2), V3(7, 3, 0.2), Palette.WoodDark)
	return model
end

-- Tanque de bomba (cilindro vertical) com tubos.
function Props.pumpTank(parent: Instance, base: Vector3, height: number, diameter: number)
	local model = Build.model(parent, "PumpTank")
	Build.cylinder(model, "Tank", base + V3(0, height / 2, 0), Vector3.yAxis, height, diameter, Palette.Metal, {
		material = Enum.Material.Metal,
	})
	Build.cylinder(model, "Cap", base + V3(0, height + 0.25, 0), Vector3.yAxis, 0.5, diameter * 0.7, Palette.MetalDark)
	Build.cylinder(model, "Band", base + V3(0, height * 0.35, 0), Vector3.yAxis, 0.4, diameter + 0.1, Palette.Hazard)
	Build.cylinder(
		model,
		"Riser",
		base + V3(0, height + (11 - height) / 2, 0),
		Vector3.yAxis,
		11 - height,
		0.8,
		Palette.Rust
	)
	Build.cylinder(model, "Valve", base + V3(diameter / 2 + 0.3, 2.5, 0), Vector3.xAxis, 0.2, 1.4, Palette.Red)
	return model
end

-- Tubo reto entre dois pontos (`solid = false` para cabos no chão: não viram obstáculo).
function Props.pipe(parent: Instance, a: Vector3, b: Vector3, diameter: number, color: Color3?, solid: boolean?)
	local delta = b - a
	return Build.cylinder(parent, "Pipe", (a + b) / 2, delta, delta.Magnitude, diameter, color or Palette.Rust, {
		collide = solid ~= false,
	})
end

-- Gerador a diesel grande.
function Props.generator(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Generator")
	piece(model, "Skid", base, yaw, V3(0, 0.3, 0), V3(11, 0.6, 6.4), Palette.MetalDark)
	piece(model, "Body", base, yaw, V3(0.5, 3, 0), V3(9, 4.8, 5.2), Palette.Hazard, { material = Enum.Material.Metal })
	piece(model, "Engine", base, yaw, V3(-4.2, 2.4, 0), V3(2, 3.6, 4), Palette.MetalDark)
	for i = -3, 3 do
		piece(model, "Grille", base, yaw, V3(i * 1.1 + 0.5, 3, -2.62), V3(0.25, 3.6, 0.05), Palette.MetalDark)
	end
	piece(model, "ControlBox", base, yaw, V3(3.5, 6, 1.5), V3(2, 1.6, 1.2), Palette.Metal)
	Build.cylinder(model, "Exhaust", at(base, yaw, V3(-3, 8.5, 1.5)), Vector3.yAxis, 5, 0.9, Palette.Rust)
	return model
end

-- Luminária de teto: devolve a peça que leva a luz.
function Props.lampFixture(parent: Instance, position: Vector3): BasePart
	local model = Build.model(parent, "Lamp")
	Build.part(model, "Housing", V3(4, 0.3, 1.2), CFrame.new(position + V3(0, 0.25, 0)), Palette.MetalDark)
	local tube =
		Build.part(model, "Tube", V3(3.6, 0.2, 0.8), CFrame.new(position), Palette.LampOff, { collide = false })
	return tube
end

-- Luz de emergência (caixinha vermelha na parede).
function Props.emergencyLight(parent: Instance, position: Vector3): BasePart
	local box = Build.part(parent, "Emergency", V3(1, 0.5, 0.5), CFrame.new(position), Palette.Emergency, {
		material = Enum.Material.Neon,
		collide = false,
	})
	return box
end

-- Fusível cerâmico: devolve o modelo e a peça foco (corpo).
function Props.fuse(parent: Instance, name: string, position: Vector3): (Model, BasePart)
	local model = Build.model(parent, name)
	local body = Build.cylinder(model, "Body", position, Vector3.xAxis, 1.1, 0.45, Palette.Ceramic, {
		collide = false,
	})
	for _, dx in { -0.6, 0.6 } do
		Build.cylinder(model, "Cap", position + V3(dx, 0, 0), Vector3.xAxis, 0.18, 0.5, Palette.Metal, {
			collide = false,
			material = Enum.Material.Metal,
		})
	end
	Build.cylinder(model, "Glow", position, Vector3.xAxis, 0.12, 0.47, Palette.FuseGlow, {
		collide = false,
		material = Enum.Material.Neon,
	})
	model.PrimaryPart = body
	return model, body
end

-- Bilhete de papel deitado.
function Props.note(parent: Instance, name: string, position: Vector3, yaw: number): BasePart
	local paper = Build.part(
		parent,
		name,
		V3(1.3, 0.05, 1.7),
		CFrame.new(position) * CFrame.Angles(0, math.rad(yaw), 0),
		Palette.Paper,
		{ collide = false }
	)
	-- "Linhas" escritas
	for i = 0, 4 do
		Build.part(
			parent,
			"Ink",
			V3(0.9 - (i % 2) * 0.25, 0.01, 0.06),
			paper.CFrame * CFrame.new(-0.05, 0.03, -0.55 + i * 0.25),
			Palette.Black,
			{ collide = false, query = false }
		)
	end
	return paper
end

-- Pinheiro em blocos (tronco + camadas giradas 45°).
function Props.tree(parent: Instance, base: Vector3, height: number, rng: Random)
	local model = Build.model(parent, "Tree")
	Build.block(model, "Trunk", base, V3(1.2, height * 0.45, 1.2), 0, Palette.Trunk)
	local layers = 4
	for i = 1, layers do
		local t = (i - 1) / (layers - 1)
		local width = (1 - t * 0.75) * height * 0.42
		local y = height * (0.3 + t * 0.55)
		Build.part(
			model,
			"Foliage",
			V3(width, height * 0.22, width),
			CFrame.new(base + V3(0, y, 0)) * CFrame.Angles(0, math.rad(45 * i + rng:NextNumber(-10, 10)), 0),
			if i % 2 == 0 then Palette.Foliage else Palette.FoliageDark
		)
	end
	return model
end

-- Van de serviço abandonada (a frente aponta para -Z local).
function Props.van(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Van")
	piece(model, "Body", base, yaw, V3(0, 3.6, 1), V3(5.6, 5, 9), Palette.VanBody)
	piece(model, "Cab", base, yaw, V3(0, 2.9, -4.5), V3(5.6, 3.6, 2.4), Palette.VanBody)
	piece(model, "Hood", base, yaw, V3(0, 2.2, -6.1), V3(5.4, 1.6, 1.2), Palette.VanBody)
	piece(model, "Windshield", base, yaw, V3(0, 4.1, -5.65), V3(5, 1.6, 0.1), Palette.Screen, { reflectance = 0.2 })
	piece(model, "Stripe", base, yaw, V3(0, 3.4, 1), V3(5.7, 0.5, 9.05), Palette.Red)
	for _, x in { -2.7, 2.7 } do
		for _, z in { -4.6, 3.6 } do
			Build.cylinder(model, "Wheel", at(base, yaw, V3(x, 1.2, z)), Vector3.xAxis, 0.8, 2.4, Palette.Black)
		end
	end
	piece(model, "Bumper", base, yaw, V3(0, 1.4, -6.8), V3(5.8, 0.6, 0.4), Palette.MetalDark)
	return model
end

-- Guarita do vigia.
function Props.booth(parent: Instance, base: Vector3, yaw: number)
	local model = Build.model(parent, "Booth")
	piece(model, "Floor", base, yaw, V3(0, 0.25, 0), V3(6, 0.5, 6), Palette.Concrete)
	piece(model, "Back", base, yaw, V3(0, 4, 2.8), V3(6, 7, 0.4), Palette.Facade)
	piece(model, "Left", base, yaw, V3(-2.8, 4, 0), V3(0.4, 7, 6), Palette.Facade)
	piece(model, "Right", base, yaw, V3(2.8, 4, 0.9), V3(0.4, 7, 4.2), Palette.Facade)
	piece(model, "FrontLow", base, yaw, V3(0, 2, -2.8), V3(6, 3.5, 0.4), Palette.Facade)
	piece(model, "Roof", base, yaw, V3(0, 7.7, 0), V3(7, 0.5, 7), Palette.Trim)
	piece(model, "Desk", base, yaw, V3(0, 2.6, -2.2), V3(5, 0.3, 1), Palette.Wood)
	return model
end

-- Poste com luminária de rua (devolve a cabeça, onde vai a luz).
function Props.streetLamp(parent: Instance, base: Vector3): BasePart
	local model = Build.model(parent, "StreetLamp")
	Build.block(model, "Pole", base, V3(0.5, 12, 0.5), 0, Palette.MetalDark)
	Build.part(model, "Arm", V3(0.3, 0.3, 3), CFrame.new(base + V3(0, 11.8, -1.4)), Palette.MetalDark)
	local head = Build.part(model, "Head", V3(1.2, 0.4, 1.8), CFrame.new(base + V3(0, 11.5, -2.8)), Palette.Sodium, {
		material = Enum.Material.Neon,
	})
	return head
end

-- Refletor em poste (devolve a cabeça, que recebe uma SpotLight).
function Props.floodLight(parent: Instance, base: Vector3, target: Vector3): BasePart
	local model = Build.model(parent, "FloodLight")
	Build.block(model, "Pole", base, V3(0.5, 10, 0.5), 0, Palette.MetalDark)
	local headPos = base + V3(0, 10.4, 0)
	local head = Build.part(model, "Head", V3(2, 1.2, 0.8), CFrame.lookAt(headPos, target), Palette.LampOff)
	return head
end

return Props
