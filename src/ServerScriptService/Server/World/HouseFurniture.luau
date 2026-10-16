--!strict
--[[
	Móveis temáticos por cômodo (só visual). Tudo encostado nas paredes externas/frontal do cômodo,
	longe da porta (lado do corredor) e do armário de esconder, sem colisão e invisível para raycasts:
	não muda rotas do Tung Tung, prompts nem testes de navegação.

	Sistema local de cada cômodo: `out` aponta para a fachada (parede externa), `z` cresce para a frente.
]]

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Build = require("./Build")

local Furniture = {}

local rgb = Color3.fromRGB
local WOOD = rgb(140, 92, 58)
local WOOD_DARK = rgb(96, 62, 42)
local FABRIC = { rgb(170, 60, 90), rgb(60, 110, 170), rgb(80, 150, 100), rgb(150, 90, 180) }

type Place = (name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?) -> BasePart

local function placer(parent: Instance, room: House.Room): Place
	local side = if room.x < 0 then -1 else 1
	local floor = room.y - 0.5
	return function(name, size, offset, color, material)
		-- offset.X: distância a partir do centro rumo à fachada; offset.Y: altura da base; offset.Z: frente/trás.
		local center = Vector3.new(room.x + side * offset.X, floor + offset.Y + size.Y / 2, room.z + offset.Z)
		local part = Build.part(parent, name, size, CFrame.new(center), color, {
			material = material or Enum.Material.SmoothPlastic,
			collide = false,
			query = false,
		})
		part.CanTouch = false
		return part
	end
end

local function lampStand(put: Place, x: number, z: number, color: Color3)
	put("LampPole", Vector3.new(0.3, 5, 0.3), Vector3.new(x, 0, z), rgb(60, 50, 70), Enum.Material.Metal)
	local shade = put("LampShade", Vector3.new(1.8, 1.4, 1.8), Vector3.new(x, 5, z), color, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 0.6
	light.Parent = shade
end

local function sofa(put: Place, x: number, z: number, color: Color3)
	put("SofaSeat", Vector3.new(3, 1.4, 8), Vector3.new(x, 0, z), color, Enum.Material.Fabric)
	put("SofaBack", Vector3.new(1, 3, 8), Vector3.new(x + 1.5, 0, z), color, Enum.Material.Fabric)
	for _, dz in { -4.2, 4.2 } do
		put(
			"SofaArm",
			Vector3.new(3, 2.2, 0.8),
			Vector3.new(x, 0, z + dz),
			color:Lerp(rgb(0, 0, 0), 0.15),
			Enum.Material.Fabric
		)
	end
end

local function shelf(put: Place, x: number, z: number, length: number)
	put("Shelf", Vector3.new(1.4, 8, length), Vector3.new(x, 0, z), WOOD_DARK, Enum.Material.Wood)
	local rng = Random.new(math.floor(x * 31 + z * 7))
	for row = 0, 2 do
		local cursor = -length / 2 + 0.4
		while cursor < length / 2 - 0.6 do
			local width = rng:NextNumber(0.4, 0.8)
			local height = rng:NextNumber(1.3, 2)
			put(
				"Book",
				Vector3.new(1, height, width),
				Vector3.new(x - 0.3, 0.6 + row * 2.5, z + cursor + width / 2),
				FABRIC[rng:NextInteger(1, #FABRIC)],
				Enum.Material.SmoothPlastic
			)
			cursor += width + 0.05
		end
	end
end

local function crate(put: Place, x: number, z: number, size: number, y: number?)
	put("Crate", Vector3.new(size, size, size), Vector3.new(x, y or 0, z), rgb(160, 120, 70), Enum.Material.WoodPlanks)
end

local function candle(put: Place, x: number, z: number, y: number?)
	local base = y or 0
	put("Candle", Vector3.new(0.4, 1.2, 0.4), Vector3.new(x, base, z), rgb(250, 240, 220))
	local flame =
		put("Flame", Vector3.new(0.25, 0.4, 0.25), Vector3.new(x, base + 1.2, z), rgb(255, 180, 60), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 170, 80)
	light.Range = 8
	light.Brightness = 0.7
	light.Parent = flame
end

local function plant(put: Place, x: number, z: number)
	put("Pot", Vector3.new(1.6, 1.4, 1.6), Vector3.new(x, 0, z), rgb(190, 100, 70), Enum.Material.Brick)
	local leaves =
		put("Leaves", Vector3.new(2.6, 2.6, 2.6), Vector3.new(x, 1.2, z), rgb(70, 150, 80), Enum.Material.Grass)
	local shape = leaves :: Part
	shape.Shape = Enum.PartType.Ball
end

-- Cada conjunto ocupa a faixa junto à fachada (x 12..17) e a parede da frente (z 10..15),
-- deixando livres a porta (x -18..-12) e o armário (x 9..13, z 5..9).
local SETS: { [string]: (put: Place, color: Color3) -> () } = {
	Living = function(put, color)
		sofa(put, 15, -6, color)
		put("Fireplace", Vector3.new(2, 6, 7), Vector3.new(16.5, 0, 3), rgb(150, 70, 60), Enum.Material.Brick)
		local fire =
			put("Fire", Vector3.new(1, 1.6, 3.6), Vector3.new(15.8, 0.4, 3), rgb(255, 140, 40), Enum.Material.Neon)
		local light = Instance.new("PointLight")
		light.Color = rgb(255, 150, 70)
		light.Range = 18
		light.Brightness = 1
		light.Parent = fire
		lampStand(put, 15, -12, rgb(255, 220, 150))
		plant(put, -2, 14)
	end,
	Kitchen = function(put)
		put("Counter", Vector3.new(3, 3.4, 14), Vector3.new(15.5, 0, -4), rgb(230, 225, 240), Enum.Material.Marble)
		put("Stove", Vector3.new(3, 3.6, 4), Vector3.new(15.5, 0, 5), rgb(60, 60, 70), Enum.Material.Metal)
		put(
			"Fridge",
			Vector3.new(3, 7.5, 3.4),
			Vector3.new(15.5, 0, -13.5),
			rgb(200, 236, 230),
			Enum.Material.SmoothPlastic
		)
		put("Pot", Vector3.new(1.4, 1, 1.4), Vector3.new(15.5, 3.6, 5), rgb(180, 60, 50), Enum.Material.Metal)
		put("Fruit", Vector3.new(0.8, 0.8, 0.8), Vector3.new(15.2, 3.4, -6), rgb(255, 80, 60))
		put("Fruit", Vector3.new(0.8, 0.8, 0.8), Vector3.new(15.6, 3.4, -5), rgb(255, 210, 60))
	end,
	Dining = function(put, color)
		put("DiningTable", Vector3.new(5, 3, 12), Vector3.new(13, 0, -1), WOOD, Enum.Material.Wood)
		for _, dz in { -4, 0, 4 } do
			put("Chair", Vector3.new(1.6, 2, 1.6), Vector3.new(16.2, 0, -1 + dz), color, Enum.Material.Fabric)
			put("ChairBack", Vector3.new(0.4, 2.4, 1.6), Vector3.new(17, 2, -1 + dz), WOOD_DARK, Enum.Material.Wood)
		end
		candle(put, 13, -3, 3)
		candle(put, 13, 1, 3)
	end,
	Bath = function(put)
		put("Tub", Vector3.new(4, 2.4, 8), Vector3.new(15, 0, -6), rgb(240, 245, 255), Enum.Material.SmoothPlastic)
		put("Water", Vector3.new(3.2, 0.2, 7), Vector3.new(15, 2, -6), rgb(110, 200, 255), Enum.Material.Glass)
		put("Sink", Vector3.new(2.4, 3, 2.4), Vector3.new(16, 0, 5), rgb(240, 245, 255), Enum.Material.SmoothPlastic)
		put("Mirror", Vector3.new(0.2, 3, 2.4), Vector3.new(17.4, 4.5, 5), rgb(200, 230, 255), Enum.Material.Glass)
		put("Duck", Vector3.new(0.8, 0.8, 0.8), Vector3.new(14.8, 2.2, -8), rgb(255, 220, 40))
	end,
	Library = function(put)
		shelf(put, 16.5, -6, 12)
		shelf(put, 16.5, 4, 6)
		put("ReadingChair", Vector3.new(3, 2.6, 3), Vector3.new(13, 0, -14), rgb(120, 50, 70), Enum.Material.Fabric)
		lampStand(put, 16, 13, rgb(180, 220, 255))
	end,
	Machine = function(put)
		for index = 0, 2 do
			put(
				"Machine",
				Vector3.new(3, 5, 4),
				Vector3.new(15.5, 0, -10 + index * 6),
				rgb(90, 100, 120),
				Enum.Material.DiamondPlate
			)
			put(
				"Gauge",
				Vector3.new(0.3, 0.9, 0.9),
				Vector3.new(14, 3.4, -10 + index * 6),
				rgb(120, 255, 140),
				Enum.Material.Neon
			)
		end
		put("Pipe", Vector3.new(1, 1, 30), Vector3.new(16.8, 9, 0), rgb(150, 110, 80), Enum.Material.Metal)
	end,
	Bedroom = function(put, color)
		put("Wardrobe", Vector3.new(2.6, 8, 5), Vector3.new(16, 0, 13), WOOD, Enum.Material.Wood)
		put("Nightstand", Vector3.new(2, 2.4, 2), Vector3.new(16, 0, -14), WOOD_DARK, Enum.Material.Wood)
		lampStand(put, 16, -14, color)
	end,
	Child = function(put, color)
		for index = 0, 4 do
			put(
				"ToyBlock",
				Vector3.new(1.4, 1.4, 1.4),
				Vector3.new(14 + index % 2, math.floor(index / 2) * 1.4, -12 + index),
				FABRIC[(index % #FABRIC) + 1]
			)
		end
		local ballPart = put("ToyBall", Vector3.new(2, 2, 2), Vector3.new(4, 0, 13), rgb(255, 90, 90))
		local shape = ballPart :: Part
		shape.Shape = Enum.PartType.Ball
		put("TeddyBody", Vector3.new(1.8, 2, 1.4), Vector3.new(16, 0, 2), rgb(170, 110, 70), Enum.Material.Fabric)
		put("TeddyHead", Vector3.new(1.4, 1.4, 1.2), Vector3.new(16, 2, 2), rgb(180, 120, 80), Enum.Material.Fabric)
		put("Rocking", Vector3.new(3, 2.4, 1.2), Vector3.new(15, 0, 13), color, Enum.Material.Wood)
	end,
	Office = function(put)
		put("Desk", Vector3.new(4, 3, 9), Vector3.new(14.5, 0, -4), WOOD, Enum.Material.Wood)
		put("Paper", Vector3.new(1.4, 0.05, 1.8), Vector3.new(14, 3, -6), rgb(250, 246, 230))
		put("OfficeChair", Vector3.new(2.2, 2.2, 2.2), Vector3.new(11, 0, -4), rgb(50, 50, 60), Enum.Material.Fabric)
		lampStand(put, 16, 5, rgb(255, 230, 170))
		shelf(put, 16.5, 12, 5)
	end,
	Locked = function(put)
		for index = 0, 3 do
			crate(put, 15, -12 + index * 4, 2.6)
		end
		put("Chains", Vector3.new(0.4, 6, 0.4), Vector3.new(16, 3, 6), rgb(120, 120, 130), Enum.Material.Metal)
	end,
	Attic = function(put)
		crate(put, 15, -10, 3)
		crate(put, 15, -10, 2, 3)
		crate(put, 15.5, 12, 3)
		put("Trunk", Vector3.new(3, 2.4, 5), Vector3.new(15, 0, 0), rgb(110, 60, 50), Enum.Material.Wood)
	end,
	Basement = function(put)
		for index = 0, 2 do
			local barrel = put(
				"Barrel",
				Vector3.new(3.2, 3.2, 3.2),
				Vector3.new(15, 0, -12 + index * 4),
				rgb(120, 80, 50),
				Enum.Material.Wood
			)
			barrel.CFrame = barrel.CFrame * CFrame.Angles(0, 0, math.rad(90))
			local shape = barrel :: Part
			shape.Shape = Enum.PartType.Cylinder
		end
		crate(put, 15, 13, 3)
	end,
	Ritual = function(put)
		for index = 0, 7 do
			local angle = (index + 0.5) / 8 * math.pi * 2
			candle(put, 0 + math.cos(angle) * 8.5, math.sin(angle) * 8.5)
		end
	end,
}
SETS.AtticClock = SETS.Attic
SETS.AtticBook = SETS.Library
SETS.AtticPhoto = SETS.Attic
SETS.Symbols = SETS.Basement
SETS.Safe = SETS.Locked
SETS.Tunnel = SETS.Basement
SETS.Mechanism = SETS.Machine

function Furniture.build(parent: Instance)
	local folder = Build.folder(parent, "Furniture")
	for index, room in House.Rooms do
		local set = SETS[room.id]
		if set then
			set(placer(folder, room), FABRIC[(index % #FABRIC) + 1])
		end
	end
end

return Furniture
