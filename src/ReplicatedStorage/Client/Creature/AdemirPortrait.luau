--!strict
-- Rosto do Ademir compartilhado entre o corpo e o susto. Uma textura local de 64 KiB,
-- reconstruída do módulo de dados; nenhuma foto é enviada ao Roblox.

local AssetService = game:GetService("AssetService")
local EncodingService = game:GetService("EncodingService")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Create = require("../UI/Create")
local Data = require("./AdemirFaceData")

local log = Logger.new("AdemirPortrait")
local portrait: EditableImage? = nil
local attempted = false

local function getPortrait(): EditableImage?
	if attempted then
		return portrait
	end
	attempted = true
	local created: EditableImage? = nil
	local ok, problem = pcall(function()
		local size = Vector2.new(Data.Width, Data.Height)
		local pixels = EncodingService:Base64Decode(buffer.fromstring(Data.RgbaBase64))
		assert(buffer.len(pixels) == Data.Width * Data.Height * 4, "invalid portrait pixel data")
		created = AssetService:CreateEditableImage({ Size = size })
		assert(created, "editable image memory unavailable")
		created:WritePixelsBuffer(Vector2.zero, size, pixels)
	end)
	if not ok then
		if created then
			created:Destroy()
		end
		log.warn("Portrait unavailable; using geometric face: %s", tostring(problem))
		return nil
	end
	portrait = created
	log.info("Local portrait ready (%dx%d)", Data.Width, Data.Height)
	return portrait
end

local AdemirPortrait = {}

-- Todas as imagens compartilham o mesmo EditableImage; o original segue retido pelo módulo.
function AdemirPortrait.createImage(props: { [string]: any }): ImageLabel?
	local image = getPortrait()
	if not image then
		return nil
	end
	local properties: { [string]: any } = {
		Name = "AdemirPhoto",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ImageContent = Content.fromObject(image),
		ResampleMode = Enum.ResamplerMode.Pixelated,
		ScaleType = Enum.ScaleType.Stretch,
	}
	for key, value in props do
		properties[key] = value
	end
	return Create("ImageLabel", properties) :: ImageLabel
end

function AdemirPortrait.applyToRig(parts: { [string]: BasePart }, light: PointLight)
	local head = parts.Head
	local surface = Create("SurfaceGui", {
		Name = "AdemirFace",
		Face = Enum.NormalId.Front,
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize,
		CanvasSize = Vector2.new(Data.Width, Data.Height),
		AlwaysOnTop = false,
		LightInfluence = 0.35,
		Brightness = 1,
		Active = false,
		Parent = head,
	}) :: SurfaceGui
	if not AdemirPortrait.createImage({ Parent = surface }) then
		surface:Destroy()
		return
	end

	-- O cabelo da referência ocupa a frente; laterais e nuca formam uma massa escura low poly.
	head.Size = Vector3.new(1.12, 1.42, 0.85)
	head.Color = Color3.fromRGB(16, 13, 13)
	head:SetAttribute("Appearance", "AdemirPhoto")
	for _, name in { "Neck", "ForearmL", "ForearmR", "HandL", "HandR" } do
		parts[name].Color = Color3.fromRGB(110, 88, 78)
	end
	for _, name in { "Torso", "Pelvis", "Skirt", "Collar", "UpperArmL", "UpperArmR" } do
		parts[name].Color = Color3.fromRGB(20, 23, 23)
	end
	for _, name in { "EyeL", "EyeR", "Mouth" } do
		parts[name].Transparency = 1
	end
	light.Color = Color3.fromRGB(170, 200, 185)
	light.Range = 4
end

return AdemirPortrait
