--!strict
--[[
	Móveis e luminárias com modelos 3D (ReplicatedStorage.Assets.MansionProps, Poly Haven CC0,
	otimizados no Blender; fontes em docs/environment/ASSET_SOURCES.md).
	Malhas visuais ancoradas, sem colisão, sem raycast, sem toque; móveis sólidos usam uma caixa simples.
	As luzes ficam em peças
	invisíveis com Build.light, para o WorldFxController controlar sombra e visibilidade.
	Sem a biblioteca (place de Script Sync sem o .rbxm), nada é criado e o jogo segue igual.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
local Build = require("./Build")
local HouseArt = require("./HouseArt")
local PrimitiveFinish = require("./HousePrimitiveFinish")

local Props = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local UP = Vector3.yAxis
local WARM = rgb(255, 196, 132)
-- Os modelos vêm a 3,6 studs/m; o personagem tem ~5,2 studs (~3 studs/m). 0,85 põe os móveis na escala dele.
local FURNITURE = 0.85
-- Peças que cobrem colisões antigas (cama, mesa baixa, guarda-roupa do esconderijo) e tapetes mantêm o tamanho
-- de antes (fator 1,25), senão a parede invisível antiga aparece para fora do modelo.
local KEEP = 1.25 / FURNITURE
-- O sofá (Sofa 03) é baixo: na escala real o assento ficava abaixo do joelho do boneco. 35% maior (aprovado 19/10).
local SOFA = 1.35

-- Só mobília decorativa. Camas, mesa baixa e esconderijos conservam os volumes funcionais antigos.
-- Mesma lista que o evento NoiseLure procura em Props (DynamicHouseService).
local LURE_MOVABLE: { [string]: boolean } = { Console = true, Nightstand = true, Armchair = true, Desk = true }
local SOLID: { [string]: boolean } = {
	Sofa = true,
	Armchair = true,
	GothicChair = true,
	RockingChair = true,
	RoundTable = true,
	Bookshelf = true,
	Cabinet = true,
	PaintedCabinet = true,
	Console = true,
	KitchenCounter = true,
	WoodStove = true,
	Icebox = true,
	Bathtub = true,
	PedestalSink = true,
	Fireplace = true,
	GrandfatherClock = true,
	Boiler = true,
	Crate = true,
	Barrel = true,
	TreasureChest = true,
	SeaChest = true,
	DayBed = true,
	Nightstand = true,
}

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
	-- Escala da mobília em relação ao personagem; peças presas à parede/teto mantêm a escala própria.
	local factor = (scale or 1) * (if anchor == "floor" or anchor == "back" or anchor == nil then FURNITURE else 1)
	if factor ~= 1 then
		model:ScaleTo(model:GetScale() * factor)
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
	if SOLID[name] then
		local frame, bounds = model:GetBoundingBox()
		-- Móveis que o evento NoiseLure (DynamicHouseService) pode arrastar só são escolhidos se o MODELO não tiver
		-- peça sólida. A caixa deles fica numa pasta irmã, parada no lugar: o visual desliza e volta, ninguém é empurrado.
		local holder: Instance = model
		if LURE_MOVABLE[name] then
			local existing = parent:FindFirstChild("FurnitureColliders")
			holder = existing or Build.folder(parent, "FurnitureColliders")
		end
		-- Recuo de 0,1 stud nas laterais: a caixa não ultrapassa o acabamento visível.
		local collider = Build.part(
			holder,
			"FurnitureCollider",
			V3(math.max(0.2, bounds.X - 0.2), bounds.Y, math.max(0.2, bounds.Z - 0.2)),
			frame,
			rgb(0, 0, 0),
			{ transparency = 1, collide = true, query = true }
		)
		-- CanQuery=false não exclui peças sólidas das consultas do engine. A caixa acompanha o móvel real;
		-- os testes verificam que não intercepta os pontos de missão, entradas e saídas dos esconderijos.
		collider.CanTouch, collider.CastShadow = false, false
		collider:SetAttribute("VisualFurnitureCollider", true)
		if holder ~= model then
			local link = Instance.new("ObjectValue")
			link.Name, link.Value, link.Parent = "Furniture", model, collider
			model.Destroying:Once(function()
				collider:Destroy()
			end)
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
	Props.place(folder, "Sofa", V3(44.4, 0, 44.5), west, SOFA, "back")
	local stand = Props.place(folder, "Nightstand", V3(44.4, 0, 52.5), west, 1, "back")
	Props.place(folder, "Lantern", V3(42.8, top(stand), 52.5), west, 1.3, "floor")
	glow(folder, "HallLampShade", V3(42.8, top(stand) + 1, 52.5), 20, 0.6, true)
	Props.place(folder, "Armchair", V3(40.6, 0, 22.5), V3(-1, 0, 0.45), 1, "floor")
	Props.place(folder, "PersianRug", V3(36, 0.02, 45), west, 0.75 * KEEP, "floor")
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

--[[
	Planta de cada cômodo (sistema local: `ox` da porta −18 à fachada +18, `oz` = eixo Z do mundo).
	Zonas que ficam livres:
	- porta (ox < −10, |oz| < 6) e tarefas no centro (|ox| < 8, oz −6..9);
	- guarda-roupa do esconderijo no canto da fachada (ox 13,5..17,5; oz 10..15) e a frente dele (ox 8..13,5; oz 9..15);
	- meio das divisórias que a campanha pode abrir (|ox| < 13 junto de oz ±16; só onde a parede é divisória).
	Os móveis vão para a parede da fachada (faixa ox 14..17.5), para os trechos da parede da porta,
	para a parede da frente (fileira 1, abaixo da janela do hall) e para a parede do fundo (fileira 3).
]]
type Wall = "facade" | "door" | "front" | "rear"

local function has(name: string): boolean
	local source = library()
	return source ~= nil and source:FindFirstChild(name) ~= nil
end

-- Móvel encostado numa parede: `along` é a posição ao longo da parede (oz na fachada/porta, ox na frente/fundo).
local function against(folder: Instance, room: RoomRef, name: string, wall: Wall, along: number, scale: number?): Model?
	local side = if room.x < 0 then -1 else 1
	local inward = V3(-side, 0, 0)
	local at: Vector3, facing: Vector3
	if wall == "facade" then
		at, facing = V3(room.x + side * 17.5, room.y, room.z + along), inward
	elseif wall == "door" then
		at, facing = V3(room.x - side * 17.5, room.y, room.z + along), -inward
	elseif wall == "front" then
		at, facing = V3(room.x + side * along, room.y, room.z + 15.5), -Vector3.zAxis
	else
		at, facing = V3(room.x + side * along, room.y, room.z - 15.5), Vector3.zAxis
	end
	return Props.place(folder, name, at, facing, scale, "back")
end

local function lampOn(folder: Instance, room: RoomRef, wall: Wall, along: number)
	local stand = against(folder, room, "Nightstand", wall, along, 1)
	if not stand then
		return
	end
	local box = stand:GetBoundingBox()
	local spot = V3(box.Position.X, top(stand), box.Position.Z)
	Props.place(folder, "Lantern", spot, box.LookVector, 1.4, "floor")
	glow(folder, "LampShade", spot + UP, 18, 0.55, true)
end

-- Janela com cortinas na fachada, no vão real da parede (HouseLayout.facadeWindows), alinhada com a janela de fora.
-- Cômodos com móveis altos nessa parede (estantes, caldeiras, bancada) ficam sem janela (Layout.NoWindow).
local function window(folder: Instance, room: RoomRef)
	if room.y < 0 or Layout.NoWindow[room.id] then
		return
	end
	local side = if room.x < 0 then -1 else 1
	local model = Props.place(
		folder,
		"WindowSet",
		V3(room.x + side * 17.5, room.y + 7.2, room.z + Layout.Window.oz),
		V3(-side, 0, 0),
		1,
		"wall"
	)
	-- Vidro quase transparente: o jardim escuro (e o que passar lá fora) aparece pela janela.
	local glass = model and model:FindFirstChild("Glass", true)
	if glass and glass:IsA("BasePart") then
		glass.Transparency = 0.8
	end
end

local ROOMS: { [string]: (folder: Instance, root: Instance, room: RoomRef) -> () } = {}

ROOMS.Living = function(folder, root, room)
	local at = roomFrame(room)
	conceal(root, room, {
		SofaSeat = true,
		SofaBack = true,
		SofaArm = true,
		LampPole = true,
		LampShade = true,
		Pot = true,
		Leaves = true,
		Fireplace = true,
		Fire = true,
	})
	-- Lareira na parede interna (a do corredor), longe do guarda-roupa da fachada; sofá na fachada
	-- de frente para o fogo e poltronas viradas para a lareira (a luz do fogo antigo continua acesa).
	local fireplace = against(folder, room, "Fireplace", "door", 10.3, 1.05)
	glow(folder, "Fire", at(-16, 10.3, 1.2), 24, 1, true)
	if fireplace then
		local box, size = fireplace:GetBoundingBox()
		local mantel = V3(box.Position.X, top(fireplace), box.Position.Z)
		Props.place(folder, "MantelClock", mantel, box.LookVector, 1.1, "floor")
		local spread = math.min(3, size.X * 0.33)
		for _, dz in { -spread, spread } do
			Props.place(folder, "Candelabra", mantel + V3(0, 0, dz), box.LookVector, 0.55, "floor")
		end
	end
	against(folder, room, "Sofa", "facade", -1.5, 1.05 * SOFA)
	-- A cadeira de balanço da Dona Cida (roteiro "A Casa de Madeira"), com o novelo de tricô pendurado no braço: é a
	-- pista que liga o fusível enrolado em tricô (cap. 2) ao encaixe da CADEIRA no quadro de luz.
	local chairAt = at(-8.6, 10.5, 0)
	-- Modelo do artista (CidaRockingChair_v2, ou a primeira versão) quando existe no place; senão, a cadeira de
	-- balanço da biblioteca de props.
	local chairPivot = CFrame.lookAt(chairAt, chairAt + V3(-1, 0, -0.15))
	if
		not HouseArt.place(folder, "CidaRockingChair_v2", chairPivot)
		and not HouseArt.place(folder, "CidaRockingChair", chairPivot)
	then
		Props.place(folder, "RockingChair", chairAt, V3(-1, 0, -0.15), 1.05, "floor")
	end
	local yarn = Build.part(
		folder,
		"KnittingYarn",
		V3(0.9, 0.9, 0.9),
		CFrame.new(at(-8.6, 10.5, 0) + V3(0.9, 2.1, 0.9)),
		rgb(176, 44, 52),
		{ material = Enum.Material.Fabric, collide = false, query = false }
	);
	(yarn :: Part).Shape = Enum.PartType.Ball
	Build.part(
		folder,
		"KnittingNeedle",
		V3(0.08, 0.08, 1.4),
		CFrame.new(at(-8.6, 10.5, 0) + V3(0.9, 2.3, 0.9)) * CFrame.Angles(math.rad(30), 0, math.rad(20)),
		rgb(200, 190, 170),
		{ material = Enum.Material.Wood, collide = false, query = false }
	)
	Props.place(folder, "Armchair", at(10.5, -11.5, 0), V3(-1, 0, 0.6), 1.05, "floor")
	lampOn(folder, room, "facade", -14.3)
	-- A estante da fachada (12,6) saiu: o guarda-roupa do esconderijo ocupa esse canto.
	local console = against(folder, room, "Console", "front", 0, 0.95)
	if console then
		local box = console:GetBoundingBox()
		Props.place(
			folder,
			"BrassCandle",
			V3(box.Position.X - 1.5, top(console), box.Position.Z),
			box.LookVector,
			1.2,
			"floor"
		)
	end
end

ROOMS.Kitchen = function(folder, root, room)
	local at = roomFrame(room)
	conceal(root, room, { Counter = true, Stove = true, Fridge = true, Pot = true, Fruit = true })
	-- Bancada contínua na fachada e fogão de ferro no fim; geladeira-baú e mesa junto da porta.
	-- Fogão no canto e bancada até a beira do esconderijo (o guarda-roupa fica em oz 5..9).
	for index = 0, 2 do
		against(folder, room, "KitchenCounter", "facade", -5.8 + index * 3.6 * FURNITURE, 1)
	end
	local stove = against(folder, room, "WoodStove", "facade", -11.8, 0.85)
	if stove then
		local box = stove:GetBoundingBox()
		Props.place(folder, "EnamelPot", V3(box.Position.X, top(stove), box.Position.Z), box.LookVector, 1.4, "floor")
	end
	against(folder, room, "Icebox", "door", -11, 0.95)
	local center = at(-11.5, 11.5, 0)
	Props.place(folder, "RoundTable", center, V3(1, 0, 0), 0.95, "floor")
	Props.place(folder, "GothicChair", center + V3(0, 0, -3.1), V3(0, 0, 1), 0.6, "floor")
	Props.place(folder, "GothicChair", center + V3(0, 0, 3.1), V3(0, 0, -1), 0.6, "floor")
	for _, ox in { -6, 0, 6 } do
		against(folder, room, "PaintedCabinet", "front", ox, 0.9)
	end
end

ROOMS.Dining = function(folder, root, room)
	local at = roomFrame(room)
	conceal(root, room, { DiningTable = true, Chair = true, ChairBack = true, Candle = true, Flame = true })
	-- Mesa com quatro cadeiras na metade da fachada, longe das passagens e do esconderijo.
	local center = at(12, -6, 0)
	local dining = Props.place(folder, "RoundTable", center, V3(1, 0, 0), 1, "floor")
	for _, offset in { V3(0, 0, -3.3), V3(0, 0, 3.3), V3(3.3, 0, 0), V3(-3.3, 0, 0) } do
		local spot = center + offset
		if math.abs(spot.X - room.x) < 17 then
			Props.place(folder, "GothicChair", spot, -offset, 0.6, "floor")
		end
	end
	if dining then
		Props.place(folder, "Candelabra", V3(center.X, top(dining), center.Z), V3(1, 0, 0), 0.75, "floor")
	end
	glow(folder, "Candle", center + V3(0, 6, 0), 26, 0.9, true)
	against(folder, room, "Console", "door", 11, 1)
end

ROOMS.Bath = function(folder, root, room)
	local at = roomFrame(room)
	conceal(root, room, { Tub = true, Water = true, Sink = true, Mirror = true, Duck = true })
	local tub = against(folder, room, "Bathtub", "facade", -9.5, 1)
	if tub then
		local box, size = tub:GetBoundingBox()
		Props.place(folder, "RubberDuck", box.Position + V3(0, size.Y / 2 - 0.2, 2), box.LookVector, 1.3, "floor")
	end
	against(folder, room, "PedestalSink", "door", 11, 0.85)
	local side = if room.x < 0 then -1 else 1
	Props.place(folder, "Mirror", V3(room.x - side * 17.5, room.y + 7.5, room.z + 11), V3(side, 0, 0), 1.6, "wall")
	against(folder, room, "PaintedCabinet", "door", -11, 0.8)
	Props.place(folder, "WoodenLantern", at(16.3, 2, 0), V3(-side, 0, 0), 1.3, "floor")
end

local SHELF_BLOCKS = { Bookshelf = true }
local LIBRARY_PIECES = { Shelf = true, Book = true, ReadingChair = true, LampPole = true, LampShade = true }

local function rearShelves(folder: Instance, root: Instance, room: RoomRef)
	-- Estantes por cima das caixas de colisão do fundo (as caixas continuam lá).
	conceal(root, room, SHELF_BLOCKS)
	-- Uma estante embutida contínua (módulos encostados, sem vão), não quatro soltas lado a lado.
	for _, ox in { -8.4, -4.2, 0, 4.2, 8.4 } do
		against(folder, room, "Bookshelf", "rear", ox, 1)
	end
end

ROOMS.Library = function(folder, root, room)
	if not has("Bookshelf") then
		return
	end
	rearShelves(folder, root, room)
	conceal(root, room, LIBRARY_PIECES)
	-- Fachada: um par de módulos encostados e um canto de leitura (poltrona e candelabro), não mais estantes.
	for _, oz in { -12.1, -7.9 } do
		against(folder, room, "Bookshelf", "facade", oz, 1)
	end
	local reading = roomFrame(room)
	Props.place(folder, "Armchair", reading(13.4, -1.5, 0), V3(-1, 0, 0.35), 1.05, "floor")
	Props.place(folder, "Candelabra", reading(15.8, 1.6, 0), V3(-1, 0, 0), 1.1, "floor")
	glow(folder, "Candle", reading(15.8, 1.6, 4), 14, 0.5, true)
	-- A poltrona do canto (14,5; 13) saiu: o guarda-roupa do esconderijo ocupa esse canto.
	lampOn(folder, room, "facade", 6)
	local console = against(folder, room, "Console", "door", 11, 1)
	if console then
		local box = console:GetBoundingBox()
		Props.place(
			folder,
			"Candelabra",
			V3(box.Position.X, top(console), box.Position.Z),
			box.LookVector,
			0.6,
			"floor"
		)
	end
end

local function bedroom(folder: Instance, root: Instance, room: RoomRef, bed: string, scale: number)
	if not has(bed) then
		return
	end
	conceal(root, room, { Bed = true, Nightstand = true, LampPole = true, LampShade = true, Wardrobe = true })
	-- Cama no lugar da cama antiga (a colisão antiga continua), cabeceira para a divisória.
	local side = if room.x < 0 then -1 else 1
	Props.place(folder, bed, V3(room.x + 9, room.y, room.z - 8), Vector3.zAxis, scale * KEEP, "floor")
	lampOn(folder, room, "door", -14)
	local dresser = against(folder, room, "Console", "door", 11, 0.95)
	Props.place(folder, "Mirror", V3(room.x - side * 17.5, room.y + 7.6, room.z + 11), V3(side, 0, 0), 1.5, "wall")
	if dresser then
		local box = dresser:GetBoundingBox()
		Props.place(
			folder,
			"BrassCandle",
			V3(box.Position.X, top(dresser), box.Position.Z + 1.5),
			box.LookVector,
			1.2,
			"floor"
		)
	end
end

ROOMS.Bedroom = function(folder, root, room)
	bedroom(folder, root, room, "GothicBed", 1.15)
	against(folder, room, "TreasureChest", "facade", -2, 0.9)
end

ROOMS.Child = function(folder, root, room)
	bedroom(folder, root, room, "IronBed", 1.2)
	conceal(root, room, { ToyBlock = true, ToyBall = true, TeddyBody = true, TeddyHead = true, Rocking = true })
	local at = roomFrame(room)
	Props.place(folder, "RockingChair", at(14, -2, 0), V3(-1, 0, 0.4), 1.05, "floor")
	against(folder, room, "SeaChest", "facade", 3.5, 0.9)
	Props.place(folder, "RubberDuck", at(-13, 5.5, 0), V3(1, 0, 0.3), 1.6, "floor")
	Props.place(folder, "Suitcase", at(15.6, -14.2, 0), V3(-1, 0, 0), 1, "floor")
end

ROOMS.Office = function(folder, root, room)
	if not has("GothicChair") then
		return
	end
	conceal(root, room, { Desk = true, Paper = true, OfficeChair = true, Shelf = true, Book = true })
	local at = roomFrame(room)
	local desk = against(folder, room, "Console", "facade", -2, 1.05)
	Props.place(folder, "GothicChair", at(14.2, -2, 0), V3(1, 0, 0), 0.6, "floor")
	if desk then
		local box = desk:GetBoundingBox()
		Props.place(
			folder,
			"MantelClock",
			V3(box.Position.X, top(desk), box.Position.Z - 2),
			box.LookVector,
			1.1,
			"floor"
		)
		Props.place(folder, "PipeLamp", V3(box.Position.X, top(desk), box.Position.Z + 2), box.LookVector, 1.3, "floor")
		glow(folder, "LampShade", V3(box.Position.X, top(desk) + 1.6, box.Position.Z + 2), 16, 0.55)
	end
	against(folder, room, "Bookshelf", "door", -11, 1)
	against(folder, room, "Bookshelf", "door", 11, 1)
	lampOn(folder, room, "facade", 7.5)
end

local STORAGE = { Crate = true, Trunk = true, Barrel = true, Chains = true }

-- Depósitos (sala trancada, sótãos, porão): baús e caixas nas paredes, nada no centro.
local function storage(folder: Instance, root: Instance, room: RoomRef, basement: boolean)
	conceal(root, room, STORAGE)
	local at = roomFrame(room)
	against(folder, room, "TreasureChest", "facade", -12.5, 1)
	against(folder, room, if basement then "Barrel" else "SeaChest", "facade", -7.5, 1)
	local lowerCrate = against(folder, room, "Crate", "facade", -1.5, 1)
	if lowerCrate then
		local box = lowerCrate:GetBoundingBox()
		Props.place(folder, "Crate", V3(box.Position.X, top(lowerCrate), box.Position.Z), box.LookVector, 0.9, "floor")
	end
	against(folder, room, if basement then "Barrel" else "Suitcase", "door", -11, 1)
	against(folder, room, "Crate", "door", 11, 1)
	Props.place(folder, if basement then "Barrel" else "Suitcase", at(-15.5, 13.5, 0), V3(1, 0, 0.5), 1, "floor")
	local lantern = at(15.6, 7.5, 0)
	Props.place(folder, "WoodenLantern", lantern, V3(-1, 0, 0), 1.3, "floor")
	glow(folder, "Candle", lantern + V3(0, 1.5, 0), 18, 0.55, true)
	if basement then
		Props.place(folder, "BrokenBarrel", at(13.5, -11, 0), V3(-1, 0, 0.3), 0.6, "floor")
	end
end

ROOMS.Locked = function(folder, root, room)
	storage(folder, root, room, false)
end

local function attic(folder: Instance, root: Instance, room: RoomRef)
	storage(folder, root, room, false)
	local at = roomFrame(room)
	Props.place(folder, "RockingChair", at(-13, 11, 0), V3(1, 0, -0.5), 1.05, "floor")
	against(folder, room, "DayBed", "door", -11.5, 0.85)
end

ROOMS.Attic = attic
ROOMS.AtticPhoto = attic
ROOMS.AtticClock = function(folder, root, room)
	storage(folder, root, room, false)
	against(folder, room, "GrandfatherClock", "door", -13, 1)
	against(folder, room, "GrandfatherClock", "door", -8.5, 0.9)
	against(folder, room, "GrandfatherClock", "door", 9, 0.95)
end
ROOMS.AtticBook = function(folder, root, room)
	ROOMS.Library(folder, root, room)
end

ROOMS.Basement = function(folder, root, room)
	storage(folder, root, room, true)
end
ROOMS.Symbols = ROOMS.Basement
ROOMS.Safe = ROOMS.Basement
ROOMS.Tunnel = ROOMS.Basement

local function machinery(folder: Instance, root: Instance, room: RoomRef)
	conceal(root, room, { Machine = true, Gauge = true, Pipe = true })
	local at = roomFrame(room)
	against(folder, room, "Boiler", "facade", -9.5, 1.15)
	against(folder, room, "Boiler", "facade", -0.3, 1.1)
	for _, ox in { -8, 0, 8 } do
		against(folder, room, "PipeRun", "rear", ox, 1.1)
	end
	against(folder, room, "Crate", "door", -11, 1)
	local crate = against(folder, room, "Crate", "door", 11, 1)
	if crate then
		local box = crate:GetBoundingBox()
		Props.place(folder, "PipeLamp", V3(box.Position.X, top(crate), box.Position.Z), box.LookVector, 1.4, "floor")
		glow(folder, "LampShade", V3(box.Position.X, top(crate) + 1.6, box.Position.Z), 18, 0.6, true)
	end
	Props.place(folder, "Barrel", at(15.5, 7.5, 0), V3(-1, 0, 0), 1, "floor")
end

ROOMS.Machine = machinery
ROOMS.Mechanism = machinery

ROOMS.Ritual = function(folder, root, room)
	conceal(root, room, { Candle = true, Flame = true })
	-- Velas de latão no círculo e candelabros nos cantos (as luzes antigas continuam acesas).
	for index = 0, 7 do
		local angle = (index + 0.5) / 8 * math.pi * 2
		Props.place(
			folder,
			"BrassCandle",
			V3(room.x + math.cos(angle) * 8.5, room.y, room.z + math.sin(angle) * 8.5),
			V3(0, 0, 1),
			1.2,
			"floor"
		)
	end
	local at = roomFrame(room)
	-- O canto da frente (oz 13,5) é do guarda-roupa do esconderijo: o segundo candelabro fica em oz 7,5.
	for _, oz in { -13.5, 7.5 } do
		Props.place(folder, "Candelabra", at(15.8, oz, 0), V3(-1, 0, 0), 1.1, "floor")
		glow(folder, "Candle", at(15.8, oz, 4), 16, 0.6, true)
	end
	for _, ox in { -9.6, 9.6 } do
		against(folder, room, "Bookshelf", "rear", ox, 1)
	end
end

-- Em todos os cômodos: tapete persa no centro, mesa baixa no lugar da mesa antiga, janela na fachada
-- e guarda-roupa por cima do armário-esconderijo (a porta interativa continua a mesma, invisível).
--[[
	Guarda-roupa do esconderijo: modelo de duas portas (Hyper3D, escolhido pelo usuário em 19/10). O pivô é o centro
	da frente, no chão, com a frente em +Z; fica no plano da frente da HideDoor (a fresta da câmera continua livre).
	As folhas LeafA (dobradiça em -HingeX) e LeafB (+HingeX) abrem para fora, cada uma para um lado, no mesmo
	ângulo da HideDoor que o WorldService.swingLocker gira. O interior oco é parte do corpo.
	Sem o modelo na biblioteca, cai no guarda-roupa antigo de uma folha abaixo.
]]
local function wardrobeModel(folder: Instance, door: BasePart): boolean
	local source = library()
	local template = source and source:FindFirstChild("WardrobeDouble")
	if not template or not template:IsA("Model") or not template:GetAttribute("PivotIsFrontFloor") then
		return false
	end
	local hingeX = template:GetAttribute("HingeX")
	-- Dobradiça na quina externa da FRENTE da folha (atrás do pivô): girando ali a folha não se desloca.
	local hingeZ = template:GetAttribute("HingeZ")
	local leafA = template:FindFirstChild("LeafA")
	local leafB = template:FindFirstChild("LeafB")
	if
		type(hingeX) ~= "number"
		or type(hingeZ) ~= "number"
		or not leafA
		or not leafB
		or not leafA:IsA("BasePart")
		or not leafB:IsA("BasePart")
	then
		return false
	end
	local model = template:Clone()
	local closed = door.CFrame
	local pivot = closed * CFrame.new(0, -door.Size.Y / 2, door.Size.Z / 2)
	model:PivotTo(pivot)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		end
	end
	model.Parent = folder
	local leaves: { { part: BasePart, hinge: CFrame, rest: CFrame, sign: number } } = {}
	local function hang(name: string, side: number)
		local part = model:FindFirstChild(name) :: BasePart
		local hinge = pivot * CFrame.new(side * hingeX, 0, hingeZ)
		table.insert(leaves, { part = part, hinge = hinge, rest = hinge:Inverse() * part.CFrame, sign = side })
	end
	hang("LeafA", -1)
	hang("LeafB", 1)
	-- O swingLocker gira a HideDoor em passos (12 por segundo); as folhas seguem o ângulo dela com uma interpolação
	-- curta, sempre em arco em torno da dobradiça.
	local angle = Instance.new("NumberValue")
	angle.Name = "LeafAngle"
	angle.Parent = model
	angle.Changed:Connect(function(value: number)
		for _, leaf in leaves do
			leaf.part.CFrame = leaf.hinge * CFrame.Angles(0, leaf.sign * value, 0) * leaf.rest
		end
	end)
	-- Som próprio: trinco abrindo e rangido ao abrir; batida de madeira e trinco ao fechar. Os arquivos são longos
	-- (vários golpes): cada som toca só um trecho (medido pela PlaybackLoudness no Studio).
	local body = model:FindFirstChild("Body") or model
	local function cut(name: string, id: string, volume: number, speed: number, from: number, to: number): Sound
		local sound = Build.sound(body, name, id, volume, speed)
		sound.PlaybackRegionsEnabled, sound.PlaybackRegion = true, NumberRange.new(from, to)
		return sound
	end
	local unlatch = cut("WardrobeUnlatch", Audio.DoorLatch.id, 0.5, 1.2, 1.45, 2.1)
	local creak = cut("WardrobeOpen", Audio.CreakWood.id, 1, 0.9, 2.8, 3.9)
	local shut = cut("WardrobeShut", Audio.StepWood.id, 0.9, 0.8, 0, 0.3)
	local latch = cut("WardrobeLatch", Audio.DoorLatch.id, 0.55, 1.2, 2.85, 3.45)
	local follow = TweenInfo.new(1 / 12, Enum.EasingStyle.Linear)
	local target = 0
	local swing = door:GetPropertyChangedSignal("CFrame"):Connect(function()
		local _, yaw = (closed.Rotation:Inverse() * door.CFrame.Rotation):ToEulerAnglesYXZ()
		local nextTarget = math.abs(yaw)
		if target < 0.01 and nextTarget >= 0.01 then
			unlatch:Play()
			creak:Play()
		elseif target >= 0.01 and nextTarget < 0.01 then
			shut:Play()
			latch:Play()
		end
		target = nextTarget
		TweenService:Create(angle, follow, { Value = nextTarget }):Play()
	end)
	model.Destroying:Once(function()
		swing:Disconnect()
	end)
	door.Destroying:Once(function()
		model:Destroy()
	end)
	return true
end

local function wardrobeDoor(folder: Instance, door: BasePart)
	local frontZ = door.Size.Z / 2
	local function piece(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): BasePart
		local part = Build.part(folder, name, size, door.CFrame * CFrame.new(offset), color, {
			material = material,
			collide = false,
			query = false,
		})
		part.CanTouch = false
		return part
	end
	piece(
		"WardrobeInterior",
		V3(door.Size.X - 0.1, door.Size.Y - 0.1, 0.02),
		V3(0, 0, frontZ + 0.02),
		rgb(16, 12, 10),
		Enum.Material.SmoothPlastic
	)
	local leaf = piece(
		"WardrobeLeaf",
		V3(door.Size.X, door.Size.Y, 0.06),
		V3(0, 0, frontZ + 0.09),
		rgb(200, 196, 192),
		Enum.Material.Wood
	)
	leaf.MaterialVariant = "MansionDarkWood"
	local parts = { leaf }
	-- Duas almofadas rebaixadas e a maçaneta de latão.
	for _, y in { -door.Size.Y * 0.22, door.Size.Y * 0.22 } do
		local inset = piece(
			"WardrobeLeafPanel",
			V3(door.Size.X * 0.7, door.Size.Y * 0.36, 0.03),
			V3(0, y, frontZ + 0.135),
			rgb(150, 140, 132),
			Enum.Material.Wood
		)
		inset.MaterialVariant = "MansionDarkWood"
		table.insert(parts, inset)
	end
	local knob = piece(
		"WardrobeKnob",
		V3(0.22, 0.22, 0.18),
		V3(door.Size.X * 0.36, 0, frontZ + 0.21),
		rgb(168, 132, 70),
		Enum.Material.Metal
	)
	table.insert(parts, knob)
	for _, part in parts do
		part.Anchored, part.Massless = false, true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = door, part
		weld.Parent = part
	end
end

local function common(folder: Instance, root: Instance, room: RoomRef)
	local basement = room.y < 0
	conceal(root, room, { Rug = true, AntiqueTable = true, Cord = true })
	if not basement and room.id ~= "Bath" and room.id ~= "Kitchen" and room.id ~= "Machine" then
		Props.place(folder, "PersianRug", V3(room.x, room.y + 0.02, room.z + 1), Vector3.zAxis, 0.8 * KEEP, "floor")
	end
	Props.place(folder, "LowTable", V3(room.x, room.y, room.z - 11), Vector3.zAxis, 0.8 * KEEP, "floor")
	window(folder, room)
	-- Cômodos da frente da ala oeste: a janela real da parede z = 12 (HouseBuilder, x = −28,75) ganha moldura
	-- e cortinas, como as janelas da fachada.
	if room.x < 0 and room.y >= 0 and math.abs(room.z + 4) < 1 then
		Props.place(folder, "WindowSet", V3(-28.75, room.y + 8.4, 11.5), -Vector3.zAxis, 1.25, "wall")
	end
	local features = root:FindFirstChild("Features")
	local cabinet = features and features:FindFirstChild(`hide_{room.id}`)
	local door = cabinet and cabinet:FindFirstChild("HideDoor")
	if cabinet and door and door:IsA("BasePart") and door.Transparency < 0.5 and wardrobeModel(folder, door) then
		for _, part in cabinet:GetChildren() do
			if part:IsA("BasePart") then
				part.Transparency = 1
			end
		end
	elseif cabinet and door and door:IsA("BasePart") and door.Transparency < 0.5 and has("Wardrobe") then
		-- A fresta da câmera fica 0,1 stud à frente da porta: a frente do guarda-roupa fica no mesmo plano.
		local front = door.Position + V3(0, -door.Size.Y / 2, door.Size.Z / 2)
		local model = Props.place(folder, "Wardrobe", front, Vector3.zAxis, 0.85 * KEEP, "floor")
		if model then
			local box, size = model:GetBoundingBox()
			model:PivotTo(model:GetPivot() + V3(0, 0, front.Z - (box.Position.Z + size.Z / 2)))
			for _, part in cabinet:GetChildren() do
				if part:IsA("BasePart") then
					part.Transparency = 1
				end
			end
			wardrobeDoor(folder, door)
		end
	end
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
				glow(folder, "HallChandelier", orb.Position - UP * 0.4, 34, 0.8, true)
			end
		elseif orb:IsA("BasePart") and orb.Name == "PictureFrame" then
			-- Centros dos cômodos em z = −4, −36, −68: o quadro de trás (oz −6) cede o lugar à janela.
			local roomZ = -4 - 32 * math.round((-4 - orb.Position.Z) / 32)
			-- No porão (tijolo) não há quadros.
			local behind = orb.Position.Z < roomZ or orb.Position.Y < 0
			local inward = Vector3.new(-math.sign(orb.Position.X), 0, 0)
			local wall = orb.Position - inward * (orb.Size.X / 2)
			local name = FRAMES[math.floor(math.abs(orb.Position.Z)) % #FRAMES + 1]
			if behind or Props.place(folder, name, wall, inward, 1.7, "wall") then
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
		if room.id == "Exterior" or room.id == "Hall" then
			continue
		end
		common(folder, root, room)
		local dress = ROOMS[room.id]
		if dress then
			dress(folder, root, room)
		end
	end
	nightLights(folder, root)
	PrimitiveFinish.build(root)
end

return Props
