--!strict
-- Acabamento visual dos suportes antigos. As peças funcionais continuam sendo a fonte de posição e colisão.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Finish = {}
local installed: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local V3 = Vector3.new

local function library(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("MansionProps")
end

local function render(parent: Instance, body: BasePart, asset: string, size: Vector3, offset: CFrame): Model?
	local assets = library()
	local template = assets and assets:FindFirstChild(asset)
	if not template or not template:IsA("Model") then
		return nil
	end
	-- Malhas com eixos alinhados à caixa do modelo. Cada uma é esticada pela mesma proporção por eixo, então o
	-- conjunto ocupa exatamente o volume antigo. Com uma malha só (Crate, SeaChest, LowTable, Lantern), ela vira a caixa.
	local meshes: { MeshPart } = {}
	for _, object in template:GetDescendants() do
		if object:IsA("BasePart") then
			if not object:IsA("MeshPart") then
				return nil
			end
			table.insert(meshes, object)
		end
	end
	if #meshes == 0 then
		return nil
	end
	local box, extent = template:GetBoundingBox()
	local scale = V3(size.X / extent.X, size.Y / extent.Y, size.Z / extent.Z)
	local model = Instance.new("Model")
	model.Name = body.Name .. "Visual"
	for index, source in meshes do
		local mesh = source:Clone()
		mesh.Name = if index == 1 then "FinishMesh" else "FinishMesh" .. index
		local relative = box:ToObjectSpace(source.CFrame)
		mesh.Size = source.Size * scale
		mesh.CFrame = body.CFrame * offset * CFrame.new(relative.Position * scale) * relative.Rotation
		mesh.Anchored, mesh.Massless = false, true
		mesh.CanCollide, mesh.CanQuery, mesh.CanTouch = false, false, false
		mesh.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = body, mesh, mesh
	end
	local source = Instance.new("ObjectValue")
	source.Name, source.Value, source.Parent = "Source", body, model
	model.Parent = parent
	body.Destroying:Once(function()
		model:Destroy()
	end)
	return model
end

local function decorate(root: Instance, folder: Instance, body: BasePart)
	if body:GetAttribute("PrimitiveFinished") then
		return
	end
	local campaign = root:FindFirstChild("CampaignActivities")
	local furnishings = root:FindFirstChild("Furnishings")
	local dynamics = root:FindFirstChild("DynamicMansion")
	local model: Model? = nil
	if body.Name == "AntiquePedestal" and campaign and body:IsDescendantOf(campaign) then
		model = render(folder, body, "LowTable", body.Size, CFrame.identity)
		if model then
			-- Não pôr a malha dentro da tarefa: refresh() oculta/reexibe os itens coletáveis recursivamente.
			body.Transparency, body.CastShadow = 1, false
		end
	elseif body.Name == "Candle" and furnishings and body.Parent == furnishings and body.Transparency < 0.5 then
		model = render(folder, body, "Lantern", V3(0.62, 1.5, 0.5), CFrame.identity)
		if model then
			body.Transparency, body.CastShadow = 1, false
			local ceiling = math.floor(body.Position.Y / 16) * 16 + 14.7
			local length = ceiling - body.Position.Y - 0.75
			if length > 0 then
				local chain = Instance.new("Part")
				chain.Name, chain.Size = "Hanger", V3(0.035, length, 0.035)
				chain.CFrame = CFrame.new(body.Position + Vector3.yAxis * (0.75 + length / 2))
				chain.Color, chain.Material = Color3.fromRGB(45, 39, 32), Enum.Material.Metal
				chain.Anchored, chain.CanCollide, chain.CanQuery, chain.CanTouch = false, false, false, false
				chain.Massless, chain.CastShadow, chain.Parent = true, false, model
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1, weld.Parent = body, chain, chain
			end
		end
	elseif
		body.Name == "Bookshelf"
		and furnishings
		and body.Parent == furnishings
		and not body:IsA("MeshPart")
		and body.Transparency < 0.5
	then
		-- Estante antiga em bloco (sótão): estante 3D no mesmo volume, frente para o lado sem parede.
		local walls = RaycastParams.new()
		walls.FilterType = Enum.RaycastFilterType.Include
		local architecture = root:FindFirstChild("Architecture")
		walls.FilterDescendantsInstances = if architecture then { architecture } else {}
		local look = body.CFrame.LookVector
		local reach = body.Size.Z / 2 + 1.5
		local blockedFront = workspace:Raycast(body.Position, look * reach, walls) ~= nil
		local blockedBack = workspace:Raycast(body.Position, -look * reach, walls) ~= nil
		local turn = if blockedFront and not blockedBack then CFrame.Angles(0, math.pi, 0) else CFrame.identity
		model = render(folder, body, "Bookshelf", body.Size, turn)
		if model then
			body.Transparency, body.CastShadow = 1, false
		end
	elseif body.Name == "PowerLamp" and furnishings and body.Parent == furnishings and body.Transparency < 0.5 then
		-- Lâmpada elétrica do cômodo (bloco solto abaixo do teto): lustre pequeno preso ao teto. A peça continua
		-- sendo a luz "Lamp" que o WorldService liga com a energia; só deixa de aparecer.
		local assets = library()
		local template = assets and assets:FindFirstChild("Chandelier")
		if template and template:IsA("Model") then
			local _, extent = template:GetBoundingBox()
			local size = extent * (2.6 / extent.X)
			local ceiling = math.floor(body.Position.Y / 16) * 16 + 14.85
			local drop = ceiling - size.Y / 2 - body.Position.Y
			model = render(folder, body, "Chandelier", size, CFrame.new(0, drop, 0))
			if model then
				local lamp = body :: BasePart
				lamp.Transparency, lamp.CastShadow = 1, false
			end
		end
	elseif dynamics and body:IsDescendantOf(dynamics) and (body.Name == "HeavyCrate" or body.Name == "Vault") then
		local crate = body :: BasePart
		local pieces: { Model } = {}
		if crate.Name == "HeavyCrate" then
			-- Dois caixotes empilhados: um só esticado até 5 × 3,6 × 3 virava uma caixa lisa e escura.
			local half = V3(crate.Size.X + 0.03, crate.Size.Y / 2 + 0.015, crate.Size.Z + 0.03)
			for _, dy in { -1, 1 } do
				local turn = CFrame.Angles(0, if dy > 0 then math.pi else 0, 0)
				local piece = render(folder, crate, "Crate", half, CFrame.new(0, dy * crate.Size.Y / 4, 0) * turn)
				if piece then
					table.insert(pieces, piece)
				end
			end
		else
			local piece = render(folder, crate, "SeaChest", crate.Size + V3(0.03, 0.03, 0.03), CFrame.identity)
			if piece then
				table.insert(pieces, piece)
			end
		end
		model = pieces[1]
		if model then
			-- O corpo permanece visível como fundo da malha: a lógica da mansão consulta sua transparência.
			crate.Material, crate.MaterialVariant = Enum.Material.Wood, "MansionDarkWood"
			crate.Color = Color3.fromRGB(176, 150, 120) -- fresta clara entre as tábuas, não um bloco escuro
			local meshes: { BasePart } = {}
			for _, piece in pieces do
				for _, mesh in piece:GetDescendants() do
					if mesh:IsA("BasePart") then
						mesh.Transparency = crate.Transparency
						table.insert(meshes, mesh)
					end
				end
			end
			local changed = crate:GetPropertyChangedSignal("Transparency"):Connect(function()
				for _, mesh in meshes do
					mesh.Transparency = crate.Transparency
				end
			end)
			model.Destroying:Once(function()
				changed:Disconnect()
			end)
		end
	end
	if model then
		body:SetAttribute("PrimitiveFinished", true)
	end
end

function Finish.build(root: Instance)
	local folder = root:FindFirstChild("PrimitiveFinish")
	if not folder then
		local created = Instance.new("Folder")
		created.Name, created.Parent = "PrimitiveFinish", root
		folder = created
	end
	local target = folder :: Instance
	local function inspect(object: Instance)
		if object:IsA("BasePart") then
			decorate(root, target, object)
		end
	end
	for _, object in root:GetDescendants() do
		inspect(object)
	end
	if not installed[root] then
		installed[root] = true
		-- Campanha e dinâmica são criadas após a decoração e reconstruídas a cada capítulo.
		root.DescendantAdded:Connect(function(object)
			if
				object:IsA("BasePart")
				and (
					object.Name == "AntiquePedestal"
					or object.Name == "Candle"
					or object.Name == "Bookshelf"
					or object.Name == "PowerLamp"
					or object.Name == "HeavyCrate"
					or object.Name == "Vault"
				)
			then
				task.defer(function()
					if object:IsDescendantOf(root) then
						inspect(object)
					end
				end)
			end
		end)
	end
end

return Finish
