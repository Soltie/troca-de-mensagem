--!strict
--[[
	Móveis e luminárias com modelos 3D (ReplicatedStorage.Assets.MansionProps, Poly Haven CC0,
	otimizados no Blender; fontes em docs/environment/ASSET_SOURCES.md).
	Só visual: MeshParts ancoradas, sem colisão, sem raycast, sem toque. As luzes ficam em peças
	invisíveis com Build.light, para o WorldFxController controlar sombra e visibilidade.
	Sem a biblioteca (place de Script Sync sem o .rbxm), nada é criado e o jogo segue igual.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require("./Build")

local Props = {}

local V3 = Vector3.new
local rgb = Color3.fromRGB
local UP = Vector3.yAxis
local WARM = rgb(255, 196, 132)

export type Anchor = "floor" | "wall" | "ceiling"

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
end

return Props
