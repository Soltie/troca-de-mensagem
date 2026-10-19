--!strict
--[[
	Fachada, telhado, varanda e jardim da mansão (lote 5 do ambiente). Só visual:
	- casca externa fina por fora das paredes: reboco PBR, soco de tijolo, cunhais de pedra, faixas e cornija;
	- janelas falsas com caixilho 3D, venezianas, frontão e luz quente (ou escura) por trás;
	- telhado do GeneratedEstate (testeira, cumeeira, chaminés, letreiro no frontão), refeito a cada nível;
	- muro de tijolo no perímetro (só a aparência das barreiras), cerca de ferro, caminho de pedra,
	  varanda, postes vitorianos, abóboras e um cemitério pequeno longe dos pavilhões.
	Nada daqui colide, recebe raycast ou toque; colisões, nomes e posições existentes não mudam.
	Final em ruínas: casca e telhado somem junto com as paredes; o jardim fica.
]]

local Build = require("./Build")
local Materials = require("./HouseMaterials")
local Props = require("./HouseProps")

local Exterior = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local UP = Vector3.yAxis

local STUCCO: Materials.Finish =
	{ variant = "MansionPlaster", material = Enum.Material.Plaster, color = rgb(206, 196, 182) }
local DECK: Materials.Finish =
	{ variant = "MansionFloorPlanks", material = Enum.Material.WoodPlanks, color = rgb(150, 132, 118) }
local TRIM = Materials.Wood
local BRICK = rgb(96, 62, 52)
local BRICK_DARK = rgb(78, 50, 44)
local STONE = rgb(118, 114, 106)
local SLATE = rgb(50, 52, 60)
local IRON = rgb(30, 28, 32)
local WARM = rgb(255, 190, 120)
local SHUTTER = rgb(44, 56, 52)
local CURTAIN = rgb(78, 26, 30)
local LEAVES = rgb(34, 56, 38)
local PLINTH = 3.2

-- Peça decorativa: sem colisão, raycast nem toque.
local function deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	class: ("Part" | "WedgePart")?
): BasePart
	local part = Build.part(parent, name, size, cframe, color, {
		material = material or Enum.Material.SmoothPlastic,
		collide = false,
		query = false,
		class = class,
	})
	part.CanTouch = false
	return part
end

local function rod(
	parent: Instance,
	name: string,
	center: Vector3,
	axis: Vector3,
	length: number,
	diameter: number,
	color: Color3,
	material: Enum.Material?
): BasePart
	local part = Build.cylinder(parent, name, center, axis, length, diameter, color, {
		material = material or Enum.Material.Metal,
		collide = false,
		query = false,
	})
	part.CanTouch = false
	return part
end

local function finish(part: BasePart, f: Materials.Finish): BasePart
	Materials.apply(part, f)
	return part
end

-- Esfera esticada (gomos de abóbora, copas): a forma Ball do Roblox é sempre redonda.
local function ellipsoid(part: BasePart): BasePart
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

--[[
	Fonte de luz invisível e sempre acesa. Não é registrada no WorldFxController: o teste de visibilidade
	dele (feito para luz de um cômodo não vazar para outro) apagava lanternas atrás de pilares e beirais.
]]
local function lamp(parent: Instance, at: Vector3, range: number, brightness: number)
	local part = deco(parent, "ExteriorLamp", V3(0.3, 0.3, 0.3), CFrame.new(at), WARM)
	part.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = WARM, range, brightness, false
	light.Parent = part
	return part
end

-- Luz de jardim no chão apontada para a fachada (lua não basta para ler a arquitetura à noite).
local function uplight(parent: Instance, at: Vector3, target: Vector3)
	local part = deco(parent, "FacadeUplight", V3(0.8, 0.3, 0.8), CFrame.lookAt(at, target), IRON, Enum.Material.Metal)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Color, light.Range, light.Brightness, light.Angle, light.Shadows = rgb(170, 186, 220), 46, 0.75, 70, false
	light.Parent = part
end

-- Triângulo no plano da parede (frontões): duas cunhas com o lado alto no meio.
local function gable(
	parent: Instance,
	name: string,
	base: Vector3,
	normal: Vector3,
	width: number,
	height: number,
	depth: number
)
	local right = UP:Cross(normal).Unit
	for _, side in { -1, 1 } do
		local z = -right * side
		local center = base + right * side * width / 4 + UP * height / 2
		local cframe = CFrame.fromMatrix(center, UP:Cross(z), UP, z)
		finish(deco(parent, name, V3(depth, height, width / 2), cframe, TRIM.color, TRIM.material, "WedgePart"), TRIM)
	end
end

--[[ Casca externa ]]

type Face = { from: Vector2, to: Vector2, normal: Vector3, top: number, bands: boolean, holes: { { number } } }

-- Faces externas (contorno do teste EstateGround). Furos: {u0, u1, y0, y1} ao longo da face.
local FACES: { Face } = {
	-- Frente do vestíbulo, com a porta.
	{
		from = Vector2.new(-24.5, 64.5),
		to = Vector2.new(45.5, 64.5),
		normal = Vector3.zAxis,
		top = 47,
		bands = true,
		holes = { { 18.5, 30.5, -1, 11.5 } },
	},
	{
		from = Vector2.new(45.5, 64.5),
		to = Vector2.new(45.5, 12),
		normal = Vector3.xAxis,
		top = 47,
		bands = true,
		holes = {},
	},
	{
		from = Vector2.new(-24.5, 12.5),
		to = Vector2.new(-24.5, 64.5),
		normal = -Vector3.xAxis,
		top = 47,
		bands = true,
		holes = {},
	},
	-- Laterais dos cômodos: as faixas já vêm do GeneratedEstate (ExteriorCornice).
	{
		from = Vector2.new(44.5, 12.5),
		to = Vector2.new(44.5, -85.5),
		normal = Vector3.xAxis,
		top = 48,
		bands = false,
		holes = {},
	},
	{
		from = Vector2.new(-44.5, -85.5),
		to = Vector2.new(-44.5, 12.5),
		normal = -Vector3.xAxis,
		top = 48,
		bands = false,
		holes = {},
	},
	{
		from = Vector2.new(44.5, -85.5),
		to = Vector2.new(-44.5, -85.5),
		normal = -Vector3.zAxis,
		top = 48,
		bands = true,
		holes = {},
	},
	-- Frente da ala oeste, com as janelas reais dos cômodos.
	{
		from = Vector2.new(-44.5, 12.5),
		to = Vector2.new(-24.5, 12.5),
		normal = Vector3.zAxis,
		top = 48,
		bands = true,
		holes = { { 11.5, 20.5, 5, 11 }, { 11.5, 20.5, 21, 27 }, { 11.5, 20.5, 37, 43 } },
	},
}

-- Retângulo menos furos (sem sobreposição entre furos): faixas verticais, cada uma recortada na altura.
local function pieces(u0: number, u1: number, y0: number, y1: number, holes: { { number } }): { { number } }
	local cuts = { u0, u1 }
	for _, hole in holes do
		table.insert(cuts, math.clamp(hole[1], u0, u1))
		table.insert(cuts, math.clamp(hole[2], u0, u1))
	end
	table.sort(cuts)
	local out = {}
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a < 0.01 then
			continue
		end
		local spans = {}
		for _, hole in holes do
			if hole[1] < b - 0.01 and hole[2] > a + 0.01 then
				table.insert(spans, { math.max(hole[3], y0), math.min(hole[4], y1) })
			end
		end
		table.sort(spans, function(p, q)
			return p[1] < q[1]
		end)
		local y = y0
		for _, span in spans do
			if span[1] > y + 0.01 then
				table.insert(out, { a, b, y, span[1] })
			end
			y = math.max(y, span[2])
		end
		if y1 > y + 0.01 then
			table.insert(out, { a, b, y, y1 })
		end
	end
	return out
end

local function plate(
	parent: Instance,
	name: string,
	face: Face,
	rect: { number },
	depth: number,
	color: Color3,
	material: Enum.Material
): BasePart
	local origin = V3(face.from.X, 0, face.from.Y)
	local right = (V3(face.to.X, 0, face.to.Y) - origin).Unit
	local u, y = (rect[1] + rect[2]) / 2, (rect[3] + rect[4]) / 2
	local center = origin + right * u + UP * y + face.normal * depth / 2
	return deco(
		parent,
		name,
		V3(rect[2] - rect[1], rect[4] - rect[3], depth),
		CFrame.lookAt(center, center + face.normal),
		color,
		material
	)
end

local function shell(folder: Instance)
	for _, face in FACES do
		local length = (face.to - face.from).Magnitude
		for _, rect in pieces(0, length, PLINTH, face.top, face.holes) do
			finish(plate(folder, "FacadeStucco", face, rect, 0.06, STUCCO.color, STUCCO.material), STUCCO)
		end
		for _, rect in pieces(0, length, 0, PLINTH, face.holes) do
			plate(folder, "FacadePlinth", face, rect, 0.3, BRICK, Enum.Material.Brick)
		end
		for _, rect in pieces(0, length, PLINTH, PLINTH + 0.35, face.holes) do
			plate(folder, "FacadePlinthCap", face, rect, 0.42, STONE, Enum.Material.Slate)
		end
		if face.bands then
			for _, y in { 16, 32 } do
				for _, rect in pieces(0, length, y - 0.3, y + 0.3, face.holes) do
					finish(plate(folder, "FacadeBand", face, rect, 0.36, TRIM.color, TRIM.material), TRIM)
				end
			end
			-- Cornija em dois degraus sob o beiral.
			finish(
				plate(
					folder,
					"FacadeCornice",
					face,
					{ 0, length, face.top - 1.1, face.top - 0.2 },
					0.5,
					TRIM.color,
					TRIM.material
				),
				TRIM
			)
			finish(
				plate(
					folder,
					"FacadeCornice",
					face,
					{ 0, length, face.top - 0.4, face.top },
					0.85,
					TRIM.color,
					TRIM.material
				),
				TRIM
			)
		end
	end
	-- Cunhais de pedra alternados nas quinas externas.
	local corners = {
		{ -44.5, -85.5, -1, -1, 48 },
		{ 44.5, -85.5, 1, -1, 48 },
		{ -44.5, 12.5, -1, 1, 48 },
		{ -24.5, 64.5, -1, 1, 47 },
		{ 45.5, 64.5, 1, 1, 47 },
	}
	for _, c in corners do
		local cx, cz, sx, sz, top = c[1], c[2], c[3], c[4], c[5]
		local index = 0
		-- Cada pedra são duas placas finas por FORA das duas faces da quina. Um bloco maciço atravessava a
		-- parede de 1 stud e aparecia dentro dos cômodos como "bloco cinza".
		local d = 0.18
		for y = PLINTH + 0.45, top - 2.6, 2.1 do
			local a = if index % 2 == 0 then 2.6 else 1.7
			index += 1
			deco(
				folder,
				"FacadeQuoin",
				V3(d, 1.85, a + d),
				CFrame.new(cx + sx * d / 2, y + 0.925, cz + sz * (d - a) / 2),
				STONE,
				Enum.Material.Slate
			)
			deco(
				folder,
				"FacadeQuoin",
				V3(a + d, 1.85, d),
				CFrame.new(cx + sx * (d - a) / 2, y + 0.925, cz + sz * d / 2),
				STONE,
				Enum.Material.Slate
			)
		end
	end
end

--[[ Janelas ]]

local function facadeWindow(folder: Instance, center: Vector3, normal: Vector3, lit: boolean, pediment: boolean)
	local right = UP:Cross(normal).Unit
	local w, h = 6.1, 7.2
	local out = center + normal * 0.06
	local model = Props.place(folder, "WindowSet", out, normal, 0.8, "wall")
	if model then
		for _, part in model:GetDescendants() do
			if part.Name == "Curtains" or part.Name == "Rod" then
				part:Destroy()
			elseif part.Name == "Glass" and part:IsA("BasePart") then
				-- Vidro mais claro que o de dentro: a luz do cômodo aparece da rua.
				part.Transparency = 0.7
			end
		end
	else
		deco(
			folder,
			"FacadeWindowFrame",
			V3(w, h, 0.4),
			CFrame.lookAt(out + normal * 0.2, out + normal),
			TRIM.color,
			Enum.Material.Wood
		)
	end
	-- Interior: luz quente com cortinas, ou um quarto escuro.
	local back = out + normal * 0.08
	local glow = deco(
		folder,
		"FacadeWindowGlow",
		V3(w - 1.1, h - 1, 0.05),
		CFrame.lookAt(back, back + normal),
		if lit then rgb(190, 120, 60) else rgb(14, 16, 22),
		if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
	)
	glow.CastShadow = false
	if lit then
		for _, side in { -1, 1 } do
			local at = back + normal * 0.04 + right * side * (w / 2 - 1.15)
			deco(
				folder,
				"FacadeCurtain",
				V3(1.1, h - 1, 0.04),
				CFrame.lookAt(at, at + normal),
				CURTAIN,
				Enum.Material.Fabric
			)
		end
	end
	for _, side in { -1, 1 } do
		local at = out + normal * 0.12 + right * side * (w / 2 + 1.05)
		local shutter = deco(
			folder,
			"FacadeShutter",
			V3(1.9, h - 0.4, 0.18),
			CFrame.lookAt(at, at + normal),
			SHUTTER,
			Enum.Material.Wood
		)
		-- Ripas da veneziana.
		for row = -1, 1 do
			deco(
				folder,
				"FacadeShutterSlat",
				V3(1.5, 0.12, 0.08),
				shutter.CFrame * CFrame.new(0, row * 2, -0.12),
				SHUTTER:Lerp(Color3.new(0, 0, 0), 0.35),
				Enum.Material.Wood
			)
		end
	end
	local sill = out + normal * 0.45 - UP * (h / 2 + 0.25)
	deco(folder, "FacadeSill", V3(w + 1.2, 0.4, 0.9), CFrame.lookAt(sill, sill + normal), STONE, Enum.Material.Slate)
	local head = out + normal * 0.3 + UP * (h / 2 + 0.3)
	finish(
		deco(folder, "FacadeHead", V3(w + 1.4, 0.5, 0.6), CFrame.lookAt(head, head + normal), TRIM.color, TRIM.material),
		TRIM
	)
	if pediment then
		gable(folder, "FacadePediment", head + UP * 0.25 + normal * 0.05, normal, w + 1.6, 1.5, 0.45)
	end
end

local function windows(folder: Instance)
	local count = 0
	-- Algumas janelas escuras quebram a repetição (casa grande, nem todos os cômodos acesos).
	local function lit(): boolean
		count += 1
		return (count * 7) % 10 < 6
	end
	local ROWS = { 7.5, 23.5, 40.2 }
	-- Frente: colunas simétricas em torno do frontão (x = 10,5); térreo livre na porta e na varanda.
	for row, y in ROWS do
		for _, x in { -15.5, -2.5, 10.5, 23.5, 36.5 } do
			if row == 1 and (x == -2.5 or x == 10.5) then
				continue
			end
			facadeWindow(folder, V3(x, y, 64.5), Vector3.zAxis, lit(), row > 1)
		end
	end
	for _, y in ROWS do
		for _, z in { 26, 50 } do
			facadeWindow(folder, V3(45.5, y, z), Vector3.xAxis, lit(), true)
			facadeWindow(folder, V3(-24.5, y, z), -Vector3.xAxis, lit(), true)
		end
		for _, z in { -14, -46, -78 } do
			facadeWindow(folder, V3(44.5, y, z), Vector3.xAxis, lit(), true)
			facadeWindow(folder, V3(-44.5, y, z), -Vector3.xAxis, lit(), true)
		end
		for _, x in { -34, -18, 18, 34 } do
			facadeWindow(folder, V3(x, y, -85.5), -Vector3.zAxis, lit(), true)
		end
		-- Ala oeste: janela real do cômodo (vidro na parede); só peitoril e verga por fora.
		local sill = V3(-28.75, y - 3.25, 12.95)
		deco(folder, "FacadeSill", V3(9.2, 0.4, 0.9), CFrame.new(sill), STONE, Enum.Material.Slate)
		finish(
			deco(folder, "FacadeHead", V3(9.2, 0.5, 0.6), CFrame.new(-28.75, y + 3.3, 12.8), TRIM.color, TRIM.material),
			TRIM
		)
	end
end

--[[ Entrada e varanda (fixas) ]]

local function entrance(shellFolder: Instance, yard: Instance)
	-- Lanternas de parede ao lado da porta.
	for _, x in { -8.5, 8.5 } do
		local wall = V3(x, 7.4, 64.56)
		deco(
			shellFolder,
			"FacadeLanternPlate",
			V3(0.9, 1.4, 0.12),
			CFrame.new(wall + V3(0, 0, 0.06)),
			IRON,
			Enum.Material.Metal
		)
		deco(
			shellFolder,
			"FacadeLanternArm",
			V3(0.16, 0.16, 1.1),
			CFrame.new(wall + V3(0, 0, 0.6)),
			IRON,
			Enum.Material.Metal
		)
		if not Props.place(shellFolder, "Lantern", wall + V3(0, -0.85, 1.15), Vector3.zAxis, 1.55, "floor") then
			deco(
				shellFolder,
				"FacadeLanternGlass",
				V3(0.9, 1.4, 0.9),
				CFrame.new(wall + V3(0, 0, 1.15)),
				WARM,
				Enum.Material.Neon
			)
		end
		lamp(shellFolder, wall + V3(0, 0.2, 1.6), 22, 1.2)
	end
	-- Piso da varanda, degrau e capacho.
	finish(deco(yard, "PorchDeck", V3(34, 0.12, 13.5), CFrame.new(0, 0.06, 71.25), DECK.color, DECK.material), DECK)
	deco(yard, "PorchStep", V3(34.4, 0.3, 0.7), CFrame.new(0, 0.15, 78.2), STONE, Enum.Material.Slate)
	deco(yard, "PorchDoormat", V3(8, 0.05, 3.2), CFrame.new(0, 0.145, 66.4), rgb(84, 40, 40), Enum.Material.Fabric)
	Props.place(yard, "RockingChair", V3(-12.5, 0.12, 67.6), V3(0.45, 0, 1), 1, "floor")
	for _, spot in { { -21, 70, -20 }, { 30, 70, 30 }, { 7, 86, 10.5 } } do
		uplight(yard, V3(spot[1], 0.2, spot[2]), V3(spot[3], 30, 64.5))
	end
	-- Sebes baixas junto à fachada (não colidem: a rota do jardim fica igual).
	for _, hedge in { { -20.75, 7 }, { 31.2, 27.6 } } do
		local part =
			deco(yard, "Hedge", V3(hedge[2], 2.6, 2.2), CFrame.new(hedge[1], 1.3, 66), LEAVES, Enum.Material.LeafyGrass)
		part.CastShadow = false
	end
end

--[[ Telhado e terreno do GeneratedEstate (refeitos a cada nível) ]]

local function flat(v: Vector3): Vector3
	return V3(v.X, 0, v.Z).Unit
end

local function roofTrim(folder: Instance, part: BasePart)
	local cframe, size = part.CFrame, part.Size
	local a, b = cframe * V3(size.X / 2, 0, 0), cframe * V3(-size.X / 2, 0, 0)
	local low, high = if a.Y < b.Y then a else b, if a.Y < b.Y then b else a
	local look = flat(cframe.LookVector)
	local fascia = low - UP * 0.4
	finish(
		deco(
			folder,
			"RoofFascia",
			V3(0.35, 1.3, size.Z + 0.4),
			CFrame.lookAt(fascia, fascia + look),
			TRIM.color,
			TRIM.material
		),
		TRIM
	)
	-- Uma cumeeira por par de águas (só na água que sobe para +X).
	if high.X > part.Position.X then
		rod(
			folder,
			"RoofRidge",
			high + UP * 0.35,
			look,
			size.Z + 0.6,
			1.1,
			SLATE:Lerp(Color3.new(0, 0, 0), 0.25),
			Enum.Material.Slate
		)
		for _, side in { -1, 1 } do
			local tip = high + look * side * (size.Z / 2 + 0.2) + UP * 0.9
			rod(folder, "RoofFinial", tip + UP * 0.8, UP, 1.8, 0.22, IRON)
			local ball =
				deco(folder, "RoofFinial", V3(0.6, 0.6, 0.6), CFrame.new(tip + UP * 1.75), IRON, Enum.Material.Metal);
			(ball :: Part).Shape = Enum.PartType.Ball
		end
	end
end

local function chimney(folder: Instance, part: BasePart)
	part.Material, part.Color = Enum.Material.Brick, BRICK
	local top = part.Position + UP * part.Size.Y / 2
	-- Faixa de tijolo saliente e dois potes de barro sobre o capitel.
	deco(
		folder,
		"RoofChimneyBand",
		V3(part.Size.X + 0.4, 0.5, part.Size.Z + 0.4),
		CFrame.new(top - UP * 1.6),
		BRICK_DARK,
		Enum.Material.Brick
	)
	for _, dx in { -1.1, 1.1 } do
		rod(folder, "RoofChimneyPot", top + V3(dx, 1.5, 0), UP, 1.7, 1.1, rgb(140, 82, 62), Enum.Material.Concrete)
	end
end

local function ironFence(folder: Instance, part: BasePart)
	local size = part.Size
	local along = if size.X > size.Z then part.CFrame.RightVector else part.CFrame.LookVector
	local length = math.max(size.X, size.Z)
	local base = part.Position - UP * size.Y / 2
	local start = base - along * length / 2
	local bars = math.floor(length / 1.6)
	for i = 0, bars do
		local at = start + along * (i * length / bars)
		local post = i % 9 == 0
		local width = if post then 0.55 else 0.2
		deco(folder, "IronFenceBar", V3(width, 4.4, width), CFrame.new(at + UP * 2.2), IRON, Enum.Material.Metal)
		local tip = deco(
			folder,
			"IronFenceTip",
			V3(0.32, 0.32, 0.2),
			CFrame.lookAt(at + UP * 4.5, at + UP * 4.5 + along:Cross(UP)) * CFrame.Angles(0, 0, math.rad(45)),
			IRON,
			Enum.Material.Metal
		)
		if post then
			tip.Size = V3(0.6, 0.6, 0.6);
			(tip :: Part).Shape = Enum.PartType.Ball
		end
	end
	for _, y in { 0.7, 3.7 } do
		local mid = base + UP * y
		deco(
			folder,
			"IronFenceRail",
			V3(0.18, 0.18, length),
			CFrame.lookAt(mid, mid + along),
			IRON,
			Enum.Material.Metal
		)
	end
end

local function porchRoof(folder: Instance, part: BasePart)
	local p, size = part.Position, part.Size
	local top, bottom = p.Y + size.Y / 2, p.Y - size.Y / 2
	deco(
		folder,
		"PorchRoofCap",
		V3(size.X + 0.6, 0.3, size.Z + 0.6),
		CFrame.new(p.X, top + 0.15, p.Z),
		SLATE,
		Enum.Material.Slate
	)
	local front = p.Z + size.Z / 2 + 0.2
	finish(
		deco(
			folder,
			"PorchRoofFascia",
			V3(size.X + 0.8, 1.3, 0.35),
			CFrame.new(p.X, p.Y - 0.1, front),
			TRIM.color,
			TRIM.material
		),
		TRIM
	)
	for _, side in { -1, 1 } do
		local x = p.X + side * (size.X / 2 + 0.2)
		finish(
			deco(
				folder,
				"PorchRoofFascia",
				V3(0.35, 1.3, size.Z + 0.4),
				CFrame.new(x, p.Y - 0.1, p.Z),
				TRIM.color,
				TRIM.material
			),
			TRIM
		)
	end
	-- Lanterna pendurada no meio da varanda.
	local hang = V3(p.X, bottom, p.Z + 2)
	rod(folder, "PorchLanternChain", hang - UP * 0.6, UP, 1.2, 0.12, IRON)
	if not Props.place(folder, "Lantern", hang - UP * 1.2, Vector3.zAxis, 1.9, "ceiling") then
		deco(folder, "PorchLanternGlass", V3(0.9, 1.4, 0.9), CFrame.new(hang - UP * 2), WARM, Enum.Material.Neon)
	end
	lamp(folder, hang - UP * 2.3, 26, 1.2)
end

local function pillar(folder: Instance, part: BasePart)
	finish(part, TRIM)
	local p, size = part.Position, part.Size
	local bottom = p.Y - size.Y / 2
	deco(folder, "PorchPillarBase", V3(2.3, 1.4, 2.3), CFrame.new(p.X, bottom + 0.7, p.Z), STONE, Enum.Material.Slate)
	finish(
		rod(folder, "PorchPillarShaft", V3(p.X, p.Y + 0.4, p.Z), UP, size.Y - 2.4, 1.8, TRIM.color, TRIM.material),
		TRIM
	)
	for _, y in { bottom + 2.2, p.Y + size.Y / 2 - 1.6 } do
		finish(rod(folder, "PorchPillarRing", V3(p.X, y, p.Z), UP, 0.35, 2.1, TRIM.color, TRIM.material), TRIM)
	end
	finish(
		deco(
			folder,
			"PorchPillarCapital",
			V3(2.2, 0.6, 2.2),
			CFrame.new(p.X, p.Y + size.Y / 2 - 0.3, p.Z),
			TRIM.color,
			TRIM.material
		),
		TRIM
	)
end

local function hide(container: Instance?, on: boolean)
	if not container then
		return
	end
	for _, item in container:GetDescendants() do
		if item:IsA("BasePart") then
			if on then
				if item:GetAttribute("ShellTransparency") == nil then
					item:SetAttribute("ShellTransparency", item.Transparency)
				end
				item.Transparency = 1
			else
				local saved = item:GetAttribute("ShellTransparency")
				if type(saved) == "number" then
					item.Transparency = saved
				end
			end
		elseif item:IsA("Light") then
			item.Enabled = not on
		elseif item:IsA("SurfaceGui") then
			(item :: SurfaceGui).Enabled = not on
		end
	end
end

-- Tijolo e ardósia PBR (lote 6). Com textura, Color só tinge: fica claro para não escurecer o mapa.
local ROOF_NAMES = { EstatePitchedRoof = true, FoyerPitchedRoof = true, PorchRoofCap = true, PavilionRoof = true }

local function pbr(container: Instance?)
	if not container then
		return
	end
	for _, part in container:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Material == Enum.Material.Brick and part.MaterialVariant == "" then
			part.MaterialVariant = "GardenBrick"
			part.Color = if part.Color == BRICK_DARK then rgb(176, 164, 158) else rgb(214, 204, 198)
		elseif ROOF_NAMES[part.Name] then
			part.Material, part.MaterialVariant, part.Color = Enum.Material.Slate, "RoofSlate", rgb(150, 150, 158)
		end
	end
end

local ESTATE_WOOD = {
	ExteriorCornice = true,
	PavilionColumn = true,
	LookoutFloor = true,
	LookoutGuard = true,
	GardenStairGuard = true,
	CourtArch = true,
	CourtArchColumn = true,
	CourtBench = true,
	PottingBench = true,
	PavilionLantern = true,
}

local function dressEstate(root: Instance)
	local estate = root:FindFirstChild("GeneratedEstate")
	if not estate or estate:FindFirstChild("RoofDress") then
		return
	end
	local roof = Build.folder(estate, "RoofDress")
	local ground = Build.folder(estate, "EstateDress")
	for _, part in estate:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local name = part.Name
		if name == "EstatePitchedRoof" or name == "FoyerPitchedRoof" then
			part.Color = SLATE
			roofTrim(roof, part)
		elseif name == "EstateGable" then
			finish(part, STUCCO)
		elseif name == "Chimney" then
			chimney(roof, part)
		elseif name == "ChimneyCap" or name == "GardenStairRamp" then
			part.Material, part.Color = Enum.Material.Slate, STONE
		elseif ESTATE_WOOD[name] then
			-- Cornijas, pavilhões, mirante e pátio dos fundos na mesma nogueira da casa.
			finish(part, TRIM)
		elseif name == "FacadePilaster" or name == "SideWindowFrame" or name == "SideWindowInset" then
			-- Substituídos pelos cunhais e janelas da casca externa.
			part.Transparency = 1
		elseif name == "EstateGround" then
			part.Material, part.Color = Enum.Material.Grass, rgb(40, 56, 40)
		elseif name == "GardenWalk" or name == "FrontWalk" or name == "RearCourt" then
			part.Material, part.Color = Enum.Material.Cobblestone, rgb(96, 92, 86)
		elseif name == "EstateFence" or name == "RearFence" then
			part.Material, part.Color = Enum.Material.WoodPlanks, rgb(58, 44, 38)
		elseif name == "FrontFence" then
			-- A colisão continua na peça original; só a aparência vira grade de ferro.
			part.Transparency = 1
			ironFence(ground, part)
		elseif name == "PorchCanopy" then
			finish(part, TRIM)
			porchRoof(roof, part)
		elseif name == "PorchPillar" then
			pillar(ground, part)
		end
	end
	-- Frontão da frente: óculo aceso e o letreiro do jogo.
	local oculus = V3(10.5, 59.3, 66.45)
	finish(rod(roof, "GableOculus", oculus, Vector3.zAxis, 0.4, 4.2, TRIM.color, TRIM.material), TRIM)
	local pane = rod(
		roof,
		"GableOculusGlow",
		oculus + V3(0, 0, 0.05),
		Vector3.zAxis,
		0.4,
		3.3,
		rgb(190, 120, 60),
		Enum.Material.Neon
	)
	pane.CastShadow = false
	local title =
		Build.sign(roof, "BigTitle", V3(10.5, 52.4, 66.5), Vector3.zAxis, Vector2.new(22, 4.2), "TUNG TUNG SAHUR", {
			textColor = rgb(233, 202, 147),
			background = rgb(38, 30, 26),
			lit = true,
			font = Enum.Font.SpecialElite,
		})
	title.CanQuery, title.CanTouch = false, false
	pbr(estate)
	if root:FindFirstChild("Ruins") then
		hide(roof, true)
	end
end

--[[ Muro do perímetro (aparência das barreiras Boundary) ]]

local function boundary(root: Instance, folder: Instance)
	local barriers = root:FindFirstChild("ProgressionBarriers")
	if not barriers then
		return
	end
	for _, part in barriers:GetChildren() do
		if not part:IsA("BasePart") or part.Name ~= "Boundary" then
			continue
		end
		part.Material, part.Color = Enum.Material.Brick, BRICK
		local size = part.Size
		local along = if size.X > size.Z then Vector3.xAxis else Vector3.zAxis
		local length = math.max(size.X, size.Z)
		local thick = math.min(size.X, size.Z)
		local top = part.Position + UP * size.Y / 2
		deco(
			folder,
			"WallCoping",
			if along == Vector3.xAxis then V3(length + 0.4, 0.5, thick + 0.8) else V3(thick + 0.8, 0.5, length + 0.4),
			CFrame.new(top + UP * 0.25),
			STONE,
			Enum.Material.Slate
		)
		local piers = math.max(1, math.floor(length / 16))
		for i = 0, piers do
			local at = part.Position - along * length / 2 + along * (i * length / piers)
			local bottom = at.Y - size.Y / 2
			local pier = deco(
				folder,
				"WallPier",
				V3(thick + 1.4, size.Y + 1.2, thick + 1.4),
				CFrame.new(at.X, bottom + (size.Y + 1.2) / 2, at.Z),
				BRICK_DARK,
				Enum.Material.Brick
			)
			pier.CastShadow = false
			deco(
				folder,
				"WallPierCap",
				V3(thick + 2, 0.5, thick + 2),
				CFrame.new(at.X, bottom + size.Y + 1.45, at.Z),
				STONE,
				Enum.Material.Slate
			)
		end
	end
end

--[[ Jardim ]]

local function lampPost(folder: Instance, at: Vector3)
	local model = Build.model(folder, "LampPost")
	deco(model, "LampBase", V3(1.7, 1, 1.7), CFrame.new(at + UP * 0.5), IRON, Enum.Material.Metal)
	rod(model, "LampPlinth", at + UP * 1.6, UP, 1.2, 1.1, IRON)
	rod(model, "Pole", at + UP * 5.6, UP, 7.6, 0.42, IRON)
	for _, y in { 2.5, 8.8 } do
		rod(model, "LampCollar", at + UP * y, UP, 0.3, 0.75, IRON)
	end
	deco(model, "LampCrossbar", V3(2.4, 0.16, 0.16), CFrame.new(at + UP * 8.4), IRON, Enum.Material.Metal)
	if not Props.place(model, "Lantern", at + UP * 9.35, Vector3.zAxis, 2.3, "floor") then
		deco(model, "Lamp", V3(1, 1.4, 1), CFrame.new(at + UP * 10.1), WARM, Enum.Material.Neon)
	end
	lamp(model, at + UP * 10.6, 28, 1.2)
end

local function pumpkin(folder: Instance, at: Vector3, size: number, face: Vector3?)
	local model = Build.model(folder, "Pumpkin")
	local center = at + UP * size * 0.34
	local orange = rgb(206, 92, 26)
	ellipsoid(
		deco(
			model,
			"PumpkinCore",
			V3(size * 0.7, size * 0.62, size * 0.7),
			CFrame.new(center),
			orange,
			Enum.Material.SmoothPlastic
		)
	)
	-- Oito gomos em volta, um pouco irregulares.
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		local dir = V3(math.cos(angle), 0, math.sin(angle))
		local lobe = deco(
			model,
			"PumpkinLobe",
			V3(size * 0.4, size * (0.66 + (i % 3) * 0.02), size * 0.6),
			CFrame.lookAt(center + dir * size * 0.22, center + dir * size),
			orange:Lerp(rgb(150, 56, 18), (i % 2) * 0.22),
			Enum.Material.SmoothPlastic
		)
		ellipsoid(lobe)
	end
	rod(
		model,
		"PumpkinStem",
		center + UP * size * 0.36,
		V3(0.2, 1, 0.1),
		size * 0.3,
		size * 0.12,
		rgb(74, 82, 44),
		Enum.Material.Wood
	)
	if face then
		-- Rosto entalhado aceso (placa transparente: SurfaceGui não desenha bem em superfícies curvas).
		local spot = center + face * size * 0.53
		local carving =
			deco(model, "PumpkinFace", V3(size * 0.75, size * 0.55, 0.05), CFrame.lookAt(spot, spot + face), orange)
		carving.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.CanvasSize = Vector2.new(100, 80)
		gui.Parent = carving
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "▲ ▲\n◡"
		label.TextScaled = true
		label.Font = Enum.Font.FredokaOne
		label.TextColor3 = rgb(255, 196, 90)
		label.Parent = gui
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = rgb(255, 150, 60), 10, 0.7, false
		light.Parent = carving
	end
end

local GRAVE_TEXT = { "R.I.P.", "TUM\nTUM", "AQUI JAZ\nUM TUM", "1912", "R.I.P.", "TUM\nTUM" }

local function grave(folder: Instance, at: Vector3, yaw: number, kind: number, text: string)
	local model = Build.model(folder, "Gravestone")
	local base = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0)
	local tilt = base * CFrame.Angles(math.rad((yaw % 5) - 2), 0, math.rad((yaw % 7) - 3))
	local stone = rgb(104, 104, 100)
	deco(
		model,
		"GraveBase",
		V3(3.4, 0.5, 1.6),
		base * CFrame.new(0, 0.25, 0),
		stone:Lerp(Color3.new(0, 0, 0), 0.2),
		Enum.Material.Slate
	)
	local front: BasePart
	if kind == 1 then
		front = deco(model, "GraveSlab", V3(2.6, 3, 0.55), tilt * CFrame.new(0, 2, 0), stone, Enum.Material.Slate)
		rod(
			model,
			"GraveArch",
			(tilt * CFrame.new(0, 3.5, 0)).Position,
			tilt.LookVector,
			0.55,
			2.6,
			stone,
			Enum.Material.Slate
		)
	elseif kind == 2 then
		front = deco(model, "GraveCross", V3(0.7, 4.4, 0.55), tilt * CFrame.new(0, 2.7, 0), stone, Enum.Material.Slate)
		deco(model, "GraveCross", V3(2.6, 0.7, 0.55), tilt * CFrame.new(0, 3.5, 0), stone, Enum.Material.Slate)
	else
		front = deco(model, "GraveObelisk", V3(1.3, 4, 1.3), tilt * CFrame.new(0, 2.5, 0), stone, Enum.Material.Slate)
		deco(
			model,
			"GraveObeliskCap",
			V3(0.9, 0.9, 0.9),
			tilt * CFrame.new(0, 4.7, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			stone,
			Enum.Material.Slate
		)
	end
	-- Musgo na base.
	deco(
		model,
		"GraveMoss",
		V3(2.2, 0.08, 1.2),
		base * CFrame.new(0.3, 0.52, 0.1),
		rgb(52, 74, 44),
		Enum.Material.LeafyGrass
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 1
	gui.CanvasSize = Vector2.new(120, 140)
	gui.Parent = front
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, if kind == 2 then 0.3 else 0.6)
	label.Position = UDim2.fromScale(0, if kind == 2 then 0.05 else 0.15)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.SpecialElite
	label.TextColor3 = rgb(54, 52, 50)
	label.Parent = gui
end

local function yard(folder: Instance)
	-- Caminho de pedra da varanda até a saída da floresta, com meio-fio.
	deco(
		folder,
		"StonePath",
		V3(8, 0.06, 53.5),
		CFrame.new(0, 0.03, 104.75),
		rgb(98, 94, 88),
		Enum.Material.Cobblestone
	)
	for _, x in { -4.3, 4.3 } do
		deco(folder, "PathEdge", V3(0.6, 0.22, 53.5), CFrame.new(x, 0.11, 104.75), STONE, Enum.Material.Slate)
	end
	for _, spot in { V3(-11, 0, 84), V3(11, 0, 84), V3(-14, 0, 112), V3(14, 0, 112), V3(-14, 0, 124), V3(14, 0, 124) } do
		lampPost(folder, spot)
	end
	-- Abóboras: acesas ao longo do caminho, um grupinho em cada pilar da varanda.
	for _, z in { 82, 90 } do
		for _, x in { -6, 6 } do
			pumpkin(folder, V3(x, 0, z), 2.4, V3(-math.sign(x), 0, 0))
		end
	end
	for _, x in { -1, 1 } do
		pumpkin(folder, V3(x * 11.6, 0.12, 76.2), 2.2, Vector3.zAxis)
		pumpkin(folder, V3(x * 12.9, 0.12, 77), 1.4, nil)
	end
	-- Cemitério pequeno no jardim oeste, longe dos pavilhões e da trilha.
	local index = 0
	for row = 0, 2 do
		for col = 0, 1 do
			index += 1
			-- Lápides viradas para o caminho do jardim (leste), cada uma um pouco torta.
			grave(
				folder,
				V3(-101 + col * 6, 0, 56 + row * 8),
				-90 + (index * 7) % 15 - 7,
				(index % 3) + 1,
				GRAVE_TEXT[index]
			)
		end
	end
	lampPost(folder, V3(-89, 0, 62))
end

-- Esconde a casca e o telhado no final em ruínas (o jardim continua) e devolve tudo como era.
local function ruins(root: Instance, shellFolder: Instance, on: boolean)
	local estate = root:FindFirstChild("GeneratedEstate")
	hide(shellFolder, on)
	hide(estate and estate:FindFirstChild("RoofDress"), on)
end

function Exterior.build(root: Instance)
	local shellFolder = Build.folder(root, "ExteriorShell")
	local yardFolder = Build.folder(root, "ExteriorYard")
	shell(shellFolder)
	windows(shellFolder)
	entrance(shellFolder, yardFolder)
	boundary(root, yardFolder)
	yard(yardFolder)
	dressEstate(root)
	pbr(shellFolder)
	pbr(yardFolder)
	pbr(root:FindFirstChild("ProgressionBarriers"))
	pbr(root:FindFirstChild("GatePillars"))
	root.ChildAdded:Connect(function(child)
		if child.Name == "GeneratedEstate" then
			-- O nível monta o GeneratedEstate inteiro na mesma execução; vestir depois que terminar.
			task.defer(dressEstate, root)
		elseif child.Name == "Ruins" then
			ruins(root, shellFolder, true)
		end
	end)
	root.ChildRemoved:Connect(function(child)
		if child.Name == "Ruins" then
			ruins(root, shellFolder, false)
		end
	end)
end

return Exterior
