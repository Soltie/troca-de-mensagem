--!strict
-- Complemento reversível: não muda os arquivos da mansão nem seus IDs de portas/trancas.
local Build = require("./Build")
local Levels = require("../Campaign/HouseLevelPlan")
local Builder = {}
local V3 = Vector3.new
local stone = Color3.fromRGB(99, 105, 109)
local trim = Color3.fromRGB(204, 183, 138)
local wood = Color3.fromRGB(79, 58, 46)
local roof = Color3.fromRGB(55, 48, 69)
local function piece(parent: Instance, name: string, base: Vector3, size: Vector3, color: Color3, solid: boolean?)
	return Build.block(parent, name, base, size, 0, color, {
		collide = solid == true,
		query = solid == true,
		material = if name == "PavilionFloor" or name == "GardenStairTread"
			then Enum.Material.Slate
			elseif name == "ClayPot" then Enum.Material.Brick
			elseif name == "Herbs" then Enum.Material.Grass
			elseif name == "PavilionRoof" then Enum.Material.Slate
			else Enum.Material.Wood,
	})
end
local function sign(parent: Instance, p: Vector3, text: string)
	Build.sign(
		parent,
		"EstateSign",
		p,
		Vector3.zAxis,
		Vector2.new(10, 2),
		text,
		{ textColor = trim, background = wood, lit = true }
	)
end
local function pavilion(parent: Instance, x: number, z: number, title: string, glass: boolean)
	-- O centro e a aproximação de cada tarefa ficam livres; os móveis ocupam as bordas.
	piece(parent, "PavilionFloor", V3(x, -1, z), V3(28, 1, 28), stone, true)
	for _, dx in { -12, 12 } do
		for _, dz in { -12, 12 } do
			piece(parent, "PavilionColumn", V3(x + dx, 0, z + dz), V3(0.7, 12, 0.7), trim, true)
		end
		if glass then
			local wall =
				piece(parent, "GreenhouseGlass", V3(x + dx, 0, z), V3(0.2, 10, 22), Color3.fromRGB(119, 157, 151))
			wall.Material, wall.Transparency = Enum.Material.Glass, 0.7
		end
		for row = 1, 3 do
			local benchZ = z - 8 + row * 4
			piece(parent, "PottingBench", V3(x + dx * 0.72, 0, benchZ), V3(3, 2.6, 2.4), wood)
			piece(parent, "ClayPot", V3(x + dx * 0.72, 2.6, benchZ), V3(1.5, 1.2, 1.5), Color3.fromRGB(139, 91, 66))
			piece(parent, "Herbs", V3(x + dx * 0.72, 3.8, benchZ), V3(2, 1.4, 2), Color3.fromRGB(54, 83, 58))
		end
	end
	piece(parent, "PavilionRoof", V3(x, 12, z), V3(30, 0.7, 30), roof, true)
	local lantern = piece(parent, "PavilionLantern", V3(x, 8, z + 10), V3(0.5, 0.7, 0.5), trim)
	Build.light(lantern, "Street", Color3.fromRGB(255, 202, 137), 22, 0.55, true, false)
	sign(parent, V3(x, 9, z + 12), title)
end
local function stairs(parent: Instance, side: number)
	local x = side * 94
	local from, to = V3(x, 0, 0), V3(x, 8, 24)
	local cf = CFrame.lookAt((from + to) / 2 - V3(0, 0.5, 0), to - V3(0, 0.5, 0))
	Build.part(parent, "GardenStairRamp", V3(10, 1, (to - from).Magnitude + 1), cf, stone)
	for i = 1, 16 do
		local p = from:Lerp(to, i / 16)
		piece(parent, "GardenStairTread", p - V3(0, 0.14, 0), V3(10, 0.16, 1.5), trim)
	end
	piece(parent, "LookoutFloor", V3(x, 7, 36), V3(18, 1, 24), wood, true)
	for _, dx in { -8.5, 8.5 } do
		piece(parent, "LookoutGuard", V3(x + dx, 8, 36), V3(0.4, 3.5, 24), trim, true)
	end
	piece(parent, "LookoutGuard", V3(x, 8, 48), V3(18, 3.5, 0.4), trim, true)
	for _, dx in { -5.2, 5.2 } do
		Build.part(parent, "GardenStairGuard", V3(0.3, 3.5, (to - from).Magnitude), cf * CFrame.new(dx, 2, 0), trim)
	end
	sign(parent, V3(x, 12.5, 47.5), "MIRANTE / A CASA OBSERVA")
end
local function suppress(part: BasePart)
	if part:GetAttribute("LevelOriginalTransparency") == nil then
		part:SetAttribute("LevelOriginalTransparency", part.Transparency)
		part:SetAttribute("LevelOriginalCollide", part.CanCollide)
		part:SetAttribute("LevelOriginalQuery", part.CanQuery)
	end
	part.Transparency, part.CanCollide, part.CanQuery = 1, false, false
end
local function serviceStairs(parent: Instance, side: number)
	local x = side * 26
	local from, to = V3(x, 16, -80), V3(x, 32, -54)
	local cf = CFrame.lookAt((from + to) / 2 - V3(0, 0.5, 0), to - V3(0, 0.5, 0))
	Build.part(parent, "ServiceStairRamp", V3(10, 1, (to - from).Magnitude + 1.5), cf, wood)
	for _, dx in { -5.2, 5.2 } do
		Build.part(parent, "ServiceStairGuard", V3(0.3, 3.5, (to - from).Magnitude), cf * CFrame.new(dx, 2, 0), trim)
	end
	for i = 1, 26 do
		piece(parent, "ServiceStairTread", from:Lerp(to, i / 26) - V3(0, 0.15, 0), V3(10, 0.16, 1), trim)
	end
	-- Recorte só no cômodo superior vago, depois de a campanha liberar o andar.
	for _, dx in { -12, 12 } do
		piece(parent, "ServiceStairFloor", V3(x + dx, 31, -68), V3(12, 1, 32), wood, true)
	end
	for _, z in { -83, -53 } do
		piece(parent, "ServiceStairLanding", V3(x, 31, z), V3(12, 1, 2), wood, true)
	end
	for _, dx in { -6, 6 } do
		piece(parent, "ServiceStairLandingGuard", V3(x + dx, 32, -68), V3(0.3, 3.5, 28), trim, true)
	end
	sign(parent, V3(x, 25, -51.3), "ESCADA DE SERVIÇO / SÓTÃO")
end
function Builder.build(root: Instance, level: Levels.Level)
	local previous = root:FindFirstChild("GeneratedEstate")
	if previous then
		previous:Destroy()
	end
	local out = Build.folder(root, "GeneratedEstate")
	root:SetAttribute("LevelEnvironment", if level.outdoor then "Exterior" else "Interior")
	root:SetAttribute("LevelTheme", level.theme)
	-- Anel contínuo de caminhada: sem lacunas, sem invadir a projeção do porão.
	for _, side in { -1, 1 } do
		piece(out, "EstateFence", V3(side * 106, 0, -20), V3(0.5, 4, 198), wood, true)
		piece(out, "FrontFence", V3(side * 77, 0, 80), V3(58, 4, 0.5), wood, true)
		piece(out, "EstateGround", V3(side * 77, -1, -20), V3(58, 1, 200), Color3.fromRGB(47, 62, 46), true)
		piece(out, "GardenWalk", V3(side * 58, -0.03, -20), V3(10, 0.03, 200), stone)
		piece(out, "FrontWalk", V3(side * 39, -0.03, 76), V3(78, 0.03, 9), stone)
		pavilion(out, side * 76, 24, if side < 0 then "JARDIM DE INVERNO" else "ESTUFA", side > 0)
		pavilion(out, side * 76, -44, if side < 0 then "PAVILHÃO DAS MEMÓRIAS" else "OFICINA DO JARDINEIRO", false)
	end
	piece(out, "RearCourt", V3(0, -1, -102), V3(106, 1, 30), stone, true)
	piece(out, "RearFence", V3(0, 0, -117), V3(212, 4, 0.5), wood, true)
	for _, side in { -1, 1 } do
		piece(out, "CourtArchColumn", V3(side * 34, 0, -112), V3(1, 14, 1), trim, true)
		piece(out, "CourtBench", V3(side * 34, 0, -106), V3(9, 2, 3), wood)
	end
	piece(out, "CourtArch", V3(0, 14, -112), V3(70, 1, 2), trim)
	sign(out, V3(0, 10, -112), "O RELÓGIO PAROU. A CASA, NÃO.")
	stairs(out, level.stairSide)
	-- Silhueta de telhado, cornijas, varanda e chaminés, vistas de todos os lados.
	local angle = math.atan(20 / 48)
	for _, side in { -1, 1 } do
		Build.part(
			out,
			"EstatePitchedRoof",
			V3(53, 0.8, 108),
			CFrame.new(side * 24, 58, -36) * CFrame.Angles(0, 0, -side * angle),
			roof,
			{ material = Enum.Material.Slate }
		)
		for _, z in { -90, 18 } do
			Build.part(
				out,
				"EstateGable",
				V3(0.6, 20, 48),
				CFrame.new(side * 24, 58, z) * CFrame.Angles(0, -side * math.pi / 2, 0),
				Color3.fromRGB(113, 100, 122),
				{ class = "WedgePart", material = Enum.Material.Plaster }
			)
		end
		Build.part(
			out,
			"FoyerPitchedRoof",
			V3(39, 0.8, 57),
			CFrame.new(10.5 + side * 17.5, 56, 38) * CFrame.Angles(0, 0, -side * math.atan(16 / 35)),
			roof,
			{ material = Enum.Material.Slate }
		)
		Build.part(
			out,
			"EstateGable",
			V3(0.6, 16, 35),
			CFrame.new(10.5 + side * 17.5, 56, 66) * CFrame.Angles(0, -side * math.pi / 2, 0),
			Color3.fromRGB(113, 100, 122),
			{ class = "WedgePart", material = Enum.Material.Plaster }
		)
		piece(out, "Chimney", V3(side * 29, 58, -62), V3(5, 16, 5), stone)
		piece(out, "ChimneyCap", V3(side * 29, 74, -62), V3(6, 0.6, 6), trim)
		for _, z in { -84, 10 } do
			piece(out, "FacadePilaster", V3(side * 44.65, 0, z), V3(1, 48, 1.4), trim)
		end
		for _, y in { 0, 16, 32, 47 } do
			piece(out, "ExteriorCornice", V3(side * 44.7, y, -36), V3(0.8, 0.7, 100), trim)
		end
		for _, z in { -78, -46, -14 } do
			for _, y in { 16, 32 } do
				piece(out, "SideWindowFrame", V3(side * 44.65, y + 4, z), V3(0.3, 7, 5), trim)
				piece(
					out,
					"SideWindowInset",
					V3(side * 44.9, y + 4.4, z),
					V3(0.2, 6.2, 4.2),
					Color3.fromRGB(94, 113, 116)
				)
			end
		end
		piece(out, "PorchPillar", V3(side * 14, 0, 74), V3(1.2, 12, 1.2), trim, true)
	end
	piece(out, "PorchCanopy", V3(0, 12, 70), V3(34, 1, 16), roof, true)
	local arch = root:FindFirstChild("Architecture")
	if not arch then
		return
	end
	for _, wall in arch:GetChildren() do
		if not wall:IsA("BasePart") then
			continue
		end
		-- Restaura primeiro: reiniciar ou voltar à História nunca acumula buracos.
		if wall:GetAttribute("LevelOriginalTransparency") ~= nil then
			wall.Transparency = wall:GetAttribute("LevelOriginalTransparency") :: number
			wall.CanCollide = wall:GetAttribute("LevelOriginalCollide") :: boolean
			wall.CanQuery = wall:GetAttribute("LevelOriginalQuery") :: boolean
		end
		if
			level.serviceStair
			and math.abs(wall.Position.X - level.stairSide * 26) < 0.1
			and math.abs(wall.Position.Z + 68) < 0.1
			and (
				(wall.Name == "RoomFloor" and math.abs(wall.Position.Y - 31.5) < 0.1)
				or (wall.Name == "RoomCeiling" and math.abs(wall.Position.Y - 31.25) < 0.1)
			)
		then
			suppress(wall)
		end
		if wall.Name ~= "RoomPartition" then
			continue
		end
		for _, opening in level.passages do
			if
				math.abs(wall.Position.X - opening.x) > 0.1
				or math.abs(wall.Position.Z - opening.z) > 0.1
				or math.abs(wall.Position.Y - (opening.y + 8)) > 0.1
			then
				continue
			end
			suppress(wall)
			local rest = (wall.Size.X - opening.width) / 2
			for _, side in { -1, 1 } do
				local p = piece(
					out,
					"ConnectedRoomWall",
					V3(opening.x + side * (opening.width + rest) / 2, opening.y, opening.z),
					V3(rest, wall.Size.Y, wall.Size.Z),
					wall.Color,
					true
				)
				p.Material, p.MaterialVariant = wall.Material, wall.MaterialVariant
			end
			local lintel = piece(
				out,
				"PassageLintel",
				V3(opening.x, opening.y + 11, opening.z),
				V3(opening.width, 5, wall.Size.Z),
				wall.Color,
				true
			)
			lintel.Material, lintel.MaterialVariant = wall.Material, wall.MaterialVariant
		end
	end
	if level.serviceStair then
		serviceStairs(out, level.stairSide)
	end
end
function Builder.ruins(root: Instance)
	local generated = root:FindFirstChild("GeneratedEstate")
	if not generated then
		return
	end
	for _, part in generated:GetChildren() do
		if
			part:IsA("BasePart")
			and (
				part.Name == "EstatePitchedRoof"
				or part.Name == "ExteriorCornice"
				or part.Name == "Chimney"
				or part.Name == "ChimneyCap"
				or part.Name == "PorchCanopy"
				or part.Name == "EstateGable"
				or part.Name == "FoyerPitchedRoof"
			)
		then
			part.Transparency, part.CanCollide, part.CanQuery = 1, false, false
		end
	end
end
return Builder
