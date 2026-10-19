--!strict
--[[
	Materiais PBR da mansão (MaterialVariant em MaterialService, texturas CC0 do Poly Haven).
	Só troca aparência: Material/MaterialVariant/Color. Tamanho, posição, colisão e nomes não mudam.
	Paredes externas recebem um revestimento interno fino (sem colisão) para o papel de parede
	não aparecer do lado de fora; o porão continua de tijolo.
]]

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Build = require("./Build")

local Materials = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB

export type Finish = { variant: string, material: Enum.Material, color: Color3 }

local WALLPAPER: Finish = { variant = "MansionWallpaper", material = Enum.Material.Plaster, color = rgb(236, 230, 220) }
local PLANKS: Finish =
	{ variant = "MansionFloorPlanks", material = Enum.Material.WoodPlanks, color = rgb(214, 202, 190) }
local STONE: Finish = { variant = "", material = Enum.Material.Slate, color = rgb(74, 70, 64) }
local ATTIC: Finish =
	{ variant = "MansionFloorPlanks", material = Enum.Material.WoodPlanks, color = rgb(170, 150, 132) }
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
local CEILINGS = { RoomCeiling = true, CorridorCeilingPanel = true, FoyerCeilingPanel = true, RoomCeilingPanel = true }
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
	AntiqueTable = true,
}
-- Armários e esconderijos (Features): só a aparência muda; porta, prompt e tags ficam iguais.
local HIDE_NAMES =
	{ Side = true, Back = true, Top = true, HideDoor = true, ChestLid = true, BedCover = true, Leg = true }
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

-- Cozinha e banheiro: ladrilho xadrez de mármore gasto (Poly Haven floor_tiles_06).
local TILES: Finish = { variant = "MansionTiles", material = Enum.Material.Slate, color = rgb(214, 206, 196) }
local TILED: { Vector3 } = {}
for _, room in House.Rooms do
	if room.id == "Kitchen" or room.id == "Bath" then
		table.insert(TILED, Vector3.new(room.x, room.y, room.z))
	end
end

local function tiled(position: Vector3): boolean
	for _, center in TILED do
		local d = position - center
		if math.abs(d.X) < 18 and math.abs(d.Z) < 16 and math.abs(d.Y) < 1.5 then
			return true
		end
	end
	return false
end

-- Sala de máquinas (térreo, fundo à direita): reboco cru, sem papel de parede.
local function utility(position: Vector3): boolean
	return position.X > 8.6 and position.Z < -52.4 and position.Y > -0.5 and position.Y < 15.5
end

local function classify(part: BasePart): Finish?
	local name = part.Name
	local basement = part.Position.Y < -0.5
	if INTERIOR_WALLS[name] then
		-- Sótão (nível 32) é tábua crua, sem papel de parede.
		return if basement
			then nil
			elseif part.Position.Y > 31 then ATTIC
			elseif name ~= "DoorWall" and name ~= "DoorLintel" and utility(part.Position) then PLASTER
			else WALLPAPER
	elseif FLOORS[name] then
		-- Porão e sala de máquinas: lajota de pedra em vez de tábua.
		if utility(part.Position + Vector3.yAxis) then
			return STONE
		elseif name == "RoomFloor" and tiled(part.Position) then
			return TILES
		end
		return if basement then (if name == "CorridorFloor" or name == "RoomFloor" then STONE else nil) else PLANKS
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

-- Revestimento interno das paredes que também são fachada (um trecho por cômodo).
local function skins(parent: Instance)
	local function skin(center: Vector3, size: Vector3)
		local part = Build.part(parent, "WallpaperSkin", size, CFrame.new(center), WALLPAPER.color, {
			collide = false,
			query = false,
		})
		part.CanTouch = false
		Materials.apply(part, if center.Y > 31 then ATTIC elseif utility(center) then PLASTER else WALLPAPER)
	end
	local W = Layout.Window
	local windows = Layout.facadeWindows(House.Rooms)
	for _, y in { 0, 16, 32 } do
		local mid = y + 7.5
		for _, side in { -1, 1 } do
			-- Fachadas laterais dos cômodos (x = ±44), uma por fileira; recortadas em volta das janelas reais.
			for row = 1, 3 do
				local zc = 28 - row * 32
				local hole: number? = nil
				for _, window in windows do
					if window.side == side and window.y == y and math.abs(window.z - zc) < 16 then
						hole = window.z
					end
				end
				if not hole then
					skin(V3(side * 43.47, mid, zc), V3(0.04, 15, 32))
				else
					local x = side * 43.47
					local z0, z1 = hole - W.halfWidth, hole + W.halfWidth
					skin(V3(x, y + W.y0 / 2, zc), V3(0.04, W.y0, 32))
					skin(V3(x, (y + W.y1 + y + 15) / 2, zc), V3(0.04, 15 - W.y1, 32))
					local band, bandY = W.y1 - W.y0, y + (W.y0 + W.y1) / 2
					skin(V3(x, bandY, (zc - 16 + z0) / 2), V3(0.04, band, z0 - (zc - 16)))
					skin(V3(x, bandY, (z1 + zc + 16) / 2), V3(0.04, band, zc + 16 - z1))
				end
			end
			-- Fundo da casa (z = -85), metade de cada lado.
			skin(V3(side * 22, mid, -84.47), V3(43, 15, 0.04))
		end
		-- Laterais da caixa da escada (x = -24 e 45).
		skin(V3(-23.47, mid, 38), V3(0.04, 15, 51))
		skin(V3(44.47, mid, 38), V3(0.04, 15, 51))
		-- Frente do hall (z = 64), com o vão da porta no térreo.
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
	local features = root:FindFirstChild("Features")
	if features then
		for _, part in features:GetDescendants() do
			-- A porta do esconderijo debaixo da cama é quase transparente e fica como está.
			if part:IsA("BasePart") and HIDE_NAMES[part.Name] and part.Transparency < 0.5 then
				-- A cama-esconderijo ganha colcha de jacquard; o resto é nogueira.
				Materials.apply(part, if part.Name == "BedCover" then RUNNER else WOOD)
			end
		end
	end
end

return Materials
