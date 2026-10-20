--!strict
--[[
	Túnel de minhoca do Tung Tung (regras em Shared/Game/WormTunnel). Nos capítulos 2 a 5 a casa ganha buracos ao pé
	das paredes externas; quando ele perde vocês de vista e está longe, entra num buraco e sai em outro, perto de quem
	está mais perto. Ninguém é pego de surpresa:
	- enquanto ele anda por dentro, um arranhado atravessa as paredes no caminho dele;
	- no buraco de saída, poeira caindo e dois olhos acesos no fundo por alguns segundos antes de ele sair.
	Contra-jogada: pregar uma tábua no buraco (barulhento: ele ouve) fecha aquela boca por um tempo.
	Interação "tunnel_<id>" chega pelo CampaignRuntime (TunnelService.board).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local WormTunnel = require("@game/ReplicatedStorage/Shared/Game/WormTunnel")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CreatureService = require("./CreatureService")
local TensionDirector = require("./TensionDirector")
local DifficultyService = require("./DifficultyService")

local TunnelService = {
	Name = "TunnelService",
}

local log = Logger.new("TunnelService")
local rng = Random.new()
local TICK = 0.5
-- Primeiro mergulho só 60 s depois de o capítulo começar (B2: ele não chega no spawn logo de cara).
local FIRST_DIVE = 60
local FAR_ENOUGH = 30
local WALK_SPEED = 12

local stage = -1
local stageAt = 0
local nextDiveAt = math.huge
local busy = false
local dives = 0
local boarded: { [string]: number } = {}
local models: { [string]: Model } = {}

local function folder(): Folder
	local existing = workspace:FindFirstChild("WormHoles")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "WormHoles"
	created.Parent = workspace
	return created
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material
	p.Anchored, p.CanCollide, p.CanTouch = true, false, false
	p.CanQuery = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sound(parent: Instance, clip: { id: string, volume: number }, volume: number, speed: number?): Sound
	local s = Instance.new("Sound")
	s.SoundId = clip.id
	s.Volume = clip.volume * volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 90
	s.Parent = parent
	s:Play()
	task.delay(8, function()
		s:Destroy()
	end)
	return s
end

-- Buraco: boca escura em arco (meio disco acima do piso), entulho, marcas de garra, olhos e tábuas escondidos.
local function buildHole(hole: WormTunnel.Hole, parent: Folder): Model
	local model = Instance.new("Model")
	model.Name = "WormHole_" .. hole.id
	local wall = Vector3.new(hole.x, hole.y, hole.z)
	local inward = Vector3.new(hole.nx, 0, 0)
	local mouth = piece(
		model,
		"Mouth",
		Vector3.new(0.3, 7, 7),
		CFrame.new(wall + inward * 0.1 + Vector3.new(0, 0.4, 0)),
		Color3.fromRGB(8, 6, 6),
		Enum.Material.SmoothPlastic
	)
	mouth.Shape = Enum.PartType.Cylinder
	mouth.CanQuery = true
	local rim = piece(
		model,
		"Rim",
		Vector3.new(0.2, 8.2, 8.2),
		CFrame.new(wall + inward * 0.05 + Vector3.new(0, 0.4, 0)),
		Color3.fromRGB(70, 58, 48),
		Enum.Material.Slate
	)
	rim.Shape = Enum.PartType.Cylinder
	-- Entulho do reboco espalhado no chão.
	for i = 1, 6 do
		local spread = Vector3.new(hole.nx * rng:NextNumber(0.8, 3.5), 0.25, rng:NextNumber(-3, 3))
		piece(
			model,
			"Rubble",
			Vector3.new(rng:NextNumber(0.4, 1.1), rng:NextNumber(0.25, 0.5), rng:NextNumber(0.4, 1.1)),
			CFrame.new(wall + spread) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)),
			if i % 2 == 0 then Color3.fromRGB(112, 100, 82) else Color3.fromRGB(82, 70, 58),
			Enum.Material.Slate
		)
	end
	-- Três riscos de garra na parede, ao lado da boca.
	for i = -1, 1 do
		piece(
			model,
			"Claw",
			Vector3.new(0.08, 3.2, 0.22),
			CFrame.new(wall + inward * 0.06 + Vector3.new(0, 3.2, 4.6 + i * 0.6)) * CFrame.Angles(math.rad(24), 0, 0),
			Color3.fromRGB(28, 20, 18),
			Enum.Material.SmoothPlastic
		)
	end
	-- Olhos lá no fundo (escondidos até ele estar para sair). Pretos e foscos, sem brilho: pedido do usuário 20/10, nenhum
	-- olho aceso no jogo; o aviso fica com a poeira e o rosnado.
	for _, side in { -0.55, 0.55 } do
		local eye = piece(
			model,
			"Eye",
			Vector3.new(0.35, 0.35, 0.35),
			CFrame.new(wall + inward * 0.25 + Vector3.new(0, 1.9, side)),
			Color3.fromRGB(14, 11, 10),
			Enum.Material.SmoothPlastic
		)
		eye.Shape = Enum.PartType.Ball
		eye.Transparency = 1
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness, glow.Enabled = Color3.fromRGB(255, 40, 30), 7, 1.4, false
		glow.Parent = eye
	end
	-- Tábuas pregadas (aparecem quando alguém prega).
	for i = 1, 3 do
		local plank = piece(
			model,
			"Board",
			Vector3.new(0.3, 0.9, 7.4),
			CFrame.new(wall + inward * 0.35 + Vector3.new(0, 0.6 + i * 1.05, 0))
				* CFrame.Angles(math.rad((i - 2) * 7), 0, 0),
			Color3.fromRGB(110, 82, 52),
			Enum.Material.WoodPlanks
		)
		plank.Transparency = 1
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "Dust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 135, 115))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.2)
	dust.Speed = NumberRange.new(1, 3)
	dust.SpreadAngle = Vector2.new(30, 30)
	dust.Acceleration = Vector3.new(0, -2, 0)
	dust.Rate = 0
	dust.Parent = mouth
	mouth:SetAttribute(Tags.Attr.InteractId, "tunnel_" .. hole.id)
	mouth:SetAttribute(Tags.Attr.InteractPrompt, "PREGAR TÁBUA")
	mouth:SetAttribute(Tags.Attr.InteractDistance, 8)
	mouth:SetAttribute(Tags.Attr.InteractEnabled, true)
	CollectionService:AddTag(mouth, Tags.Interactable)
	model.PrimaryPart = mouth
	model.Parent = parent
	return model
end

local function setBoarded(id: string, on: boolean)
	local model = models[id]
	if not model then
		return
	end
	for _, p in model:GetChildren() do
		if p.Name == "Board" and p:IsA("BasePart") then
			p.Transparency = if on then 0 else 1
			p.CanCollide = on
		end
	end
	local mouth = model.PrimaryPart
	if mouth then
		mouth:SetAttribute(Tags.Attr.InteractEnabled, not on)
	end
end

local function rebuild(current: number)
	local root = folder()
	root:ClearAllChildren()
	table.clear(models)
	table.clear(boarded)
	for _, hole in WormTunnel.holes(current) do
		models[hole.id] = buildHole(hole, root)
	end
end

local function activePoints(): { WormTunnel.Point }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player:GetAttribute("CampaignStatus") == "Active" then
			-- Pés: a raiz fica ~3 studs acima do piso.
			table.insert(out, { x = root.Position.X, y = root.Position.Y - 3, z = root.Position.Z })
		end
	end
	return out
end

local function vector(p: WormTunnel.Point): Vector3
	return Vector3.new(p.x, p.y, p.z)
end

local function clearPath(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	params.FilterDescendantsInstances = if world then { world } else {}
	params.RespectCanCollide = true
	local offset = Vector3.new(0, 3, 0)
	return workspace:Raycast(from + offset, (to - from), params) == nil
end

local function eyes(id: string, on: boolean)
	local model = models[id]
	if not model then
		return
	end
	for _, p in model:GetChildren() do
		if p.Name == "Eye" and p:IsA("BasePart") then
			p.Transparency = if on then 0 else 1
			local glow = p:FindFirstChildOfClass("PointLight")
			if glow then
				glow.Enabled = false
			end
		end
	end
end

-- Anda até a boca do buraco e mergulha de cabeça na parede.
local function walkAndDive(entry: WormTunnel.Hole, from: Vector3)
	local mouthIn = vector(WormTunnel.mouth(entry))
	local look = (mouthIn - from) * Vector3.new(1, 0, 1)
	local steps = math.max(1, math.floor(look.Magnitude / (WALK_SPEED * 0.05)))
	for i = 1, steps do
		CreatureService.scriptPlace(from:Lerp(mouthIn, i / steps), look)
		task.wait(0.05)
	end
	local wall = Vector3.new(entry.x, entry.y, entry.z)
	local entryModel = models[entry.id]
	if entryModel and entryModel.PrimaryPart then
		sound(entryModel.PrimaryPart, Audio.WallBurst, 0.9, 1.1)
		local dust = entryModel.PrimaryPart:FindFirstChild("Dust")
		if dust and dust:IsA("ParticleEmitter") then
			dust:Emit(25)
		end
	end
	for i = 1, 10 do
		local k = i / 10
		CreatureService.scriptPlace(mouthIn:Lerp(wall, k) - Vector3.new(0, k * 7, 0), -Vector3.new(entry.nx, 0, 0))
		task.wait(0.05)
	end
end

-- Longe de um buraco: cava o piso onde está e afunda girando. Fica uma cratera de tábuas quebradas por um tempo.
local function burrowInto(at: Vector3)
	local scar = Instance.new("Model")
	scar.Name = "BurrowScar"
	local hole = piece(
		scar,
		"Crater",
		Vector3.new(0.2, 6.5, 6.5),
		CFrame.new(at + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(12, 9, 8),
		Enum.Material.SmoothPlastic
	)
	hole.Shape = Enum.PartType.Cylinder
	for i = 1, 9 do
		local angle = i / 9 * math.pi * 2
		local radius = rng:NextNumber(3.1, 4.2)
		piece(
			scar,
			"Splinter",
			Vector3.new(rng:NextNumber(0.5, 1.6), rng:NextNumber(0.2, 0.45), rng:NextNumber(0.3, 0.6)),
			CFrame.new(at + Vector3.new(math.cos(angle) * radius, 0.25, math.sin(angle) * radius))
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), angle, rng:NextNumber(-0.4, 0.4)),
			if i % 2 == 0 then Color3.fromRGB(96, 70, 46) else Color3.fromRGB(70, 52, 36),
			Enum.Material.WoodPlanks
		)
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(150, 135, 115))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3.4) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	dust.Lifetime = NumberRange.new(1.2, 2.4)
	dust.Speed = NumberRange.new(3, 7)
	dust.SpreadAngle = Vector2.new(70, 70)
	dust.Acceleration = Vector3.new(0, -3, 0)
	dust.Rate = 0
	dust.Parent = hole
	scar.Parent = folder()
	sound(hole, Audio.WallBurst, 1.1, 0.75)
	sound(hole, Audio.Growl, 0.7, 0.75)
	dust:Emit(45)
	for i = 1, 14 do
		local k = i / 14
		CreatureService.scriptPlace(at - Vector3.new(0, k * 8, 0), Vector3.new(math.cos(k * 7), 0, math.sin(k * 7)))
		task.wait(0.05)
	end
	task.delay(30, function()
		scar:Destroy()
	end)
end

-- Arranhado andando por dentro das paredes até a saída.
local function travelInside(wall: Vector3, entry: WormTunnel.Hole, exit: WormTunnel.Hole, mySerial: number)
	local scurry = Instance.new("Part")
	scurry.Name = "TunnelScurry"
	scurry.Anchored, scurry.CanCollide, scurry.CanQuery, scurry.CanTouch = true, false, false, false
	scurry.Transparency = 1
	scurry.Size = Vector3.one
	scurry.Position = wall + Vector3.new(0, 2, 0)
	scurry.Parent = folder()
	local loop = Instance.new("Sound")
	loop.SoundId = Audio.WallScurry.id
	loop.Volume = Audio.WallScurry.volume * 1.4
	loop.PlaybackSpeed = 0.55
	loop.Looped = true
	loop.RollOffMode = Enum.RollOffMode.InverseTapered
	loop.RollOffMinDistance = 6
	loop.RollOffMaxDistance = 60
	loop.Parent = scurry
	loop:Play()
	local travel = WormTunnel.travelSeconds(entry, exit)
	local target = Vector3.new(exit.x, exit.y + 2, exit.z)
	local t0 = os.clock()
	while os.clock() - t0 < travel and stage == mySerial do
		local k = (os.clock() - t0) / travel
		scurry.Position = scurry.Position:Lerp(wall:Lerp(target, k) + Vector3.new(0, math.sin(k * 9) * 1.5, 0), 0.5)
		task.wait(0.1)
	end
	scurry:Destroy()
end

-- Aviso na saída: poeira caindo e os olhos acesos no fundo. Devolve true se a boca foi pregada nesse meio tempo
-- (ele bate na tábua e volta por onde veio).
local function warnAndCheckBoard(entry: WormTunnel.Hole, exit: WormTunnel.Hole): boolean
	local exitModel = models[exit.id]
	if not exitModel or not exitModel.PrimaryPart then
		return false
	end
	local mouth = exitModel.PrimaryPart
	local dust = mouth:FindFirstChild("Dust")
	if dust and dust:IsA("ParticleEmitter") then
		dust:Emit(18)
	end
	sound(mouth, Audio.Growl, 0.8, 0.8)
	eyes(exit.id, true)
	task.wait(WormTunnel.WARN_SECONDS)
	eyes(exit.id, false)
	if (boarded[exit.id] or 0) > workspace:GetServerTimeNow() then
		sound(mouth, Audio.DoorBang, 1.3, 0.7)
		CreatureService.debugPlace(vector(WormTunnel.mouth(entry, 4)))
		return true
	end
	sound(mouth, Audio.WallBurst, 1.2, 0.9)
	if dust and dust:IsA("ParticleEmitter") then
		dust:Emit(40)
	end
	return false
end

-- A viagem inteira: entra (buraco ou chão), arranha por dentro das paredes, avisa e sai do outro lado.
local function dive(entry: WormTunnel.Hole, exit: WormTunnel.Hole)
	busy = true
	local mySerial = stage
	CreatureService.setFrozen(true)
	local ok: boolean, err: any = pcall(function()
		local from = CreatureService.state().position :: Vector3
		if entry.id == WormTunnel.BURROW_ID then
			burrowInto(from)
		else
			walkAndDive(entry, from)
		end
		CreatureService.debugPlace(Vector3.new(entry.x, entry.y - 60, entry.z))
		travelInside(Vector3.new(entry.x, entry.y, entry.z), entry, exit, mySerial)
		if stage ~= mySerial or warnAndCheckBoard(entry, exit) then
			return
		end
		local exitWall = Vector3.new(exit.x, exit.y, exit.z)
		local mouthOut = vector(WormTunnel.mouth(exit))
		local outward = Vector3.new(exit.nx, 0, 0)
		for i = 1, 12 do
			local k = i / 12
			CreatureService.scriptPlace(exitWall:Lerp(mouthOut, k) - Vector3.new(0, (1 - k) * 7, 0), outward)
			task.wait(0.05)
		end
		dives += 1
		log.info("tunnel %s -> %s", entry.id, exit.id)
	end)
	if not ok then
		log.warn("dive failed: %s", tostring(err))
	end
	if stage == mySerial then
		CreatureService.setFrozen(false)
		-- Sai farejando: vai atrás do barulho mais perto da saída.
		local nearest: Vector3? = nil
		local best = math.huge
		for _, p in activePoints() do
			local d = (vector(p) - Vector3.new(exit.x, exit.y, exit.z)).Magnitude
			if d < best then
				best, nearest = d, vector(p)
			end
		end
		if nearest and best < 60 then
			CreatureService.makeNoise(nearest, 40)
		end
	end
	nextDiveAt = os.clock() + rng:NextNumber(30, 50)
	busy = false
end

local function onFloor(y: number): boolean
	return math.abs(y - math.floor(y / 16 + 0.5) * 16) < 1.5
end

local function tick()
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	if not campaign then
		return
	end
	local current = (tonumber(campaign:GetAttribute("Stage")) or 0) :: number
	if current ~= stage then
		stage, stageAt = current, os.clock()
		nextDiveAt = stageAt + FIRST_DIVE
		rebuild(current)
	end
	if busy or campaign:GetAttribute("Phase") ~= "Playing" or os.clock() < nextDiveAt then
		return
	end
	local holes = WormTunnel.holes(current)
	if #holes < 2 or not CreatureService.isActive() then
		return
	end
	local state = CreatureService.state()
	if state.frozen or (state.holdOff :: number) > 0 or state.seeing or state.mode == "Search" then
		return
	end
	-- Na folga do diretor de tensão ele se afasta; nas outras fases o túnel é a forma de voltar até vocês.
	if TensionDirector.phase() == "Relax" then
		return
	end
	local tungAt = state.position :: Vector3
	local tung = { x = tungAt.X, y = tungAt.Y, z = tungAt.Z }
	local players = activePoints()
	for _, p in players do
		-- Só vale a pena (e só é justo) quando ninguém está perto dele no mesmo andar.
		local flat = Vector3.new(p.x - tungAt.X, 0, p.z - tungAt.Z).Magnitude
		if math.abs(p.y - tungAt.Y) < 6 and flat < FAR_ENOUGH then
			return
		end
	end
	local now = workspace:GetServerTimeNow()
	local entry = WormTunnel.entry(holes, tung, boarded, now)
	if entry and not clearPath(tungAt, vector(WormTunnel.mouth(entry))) then
		entry = nil
	end
	-- Sem buraco à mão: cava o chão onde está (no meio da escada, não).
	if not entry then
		if not onFloor(tungAt.Y) then
			return
		end
		entry = WormTunnel.burrow(tung)
	end
	local exit = WormTunnel.exit(holes, entry :: WormTunnel.Hole, players, boarded, now)
	if not exit then
		return
	end
	task.spawn(dive, entry :: WormTunnel.Hole, exit)
end

-- Momento roteirizado: ele cava o chão agora e sai no buraco mais perto de `player` (ignora o relógio).
function TunnelService.force(player: Player): boolean
	local holes = WormTunnel.holes(stage)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if busy or #holes < 2 or not CreatureService.isActive() or not root or not root:IsA("BasePart") then
		return false
	end
	local state = CreatureService.state()
	if state.frozen then
		return false
	end
	local now = workspace:GetServerTimeNow()
	local feet = { x = root.Position.X, y = root.Position.Y - 3, z = root.Position.Z }
	local exit = WormTunnel.nearestTo(holes, feet, boarded, now)
	if not exit then
		return false
	end
	local tungAt = state.position :: Vector3
	task.spawn(dive, WormTunnel.burrow({ x = tungAt.X, y = tungAt.Y, z = tungAt.Z }), exit)
	return true
end

-- Depuração: quantas viagens completas neste servidor e quando é a próxima.
function TunnelService.stats(): { [string]: any }
	return { dives = dives, busy = busy, nextIn = nextDiveAt - os.clock(), stage = stage }
end
-- Interação "tunnel_<id>": prega a tábua (faz barulho; ele ouve).
function TunnelService.board(player: Player, id: string): { accepted: boolean, message: string }
	local holeId = string.sub(id, 8)
	local model = models[holeId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not model or not model.PrimaryPart or not root or not root:IsA("BasePart") then
		return { accepted = false, message = "not_available" }
	end
	if (root.Position - model.PrimaryPart.Position).Magnitude > 12 then
		return { accepted = false, message = "too_far" }
	end
	local now = workspace:GetServerTimeNow()
	if (boarded[holeId] or 0) > now then
		return { accepted = false, message = "not_available" }
	end
	boarded[holeId] = now + WormTunnel.BOARD_SECONDS
	setBoarded(holeId, true)
	sound(model.PrimaryPart, Audio.HammerNail, 1.2, 1)
	CreatureService.makeNoise(model.PrimaryPart.Position, 45)
	DifficultyService.unlock(player, "tabua")
	task.delay(WormTunnel.BOARD_SECONDS, function()
		if (boarded[holeId] or 0) <= workspace:GetServerTimeNow() + 0.1 and models[holeId] == model then
			setBoarded(holeId, false)
		end
	end)
	return { accepted = true, message = "boarded" }
end

function TunnelService.Start()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < TICK then
			return
		end
		clock = 0
		local ok: boolean, err: any = pcall(tick)
		if not ok then
			log.warn("tick failed: %s", tostring(err))
		end
	end)
end

return TunnelService
