--!strict
--[[
	Helpers para montar o mundo com primitivas (Part/Wedge/Cylinder), placas com texto e luzes.
	Tudo nasce ancorado e com superfícies lisas. Geometria opaca sólida projeta sombra.
]]

local CollectionService = game:GetService("CollectionService")

local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")

export type PartOptions = {
	material: Enum.Material?,
	transparency: number?,
	collide: boolean?,
	query: boolean?,
	reflectance: number?,
	class: ("Part" | "WedgePart" | "CornerWedgePart")?,
}

export type SignOptions = {
	textColor: Color3,
	background: Color3?,
	backgroundTransparency: number?,
	font: Enum.Font?,
	-- true = texto emite luz (não depende da iluminação da cena).
	lit: boolean?,
	pixelsPerStud: number?,
	partColor: Color3?,
	thickness: number?,
}

local Build = {}

function Build.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	options: PartOptions?
): BasePart
	local opts: PartOptions = options or {}
	local part = Instance.new(opts.class or "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = opts.material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Transparency = opts.transparency or 0
	part.CastShadow = part.Transparency < 0.5 and opts.collide ~= false
	part.Reflectance = opts.reflectance or 0
	if opts.collide ~= nil then
		part.CanCollide = opts.collide
	end
	if opts.query ~= nil then
		part.CanQuery = opts.query
	end
	part.Parent = parent
	return part
end

-- Caixa alinhada aos eixos a partir dos cantos mínimo e máximo.
function Build.box(
	parent: Instance,
	name: string,
	min: Vector3,
	max: Vector3,
	color: Color3,
	options: PartOptions?
): BasePart
	local size = max - min
	return Build.part(parent, name, size, CFrame.new((min + max) / 2), color, options)
end

-- Caixa apoiada no chão: `base` é o centro da face de baixo; `yaw` em graus.
function Build.block(
	parent: Instance,
	name: string,
	base: Vector3,
	size: Vector3,
	yaw: number,
	color: Color3,
	options: PartOptions?
): BasePart
	local cframe = CFrame.new(base + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, math.rad(yaw), 0)
	return Build.part(parent, name, size, cframe, color, options)
end

-- Cilindro com o eixo na direção `axis`.
function Build.cylinder(
	parent: Instance,
	name: string,
	center: Vector3,
	axis: Vector3,
	length: number,
	diameter: number,
	color: Color3,
	options: PartOptions?
): BasePart
	local x = axis.Unit
	local helper = if math.abs(x.Y) > 0.9 then Vector3.xAxis else Vector3.yAxis
	local z = x:Cross(helper).Unit
	local y = z:Cross(x).Unit
	local cframe = CFrame.fromMatrix(center, x, y)
	local part = Build.part(parent, name, Vector3.new(length, diameter, diameter), cframe, color, options);
	(part :: Part).Shape = Enum.PartType.Cylinder
	return part
end

-- Liga uma PointLight a uma peça e registra a tag/atributos para WorldService e cliente.
function Build.light(
	part: BasePart,
	kind: string,
	color: Color3,
	range: number,
	brightness: number,
	enabled: boolean,
	flicker: boolean?
): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Enabled = enabled
	light.Parent = part
	part:SetAttribute(Tags.Attr.LightKind, kind)
	part:SetAttribute(Tags.Attr.Flicker, flicker == true)
	part:SetAttribute("BaseBrightness", brightness)
	CollectionService:AddTag(part, Tags.PowerLight)
	return light
end

-- Placa com texto. `facing` é a direção para onde o texto olha (o leitor fica nesse lado).
function Build.sign(
	parent: Instance,
	name: string,
	position: Vector3,
	facing: Vector3,
	size: Vector2,
	text: string,
	options: SignOptions
): BasePart
	local thickness = options.thickness or 0.2
	local cframe = CFrame.lookAt(position, position + facing)
	local part = Build.part(
		parent,
		name,
		Vector3.new(size.X, size.Y, thickness),
		cframe,
		options.partColor or options.background or Color3.new(0, 0, 0),
		{ collide = false }
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = options.pixelsPerStud or 40
	gui.LightInfluence = if options.lit then 0 else 1
	gui.Brightness = if options.lit then 1.6 else 1
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = options.background or Color3.new(0, 0, 0)
	label.BackgroundTransparency = options.backgroundTransparency or (if options.background then 0 else 1)
	label.BorderSizePixel = 0
	label.Font = options.font or Enum.Font.Arcade
	label.TextColor3 = options.textColor
	label.TextScaled = true
	label.Text = if label.Font == Enum.Font.Arcade then PixelText.normalize(text) else text
	label.Parent = gui

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.PaddingTop = UDim.new(0.12, 0)
	padding.PaddingBottom = UDim.new(0.12, 0)
	padding.Parent = label
	return part
end

-- Som 3D preso a uma peça (o servidor toca; replica para os clientes).
function Build.sound(part: Instance, name: string, id: string, volume: number, speed: number?, looped: boolean?): Sound
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = id
	sound.Volume = volume
	sound.PlaybackSpeed = speed or 1
	sound.Looped = looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 6
	sound.RollOffMaxDistance = 80
	sound.Parent = part
	return sound
end

return Build
