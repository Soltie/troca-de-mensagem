--!strict
--[[
	Materiais PBR da mansÃ£o (MaterialVariant em MaterialService, texturas CC0 do Poly Haven).
	SÃ³ troca aparÃªncia: Material/MaterialVariant/Color. Tamanho, posiÃ§Ã£o, colisÃ£o e nomes nÃ£o mudam.
	Paredes externas recebem um revestimento interno fino (sem colisÃ£o) para o papel de parede
	nÃ£o aparecer do lado de fora; o porÃ£o continua de tijolo.
]]

local Build = require("./Build")

local Materials = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB

export type Finish = { variant: string, material: Enum.Material, color: Color3 }

local WALLPAPER: Finish = { variant = "MansionWallpaper", material = Enum.Material.Plaster, color = rgb(236, 230, 220) }
local PLANKS: Finish =
	{ variant = "MansionFloorPlanks", material = Enum.Material.WoodPlanks, color = rgb(214, 202, 190) }
local PLASTER: Finish = { variant = "MansionPlaster", material = Enum.Material.Plaster, color = rgb(226, 214, 196) }
local WOOD: Finish = { variant = "MansionDarkWood", material = Enum.Material.Wood, color = rgb(200, 196, 192) }
local WOOD_LIGHT: Finish = { variant = "MansionDarkWood", material = Enum.Material.Wood, color = rgb(255, 250, 244) }
local RUNNER: Finish = { variant = "MansionRunner", material = Enum.Material.Fabric, color = rgb(196, 168, 176) }
local LEATHER: Finish = { variant = "MansionLeather", material = Enum.Material.Leather, color = rgb(190, 150, 140) }

Materials.Wallpaper = WALLPAPER
Materials.Wood = WOOD

-- Paredes com as duas faces dentro da casa.
local INTERIOR_WALLS = {
	DoorWall = true,
	DoorLintel = true,
	RoomPartition = true,
	ConnectedRoomWall = true,
	PassageLintel = true,
	FacadeSill = true,
	FacadeTop = true,
	WindowSide = true,
}
local FLOORS = {
	CorridorFloor = true,
	RoomFloor = true,
	StairDeck = true,
	ReturnWalkway = true,
	SouthLanding = true,
	NorthLanding = true,
	MainStairs = true,
	AtticStairs = true,
}
local CEILINGS = { RoomCeiling = true, CorridorCeilingPanel = true, FoyerCeilingPanel = true }
local WOOD_NAMES = {
	Wainscot = true,
	DoorCasing = true,
	Skirting = true,
	Cornice = true,
	CeilingBeam = true,
	Handrail = true,
	Railing = true,
	StairTread = true,
	StairBaluster = true,
	LandingGuard = true,
	FinishWainscot = true,
	FinishSkirting = true,
	FinishChairRail = true,
	CorridorCrown = true,
	GuardNewel = true,
	ConsoleApron = true,
	ConsoleLeg = true,
	BenchBack = true,
	BenchLeg = true,
	ClockPlinth = true,
	ClockHood = true,
}
local WOOD_LIGHT_NAMES = {
	WainscotPanel = true,
	ChairRail = true,
	FinishPanel = true,
	GuardPanel = true,
	DoorPanelUpper = true,
	DoorPanelLower = true,
	ConsoleTop = true,
	BenchSeat = true,
	ClockCase = true,
}

function Materials.apply(part: BasePart, finish: Finish)
	part.Material = finish.material
	part.MaterialVariant = finish.variant
	part.Color = finish.color
end

local function classify(part: BasePart): Finish?
	local name = part.Name
	local basement = part.Position.Y < -0.5
	if INTERIOR_WALLS[name] then
		return if basement then nil else WALLPAPER
	elseif FLOORS[name] then
		return if basement and name ~= "CorridorFloor" and name ~= "RoomFloor" then nil else PLANKS
	elseif CEILINGS[name] then
		return PLASTER
	elseif WOOD_NAMES[name] or string.sub(name, 1, 11) == "house_door_" then
		return WOOD
	elseif WOOD_LIGHT_NAMES[name] then
		return WOOD_LIGHT
	elseif name == "HallRunner" or name == "CorridorRunner" then
		return RUNNER
	elseif name == "BenchCushion" then
		return LEATHER
	end
	return nil
end

-- Revestimento interno das paredes que tambÃ©m sÃ£o fachada.
local function skins(parent: Instance)
	local function skin(center: Vector3, size: Vector3)
		local part = Build.part(parent, "WallpaperSkin", size, CFrame.new(center), WALLPAPER.color, {
			collide = false,
			query = false,
		})
		part.CanTouch = false
		Materials.apply(part, WALLPAPER)
	end
	for _, y in { 0, 16, 32 } do
		local mid = y + 7.5
		for _, side in { -1, 1 } do
			-- Fachadas laterais dos cÃ´modos (x = Â±44).
			skin(V3(side * 43.47, mid, -36), V3(0.04, 15, 96))
		end
		-- Fundo da casa (z = -85) e laterais da caixa da escada (x = -24 e 45).
		skin(V3(0, mid, -84.47), V3(87, 15, 0.04))
		skin(V3(-23.47, mid, 38), V3(0.04, 15, 51))
		skin(V3(44.47, mid, 38), V3(0.04, 15, 51))
		-- Frente do hall (z = 64), com o vÃ£o da porta no tÃ©rreo.
		if y == 0 then
			skin(V3(-14.75, mid, 63.47), V3(17.5, 15, 0.04))
			skin(V3(25.25, mid, 63.47), V3(38.5, 15, 0.04))
			skin(V3(0, 13.25, 63.47), V3(12, 3.5, 0.04))
		else
			skin(V3(10.5, mid, 63.47), V3(68, 15, 0.04))
		end
	end
end

local function paint(container: Instance?)
	if not container then
		return
	end
	for _, part in container:GetDescendants() do
		if part:IsA("BasePart") then
			local finish = classify(part)
			if finish then
				Materials.apply(part, finish)
			end
		end
	end
end

function Materials.build(root: Instance)
	local finish = root:FindFirstChild("Finish")
	if finish then
		skins(finish)
	end
	for _, name in { "Architecture", "Furnishings", "Doors", "Finish", "GeneratedEstate" } do
		paint(root:FindFirstChild(name))
	end
end

return Materials
