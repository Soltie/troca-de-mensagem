--!strict
--[[
	WorldService: dono do mundo físico. Constrói o mapa no boot (MapBuilder + FeatureBuilder),
	controla iluminação/energia, portas (aberta / fresta / fechada / trancada), portão, quadro,
	disjuntores, fusíveis, chave, pilhas e armários, e restaura tudo a cada rodada ou checkpoint.

	Só o servidor muda o mundo; o cliente lê (tags/atributos) e faz efeitos locais.
	As REGRAS (o que pode ou não) ficam no RoundService e em Server/Game; aqui só se aplica.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local LightingProfile = require("@game/ReplicatedStorage/Shared/Game/LightingProfile")
local PhysicsService = game:GetService("PhysicsService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Build = require("../World/Build")
local ArtBuilder = require("../World/ArtBuilder")
local FeatureBuilder = require("../World/FeatureBuilder")
local Features = require("../World/Features")
local Layout = require("../World/Layout")
local MapBuilder = require("../World/MapBuilder")
local Palette = require("../World/Palette")
local ProceduralLayout = require("../World/ProceduralLayout")
local SectorBuilder = require("../World/SectorBuilder")

export type DoorState = "open" | "crack" | "closed"

-- Interagível do mapa original ou das novidades (kind como texto: Fuse, Door, Hide, Key...).
export type Interactable = FeatureBuilder.Interactable

local log = Logger.new("WorldService")

local world: MapBuilder.World? = nil
local features: FeatureBuilder.Built? = nil
local fuseFolder: Instance? = nil
local powered = false
local doorStates: { [string]: DoorState } = {}
local doorTokens: { [string]: number } = {}
local locked: { [string]: boolean } = {}
local modifiers: { [string]: PathfindingModifier } = {}
local rattles: { [string]: Sound } = {}
local latches: { [string]: Sound } = {}
local bangs: { [string]: Sound } = {}
local taken: { [string]: boolean } = {}
local sparkCount = 0
local sectorPlan: ProceduralLayout.Plan? = nil

local function getWorld(): MapBuilder.World
	assert(world, "[WorldService] used before Init")
	return world
end

local function getFeatures(): FeatureBuilder.Built
	assert(features, "[WorldService] used before Init")
	return features
end

local function vec(p: Layout.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

-- A base do template (Baseplate/SpawnLocation) é substituída pelo mapa do jogo.
local function removeTemplateWorld()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = workspace:FindFirstChild(name)
		if leftover then
			leftover:Destroy()
		end
	end
end

local function applyLighting(power: boolean)
	for _, child in Lighting:GetChildren() do
		if child:IsA("Atmosphere") or child:IsA("Clouds") then
			child:Destroy() -- a névoa clássica (Fog*) só funciona sem Atmosphere
		end
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.StarCount = 900
		sky.CelestialBodiesShown = true
		sky.MoonAngularSize = 9
		sky.Parent = Lighting
	end
	local visual = LightingProfile.World
	Lighting.ClockTime = visual.clock
	Lighting.Brightness = visual.brightness
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = visual.shadowSoftness
	Lighting.EnvironmentDiffuseScale = visual.diffuse
	Lighting.EnvironmentSpecularScale = visual.specular
	Lighting.ExposureCompensation = 0
	local function rgb(v: { number }): Color3
		return Color3.fromRGB(v[1], v[2], v[3])
	end
	Lighting.Ambient = rgb(if power then visual.ambientPower else visual.ambient)
	Lighting.OutdoorAmbient = rgb(visual.outdoor)
	Lighting.FogColor = rgb(if power then visual.fogPower else visual.fog)
	Lighting.FogStart = visual.fogStart
	Lighting.FogEnd = if power then visual.fogEndPower else visual.fogEnd
	Lighting:SetAttribute("S9PowerOn", power)
	-- Base para a névoa dinâmica do cliente (perigo encurta a névoa localmente).
	Lighting:SetAttribute("BaseFogEnd", Lighting.FogEnd)
end

local function lights(): { BasePart }
	local list = {}
	local root = getWorld().root
	for _, part in CollectionService:GetTagged(Tags.PowerLight) do
		if part:IsA("BasePart") and part:IsDescendantOf(root) then
			table.insert(list, part)
		end
	end
	return list
end

local function setLightPart(part: BasePart, on: boolean)
	local light = part:FindFirstChildWhichIsA("Light")
	if light then
		light.Enabled = on
	end
	local kind = part:GetAttribute(Tags.Attr.LightKind)
	if kind == "Lamp" then
		part.Color = if on then Palette.LampOn else Palette.LampOff
		part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	elseif kind == "Flood" then
		part.Color = if on then Palette.Sodium else Palette.LampOff
		part.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

-- ===================== Portas =====================

local function doorPose(door: MapBuilder.DoorHandle, angle: number): CFrame
	return door.hinge * CFrame.Angles(0, angle, 0) * (door.hinge:Inverse() * door.closedCFrame)
end

local function angleFor(door: MapBuilder.DoorHandle, state: DoorState): number
	if state == "open" then
		return door.openAngle
	elseif state == "crack" then
		return door.openAngle * (Config.Doors.CrackAngle / 95)
	end
	return 0
end

local function currentAngle(door: MapBuilder.DoorHandle): number
	-- Ângulo atual a partir da peça (a animação pode ter sido interrompida).
	local relative = door.hinge:Inverse() * door.panel.CFrame
	local closedRelative = door.hinge:Inverse() * door.closedCFrame
	local a = relative.Position
	local b = closedRelative.Position
	local angle = math.atan2(b.Z, b.X) - math.atan2(a.Z, a.X)
	while angle > math.pi do
		angle -= 2 * math.pi
	end
	while angle < -math.pi do
		angle += 2 * math.pi
	end
	return angle
end

local function refreshDoorPrompt(door: MapBuilder.DoorHandle)
	local state = doorStates[door.id] or "closed"
	local panel = door.panel
	panel:SetAttribute("DoorState", state)
	panel:SetAttribute("Locked", locked[door.id] == true)
	if locked[door.id] then
		panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorLocked)
		panel:SetAttribute("InteractAlt", nil)
	elseif state == "open" then
		panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorClose)
		panel:SetAttribute("InteractAlt", Text.Prompts.DoorCrack)
	elseif state == "crack" then
		panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorOpen)
		panel:SetAttribute("InteractAlt", Text.Prompts.DoorShut)
	else
		panel:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.DoorOpen)
		panel:SetAttribute("InteractAlt", Text.Prompts.DoorCrack)
	end
end

--[[
	Anima a porta com PESO: começa devagar, acelera e assenta (curva suave), mas sempre em passos
	de 12 quadros/s (stop-motion). O estado lógico muda na hora.
]]
local function animateDoor(door: MapBuilder.DoorHandle, state: DoorState, instant: boolean?)
	doorStates[door.id] = state
	door.isOpen = state == "open"
	refreshDoorPrompt(door)
	local target = angleFor(door, state)
	local token = (doorTokens[door.id] or 0) + 1
	doorTokens[door.id] = token
	if instant then
		door.panel.CFrame = doorPose(door, target)
		door.busy = false
		return
	end
	local from = currentAngle(door)
	local delta = target - from
	if math.abs(delta) < 1e-3 then
		return
	end
	door.busy = true
	local closing = state == "closed"
	local sound = door.sound
	sound.PlaybackSpeed = if state == "crack" then 1.25 else (if closing then 1.1 else 0.9)
	sound.Volume = Audio.Door.volume * (if state == "crack" then 0.45 else 1)
	sound:Play()
	local frames = math.max(3, math.ceil(math.abs(delta) / math.rad(10)))
	task.spawn(function()
		for i = 1, frames do
			if doorTokens[door.id] ~= token then
				return
			end
			local t = i / frames
			local eased = t * t * (3 - 2 * t)
			door.panel.CFrame = doorPose(door, from + delta * eased)
			task.wait(1 / 12)
		end
		if closing then
			local latch = latches[door.id]
			if latch then
				latch:Play()
			end
		end
		if doorTokens[door.id] == token then
			door.busy = false
		end
	end)
end

local function setLocked(door: MapBuilder.DoorHandle, value: boolean)
	locked[door.id] = value
	local modifier = modifiers[door.id]
	if modifier then
		-- Trancada: o pathfinding não atravessa (o Vigia contorna pela ampliação ou desiste).
		modifier.PassThrough = not value
	end
	door.panel:SetAttribute("LockState", if value then "locked" else "unlocked")
	refreshDoorPrompt(door)
end

-- Pequeno tranco na folha (tranca chacoalhando / pancada do outro lado).
local function twitch(door: MapBuilder.DoorHandle, strength: number)
	if door.busy then
		return
	end
	local base = door.panel.CFrame
	task.spawn(function()
		for i = 1, 4 do
			local offset = (if i % 2 == 1 then 1 else -1) * strength * (1 - i / 5)
			door.panel.CFrame = doorPose(door, angleFor(door, doorStates[door.id] or "closed") + math.rad(offset))
			task.wait(1 / 12)
		end
		if not door.busy then
			door.panel.CFrame = base
		end
	end)
end

-- ===================== Novidades (chave, pilhas, armários, disjuntores) =====================

local function setModelShown(model: Model, shown: boolean, home: Instance)
	model.Parent = if shown then home else nil
end

local function setFeatureEnabled(id: string, enabled: boolean)
	local item = getFeatures().interactables[id]
	if item then
		item.enabled = enabled
		item.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
	end
end

local function pickupsFolder(): Instance
	local folder = getFeatures().root:FindFirstChild("Pickups")
	assert(folder, "Pickups folder")
	return folder
end

local WorldService = {
	Name = "WorldService",
}

function WorldService.Init()
	removeTemplateWorld()
	if not PhysicsService:IsCollisionGroupRegistered(MapBuilder.NAV_GROUP) then
		PhysicsService:RegisterCollisionGroup(MapBuilder.NAV_GROUP)
	end
	PhysicsService:CollisionGroupSetCollidable(MapBuilder.NAV_GROUP, "Default", false)
	local started = os.clock()
	world = MapBuilder.build(workspace)
	local built = getWorld()
	features = FeatureBuilder.build(built.root)
	ArtBuilder.build(built.root)
	WorldService.rebuildSector(ProceduralLayout.create(1, 1))
	local pickups = built.root:FindFirstChild("Pickups")
	fuseFolder = if pickups then pickups:FindFirstChild("Fuses") else nil

	local doorsFolder = built.root:FindFirstChild("Doors")
	for id, door in built.doors do
		local region = doorsFolder and doorsFolder:FindFirstChild(`{id}_Path`)
		local modifier = region and region:FindFirstChildOfClass("PathfindingModifier")
		if modifier then
			modifiers[id] = modifier
		end
		rattles[id] =
			Build.sound(door.panel, "Rattle", Audio.DoorRattle.id, Audio.DoorRattle.volume, Audio.DoorRattle.speed)
		latches[id] = Build.sound(door.panel, "Latch", Audio.DoorLatch.id, Audio.DoorLatch.volume * 0.6, 1.1)
		bangs[id] = Build.sound(door.panel, "Bang", Audio.DoorBang.id, Audio.DoorBang.volume)
		bangs[id].RollOffMaxDistance = 120
	end

	applyLighting(false)
	local count = 0
	for _, d in built.root:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	log.info("world built: %d parts in %.0f ms", count, (os.clock() - started) * 1000)
end

function WorldService.get(): MapBuilder.World
	return getWorld()
end

function WorldService.features(): FeatureBuilder.Built
	return getFeatures()
end

function WorldService.rebuildSector(plan: ProceduralLayout.Plan)
	SectorBuilder.build(getWorld().root, plan)
	sectorPlan = plan
end

function WorldService.patrolNodes(): { Layout.Point }
	local nodes = table.clone(Layout.PatrolNodes)
	if sectorPlan then
		for _, point in ProceduralLayout.patrolPoints(sectorPlan) do
			table.insert(nodes, point)
		end
	end
	return nodes
end

function WorldService.creatureSpawns(): { Layout.Point }
	local nodes = table.clone(Layout.CreatureSpawns)
	if sectorPlan then
		for _, room in sectorPlan.rooms do
			table.insert(nodes, { x = room.x, y = 0, z = room.z })
		end
	end
	return nodes
end

function WorldService.spawnCFrame(): CFrame
	return getWorld().spawnCFrame
end

function WorldService.checkpointCFrame(): CFrame
	local spot = Features.CheckpointSpawn
	return CFrame.lookAt(vec(spot.position), vec(spot.lookAt))
end

function WorldService.interactable(id: string): Interactable?
	local item = getWorld().interactables[id]
	if item then
		return item :: any
	end
	return getFeatures().interactables[id]
end

function WorldService.setInteractEnabled(id: string, enabled: boolean)
	local item = getWorld().interactables[id]
	if item then
		item.enabled = enabled
		item.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
		return
	end
	setFeatureEnabled(id, enabled)
end

-- Restaura o mundo para o início de uma rodada. `rng` sorteia fusíveis, chave e pilhas.
function WorldService.resetRound(rng: Random, plan: ProceduralLayout.Plan?)
	local w = getWorld()
	local f = getFeatures()
	WorldService.rebuildSector(plan or ProceduralLayout.create(rng:NextInteger(1, 2147483646), 1))
	for id, model in w.fuseModels do
		local spots = Layout.FuseSpots[id]
		local spot = spots[rng:NextInteger(1, #spots)]
		model.Parent = fuseFolder
		model:PivotTo(CFrame.new(vec(spot)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0))
		WorldService.setInteractEnabled(id, true)
	end
	table.clear(taken)
	for _, door in w.doors do
		door.busy = false
		local startsLocked = Features.LockedDoors[door.id] == true
		setLocked(door, startsLocked)
		animateDoor(door, if door.startsOpen and not startsLocked then "open" else "closed", true)
	end
	w.gate.busy = false
	w.gate.isOpen = false
	w.gate.model:PivotTo(w.gate.closedPivot)
	WorldService.setInteractEnabled("gate", true)
	WorldService.setInteractEnabled("panel", true)
	WorldService.setPanelFuses(0)

	-- Chave: uma posição por rodada.
	local keySpot = Features.KeySpots[rng:NextInteger(1, #Features.KeySpots)]
	for id, model in f.keys do
		local shown = id == keySpot.id
		setModelShown(model, shown, pickupsFolder())
		setFeatureEnabled(id, shown)
	end
	-- Pilhas: algumas posições por rodada.
	local chosen = Features.pick(Features.BatterySpots, Config.Battery.PickupsPerRound, function(a, b)
		return rng:NextInteger(a, b)
	end)
	local chosenIds: { [string]: boolean } = {}
	for _, spot in chosen do
		chosenIds[spot.id] = true
	end
	for id, model in f.batteries do
		setModelShown(model, chosenIds[id] == true, pickupsFolder())
		setFeatureEnabled(id, chosenIds[id] == true)
	end
	for _, locker in f.lockers do
		locker.occupant = nil
		locker.door.CFrame = locker.doorClosed
	end
	WorldService.setBreakers({ false, false, false })
	WorldService.setPower(false)
end

-- ----- Fusíveis, quadro, energia -----

function WorldService.setFuseCollected(id: string)
	local model = getWorld().fuseModels[id]
	if model then
		model.Parent = nil
	end
	WorldService.setInteractEnabled(id, false)
end

function WorldService.setPanelFuses(count: number)
	local panel = getWorld().panel
	for index, fuse in panel.slotFuses do
		fuse.Transparency = if index <= count then 0 else 1
	end
	if count > 0 then
		panel.switchSound:Play()
	end
	panel.focus:SetAttribute("Fuses", count)
end

function WorldService.setPower(on: boolean)
	powered = on
	local w = getWorld()
	for _, part in lights() do
		local kind = part:GetAttribute(Tags.Attr.LightKind)
		if kind == "Lamp" or kind == "Flood" or kind == "Beacon" then
			setLightPart(part, on)
		end
	end
	w.panel.status.Color = if on then Palette.PanelOn else Palette.PanelOff
	for _, buzz in w.buzz do
		if on then
			buzz:Play()
		else
			buzz:Stop()
		end
	end
	if on then
		w.panel.hum:Play()
		w.panel.switchSound:Play()
	else
		w.panel.hum:Stop()
	end
	applyLighting(on)
end

function WorldService.isPowered(): boolean
	return powered
end

-- ----- Disjuntores -----

-- Posição das alavancas (true = levantada) e lâmpadas (verde quando levantada).
function WorldService.setBreakers(up: { boolean })
	local b = getFeatures().breakers
	for i, lever in b.levers do
		local isUp = up[i] == true
		lever.CFrame = if isUp then b.up[i] else b.down[i]
		local lamp = b.lamps[i]
		lamp.Color = if isUp then Palette.PanelOn else Palette.LampOff
		lamp.Material = if isUp then Enum.Material.Neon else Enum.Material.SmoothPlastic
	end
end

-- Texto do procedimento na prancheta da parede (ordem da rodada).
function WorldService.setProcedure(order: string)
	local b = getFeatures().breakers
	b.diagram.Text = `RELIGAMENTO\n\n{order}`
	b.box:SetAttribute("Order", order)
end

-- Feedback físico: "ok" (clique seco), "wrong" (pancada + faíscas), "solved" (chave geral), "denied".
function WorldService.breakerFeedback(kind: "ok" | "wrong" | "solved" | "denied")
	local b = getFeatures().breakers
	if kind == "ok" then
		b.toggle.PlaybackSpeed = 0.8
		b.toggle:Play()
	elseif kind == "denied" then
		b.toggle.PlaybackSpeed = 0.55
		b.toggle:Play()
	elseif kind == "wrong" then
		b.toggle.PlaybackSpeed = 0.7
		b.toggle:Play()
		b.fail:Play()
		sparkCount += 1
		-- O cliente solta faíscas e pisca as lâmpadas em vermelho ao ver o contador mudar.
		b.box:SetAttribute("Spark", sparkCount)
		for _, lamp in b.lamps do
			lamp.Color = Palette.Emergency
			lamp.Material = Enum.Material.Neon
		end
	elseif kind == "solved" then
		b.solved:Play()
		b.box:SetAttribute("Solved", os.clock())
	end
end

-- ----- Chave e pilhas -----

function WorldService.setTaken(id: string)
	local f = getFeatures()
	taken[id] = true
	local model = f.keys[id] or f.batteries[id]
	if model then
		model.Parent = nil
	end
	setFeatureEnabled(id, false)
end

function WorldService.takenSnapshot(): { [string]: boolean }
	return table.clone(taken)
end

-- Checkpoint: itens pegos continuam pegos (os outros voltam como estavam na rodada).
function WorldService.applyTaken(snapshot: { [string]: boolean })
	for id in snapshot do
		WorldService.setTaken(id)
	end
end

-- ----- Armários -----

function WorldService.locker(id: string): FeatureBuilder.LockerHandle?
	return getFeatures().lockers[id]
end

-- Porta do armário abre e fecha (entrada/saída), em passos.
function WorldService.swingLocker(id: string)
	local locker = getFeatures().lockers[id]
	if not locker then
		return
	end
	locker.sound:Play()
	task.spawn(function()
		for _, angle in { 35, 70, 70, 30, 0 } do
			locker.door.CFrame = locker.hinge
				* CFrame.Angles(0, math.rad(-angle), 0)
				* (locker.hinge:Inverse() * locker.doorClosed)
			task.wait(1 / 12)
		end
		locker.door.CFrame = locker.doorClosed
	end)
end

-- ----- Portas -----

function WorldService.door(id: string): MapBuilder.DoorHandle?
	return getWorld().doors[id]
end

function WorldService.doorState(id: string): DoorState
	return doorStates[id] or "closed"
end

function WorldService.isLocked(id: string): boolean
	return locked[id] == true
end

-- Ação principal (E). Retorna (ok, estado novo).
function WorldService.useDoor(id: string): (boolean, DoorState)
	local door = getWorld().doors[id]
	if not door or locked[id] then
		return false, WorldService.doorState(id)
	end
	local nextState: DoorState = if doorStates[id] == "open" then "closed" else "open"
	animateDoor(door, nextState)
	return true, nextState
end

-- Ação alternativa (Q): entreabrir ou fechar a fresta.
function WorldService.altDoor(id: string): (boolean, DoorState)
	local door = getWorld().doors[id]
	if not door or locked[id] then
		return false, WorldService.doorState(id)
	end
	local nextState: DoorState = if doorStates[id] == "crack" then "closed" else "crack"
	animateDoor(door, nextState)
	return true, nextState
end

-- Compatível com a API antiga (abre/fecha).
function WorldService.toggleDoor(id: string): (boolean, boolean)
	local ok, state = WorldService.useDoor(id)
	return ok, state == "open"
end

function WorldService.rattleDoor(id: string)
	local door = getWorld().doors[id]
	if not door then
		return
	end
	local sound = rattles[id]
	if sound and not sound.IsPlaying then
		sound:Play()
	end
	twitch(door, 1.2)
end

-- Destranca com a chave: insere, gira, clique (UnlockTime s) e deixa entreaberta.
function WorldService.unlockDoor(id: string, player: Player): boolean
	local door = getWorld().doors[id]
	if not door or not locked[id] then
		return false
	end
	door.panel:SetAttribute("LockState", "unlocking")
	door.panel:SetAttribute("UnlockBy", player.UserId)
	task.spawn(function()
		local latch = latches[id]
		task.wait(0.35)
		if latch then
			latch.PlaybackSpeed = 1.6
			latch:Play()
		end
		task.wait(Config.Doors.UnlockTime - 0.35)
		if latch then
			latch.PlaybackSpeed = 1.1
		end
		setLocked(door, false)
		animateDoor(door, "crack")
	end)
	return true
end

-- Porta fechada (ou entreaberta) e destrancada perto de `position`: o Vigia empurra.
function WorldService.closedDoorNear(position: Vector3, range: number): MapBuilder.DoorHandle?
	for _, door in getWorld().doors do
		if not door.isOpen and not door.busy and not locked[door.id] then
			local delta = door.center - position
			if Vector3.new(delta.X, 0, delta.Z).Magnitude <= range then
				return door
			end
		end
	end
	return nil
end

-- Porta trancada perto de `position` (o Vigia bate e desiste).
function WorldService.lockedDoorNear(position: Vector3, range: number): MapBuilder.DoorHandle?
	for _, door in getWorld().doors do
		if locked[door.id] then
			local delta = door.center - position
			if Vector3.new(delta.X, 0, delta.Z).Magnitude <= range then
				return door
			end
		end
	end
	return nil
end

function WorldService.bangDoor(door: MapBuilder.DoorHandle)
	door.panel:SetAttribute("BangSerial", ((door.panel:GetAttribute("BangSerial") :: number?) or 0) + 1)
	local sound = bangs[door.id]
	if sound and not sound.IsPlaying then
		sound:Play()
	end
	twitch(door, 2.5)
end

function WorldService.forceOpenDoor(door: MapBuilder.DoorHandle)
	if not door.isOpen and not locked[door.id] then
		animateDoor(door, "open")
		door.sound.PlaybackSpeed = 0.75
	end
end

function WorldService.doorSnapshot(): ({ [string]: DoorState }, { [string]: boolean })
	return table.clone(doorStates), table.clone(locked)
end

function WorldService.applyDoors(states: { [string]: DoorState }, lockedStates: { [string]: boolean })
	for id, door in getWorld().doors do
		setLocked(door, lockedStates[id] == true)
		animateDoor(door, states[id] or "closed", true)
	end
end

-- ----- Portão -----

function WorldService.openGate(): boolean
	local gate = getWorld().gate
	if gate.isOpen or gate.busy then
		return false
	end
	gate.isOpen = true
	gate.busy = true
	WorldService.setInteractEnabled("gate", false)
	gate.sound:Play()
	task.spawn(function()
		local frames = Config.Visual.GateFrames
		for i = 1, frames do
			gate.model:PivotTo(gate.closedPivot:Lerp(gate.openPivot, i / frames))
			task.wait(0.3)
		end
		gate.busy = false
	end)
	return true
end

function WorldService.isInsideBuilding(position: Vector3): boolean
	local inSector = sectorPlan ~= nil and ProceduralLayout.isIndoor(sectorPlan, position.X, position.Z)
	return (Layout.isIndoor(position.X, position.Z) or inSector) and position.Y < Layout.CEILING
end

function WorldService.isInExitZone(position: Vector3): boolean
	return Layout.inRect(Layout.ExitZone, position.X, position.Z)
end

return WorldService
