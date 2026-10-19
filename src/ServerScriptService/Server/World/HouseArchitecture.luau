--!strict
-- Fechamentos e acabamentos; colisão fica na estrutura, detalhes nunca bloqueiam o caminho.
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Build = require("./Build")
local Architecture = {}
local V3 = Vector3.new
local wood = Color3.fromRGB(78, 57, 43)
local trim = Color3.fromRGB(156, 131, 94)
local plaster = Color3.fromRGB(125, 119, 110)
local decor = { collide = false, query = false, material = Enum.Material.Wood }

local function piece(parent: Instance, name: string, base: Vector3, size: Vector3, color: Color3, solid: boolean?)
	local part = Build.block(parent, name, base, size, 0, color, if solid then nil else decor)
	if name == "CorridorPendant" or name == "StairPendant" or name == "LandingSconce" then
		part.Material = Enum.Material.Metal
		local glass = Build.cylinder(
			parent,
			"FixtureGlass",
			part.Position - V3(0, 0.22, 0),
			Vector3.yAxis,
			0.16,
			math.max(size.X, size.Z) * 0.75,
			Color3.fromRGB(217, 177, 117),
			{ material = Enum.Material.Neon, collide = false, query = false }
		)
		glass:SetAttribute("VisualDetail", true)
	end
	return part
end
local function plaque(parent: Instance, position: Vector3, facing: Vector3, text: string)
	Build.sign(parent, "Wayfinding", position, facing, Vector2.new(9, 1.5), text, {
		textColor = Color3.fromRGB(224, 205, 158),
		background = wood,
		font = Enum.Font.SpecialElite,
	})
end
function Architecture.build(structure: Instance, dressing: Instance)
	for _, y in Layout.Floors do
		for _, rect in Layout.decks(y) do
			local slab = Build.box(
				structure,
				"StairDeck",
				V3(rect.x0, y - 1, rect.z0),
				V3(rect.x1, y, rect.z1),
				wood,
				{ material = if y < 0 then Enum.Material.Slate else Enum.Material.WoodPlanks }
			)
			slab:SetAttribute("FloorLevel", y)
		end
		local hole = Layout.opening(y)
		if hole then
			-- Guarda-corpo de verdade ao lado do vão; bocas da escada ficam livres.
			for _, x in { hole.x0, hole.x1 } do
				piece(structure, "LandingGuard", V3(x, y, 38), V3(0.35, 3.5, 32), wood, true)
				piece(dressing, "Handrail", V3(x, y + 3.5, 38), V3(0.6, 0.25, 32), trim)
			end
		end
		for _, x in { -23.4, 44.4 } do
			piece(dressing, "Skirting", V3(x, y, 38), V3(0.18, 1, 51), wood)
			piece(dressing, "Cornice", V3(x, y + 14.8, 38), V3(0.35, 0.4, 51), trim)
		end
		local names = if y < 0
			then "PORÃO / RITUAL"
			elseif y == 0 then "TÉRREO / BIBLIOTECA"
			elseif y == 16 then "QUARTOS / ESCRITÓRIO"
			else "SÓTÃO / MEMÓRIAS"
		-- Na parede oeste do hall, à esquerda de quem entra (antes ficava solta no vão da porta de entrada).
		plaque(dressing, V3(-23.38, y + 8.5, 52), Vector3.xAxis, names)
		plaque(dressing, V3(0, y + 8.5, 13.1), Vector3.zAxis, "CORREDOR CENTRAL")
		for _, z in { 16, 59 } do
			local lamp = piece(dressing, "LandingSconce", V3(-22.8, y + 7, z), V3(0.5, 1.4, 0.8), trim)
			Build.light(lamp, "Street", Color3.fromRGB(255, 213, 160), 26, 0.55, true)
		end
		-- Rodapé, lambri e friso seguem as aberturas reais, sem atravessar portas.
		for _, side in { -1, 1 } do
			for row = 1, 3 do
				local z = 28 - row * 32
				for _, dz in { -10.5, 10.5 } do
					piece(dressing, "Wainscot", V3(side * 7.42, y, z + dz), V3(0.16, 3.5, 10.8), wood)
					piece(dressing, "ChairRail", V3(side * 7.3, y + 3.5, z + dz), V3(0.25, 0.18, 10.8), trim)
					-- Painéis baixos afastados da parede; não interceptam portas, colisões ou raycasts.
					for _, inset in { -3.6, 0, 3.6 } do
						local panel = piece(
							dressing,
							"WainscotPanel",
							V3(side * 7.26, y + 0.4, z + dz + inset),
							V3(0.12, 2.6, 3.1),
							wood:Lerp(trim, 0.12)
						)
						panel:SetAttribute("VisualDetail", true)
					end
				end
				for _, dz in { -5.15, 5.15 } do
					piece(dressing, "DoorCasing", V3(side * 7.35, y, z + dz), V3(0.3, 11.6, 0.3), trim)
				end
				piece(dressing, "DoorCasing", V3(side * 7.35, y + 11.5, z), V3(0.3, 0.3, 10.6), trim)
			end
		end
		for _, z in { -9, -41, -73 } do
			piece(dressing, "CeilingBeam", V3(0, y + 14.5, z), V3(16, 0.4, 0.6), wood)
			local lamp = piece(dressing, "CorridorPendant", V3(0, y + 12.6, z), V3(1.4, 0.35, 1.4), trim)
			Build.light(lamp, "Street", Color3.fromRGB(245, 211, 170), 24, 0.5, true)
		end
	end
	-- O subsolo também tem paredes externas: terreno não substitui fundação.
	for _, x in { -24, 45 } do
		Build.block(
			structure,
			"StairFacade",
			V3(x, -16, 38),
			V3(1, 63, 52),
			0,
			plaster,
			{ material = Enum.Material.Plaster }
		)
	end
	Build.block(
		structure,
		"FoundationFacade",
		V3(10.5, -16, 64),
		V3(70, 16, 1),
		0,
		plaster,
		{ material = Enum.Material.Brick }
	)
	Build.block(
		structure,
		"BasementFrontFacade",
		V3(-34, -16, 12),
		V3(20, 16, 1),
		0,
		plaster,
		{ material = Enum.Material.Brick }
	)
	Build.block(
		structure,
		"CorridorRoof",
		V3(0, 47, -36),
		V3(16, 1, 98),
		0,
		plaster,
		{ material = Enum.Material.Plaster }
	)
	-- Espelhos baixos: a malha visual acompanha a rampa contínua de colisão.
	for _, stair in Layout.Stairs do
		local lamp =
			piece(dressing, "StairPendant", V3(stair.x, (stair.y0 + stair.y1) / 2 + 7, 38), V3(1.4, 0.4, 1.4), trim)
		Build.light(lamp, "Street", Color3.fromRGB(246, 212, 165), 24, 0.75, true)
		for step = 0, 31 do
			local t = (step + 0.5) / 32
			local z = stair.z0 + (stair.z1 - stair.z0) * t
			local y = stair.y0 + (stair.y1 - stair.y0) * t
			piece(dressing, "StairTread", V3(stair.x, y + 0.08, z), V3(9.8, 0.08, 0.85), wood)
			for _, side in { -1, 1 } do
				if step % 4 == 0 then
					piece(dressing, "StairBaluster", V3(stair.x + side * 5.1, y, z), V3(0.18, 3.1, 0.18), trim)
				end
			end
		end
	end
end
return Architecture
