--!strict
--[[
	Itens escondidos nos capítulos da casa: chaves, fusíveis, relógio, máscara, foto e isqueiro ficam dentro de um de
	três móveis do cômodo (cômoda com gaveta ou baú). Os outros dois estão vazios. Qual é o certo é sorteado a cada
	partida (não pela semente do mapa), então não dá para decorar. Abrir faz barulho: procurar tem risco.
	O móvel certo, ao abrir, mostra o item por um instante e o time recolhe (mesmo fluxo da tarefa de coletar).
]]
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Build = require("../World/Build")
local TaskProps = require("../World/HouseTaskProps")

local Stash = {}

export type Target = {
	taskId: string,
	button: number,
	focus: BasePart,
	search: boolean,
	decoy: boolean,
	opened: boolean,
	moving: { BasePart },
	opening: CFrame?,
	hinge: CFrame?,
	item: { BasePart },
}

local WOOD = Color3.fromRGB(66, 44, 31)
local TRIM = Color3.fromRGB(48, 32, 23)
local BRASS = Color3.fromRGB(176, 136, 64)
local COUNT = 3
-- Um gerador só para o servidor todo: criar um por cômodo no mesmo instante repetia o sorteio.
local rng = Random.new()

-- Só itens pequenos e só dentro da casa (cômodos do catálogo; a floresta e os pátios ao ar livre ficam como estão).
function Stash.hideable(stage: number, spec: any): boolean
	if stage > 5 or spec.kind ~= "collect" or type(spec.item) ~= "string" then
		return false
	end
	local item = spec.item
	local small = string.find(item, "key", 1, true) ~= nil
		or string.find(item, "fuse", 1, true) ~= nil
		or item == "clock"
		or item == "mask"
		or item == "photo"
		or item == "lighter"
	if not small then
		return false
	end
	for _, room in House.Rooms do
		if room.id == spec.room then
			return true
		end
	end
	return false
end

-- Centro do cômodo da tarefa (os móveis vão para as paredes em volta dele).
function Stash.center(spec: any): Vector3?
	for _, room in House.Rooms do
		if room.id == spec.room then
			return Vector3.new(room.x, room.y, room.z)
		end
	end
	return nil
end

local function piece(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Item pequeno dentro do móvel: o modelo do item (o mesmo da mesa) reduzido e escondido até abrir.
local function placeItem(model: Model, item: string, at: Vector3, scale: number): { BasePart }
	local holder = Instance.new("Model")
	holder.Name = "HiddenItem"
	holder.Parent = model
	TaskProps.build(holder, Vector3.zero, item, "collect")
	local parts: { BasePart } = {}
	for _, d in holder:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	if #parts == 0 then
		holder:Destroy()
		return {}
	end
	local _, size = holder:GetBoundingBox()
	local fit = math.min(scale / math.max(size.X, size.Y, size.Z, 0.1), 1)
	pcall(function()
		holder:ScaleTo(fit)
	end)
	holder:PivotTo(CFrame.new(at))
	for _, part in parts do
		part.Transparency = 1
		part.CastShadow = false
		part.CanQuery = false
	end
	return parts
end

local function build(
	root: Instance,
	name: string,
	at: Vector3,
	facing: Vector3,
	chest: boolean
): (Model, CFrame, { BasePart }, CFrame?, CFrame?, Vector3)
	local model = Build.model(root, name)
	local frame = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
	local moving: { BasePart } = {}
	if chest then
		-- Baú: caixa com tampa que gira na dobradiça de trás.
		piece(model, "ChestBody", Vector3.new(3.4, 1.6, 2), frame * CFrame.new(0, 0.8, 0), WOOD)
		for _, x in { -1.45, 1.45 } do
			piece(
				model,
				"ChestBand",
				Vector3.new(0.18, 1.64, 2.04),
				frame * CFrame.new(x, 0.8, 0),
				TRIM,
				Enum.Material.Metal
			)
		end
		local lid = piece(model, "ChestLid", Vector3.new(3.5, 0.35, 2.1), frame * CFrame.new(0, 1.78, 0), TRIM)
		local lock = piece(
			model,
			"ChestLock",
			Vector3.new(0.35, 0.4, 0.12),
			frame * CFrame.new(0, 1.55, -1.06),
			BRASS,
			Enum.Material.Metal
		)
		table.insert(moving, lid)
		table.insert(moving, lock)
		-- Acabamento: cantoneiras de latão, rebites nas faixas e alça na tampa (a tampa e a alça giram juntas).
		for _, x in { -1.7, 1.7 } do
			for _, z in { -0.98, 0.98 } do
				piece(
					model,
					"ChestCorner",
					Vector3.new(0.14, 1.62, 0.14),
					frame * CFrame.new(x, 0.8, z),
					BRASS,
					Enum.Material.Metal
				)
			end
			for _, y in { 0.35, 0.8, 1.25 } do
				local rivet = piece(
					model,
					"Rivet",
					Vector3.new(0.09, 0.09, 0.09),
					frame * CFrame.new(x * 0.853, y, -1.03),
					BRASS,
					Enum.Material.Metal
				)
				rivet.Shape = Enum.PartType.Ball
			end
		end
		local handle = piece(
			model,
			"ChestHandle",
			Vector3.new(0.9, 0.12, 0.12),
			frame * CFrame.new(0, 2.0, 0),
			BRASS,
			Enum.Material.Metal
		)
		table.insert(moving, handle)
		local hinge = frame * CFrame.new(0, 1.6, 1.05)
		return model, frame, moving, hinge, nil, (frame * CFrame.new(0, 1.05, 0)).Position
	end
	-- Cômoda: três gavetas; a de cima desliza para fora.
	piece(model, "DresserBody", Vector3.new(3.8, 3, 1.8), frame * CFrame.new(0, 1.5, 0.05), WOOD)
	piece(model, "DresserTop", Vector3.new(4, 0.18, 2), frame * CFrame.new(0, 3.08, 0.05), TRIM)
	-- Acabamento: rodapé, molduras nas laterais e pés torneados.
	piece(model, "DresserPlinth", Vector3.new(3.95, 0.22, 1.95), frame * CFrame.new(0, 0.11, 0.05), TRIM)
	for _, x in { -1.91, 1.91 } do
		piece(model, "SidePanel", Vector3.new(0.04, 2.2, 1.3), frame * CFrame.new(x, 1.55, 0.05), TRIM)
		for _, z in { -0.8, 0.85 } do
			local foot = piece(model, "Foot", Vector3.new(0.3, 0.3, 0.3), frame * CFrame.new(x * 0.95, 0.05, z), TRIM)
			foot.Shape = Enum.PartType.Ball
		end
	end
	for index, y in { 0.55, 1.45 } do
		piece(model, `DrawerFront{index}`, Vector3.new(3.4, 0.75, 0.12), frame * CFrame.new(0, y, -0.9), TRIM)
		piece(model, `DrawerInlay{index}`, Vector3.new(3.0, 0.45, 0.04), frame * CFrame.new(0, y, -0.97), WOOD)
		for _, x in { -0.9, 0.9 } do
			local knob = piece(
				model,
				`DrawerKnob{index}`,
				Vector3.new(0.2, 0.2, 0.2),
				frame * CFrame.new(x, y, -1.0),
				BRASS,
				Enum.Material.Metal
			)
			knob.Shape = Enum.PartType.Ball
		end
	end
	local drawer = piece(model, "Drawer", Vector3.new(3.3, 0.6, 1.6), frame * CFrame.new(0, 2.38, -0.05), WOOD)
	local front = piece(model, "DrawerFront3", Vector3.new(3.4, 0.75, 0.12), frame * CFrame.new(0, 2.35, -0.9), TRIM)
	local knob = piece(
		model,
		"DrawerKnob3",
		Vector3.new(0.22, 0.22, 0.22),
		frame * CFrame.new(0, 2.35, -1.0),
		BRASS,
		Enum.Material.Metal
	)
	knob.Shape = Enum.PartType.Ball
	local inlay = piece(model, "DrawerInlay3", Vector3.new(3.0, 0.45, 0.04), frame * CFrame.new(0, 2.35, -0.97), WOOD)
	for _, part in { drawer, front, knob, inlay } do
		table.insert(moving, part)
	end
	return model, frame, moving, nil, CFrame.new(frame.LookVector * 1.4), (frame * CFrame.new(0, 2.75, -0.1)).Position
end

-- Monta os móveis do cômodo (três, ou `count`). `spot(avoid)` devolve um lugar livre perto da tarefa.
function Stash.build(
	root: Instance,
	spec: any,
	center: Vector3,
	spot: ({ Vector3 }) -> (Vector3, Vector3?),
	distance: number,
	-- Quantos móveis (3 por padrão; a Caixinha da Lia usa 6).
	count: number?
): { [string]: Target }
	local total = count or COUNT
	local real = rng:NextInteger(1, total)
	local taken: { Vector3 } = {}
	local targets: { [string]: Target } = {}
	for n = 1, total do
		local at, wallFacing = spot(taken)
		table.insert(taken, at)
		local toCenter = Vector3.new(center.X - at.X, 0, center.Z - at.Z)
		local facing = wallFacing or (if toCenter.Magnitude > 0.5 then toCenter.Unit else Vector3.zAxis)
		local chest = rng:NextNumber() < 0.45
		local id = `search_{spec.id}_{n}`
		local model, frame, moving, hinge, slide, inside = build(root, id, at, facing, chest)
		local item: { BasePart } = {}
		if n == real then
			item = placeItem(model, spec.item, inside, if chest then 1.2 else 0.9)
			-- O item anda junto com a gaveta.
			if slide then
				for _, part in item do
					table.insert(moving, part)
				end
			end
		end
		local focus = piece(
			model,
			id,
			if chest then Vector3.new(3.6, 1.9, 2.3) else Vector3.new(4, 3.2, 2.1),
			frame * CFrame.new(0, if chest then 0.95 else 1.6, 0),
			WOOD
		)
		focus.Transparency = 1
		focus.CanQuery = true
		focus:SetAttribute(Tags.Attr.InteractId, id)
		focus:SetAttribute(Tags.Attr.InteractPrompt, if chest then "ABRIR O BAÚ" else "ABRIR A GAVETA")
		focus:SetAttribute(Tags.Attr.InteractDistance, distance)
		focus:SetAttribute(Tags.Attr.InteractEnabled, false)
		CollectionService:AddTag(focus, Tags.Interactable)
		targets[id] = {
			taskId = spec.id,
			button = 1,
			focus = focus,
			search = true,
			decoy = n ~= real,
			opened = false,
			moving = moving,
			opening = slide,
			hinge = hinge,
			item = item,
		}
	end
	return targets
end

-- Abre o móvel (gaveta desliza ou tampa gira). No certo, o item aparece e some depois de recolhido.
function Stash.open(target: Target)
	if target.opened then
		return
	end
	target.opened = true
	target.focus:SetAttribute(Tags.Attr.InteractEnabled, false)
	local info = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if target.opening then
		for _, part in target.moving do
			TweenService:Create(part, info, { CFrame = target.opening * part.CFrame }):Play()
		end
	elseif target.hinge then
		local hinge = target.hinge
		local turn = hinge * CFrame.Angles(math.rad(75), 0, 0)
		for _, part in target.moving do
			TweenService:Create(part, info, { CFrame = turn * hinge:ToObjectSpace(part.CFrame) }):Play()
		end
	end
	for _, part in target.item do
		part.Transparency = 0
	end
	if #target.item > 0 then
		task.delay(1.8, function()
			for _, part in target.item do
				part.Transparency = 1
			end
		end)
	end
end

return Stash
