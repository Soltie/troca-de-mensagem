--!strict
--[[
	CosmeticService: aplica no personagem (servidor -> todos veem) a farda e o título equipados.

	Farda: troca a roupa clássica do avatar (Shirt/Pants e roupas em camadas) pelas cores da
	farda (BodyColors) e acrescenta capacete ou quepe e faixa refletiva, em peças sem colisão
	soldadas ao corpo. Chapéus, cabelo e rosto do avatar são mantidos (identidade do jogador).
	Título: placa sobre a cabeça (BillboardGui "TitleTag"); o cliente só mostra fora da ação.

	Lanterna e filtro são locais (CosmeticController, no cliente), lendo os atributos Equip*.
	Puramente visual: nenhuma colisão, hitbox ou velocidade muda.
]]

local Players = game:GetService("Players")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local StoreService = require("./StoreService")

local log = Logger.new("CosmeticService")
local FOLDER = "S9Cosmetics"
-- Última combinação aplicada por personagem (evita refazer peças a cada mudança de moeda).
local applied: { [Model]: string } = {}

-- Roupas em camadas (avatar) que a farda substitui.
local CLOTHING: { [Enum.AccessoryType]: boolean } = {
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.DressSkirt] = true,
}

local function rgb(c: StoreCatalog.RGB?): Color3?
	if not c then
		return nil
	end
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function attach(folder: Instance, base: BasePart, name: string, size: Vector3, offset: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.CFrame = base.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = base
	weld.Part1 = part
	weld.Parent = part
	part.Parent = folder
	return part
end

local function bodyPart(character: Model, names: { string }): BasePart?
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function applyUniform(character: Model, folder: Instance, item: StoreCatalog.Item)
	for _, child in character:GetChildren() do
		local classic = child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic")
		if classic or (child:IsA("Accessory") and CLOTHING[child.AccessoryType]) then
			child:Destroy()
		end
	end
	local shirt = rgb(item.shirt) or Color3.fromRGB(46, 58, 84)
	local pants = rgb(item.pants) or shirt
	local colors = character:FindFirstChildOfClass("BodyColors")
	if not colors then
		local created = Instance.new("BodyColors")
		created.Parent = character
		colors = created
	end
	assert(colors, "body colors")
	colors.TorsoColor3 = shirt
	colors.LeftArmColor3 = shirt
	colors.RightArmColor3 = shirt
	colors.LeftLegColor3 = pants
	colors.RightLegColor3 = pants

	local head = bodyPart(character, { "Head" })
	if head then
		local top = head.Size.Y / 2
		local helmet = rgb(item.helmet)
		if helmet then
			attach(folder, head, "Helmet", Vector3.new(1.3, 0.5, 1.35), CFrame.new(0, top + 0.05, 0), helmet)
			attach(folder, head, "Brim", Vector3.new(1.45, 0.08, 1.55), CFrame.new(0, top - 0.17, -0.05), helmet)
		elseif item.cap then
			local cap = shirt:Lerp(Color3.new(0, 0, 0), 0.25)
			attach(folder, head, "Cap", Vector3.new(1.25, 0.32, 1.3), CFrame.new(0, top, 0), cap)
			attach(folder, head, "Visor", Vector3.new(1.0, 0.07, 0.55), CFrame.new(0, top - 0.12, -0.75), cap)
			local badge = rgb(item.stripe)
			if badge then
				attach(folder, head, "Badge", Vector3.new(0.3, 0.2, 0.05), CFrame.new(0, top + 0.02, -0.66), badge)
			end
		end
	end
	local stripe = rgb(item.stripe)
	local torso = bodyPart(character, { "UpperTorso", "Torso" })
	if stripe and torso then
		local size = torso.Size
		attach(
			folder,
			torso,
			"Stripe",
			Vector3.new(size.X + 0.04, 0.14, size.Z + 0.04),
			CFrame.new(0, -size.Y * 0.18, 0),
			stripe
		)
	end
	for _, legName in { "LeftLowerLeg", "RightLowerLeg" } do
		local leg = bodyPart(character, { legName })
		if stripe and leg then
			attach(
				folder,
				leg,
				"LegStripe",
				Vector3.new(leg.Size.X + 0.04, 0.1, leg.Size.Z + 0.04),
				CFrame.new(0, leg.Size.Y * 0.1, 0),
				stripe
			)
		end
	end
end

local function applyTitle(character: Model, folder: Instance, item: StoreCatalog.Item)
	local head = bodyPart(character, { "Head" })
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "TitleTag"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(220, 24)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 45
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.Text = PixelText.normalize(item.name)
	label.TextColor3 = rgb(item.color) or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	gui.Parent = folder
end

local function apply(player: Player, force: boolean?)
	local character = player.Character
	if not character then
		return
	end
	local signature = StoreService.equipped(player, "uniform") .. "|" .. StoreService.equipped(player, "title")
	if not force and applied[character] == signature and character:FindFirstChild(FOLDER) then
		return
	end
	applied[character] = signature
	character.Destroying:Once(function()
		applied[character] = nil
	end)
	local old = character:FindFirstChild(FOLDER)
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = character
	local uniform = StoreCatalog.ItemById[StoreService.equipped(player, "uniform")]
	local title = StoreCatalog.ItemById[StoreService.equipped(player, "title")]
	local ok, err = pcall(function()
		if uniform then
			applyUniform(character, folder, uniform)
		end
		if title then
			applyTitle(character, folder, title)
		end
	end)
	if not ok then
		log.warn("cosmetics failed for %s: %s", player.Name, tostring(err))
	end
end

local function watch(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		apply(player, true)
	end)
	if player.Character then
		task.defer(apply, player, true)
	end
end

local CosmeticService = {
	Name = "CosmeticService",
}

function CosmeticService.Start()
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- Equipou outra farda/título: reaplica na hora.
	StoreService.onChanged(function(player: Player)
		apply(player)
	end)
end

function CosmeticService.apply(player: Player)
	apply(player, true)
end

return CosmeticService
