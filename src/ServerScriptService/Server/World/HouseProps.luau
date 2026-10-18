--!strict
--[[
	Móveis e luminárias com modelos 3D (ReplicatedStorage.Assets.MansionProps, Poly Haven CC0,
	otimizados no Blender; fontes em docs/environment/ASSET_SOURCES.md).
	Só visual: MeshParts ancoradas, sem colisão, sem raycast, sem toque. As luzes ficam em peças
	invisíveis com Build.light, para o WorldFxController controlar sombra e visibilidade.
	Sem a biblioteca (place de Script Sync sem o .rbxm), nada é criado e o jogo segue igual.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Build = require("./Build")

local Props = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local UP = Vector3.yAxis
local WARM = rgb(255, 196, 132)

-- floor: centro da base; back: meio da aresta de trás da base (móvel encostado na parede);
-- wall: centro da face de trás; ceiling: centro do topo.
export type Anchor = "floor" | "back" | "wall" | "ceiling"

local function library(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("MansionProps")
end

--[[
	Coloca um modelo: `at` é o centro da base (floor), da face de trás (wall) ou do topo (ceiling);
	`facing` é para onde a frente do móvel olha. `scale` multiplica a escala da biblioteca.
]]
function Props.place(
	parent: Instance,
	name: string,
	at: Vector3,
	facing: Vector3,
	scale: number?,
	anchor: Anchor?
): Model?
	local source = library()
	local template = source and source:FindFirstChild(name)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	if scale and scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	model:PivotTo(CFrame.lookAt(Vector3.zero, facing.Unit))
	local box, size = model:GetBoundingBox()
	local look = box.LookVector
	-- Peças de parede ficam 0,1 stud à frente do revestimento (a tela fica no fundo da moldura).
	local reference = if anchor == "wall"
		then box.Position - look * (size.Z / 2 + 0.1)
		elseif anchor == "ceiling" then box.Position + UP * (size.Y / 2)
		elseif anchor == "back" then box.Position - look * (size.Z / 2 + 0.1) - UP * (size.Y / 2)
		else box.Position - UP * (size.Y / 2)
	model:PivotTo(model:GetPivot() + (at - reference))
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
	end
	model.Parent = parent
	return model
end

-- Topo do modelo (para apoiar objetos em cima).
local function top(model: Model?): number
	if not model then
		return 0
	end
	local box, size = model:GetBoundingBox()
	return box.Position.Y + size.Y / 2
end

-- Fonte de luz invisível; o modelo dá a forma, esta peça dá a luz.
local function glow(parent: Instance, name: string, at: Vector3, range: number, brightness: number, flicker: boolean?)
	local part = Build.part(parent, name, V3(0.3, 0.3, 0.3), CFrame.new(at), WARM, {
		transparency = 1,
		collide = false,
		query = false,
	})
	part.CanTouch = false
	Build.light(part, "Street", WARM, range, brightness, true, flicker)
	return part
end

local function hall(folder: Instance)
	local west, east, front = -Vector3.xAxis, -Vector3.xAxis, -Vector3.zAxis
	-- Lustre de velas sob o medalhão; patamares com versões menores.
	Props.place(folder, "Chandelier", V3(0, 14.85, 40), front, 1.05, "ceiling")
	glow(folder, "HallChandelier", V3(0, 12, 40), 34, 0.75, true)
	for _, y in { 16, 32 } do
		Props.place(folder, "Chandelier", V3(0, y + 14.85, 40), front, 0.75, "ceiling")
		glow(folder, "HallChandelier", V3(0, y + 12.6, 40), 26, 0.55, true)
	end
	-- Entrada: arandelas e, à direita, aparador com espelho e lamparina.
	for _, x in { -8.5, 8.5 } do
		Props.place(folder, "Sconce", V3(x, 7.2, 63.5), front, 2.2, "wall")
		glow(folder, "HallSconce", V3(x, 6.9, 62.6), 16, 0.45)
	end
	local console = Props.place(folder, "Console", V3(15, 0, 62.4), front, 1, "floor")
	Props.place(folder, "Mirror", V3(15, 6.9, 63.5), front, 1.45, "wall")
	Props.place(folder, "Lantern", V3(12.8, top(console), 62.4), front, 1.7, "floor")
	glow(folder, "Candle", V3(12.8, top(console) + 0.9, 62.2), 13, 0.55, true)
	Props.place(folder, "FrameOval", V3(-15, 7.4, 63.5), front, 2.1, "wall")
	-- Canto leste, atrás da escada: relógio parado às 03:12, sofá, criado-mudo, poltrona e quadros.
	Props.place(folder, "GrandfatherClock", V3(43.6, 0, 30), west, 1, "floor")
	Props.place(folder, "Sofa", V3(42.9, 0, 45.5), west, 1, "floor")
	local stand = Props.place(folder, "Nightstand", V3(43.5, 0, 51.6), west, 1, "floor")
	Props.place(folder, "Lantern", V3(43.5, top(stand), 51.6), west, 1.6, "floor")
	glow(folder, "HallLampShade", V3(43.3, top(stand) + 0.9, 51.6), 20, 0.6, true)
	Props.place(folder, "Armchair", V3(41.4, 0, 22.5), V3(-1, 0, 0.45), 1, "floor")
	Props.place(folder, "FrameRococo", V3(44.5, 7.6, 21), east, 1.55, "wall")
	Props.place(folder, "FrameLandscape", V3(44.5, 7.9, 45.5), east, 2.2, "wall")
	for _, z in { 26.5, 33.5 } do
		Props.place(folder, "Sconce", V3(44.5, 7.4, z), east, 2, "wall")
		glow(folder, "HallSconce", V3(43.7, 7.1, z), 18, 0.45)
	end
end

local FRAMES = { "FrameRococo", "FrameLandscape", "FrameOval" }

local function corridors(folder: Instance)
	-- Um quadro por cômodo, no trecho de parede sem a placa do cômodo.
	for _, y in { 0, 16, 32 } do
		for _, side in { -1, 1 } do
			for row = 1, 3 do
				local z = 28 - row * 32 - 10.5
				local name = FRAMES[(row + (if side > 0 then 1 else 0) + y // 16) % #FRAMES + 1]
				Props.place(folder, name, V3(side * 7.5, y + 7.2, z), V3(-side, 0, 0), 1.6, "wall")
			end
		end
	end
end

--[[
	Cômodos. Sistema local: `ox` cresce da porta (−18) para a fachada (+18); `oz` é o eixo Z do mundo.
	O centro (|ox| < 9) é das tarefas, (ox 9..13, oz 4..12) é do esconderijo: os móveis ficam nas paredes.
	Caixas antigas que colidem (estantes, camas) ficam como colisão invisível, com o modelo por cima.
]]
type RoomRef = { id: string, x: number, y: number, z: number }

local function inRoom(part: BasePart, room: RoomRef): boolean
	local p = part.Position
	return math.abs(p.X - room.x) < 18 and math.abs(p.Z - room.z) < 16 and p.Y > room.y - 1 and p.Y < room.y + 15
end

-- Esconde a peça antiga sem mexer em colisão, consulta ou luz (a luz continua na peça).
local function conceal(root: Instance, room: RoomRef, names: { [string]: boolean })
	for _, folderName in { "Furniture", "Furnishings", "Dressing" } do
		local folder = root:FindFirstChild(folderName)
		if folder then
			for _, part in folder:GetDescendants() do
				if part:IsA("BasePart") and names[part.Name] and inRoom(part, room) then
					part.Transparency, part.CastShadow = 1, false
					part:SetAttribute("VisualReplaced", true)
				end
			end
		end
	end
end

local function roomFrame(room: RoomRef)
	local side = if room.x < 0 then -1 else 1
	local function at(ox: number, oz: number, dy: number?): Vector3
		return V3(room.x + side * ox, room.y + (dy or 0), room.z + oz)
	end
	return at, V3(-side, 0, 0), side
end

local SHELF_BLOCKS = { Bookshelf = true }
local LIBRARY_PIECES = { Shelf = true, Book = true, ReadingChair = true, LampPole = true, LampShade = true }

local function has(name: string): boolean
	local source = library()
	return source ~= nil and source:FindFirstChild(name) ~= nil
end

local function bookshelves(folder: Instance, root: Instance, room: RoomRef)
	-- Estantes 3D sobre as caixas de colisão da parede do fundo (as caixas continuam lá).
	if not has("Bookshelf") then
		return
	end
	conceal(root, room, SHELF_BLOCKS)
	for _, dx in { -5, 0, 5, 10 } do
		Props.place(folder, "Bookshelf", V3(room.x + dx, room.y - 0.5, room.z - 15.5), Vector3.zAxis, 1, "back")
	end
end

local function lampOn(folder: Instance, at: Vector3, inward: Vector3)
	local stand = Props.place(folder, "Nightstand", at, inward, 1, "back")
	local light = at + inward * 0.9
	Props.place(folder, "Lantern", V3(light.X, top(stand), light.Z), inward, 1.6, "floor")
	glow(folder, "LampShade", V3(light.X, top(stand) + 0.9, light.Z), 16, 0.55, true)
end

local ROOMS: { [string]: (folder: Instance, root: Instance, room: RoomRef) -> () } = {}

ROOMS.Living = function(folder, root, room)
	local at, inward = roomFrame(room)
	conceal(root, room, {
		SofaSeat = true,
		SofaBack = true,
		SofaArm = true,
		LampPole = true,
		LampShade = true,
		Pot = true,
		Leaves = true,
	})
	Props.place(folder, "Sofa", at(17.5, -6, -0.5), inward, 1.25, "back")
	Props.place(folder, "Armchair", at(9.5, -12.5, -0.5), inward + V3(0, 0, 0.7), 1.05, "floor")
	lampOn(folder, at(17.5, -12.5, -0.5), inward)
	-- Relógio e castiçais sobre a lareira.
	Props.place(folder, "MantelClock", at(16.4, 3, 5.5), inward, 1.4, "floor")
	for _, oz in { 0.6, 5.4 } do
		Props.place(folder, "Candlestick", at(16.4, oz, 5.5), inward, 1.6, "floor")
	end
end

ROOMS.Dining = function(folder, root, room)
	local at, inward = roomFrame(room)
	if not has("RoundTable") then
		return
	end
	conceal(root, room, { DiningTable = true, Chair = true, ChairBack = true, Candle = true, Flame = true })
	local center = at(12.5, -1, -0.5)
	local dining = Props.place(folder, "RoundTable", center, inward, 1.2, "floor")
	for index = 0, 3 do
		local angle = index * math.pi / 2
		local offset = V3(math.cos(angle), 0, math.sin(angle)) * 4.6
		Props.place(folder, "GothicChair", center + offset, -offset, 0.85, "floor")
	end
	for _, oz in { -1.8, 0.8 } do
		Props.place(folder, "Candlestick", V3(center.X, top(dining), center.Z + oz), inward, 1.6, "floor")
	end
	glow(folder, "Candle", V3(center.X, top(dining) + 1.2, center.Z - 0.5), 18, 0.6, true)
	Props.place(folder, "Cabinet", at(0, -15.5, -0.5), Vector3.zAxis, 1, "back")
end

ROOMS.Library = function(folder, root, room)
	local at, inward = roomFrame(room)
	bookshelves(folder, root, room)
	if not has("Bookshelf") then
		return
	end
	conceal(root, room, LIBRARY_PIECES)
	for _, oz in { -9.6, -4.6, 0.4 } do
		Props.place(folder, "Bookshelf", at(17.5, oz, -0.5), inward, 1, "back")
	end
	Props.place(folder, "Armchair", at(12, -12.5, -0.5), inward + V3(0, 0, 0.6), 1.05, "floor")
	lampOn(folder, at(17.5, 13, -0.5), inward)
end

local function bedroom(folder: Instance, root: Instance, room: RoomRef, bed: string, scale: number)
	local at, inward = roomFrame(room)
	if not has(bed) then
		return
	end
	conceal(root, room, { Bed = true, Nightstand = true, LampPole = true, LampShade = true, Wardrobe = true })
	-- Armário no canto da fachada, sem invadir o esconderijo (ox 7..15, oz 4..10).
	Props.place(folder, "Cabinet", at(17.5, 12.4, -0.5), inward, 0.85, "back")
	-- Mesmo lugar da cama antiga (que continua como colisão invisível).
	Props.place(folder, bed, V3(room.x + 9, room.y - 0.5, room.z - 8), Vector3.zAxis, scale, "floor")
	lampOn(folder, at(17.5, -14, -0.5), inward)
end

ROOMS.Bedroom = function(folder, root, room)
	bedroom(folder, root, room, "GothicBed", 1.45)
end

ROOMS.Child = function(folder, root, room)
	bedroom(folder, root, room, "IronBed", 1.5)
end

ROOMS.Office = function(folder, root, room)
	local at, inward = roomFrame(room)
	if not has("GothicChair") then
		return
	end
	conceal(root, room, { Desk = true, Paper = true, OfficeChair = true, Shelf = true, Book = true })
	local desk = Props.place(folder, "Console", at(17.5, -4, -0.5), inward, 1.05, "back")
	Props.place(folder, "GothicChair", at(11.5, -4, -0.5), -inward, 0.85, "floor")
	Props.place(folder, "MantelClock", at(16.6, -6, top(desk) - room.y), inward, 1.3, "floor")
	Props.place(folder, "Candlestick", at(16.6, -1.5, top(desk) - room.y), inward, 1.6, "floor")
	Props.place(folder, "Bookshelf", at(17.5, 12.5, -0.5), inward, 1, "back")
end

ROOMS.Kitchen = function(folder, _root, room)
	local at = roomFrame(room)
	for _, ox in { -3, 3 } do
		Props.place(folder, "PaintedCabinet", at(ox, -15.5, -0.5), Vector3.zAxis, 1.2, "back")
	end
end

local function attic(folder: Instance, root: Instance, room: RoomRef)
	local at, inward = roomFrame(room)
	bookshelves(folder, root, room)
	Props.place(folder, "DayBed", at(17.5, -8, -0.5), inward, 1.05, "back")
	Props.place(folder, "PaintedCabinet", at(17.5, 13, -0.5), inward, 1.1, "back")
end

ROOMS.Attic = attic
ROOMS.AtticPhoto = attic
ROOMS.AtticClock = function(folder, root, room)
	local at, inward = roomFrame(room)
	bookshelves(folder, root, room)
	Props.place(folder, "GrandfatherClock", at(17.5, -6, -0.5), inward, 1, "back")
	Props.place(folder, "GrandfatherClock", at(17.5, -1, -0.5), inward, 0.9, "back")
	Props.place(folder, "MantelClock", at(17, 13, 0), inward, 1.4, "floor")
end
ROOMS.AtticBook = function(folder, root, room)
	ROOMS.Library(folder, root, room)
end

-- Luz noturna: a esfera neon vira uma lamparina pendurada (a luz continua na peça antiga).
local function nightLights(folder: Instance, root: Instance)
	local dressing = root:FindFirstChild("Dressing")
	if not dressing then
		return
	end
	for _, orb in dressing:GetChildren() do
		if orb:IsA("BasePart") and orb.Name == "NightLight" then
			if Props.place(folder, "Lantern", orb.Position + UP * 1.2, -Vector3.zAxis, 1.9, "ceiling") then
				orb.Transparency = 1
				orb:SetAttribute("VisualReplaced", true)
				-- A esfera neon iluminava o cômodo pelo brilho; a lamparina ganha luz própria.
				glow(folder, "HallChandelier", orb.Position - UP * 0.4, 26, 0.5, true)
			end
		elseif orb:IsA("BasePart") and orb.Name == "PictureFrame" then
			-- Quadro liso da parede da fachada vira moldura 3D no mesmo lugar.
			local inward = Vector3.new(-math.sign(orb.Position.X), 0, 0)
			local name = FRAMES[math.floor(math.abs(orb.Position.Z)) % #FRAMES + 1]
			local wall = orb.Position - inward * (orb.Size.X / 2)
			if Props.place(folder, name, wall, inward, 1.7, "wall") then
				orb.Transparency = 1
				for _, sibling in dressing:GetChildren() do
					if sibling:IsA("BasePart") and sibling.Name == "Picture" and sibling.Position == orb.Position then
						sibling.Transparency = 1
					end
				end
			end
		end
	end
end

function Props.build(root: Instance)
	local old = root:FindFirstChild("Props")
	if old then
		old:Destroy()
	end
	if not library() then
		return
	end
	local folder = Build.folder(root, "Props")
	hall(folder)
	corridors(folder)
	for _, room in House.Rooms do
		local dress = ROOMS[room.id]
		if dress then
			dress(folder, root, room)
		end
	end
	nightLights(folder, root)
end

return Props
