--!strict
--[[
	WorldService: dono do mundo físico. Constrói o mapa no boot (MapBuilder), controla
	iluminação/energia, portas, portão, quadro e fusíveis, e restaura tudo a cada rodada.

	Só o servidor muda o mundo; o cliente lê (tags/atributos) e faz efeitos locais.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Layout = require("../World/Layout")
local MapBuilder = require("../World/MapBuilder")
local Palette = require("../World/Palette")

local log = Logger.new("WorldService")

local world: MapBuilder.World? = nil
local fuseFolder: Instance? = nil
local powered = false

local function getWorld(): MapBuilder.World
	assert(world, "[WorldService] used before Init")
	return world
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
	Lighting.ClockTime = 0.3
	Lighting.Brightness = 0.4
	Lighting.GlobalShadows = false
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	Lighting.ExposureCompensation = 0
	Lighting.Ambient = if power then Palette.AmbientPower else Palette.Ambient
	Lighting.OutdoorAmbient = Palette.OutdoorAmbient
	Lighting.FogColor = if power then Palette.FogPower else Palette.Fog
	Lighting.FogStart = 4
	Lighting.FogEnd = if power then 115 else 90
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

local function doorPose(door: MapBuilder.DoorHandle, angle: number): CFrame
	return door.hinge * CFrame.Angles(0, angle, 0) * (door.hinge:Inverse() * door.closedCFrame)
end

-- Anima a porta em poucos quadros (stop-motion). Estado lógico muda na hora.
local function animateDoor(door: MapBuilder.DoorHandle, open: boolean, instant: boolean?)
	door.isOpen = open
	door.panel:SetAttribute(Tags.Attr.InteractPrompt, if open then Text.Prompts.DoorClose else Text.Prompts.DoorOpen)
	local target = if open then door.openAngle else 0
	if instant then
		door.panel.CFrame = doorPose(door, target)
		return
	end
	door.busy = true
	door.sound:Play()
	task.spawn(function()
		local frames = Config.Visual.DoorFrames
		local from = if open then 0 else door.openAngle
		for i = 1, frames do
			door.panel.CFrame = doorPose(door, from + (target - from) * (i / frames))
			task.wait(0.09)
		end
		door.busy = false
	end)
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
	local pickups = built.root:FindFirstChild("Pickups")
	fuseFolder = if pickups then pickups:FindFirstChild("Fuses") else nil
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

function WorldService.spawnCFrame(): CFrame
	return getWorld().spawnCFrame
end

function WorldService.interactable(id: string): MapBuilder.Interactable?
	return getWorld().interactables[id]
end

function WorldService.setInteractEnabled(id: string, enabled: boolean)
	local item = getWorld().interactables[id]
	if item then
		item.enabled = enabled
		item.focus:SetAttribute(Tags.Attr.InteractEnabled, enabled)
	end
end

-- Restaura o mundo para o início de uma rodada. `rng` sorteia a posição dos fusíveis.
function WorldService.resetRound(rng: Random)
	local w = getWorld()
	for id, model in w.fuseModels do
		local spots = Layout.FuseSpots[id]
		local spot = spots[rng:NextInteger(1, #spots)]
		model.Parent = fuseFolder
		model:PivotTo(CFrame.new(vec(spot)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0))
		WorldService.setInteractEnabled(id, true)
	end
	for _, door in w.doors do
		door.busy = false
		animateDoor(door, door.startsOpen, true)
	end
	w.gate.busy = false
	w.gate.isOpen = false
	w.gate.model:PivotTo(w.gate.closedPivot)
	WorldService.setInteractEnabled("gate", true)
	WorldService.setInteractEnabled("panel", true)
	WorldService.setPanelFuses(0)
	WorldService.setPower(false)
end

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

function WorldService.door(id: string): MapBuilder.DoorHandle?
	return getWorld().doors[id]
end

-- Alterna a porta. Retorna (ok, abriu?).
function WorldService.toggleDoor(id: string): (boolean, boolean)
	local door = getWorld().doors[id]
	if not door or door.busy then
		return false, false
	end
	animateDoor(door, not door.isOpen)
	return true, door.isOpen
end

-- Porta fechada perto de `position`? Usado pelo Vigia para arrombar.
function WorldService.closedDoorNear(position: Vector3, range: number): MapBuilder.DoorHandle?
	for _, door in getWorld().doors do
		if not door.isOpen and not door.busy then
			local delta = door.center - position
			if Vector3.new(delta.X, 0, delta.Z).Magnitude <= range then
				return door
			end
		end
	end
	return nil
end

function WorldService.forceOpenDoor(door: MapBuilder.DoorHandle)
	if not door.isOpen then
		animateDoor(door, true)
		door.sound.PlaybackSpeed = 0.8
		task.delay(1, function()
			door.sound.PlaybackSpeed = 1
		end)
	end
end

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
	return Layout.inRect(Layout.Building, position.X, position.Z) and position.Y < Layout.CEILING
end

function WorldService.isInExitZone(position: Vector3): boolean
	return Layout.inRect(Layout.ExitZone, position.X, position.Z)
end

return WorldService
