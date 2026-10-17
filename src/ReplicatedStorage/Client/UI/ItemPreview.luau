--!strict
--[[
	Prévias dos cosméticos a partir dos MESMOS dados que o jogo aplica (StoreCatalog):
	  lanterna  corpo, cabeça, lente com a cor do feixe e material (como o FlashlightController);
	  farda     camisa, calça, capacete ou boné, faixas (como o CosmeticService);
	  filtro    cena com a tinta, saturação e brilho do filtro (como o LightingController);
	  título    placa com o nome na cor do título.

	  thumbnail(parent, item)   miniatura 2D leve (grade da loja: nenhum ViewportFrame por cartão)
	  model(parent, item)       ViewportFrame 3D girável (só no painel de detalhe); limpa sozinho ao sair
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local StoreView = require("@game/ReplicatedStorage/Shared/Game/StoreView")
local Create = require("./Create")
local Theme = require("./Theme")

type Item = StoreCatalog.Item

local ItemPreview = {}

local GRID = 12
local SKIN = Color3.fromRGB(214, 170, 132)
local SWITCH = Color3.fromRGB(150, 32, 28)

local function rgb(value: StoreCatalog.RGB?, fallback: Color3): Color3
	if value then
		return Color3.fromRGB(value[1], value[2], value[3])
	end
	return fallback
end

-- Camadas pixel-art: cada linha de cada camada recebe uma cor (mesmo grid 12×12 dos ícones).
local FLASHLIGHT_LAYERS: { { string } } = {
	-- corpo
	{
		"............",
		"............",
		"............",
		"............",
		"#######.....",
		"#######.....",
		"#######.....",
		"#######.....",
		"............",
		"............",
		"............",
		"............",
	},
	-- cabeça
	{
		"............",
		"............",
		".......###..",
		".......####.",
		".......####.",
		".......####.",
		".......####.",
		".......####.",
		".......####.",
		".......###..",
		"............",
		"............",
	},
	-- lente
	{
		"............",
		"............",
		"............",
		"...........#",
		"...........#",
		"...........#",
		"...........#",
		"...........#",
		"...........#",
		"............",
		"............",
		"............",
	},
	-- botão
	{
		"............",
		"............",
		"............",
		"..##........",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
	},
}

local UNIFORM_LAYERS: { [string]: { string } } = {
	helmet = {
		"...######...",
		"..########..",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
	},
	cap = {
		"...#####....",
		"...#######..",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
	},
	skin = {
		"............",
		"............",
		"....####....",
		"....####....",
		"............",
		"............",
		"............",
		"............",
		".#........#.",
		"............",
		"............",
		"............",
	},
	shirt = {
		"............",
		"............",
		"............",
		"............",
		".##########.",
		".##########.",
		".##.####.##.",
		".##.####.##.",
		"............",
		"............",
		"............",
		"............",
	},
	pants = {
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"...######...",
		"...##..##...",
		"...##..##...",
		"...##..##...",
	},
	stripe = {
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"....####....",
		"............",
		"............",
		"...##..##...",
		"............",
	},
}

local function drawLayer(holder: Instance, rows: { string }, color: Color3, material: Enum.Material?)
	for y, row in rows do
		local start: number? = nil
		for x = 1, GRID + 1 do
			local on = x <= GRID and row:sub(x, x) == "#"
			if on and not start then
				start = x
			elseif not on and start then
				local px = Create("Frame", {
					Name = "Px",
					Position = UDim2.fromScale((start - 1) / GRID, (y - 1) / GRID),
					Size = UDim2.fromScale((x - start) / GRID, 1 / GRID),
					BackgroundColor3 = color,
					BorderSizePixel = 0,
					Parent = holder,
				}) :: Frame
				-- Metal/cromo/ouro ganham um brilho sutil de cima para baixo; neon fica chapado e vivo.
				if material == Enum.Material.Metal or material == Enum.Material.Foil then
					Create("UIGradient", {
						Rotation = 90,
						Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color:Lerp(Color3.new(), 0.2)),
						Parent = px,
					})
				end
				start = nil
			end
		end
	end
end

local function square(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	return Create("Frame", {
		Name = "Art",
		AnchorPoint = anchor,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Parent = parent,
	}, {
		Create("UIAspectRatioConstraint", { AspectRatio = 1 }),
	}) :: Frame
end

local function materialOf(item: Item): Enum.Material
	local name = item.material
	if type(name) == "string" then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and typeof(value) == "EnumItem" then
			return value :: any
		end
	end
	return Enum.Material.SmoothPlastic
end

local function flashlightThumb(parent: Instance, item: Item)
	local beam = rgb(item.beam, Color3.fromRGB(255, 232, 196))
	-- Feixe: cone suave saindo da lente (a cor real do feixe do item).
	-- Feixe em três faixas que abrem e somem, saindo exatamente da lente.
	for index, spread in { 0.16, 0.3, 0.44 } do
		Create("Frame", {
			Name = "Beam",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0.66, 0.5),
			Size = UDim2.fromScale(0.34, spread),
			BackgroundColor3 = beam,
			BorderSizePixel = 0,
			Parent = parent,
		}, {
			Create("UIGradient", {
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.55 + index * 0.1),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	local art = square(parent, UDim2.fromScale(0.62, 0.62), UDim2.fromScale(0.36, 0.5), Vector2.new(0.5, 0.5))
	local material = materialOf(item)
	drawLayer(art, FLASHLIGHT_LAYERS[1], rgb(item.body, Color3.fromRGB(38, 40, 44)), material)
	drawLayer(art, FLASHLIGHT_LAYERS[2], rgb(item.head, Color3.fromRGB(52, 54, 58)), material)
	drawLayer(art, FLASHLIGHT_LAYERS[3], beam, nil)
	drawLayer(art, FLASHLIGHT_LAYERS[4], SWITCH, nil)
end

local function uniformThumb(parent: Instance, item: Item)
	local art = square(parent, UDim2.fromScale(0.78, 0.78), UDim2.fromScale(0.5, 0.52), Vector2.new(0.5, 0.5))
	local shirt = rgb(item.shirt, Color3.fromRGB(46, 58, 84))
	local pants = rgb(item.pants, shirt)
	drawLayer(art, UNIFORM_LAYERS.pants, pants)
	drawLayer(art, UNIFORM_LAYERS.shirt, shirt)
	drawLayer(art, UNIFORM_LAYERS.skin, SKIN)
	if item.helmet then
		drawLayer(art, UNIFORM_LAYERS.helmet, rgb(item.helmet, shirt))
	elseif item.cap then
		drawLayer(art, UNIFORM_LAYERS.cap, shirt:Lerp(Color3.new(), 0.25))
	end
	if item.stripe then
		drawLayer(art, UNIFORM_LAYERS.stripe, rgb(item.stripe, shirt))
	end
end

-- Cena noturna da casa desenhada já com o filtro aplicado (StoreView.grade = ColorCorrection).
local function filterThumb(parent: Instance, item: Item)
	local function graded(r: number, g: number, b: number): Color3
		local c = StoreView.grade({ r, g, b }, item)
		return Color3.fromRGB(c[1], c[2], c[3])
	end
	local scene = Create("Frame", {
		Name = "Scene",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Create("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(graded(30, 54, 112), graded(206, 120, 64)),
		}),
	}) :: Frame
	local house = square(scene, UDim2.fromScale(0.7, 0.7), UDim2.fromScale(0.5, 1), Vector2.new(0.5, 1))
	drawLayer(house, {
		".....##.....",
		"....####....",
		"...######...",
		"..########..",
		".##########.",
		"############",
		"..########..",
		"..##.##.##..",
		"..########..",
		"..###..###..",
		"..###..###..",
		"............",
	}, graded(52, 34, 28))
	-- Janelas acesas, lua e grama: tons quentes, frios e verdes mostram o que o filtro muda.
	drawLayer(house, {
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"............",
		"....#..#....",
		"............",
		"............",
		"............",
		"............",
	}, graded(255, 206, 96))
	Create("Frame", {
		Name = "Grass",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0.1),
		BackgroundColor3 = graded(58, 120, 54),
		BorderSizePixel = 0,
		Parent = scene,
	})
	local moon = Create("Frame", {
		Name = "Moon",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(0.9, 0.1),
		Size = UDim2.fromScale(0.16, 0.16),
		BackgroundColor3 = graded(244, 238, 214),
		BorderSizePixel = 0,
		Parent = scene,
	}, { Create("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = moon })
end
local function titleThumb(parent: Instance, item: Item)
	local color = rgb(item.color, Theme.GoldLight)
	local plate = Create("Frame", {
		Name = "Plate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.5),
		BackgroundColor3 = Theme.BgSunken,
		BorderSizePixel = 0,
		Parent = parent,
	}, {
		Create("UICorner", { CornerRadius = Theme.CornerSmall }),
		Create("UIStroke", { Color = color, Thickness = 2, Transparency = 0.2 }),
		Create("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
	Create("TextLabel", {
		Name = "Name",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = item.name,
		TextColor3 = color,
		TextScaled = true,
		Parent = plate,
	}, {
		Create("UITextSizeConstraint", { MaxTextSize = 22, MinTextSize = 9 }),
	})
end

-- Miniatura 2D que preenche `parent` (fundo escuro com vinheta sutil).
function ItemPreview.thumbnail(parent: Instance, item: Item): Frame
	local frame = Create("Frame", {
		Name = "Thumbnail",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.BgSunken,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, {
		Create("UICorner", { CornerRadius = Theme.CornerSmall }),
	}) :: Frame
	if item.kind == "flashlight" then
		flashlightThumb(frame, item)
	elseif item.kind == "uniform" then
		uniformThumb(frame, item)
	elseif item.kind == "filter" then
		filterThumb(frame, item)
	else
		titleThumb(frame, item)
	end
	frame.Parent = parent
	return frame
end

-- ===================== 3D =====================

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Mesma lanterna low poly do FlashlightController (proporções ×5), lente acesa na cor do feixe.
local function buildFlashlight(model: Model, item: Item)
	local material = materialOf(item)
	local k = 5
	part(
		model,
		"Body",
		Vector3.new(0.17, 0.17, 0.85) * k,
		CFrame.new(),
		rgb(item.body, Color3.fromRGB(38, 40, 44)),
		material
	)
	part(
		model,
		"Head",
		Vector3.new(0.27, 0.27, 0.2) * k,
		CFrame.new(0, 0, -0.5 * k),
		rgb(item.head, Color3.fromRGB(52, 54, 58)),
		material
	)
	part(
		model,
		"Lens",
		Vector3.new(0.22, 0.22, 0.03) * k,
		CFrame.new(0, 0, -0.61 * k),
		rgb(item.beam, Color3.fromRGB(255, 232, 196)),
		Enum.Material.Neon
	)
	part(model, "Switch", Vector3.new(0.06, 0.04, 0.12) * k, CFrame.new(0, 0.1 * k, -0.12 * k), SWITCH)
end

-- Boneco com as cores e peças do CosmeticService (capacete+aba ou boné+viseira, faixas).
local function buildUniform(model: Model, item: Item)
	local shirt = rgb(item.shirt, Color3.fromRGB(46, 58, 84))
	local pants = rgb(item.pants, shirt)
	local fabric = Enum.Material.Fabric
	part(model, "Torso", Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), shirt, fabric)
	part(model, "LeftArm", Vector3.new(1, 2, 1), CFrame.new(-1.5, 3, 0), shirt, fabric)
	part(model, "RightArm", Vector3.new(1, 2, 1), CFrame.new(1.5, 3, 0), shirt, fabric)
	part(model, "LeftLeg", Vector3.new(1, 2, 1), CFrame.new(-0.5, 1, 0), pants, fabric)
	part(model, "RightLeg", Vector3.new(1, 2, 1), CFrame.new(0.5, 1, 0), pants, fabric)
	part(model, "Head", Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), SKIN)
	for _, x in { -0.25, 0.25 } do
		part(model, "Eye", Vector3.new(0.14, 0.2, 0.05), CFrame.new(x, 4.7, -0.61), Color3.fromRGB(20, 20, 24))
	end
	local top = 4.6 + 0.6
	local helmet = item.helmet
	if helmet then
		local color = rgb(helmet, shirt)
		part(model, "Helmet", Vector3.new(1.3, 0.5, 1.35), CFrame.new(0, top + 0.05, 0), color)
		part(model, "Brim", Vector3.new(1.45, 0.08, 1.55), CFrame.new(0, top - 0.17, -0.05), color)
	elseif item.cap then
		local cap = shirt:Lerp(Color3.new(), 0.25)
		part(model, "Cap", Vector3.new(1.25, 0.32, 1.3), CFrame.new(0, top, 0), cap)
		part(model, "Visor", Vector3.new(1.0, 0.07, 0.55), CFrame.new(0, top - 0.12, -0.75), cap)
		if item.stripe then
			part(model, "Badge", Vector3.new(0.3, 0.2, 0.05), CFrame.new(0, top + 0.02, -0.66), rgb(item.stripe, cap))
		end
	end
	if item.stripe then
		local stripe = rgb(item.stripe, shirt)
		part(model, "Stripe", Vector3.new(2.04, 0.14, 1.04), CFrame.new(0, 3 - 2 * 0.18, 0), stripe)
		for _, x in { -0.5, 0.5 } do
			part(model, "LegStripe", Vector3.new(1.04, 0.1, 1.04), CFrame.new(x, 0.6, 0), stripe)
		end
	end
end

-- Modelo 3D girável. Gira sozinho devagar; arrastar (mouse ou dedo) gira na mão. Limpa ao sair.
function ItemPreview.model(parent: Instance, item: Item): ViewportFrame?
	if item.kind ~= "flashlight" and item.kind ~= "uniform" then
		return nil
	end
	local viewport = Create("ViewportFrame", {
		Name = "Preview3D",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(190, 190, 200),
		LightColor = Color3.fromRGB(255, 244, 228),
		LightDirection = Vector3.new(-0.5, -1, -0.6),
		Active = true,
	}) :: ViewportFrame
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local model = Instance.new("Model")
	if item.kind == "flashlight" then
		buildFlashlight(model, item)
	else
		buildUniform(model, item)
	end
	model.Parent = world
	-- Enquadra pelo volume real do modelo (gira em torno do centro).
	local box, extents = model:GetBoundingBox()
	local focus = box.Position
	local distance = extents.Magnitude * (if item.kind == "flashlight" then 1.05 else 1.35)
	local pivot = model:GetPivot()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(distance * 0.55, distance * 0.25, -distance * 0.85), focus)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport:SetAttribute("ItemId", item.id)

	local angle = if item.kind == "flashlight" then 0.6 else 0
	local dragging = false
	local lastX = 0
	local idle = 0
	local connections: { RBXScriptConnection } = {}
	local function cleanup()
		for _, connection in connections do
			connection:Disconnect()
		end
		table.clear(connections)
	end
	table.insert(
		connections,
		viewport.InputBegan:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				dragging, lastX, idle = true, input.Position.X, 0
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) then
				angle += (input.Position.X - lastX) * 0.012
				lastX = input.Position.X
			end
		end)
	)
	table.insert(
		connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				dragging = false
			end
		end)
	)
	table.insert(
		connections,
		RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then
				cleanup()
				return
			end
			if not dragging then
				idle += dt
				-- Depois de soltar, espera um pouco antes de voltar a girar sozinho.
				if idle > 1.5 then
					angle += dt * 0.5
				end
			end
			model:PivotTo(pivot * CFrame.Angles(0, angle, 0))
		end)
	)
	viewport.Destroying:Connect(cleanup)
	viewport.Parent = parent
	return viewport
end

return ItemPreview
