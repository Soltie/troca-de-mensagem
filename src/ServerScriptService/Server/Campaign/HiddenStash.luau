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
-- Cor do que enrola cada fusível do cap. 2: tricô da Dona Cida, fita da Lia, barbante do pião do Juca.
local FUSE_WRAPS: { [string]: Color3 } = {
	fuse_1 = Color3.fromRGB(176, 44, 52),
	fuse_2 = Color3.fromRGB(232, 120, 170),
	fuse_3 = Color3.fromRGB(210, 190, 140),
}
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

-- Variações de um mesmo móvel (crítico, B9): tom da madeira sorteado entre três e um enfeite em cima
-- (nada, toco de vela, pilha de livros ou paninho de renda). Só aparência, nada que mexe na abertura.
local TONES = { WOOD, Color3.fromRGB(84, 58, 40), Color3.fromRGB(52, 35, 25) }
local function vary(model: Model, frame: CFrame, top: number)
	local tone = TONES[rng:NextInteger(1, #TONES)]
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") and part.Color == WOOD then
			part.Color = tone
		end
	end
	local style = rng:NextInteger(1, 4)
	if style == 2 then
		local candle = piece(
			model,
			"DecorCandle",
			Vector3.new(0.3, 0.6, 0.3),
			frame * CFrame.new(0.9, top + 0.3, 0.2),
			Color3.fromRGB(220, 210, 186),
			Enum.Material.SmoothPlastic
		)
		candle.Shape = Enum.PartType.Cylinder
		candle.CFrame *= CFrame.Angles(0, 0, math.rad(90))
	elseif style == 3 then
		for n = 0, 2 do
			piece(
				model,
				"DecorBook",
				Vector3.new(0.9, 0.18, 0.65),
				frame * CFrame.new(-0.8, top + 0.09 + n * 0.18, 0.1) * CFrame.Angles(0, math.rad(n * 12 - 10), 0),
				Color3.fromHSV(rng:NextNumber(0, 0.12), 0.45, 0.35),
				Enum.Material.Fabric
			)
		end
	elseif style == 4 then
		piece(
			model,
			"DecorCloth",
			Vector3.new(1.6, 0.04, 1.1),
			frame * CFrame.new(0, top + 0.02, 0),
			Color3.fromRGB(214, 206, 188),
			Enum.Material.Fabric
		)
	end
end

local function build(
	root: Instance,
	name: string,
	at: Vector3,
	facing: Vector3,
	chest: boolean
): (Model, CFrame, { BasePart }, CFrame?, CFrame?, Vector3)
	local model = Build.model(root, name)
	-- Sem repetição visível (crítico, B9): giro leve fora do esquadro em cada móvel.
	local frame = CFrame.lookAt(at, at + Vector3.new(facing.X, 0, facing.Z))
		* CFrame.Angles(0, math.rad(rng:NextNumber(-7, 7)), 0)
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
		vary(model, frame, 1.95)
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
	vary(model, frame, 3.17)
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
	-- Lugares primeiro: com muitos móveis (Caixinha da Lia), quem não achou parede fica de fora (nada no meio do
	-- tapete), e o móvel certo é sorteado só entre os que estão encostados numa parede.
	local taken: { Vector3 } = {}
	local spots: { { at: Vector3, wall: Vector3? } } = {}
	for _ = 1, total do
		local at, wallFacing = spot(taken)
		if count and not wallFacing then
			continue
		end
		table.insert(taken, at)
		table.insert(spots, { at = at, wall = wallFacing })
	end
	if #spots == 0 then
		local at, wallFacing = spot({})
		table.insert(spots, { at = at, wall = wallFacing })
	end
	local real = rng:NextInteger(1, #spots)
	local targets: { [string]: Target } = {}
	for n, place in spots do
		local at, wallFacing = place.at, place.wall
		local toCenter = Vector3.new(center.X - at.X, 0, center.Z - at.Z)
		local facing = wallFacing or (if toCenter.Magnitude > 0.5 then toCenter.Unit else Vector3.zAxis)
		local chest = rng:NextNumber() < 0.45
		local id = `search_{spec.id}_{n}`
		local model, frame, moving, hinge, slide, inside = build(root, id, at, facing, chest)
		local item: { BasePart } = {}
		if n == real then
			item = placeItem(model, spec.item, inside, if chest then 1.2 else 0.9)
			-- Caixinha da Lia (cap. 1): a chave aparece presa na corda da caixinha de música, com a fita de cabelo.
			if spec.item == "key_living" and count then
				local box = piece(
					model,
					"MusicBox",
					Vector3.new(1.1, 0.6, 0.8),
					CFrame.new(inside + Vector3.new(0, -0.15, 0)),
					Color3.fromRGB(120, 70, 50)
				)
				local ribbon = piece(
					model,
					"HairRibbon",
					Vector3.new(0.12, 0.45, 0.85),
					CFrame.new(inside + Vector3.new(0.45, 0.05, 0)),
					Color3.fromRGB(232, 120, 170),
					Enum.Material.Fabric
				)
				for _, part in { box, ribbon } do
					part.Transparency = 1
					table.insert(item, part)
				end
			end
			-- Fusíveis da Família (cap. 2): cada fusível vem enrolado em algo da pessoa dona dele.
			local wrap = FUSE_WRAPS[spec.item]
			if wrap and #item > 0 then
				local ring = piece(
					model,
					"FuseWrap",
					Vector3.new(0.5, 0.55, 0.55),
					CFrame.new(inside) * CFrame.Angles(0, 0, math.rad(90)),
					wrap,
					Enum.Material.Fabric
				)
				ring.Shape = Enum.PartType.Cylinder
				ring.Transparency = 1
				table.insert(item, ring)
			end
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
