--!strict
--[[
	Cena da captura de verdade no modo História ("virar móvel"; regras em Server/Game/CaptureRules).

	  machine  o Tung arrasta pelo pé (anda de costas), corte para a boca do funil da máquina da oficina
	           (Workspace.CursedHouse.Furnishings.CarpenterMachine: atributos ThrowTarget e SpawnPoint), arremessa;
	  wall     arrasta um pouco e puxa a vítima para dentro da parede de madeira (serragem no cliente);
	  stump    floresta: vira toco/boneco de graveto ali mesmo.

	No fim o personagem fica escondido e ancorado dentro do móvel (cadeira, banquinho, abajur, toco ou graveto) e o
	ponto de resgate do CampaignRuntime acompanha o HumanoidRootPart. release() devolve o jogador ao lado do móvel.

	Interface com o Animador (Root do Tung): DragTarget + DragSerial, DragCut, ThrowTarget + ThrowSerial, WallSerial.
	No jogador: BeingDragged, Thrown, Furniture (tipo do móvel enquanto preso).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local CaptureRules = require("../Game/CaptureRules")
local CreatureService = require("./CreatureService")

local log = Logger.new("CaptureSequence")

local R = CaptureRules
-- Corpo arrastado: pé na mão do Tung, deitado de costas (combinado com o Animador).
local DRAG_OFFSET = CFrame.new(0, -2.6, 3.2) * CFrame.Angles(math.rad(90), 0, 0)

type Hidden = { [Instance]: number }
type Captive = {
	token: number,
	furniture: Model?,
	hidden: Hidden,
	spot: Vector3?,
}

local captives: { [number]: Captive } = {}
local token = 0
local rng = Random.new()

local function bump(instance: Instance, name: string)
	instance:SetAttribute(name, ((instance:GetAttribute(name) :: number?) or 0) + 1)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function machine(): (Vector3?, Vector3?)
	local house = workspace:FindFirstChild("CursedHouse")
	local furnishings = house and house:FindFirstChild("Furnishings")
	local carpenter = furnishings and furnishings:FindFirstChild("CarpenterMachine")
	if not carpenter then
		return nil, nil
	end
	local throw = carpenter:GetAttribute("ThrowTarget")
	local spawn = carpenter:GetAttribute("SpawnPoint")
	return if typeof(throw) == "Vector3" then throw else nil, if typeof(spawn) == "Vector3" then spawn else nil
end

local function rayParams(player: Player): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local creature = CreatureService.rootPart().Parent
	if creature then
		table.insert(exclude, creature)
	end
	params.FilterDescendantsInstances = exclude
	local _ = player
	return params
end

-- Chão abaixo de `point` (ou o próprio ponto se não achar).
local function floorAt(point: Vector3, params: RaycastParams): Vector3
	local hit = workspace:Raycast(point + Vector3.new(0, 4, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else point
end

-- Esconde o personagem (lembra a transparência de cada parte para devolver).
local function hide(player: Player, hidden: Hidden)
	local character = player.Character
	if not character then
		return
	end
	for _, item in character:GetDescendants() do
		if (item:IsA("BasePart") or item:IsA("Decal")) and hidden[item] == nil then
			local visual = item :: any
			hidden[item] = visual.Transparency
			visual.Transparency = 1
		end
	end
end

local function reveal(hidden: Hidden)
	for item, value in hidden do
		if item.Parent and (item:IsA("BasePart") or item:IsA("Decal")) then
			(item :: any).Transparency = value
		end
	end
	table.clear(hidden)
end

-- Cor do jogador no móvel (camisa/tronco): o grupo reconhece quem é.
local function accentOf(player: Player): Color3
	local character = player.Character
	local colors = character and character:FindFirstChildOfClass("BodyColors")
	if colors then
		return colors.TorsoColor3
	end
	local torso = character and (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso"))
	return if torso and torso:IsA("BasePart") then torso.Color else Color3.fromRGB(200, 60, 60)
end

local WOOD = Color3.fromRGB(122, 84, 52)
local WOOD_DARK = Color3.fromRGB(84, 56, 34)

local function piece(model: Model, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.Wood
	part.Anchored = true
	part.CanCollide = true
	part.CastShadow = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

-- Móvel simples por código (v1). `base` é o chão; `yaw` em radianos.
local function buildFurniture(kind: string, base: Vector3, yaw: number, accent: Color3, owner: Player): Model
	local model = Instance.new("Model")
	model.Name = `CapturedFurniture_{owner.UserId}`
	model:SetAttribute("Furniture", kind)
	model:SetAttribute("OwnerUserId", owner.UserId)
	local at = CFrame.new(base) * CFrame.Angles(0, yaw, 0)
	if kind == "chair" then
		for _, x in { -0.9, 0.9 } do
			for _, z in { -0.9, 0.9 } do
				piece(model, "Leg", Vector3.new(0.3, 1.8, 0.3), at * CFrame.new(x, 0.9, z), WOOD_DARK)
			end
		end
		piece(model, "Seat", Vector3.new(2.2, 0.3, 2.2), at * CFrame.new(0, 1.95, 0), accent, Enum.Material.Fabric)
		piece(model, "Back", Vector3.new(2.2, 2.4, 0.3), at * CFrame.new(0, 3.3, 0.95), WOOD)
	elseif kind == "stool" then
		for _, angle in { 0, 2.09, 4.19 } do
			local offset = Vector3.new(math.cos(angle) * 0.7, 0.9, math.sin(angle) * 0.7)
			piece(model, "Leg", Vector3.new(0.25, 1.8, 0.25), at * CFrame.new(offset), WOOD_DARK)
		end
		local seat = piece(
			model,
			"Seat",
			Vector3.new(0.35, 1.8, 1.8),
			at * CFrame.new(0, 1.95, 0) * CFrame.Angles(0, 0, math.pi / 2),
			accent
		)
		seat.Shape = Enum.PartType.Cylinder
	elseif kind == "lamp" then
		local foot = piece(
			model,
			"Foot",
			Vector3.new(0.3, 1.4, 1.4),
			at * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WOOD_DARK
		)
		foot.Shape = Enum.PartType.Cylinder
		piece(model, "Pole", Vector3.new(0.25, 3.6, 0.25), at * CFrame.new(0, 2.1, 0), WOOD)
		local shade =
			piece(model, "Shade", Vector3.new(1.6, 1.4, 1.6), at * CFrame.new(0, 4.3, 0), accent, Enum.Material.Fabric)
		local light = Instance.new("PointLight")
		light.Range, light.Brightness, light.Color, light.Shadows = 8, 0.4, Color3.fromRGB(255, 196, 140), false
		light.Parent = shade
	elseif kind == "stump" then
		local trunk = piece(
			model,
			"Stump",
			Vector3.new(1.6, 2.2, 2.2),
			at * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.pi / 2),
			WOOD_DARK
		)
		trunk.Shape = Enum.PartType.Cylinder
		piece(model, "Band", Vector3.new(2.3, 0.25, 2.3), at * CFrame.new(0, 1.2, 0), accent, Enum.Material.Fabric)
	else -- twig: boneco de graveto
		piece(model, "Body", Vector3.new(0.3, 2.2, 0.3), at * CFrame.new(0, 1.8, 0), WOOD)
		piece(model, "Arms", Vector3.new(2, 0.25, 0.25), at * CFrame.new(0, 2.4, 0), WOOD)
		for _, x in { -0.35, 0.35 } do
			piece(
				model,
				"Leg",
				Vector3.new(0.25, 1.4, 0.25),
				at * CFrame.new(x, 0.7, 0) * CFrame.Angles(0, 0, x * 0.6),
				WOOD
			)
		end
		piece(model, "Head", Vector3.new(0.7, 0.7, 0.7), at * CFrame.new(0, 3.2, 0), accent, Enum.Material.Fabric)
	end
	local primary = model:FindFirstChildWhichIsA("BasePart")
	if primary then
		model.PrimaryPart = primary
	end
	return model
end

-- Modelos do artista 3D (importados à mão): Assets/CaptureFurniture ou Assets direto, em ReplicatedStorage ou
-- ServerStorage. Partes com "PlayerColor" no nome levam a cor do jogador. Sem o modelo, usa o móvel por código.
local MODEL_NAMES: { [string]: string } = {
	chair = "CapturedChair",
	stool = "PersonStool",
	lamp = "PersonLamp",
	stump = "CapturedStump",
	twig = "CapturedTwigDoll",
}

local function findTemplate(kind: string): Model?
	local name = MODEL_NAMES[kind]
	if not name then
		return nil
	end
	for _, service in { game:GetService("ReplicatedStorage"), game:GetService("ServerStorage") } do
		local assets = service:FindFirstChild("Assets")
		local folder = assets and assets:FindFirstChild("CaptureFurniture")
		for _, parent in { folder, assets } do
			local found = parent and parent:FindFirstChild(name)
			if found and found:IsA("Model") then
				return found
			end
		end
	end
	return nil
end

local function makeFurniture(kind: string, base: Vector3, yaw: number, accent: Color3, owner: Player): Model
	local template = findTemplate(kind)
	if not template then
		return buildFurniture(kind, base, yaw, accent, owner)
	end
	local model = template:Clone()
	model.Name = `CapturedFurniture_{owner.UserId}`
	model:SetAttribute("Furniture", kind)
	model:SetAttribute("OwnerUserId", owner.UserId)
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = true
			if string.find(item.Name, "PlayerColor", 1, true) then
				item.Color = accent
			end
		end
	end
	-- Apoia a base do modelo no chão, girado em `yaw`.
	local boxCFrame, size = model:GetBoundingBox()
	local pivot = model:GetPivot()
	local bottomOffset = pivot.Position.Y - (boxCFrame.Position.Y - size.Y / 2)
	model:PivotTo(CFrame.new(base + Vector3.new(0, bottomOffset, 0)) * CFrame.Angles(0, yaw, 0))
	return model
end

-- Cômodo sorteado da casa, entre os acessíveis no capítulo (mesma regra da patrulha).
local function randomRoom(stage: number): Vector3?
	local options: { Vector3 } = {}
	for _, room in House.Rooms do
		local accessible = room.y == 0 or (room.y > 0 and stage >= 3) or (room.y < 0 and stage >= 4)
		if accessible and room.id ~= "Exterior" then
			table.insert(options, Vector3.new(room.x, room.y, room.z))
		end
	end
	return if #options > 0 then options[rng:NextInteger(1, #options)] else nil
end

-- Segura o corpo preso ao Tung (pé na mão) enquanto `alive()`; o Tung anda de costas `speed` studs/s por `seconds`.
local function drag(player: Player, seconds: number, speed: number, alive: () -> boolean)
	local creature = CreatureService.rootPart()
	local feet = CreatureService.feetNow()
	local look = creature.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = if look.Magnitude > 1e-3 then look.Unit else Vector3.zAxis
	local started = os.clock()
	while alive() do
		local elapsed = math.min(os.clock() - started, seconds)
		CreatureService.scriptPlace(feet - look * speed * elapsed, look)
		local body = rootOf(player)
		if body then
			body.Anchored = true
			body.CFrame = creature.CFrame * DRAG_OFFSET
		end
		if elapsed >= seconds then
			return
		end
		RunService.Heartbeat:Wait()
	end
end

-- Espaço livre atrás do Tung (para onde ele anda de costas).
local function freeBehind(params: RaycastParams): number
	local creature = CreatureService.rootPart()
	local back = -(creature.CFrame.LookVector * Vector3.new(1, 0, 1))
	if back.Magnitude < 1e-3 then
		return 0
	end
	local from = CreatureService.feetNow() + Vector3.new(0, 2, 0)
	local hit = workspace:Raycast(from, back.Unit * 40, params)
	return if hit then math.max(0, (hit.Position - from).Magnitude - 2.5) else 40
end

local CaptureSequenceService = {
	Name = "CaptureSequenceService",
}

-- Começa a cena. `onDone(spot)` recebe onde o móvel ficou. Retorna a duração (s) para a derrota/recuperação
-- esperarem; 0 se não há cena (aí o fluxo antigo segue).
function CaptureSequenceService.begin(
	player: Player,
	kind: CaptureRules.Kind,
	stage: number,
	onDone: (Vector3) -> ()
): number
	if kind == "none" or not rootOf(player) then
		return 0
	end
	local throwTarget, spawnPoint = machine()
	if kind == "machine" and not throwTarget then
		-- Máquina ainda não montada neste mapa: cena da parede no lugar.
		kind = "wall"
	end
	local params = rayParams(player)
	local machineDistance = if throwTarget then (throwTarget - CreatureService.feetNow()).Magnitude else math.huge
	local dragSeconds = if kind == "machine"
		then R.dragSeconds(freeBehind(params), machineDistance)
		elseif kind == "wall" then math.min(R.WallDrag, freeBehind(params) / R.DragSpeed)
		else 0
	token += 1
	local captive: Captive = { token = token, furniture = nil, hidden = {}, spot = nil }
	local previous = captives[player.UserId]
	if previous then
		CaptureSequenceService.release(player, false)
	end
	captives[player.UserId] = captive
	local function alive(): boolean
		return captives[player.UserId] == captive and player.Parent ~= nil
	end
	local duration = R.duration(kind, dragSeconds)
	log.info("%s captured: %s (%.1fs)", player.Name, kind, duration)
	task.spawn(function()
		task.wait(R.PreDrag)
		if not alive() then
			return
		end
		local creature = CreatureService.rootPart()
		local furnitureKind = R.furniture(kind, rng:NextNumber())
		local spot: Vector3? = nil
		if kind == "machine" or kind == "wall" then
			player:SetAttribute("BeingDragged", true)
			creature:SetAttribute("DragTarget", player.UserId)
			bump(creature, "DragSerial")
			drag(player, dragSeconds, R.DragSpeed, alive)
			if not alive() then
				return
			end
		end
		if kind == "machine" and throwTarget then
			bump(creature, "DragCut")
			task.wait(R.Cut / 2)
			-- Em pé na frente do funil, olhando para a boca.
			local away = if spawnPoint then (spawnPoint - throwTarget) * Vector3.new(1, 0, 1) else Vector3.zAxis
			away = if away.Magnitude > 1e-3 then away.Unit else Vector3.zAxis
			local stand = floorAt(throwTarget + away * 3.5, params)
			CreatureService.scriptPlace(stand, -away)
			local body = rootOf(player)
			if body then
				body.CFrame = creature.CFrame * DRAG_OFFSET
			end
			task.wait(R.Cut / 2)
			if not alive() then
				return
			end
			player:SetAttribute("BeingDragged", false)
			player:SetAttribute("Thrown", true)
			creature:SetAttribute("ThrowTarget", player.UserId)
			bump(creature, "ThrowSerial")
			task.wait(R.ThrowImpact)
			if not alive() then
				return
			end
			local inside = rootOf(player)
			if inside then
				inside.CFrame = CFrame.new(throwTarget)
			end
			hide(player, captive.hidden)
			task.wait(R.ThrowEnd - R.ThrowImpact)
			spot = randomRoom(stage) or spawnPoint
		elseif kind == "wall" then
			bump(creature, "WallSerial")
			hide(player, captive.hidden)
			task.wait(R.Cut)
			spot = randomRoom(stage)
		else
			task.wait(R.StumpDelay)
			local body = rootOf(player)
			spot = if body then body.Position else nil
			hide(player, captive.hidden)
		end
		if not alive() then
			return
		end
		player:SetAttribute("BeingDragged", false)
		player:SetAttribute("Thrown", false)
		local fallback = rootOf(player)
		local chosen = spot or (if fallback then fallback.Position else Vector3.zero)
		local base = floorAt(chosen, params)
		local furniture = makeFurniture(furnitureKind, base, rng:NextNumber(0, math.pi * 2), accentOf(player), player)
		local house = workspace:FindFirstChild("CursedHouse")
		furniture.Parent = house or workspace
		captive.furniture = furniture
		captive.spot = base
		player:SetAttribute("Furniture", furnitureKind)
		local body = rootOf(player)
		if body then
			body.Anchored = true
			body.CFrame = CFrame.new(base + Vector3.new(0, 1.5, 0))
		end
		hide(player, captive.hidden)
		onDone(base)
	end)
	return duration
end

-- O jogador está preso num móvel (ou a caminho dele)?
function CaptureSequenceService.isCaptive(player: Player): boolean
	return captives[player.UserId] ~= nil
end
function CaptureSequenceService.isCaptiveId(userId: number): boolean
	return captives[userId] ~= nil
end

-- Resgatado / capítulo novo: desfaz o móvel e mostra o personagem de novo (ao lado do móvel se `teleport`).
function CaptureSequenceService.release(player: Player, teleport: boolean?)
	local captive = captives[player.UserId]
	if not captive then
		return
	end
	captives[player.UserId] = nil
	reveal(captive.hidden)
	if captive.furniture then
		captive.furniture:Destroy()
	end
	player:SetAttribute("BeingDragged", false)
	player:SetAttribute("Thrown", false)
	player:SetAttribute("Furniture", nil)
	local body = rootOf(player)
	if teleport and body and captive.spot then
		body.CFrame = CFrame.new(captive.spot + Vector3.new(2.5, 3, 0))
	end
end

function CaptureSequenceService.clear()
	for _, player in Players:GetPlayers() do
		CaptureSequenceService.release(player)
	end
	table.clear(captives)
end

function CaptureSequenceService.Init() end

function CaptureSequenceService.Start()
	Players.PlayerRemoving:Connect(function(player)
		local captive = captives[player.UserId]
		if captive and captive.furniture then
			captive.furniture:Destroy()
		end
		captives[player.UserId] = nil
	end)
	-- Renascer (capítulo novo, continuar) devolve o personagem: o móvel antigo sai.
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			CaptureSequenceService.release(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			CaptureSequenceService.release(player)
		end)
	end
end

return CaptureSequenceService
