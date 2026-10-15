--!strict
--[[
	Monta no mundo as novidades do polish (dados em Features.luau). Chamado pelo WorldService
	DEPOIS do MapBuilder.build, dentro de Workspace.Substation9.Features. Não mexe em paredes.

	Devolve handles para o WorldService/PropService: interagíveis novos (chave, pilhas, armários,
	disjuntores, procedimento), armários, disjuntores e objetos que caem.
]]

local CollectionService = game:GetService("CollectionService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Build = require("./Build")
local Features = require("./Features")
local Layout = require("./Layout")
local Palette = require("./Palette")

export type Interactable = {
	id: string,
	kind: string,
	focus: BasePart,
	model: Instance,
	maxDistance: number,
	enabled: boolean,
}

export type LockerHandle = {
	id: string,
	model: Model,
	door: BasePart,
	doorClosed: CFrame,
	hinge: CFrame,
	inside: CFrame,
	eye: CFrame,
	exit: CFrame,
	front: Vector3,
	sound: Sound,
	occupant: Player?,
}

export type BreakerHandle = {
	box: BasePart,
	levers: { BasePart },
	down: { CFrame },
	up: { CFrame },
	lamps: { BasePart },
	toggle: Sound,
	fail: Sound,
	solved: Sound,
	diagram: TextLabel,
}

export type FallableHandle = {
	id: string,
	kind: string,
	model: Model,
	primary: BasePart,
	home: { [BasePart]: CFrame },
	fall: Vector3,
	fallen: boolean,
	sound: Sound,
}

export type Built = {
	root: Folder,
	interactables: { [string]: Interactable },
	keys: { [string]: Model },
	batteries: { [string]: Model },
	lockers: { [string]: LockerHandle },
	breakers: BreakerHandle,
	fallables: { FallableHandle },
	radio: BasePart,
}

local V3 = Vector3.new
local FeatureBuilder = {}

local function vec(p: Features.Point): Vector3
	return V3(p.x, p.y, p.z)
end

local function register(
	built: Built,
	id: string,
	kind: string,
	focus: BasePart,
	model: Instance,
	prompt: string,
	distance: number?
)
	local maxDistance = distance or Config.Game.InteractDistance
	focus:SetAttribute(Tags.Attr.InteractId, id)
	focus:SetAttribute(Tags.Attr.InteractPrompt, prompt)
	focus:SetAttribute(Tags.Attr.InteractDistance, maxDistance)
	focus:SetAttribute(Tags.Attr.InteractEnabled, true)
	CollectionService:AddTag(focus, Tags.Interactable)
	built.interactables[id] = {
		id = id,
		kind = kind,
		focus = focus,
		model = model,
		maxDistance = maxDistance,
		enabled = true,
	}
end

local function clip(part: Instance, name: string, clipName: string, speed: number?, looped: boolean?): Sound
	local c = Audio[clipName]
	assert(c, `[FeatureBuilder] unknown clip {clipName}`)
	local sound = Build.sound(part, name, c.id, c.volume, speed or c.speed, looped)
	if c.region then
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(c.region[1], c.region[2])
	end
	return sound
end

-- Armário de metal oco com frestas na porta (o jogador cabe dentro, de pé).
local function buildLocker(built: Built, parent: Instance, spec: Features.Locker)
	local base = vec(spec.base)
	local front = vec(spec.front).Unit
	local frame = CFrame.lookAt(base, base + front)
	local W, H, D = 2.8, 7.4, 2.6
	local model = Build.model(parent, spec.id)
	local function local3(x: number, y: number, z: number): CFrame
		-- z negativo = para a frente (LookVector).
		return frame * CFrame.new(x, y, z)
	end
	local color = Palette.WallLowerCold
	local metal = { material = Enum.Material.Metal }
	Build.part(model, "Back", V3(W, H, 0.2), local3(0, H / 2, D / 2 - 0.1), color, metal)
	Build.part(model, "Left", V3(0.2, H, D), local3(-W / 2 + 0.1, H / 2, 0), color, metal)
	Build.part(model, "Right", V3(0.2, H, D), local3(W / 2 - 0.1, H / 2, 0), color, metal)
	Build.part(model, "Top", V3(W, 0.2, D), local3(0, H - 0.1, 0), color, metal)
	Build.part(model, "Floor", V3(W, 0.2, D), local3(0, 0.1, 0), Palette.MetalDark, metal)
	Build.part(model, "Label", V3(1.2, 0.35, 0.05), local3(0, H - 0.6, -D / 2 - 0.08), Palette.Paper, {
		collide = false,
	})

	-- Porta (folha que gira na dobradiça da esquerda). Frestas = vãos entre as faixas.
	local doorClosed = local3(0, H / 2, -D / 2 + 0.06)
	local door = Build.part(model, "Door", V3(W - 0.1, H - 0.1, 0.14), doorClosed, color, metal)
	door.Transparency = 1 -- a folha "lógica" fica invisível; as faixas abaixo formam a porta visível
	door.CanCollide = true
	-- Vãos (frestas) em 4.05-4.2, 4.45-4.65 (altura do olho) e 4.9-5.05.
	local slats: { { y0: number, y1: number } } = {
		{ y0 = 0.05, y1 = 4.05 },
		{ y0 = 4.2, y1 = 4.45 },
		{ y0 = 4.65, y1 = 4.9 },
		{ y0 = 5.05, y1 = 7.3 },
	}
	for _, s in slats do
		local h = s.y1 - s.y0
		local slat = Build.part(
			model,
			"Slat",
			V3(W - 0.1, h, 0.12),
			local3(0, s.y0 + h / 2, -D / 2 + 0.06),
			color,
			{ material = Enum.Material.Metal, collide = false }
		)
		slat.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = door
		weld.Part1 = slat
		weld.Parent = door
	end
	local handle = Build.part(
		model,
		"Handle",
		V3(0.12, 0.7, 0.12),
		local3(W / 2 - 0.4, 3.6, -D / 2 - 0.05),
		Palette.Metal,
		{ collide = false }
	)
	handle.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = door
	weld.Part1 = handle
	weld.Parent = door
	-- As frestas deixam a luz de dentro para fora... e a de fora para dentro: escuro lá dentro.
	door.CanQuery = true

	local hinge = local3(-W / 2 + 0.1, H / 2, -D / 2 + 0.06)
	local inside = CFrame.lookAt(base + V3(0, 3.1, 0) + front * 0.1, base + V3(0, 3.1, 0) + front * 5)
	-- Olho perto da porta: as frestas viram faixas largas de visão.
	local eyePosition = base + V3(0, 4.55, 0) + front * 0.85
	built.lockers[spec.id] = {
		id = spec.id,
		model = model,
		door = door,
		doorClosed = doorClosed,
		hinge = hinge,
		inside = inside,
		eye = CFrame.lookAt(eyePosition, eyePosition + front),
		exit = CFrame.lookAt(base + front * (D / 2 + 1.8) + V3(0, 3.1, 0), base + front * 10 + V3(0, 3.1, 0)),
		front = base + front * (D / 2 + 0.8),
		sound = clip(door, "Latch", "LockerLatch"),
		occupant = nil,
	}
	register(built, spec.id, "Hide", door, model, Text.Prompts.Hide, 6)
end

local function buildKey(built: Built, parent: Instance, spot: Features.Spot)
	local p = vec(spot.position)
	local model = Build.model(parent, spot.id)
	-- Quadro de chaves na parede atrás (aponta para o lado do jogador).
	local standDir = (vec(spot.stand) - V3(p.X, 0, p.Z))
	local facing = V3(standDir.X, 0, standDir.Z).Unit
	local board = Build.part(
		model,
		"KeyBoard",
		V3(1.6, 1.3, 0.08),
		CFrame.lookAt(p - facing * 0.12 + V3(0, 0.15, 0), p - facing * 0.12 + V3(0, 0.15, 0) + facing),
		Palette.WoodDark,
		{ collide = false }
	)
	board.CanQuery = false
	local frame = CFrame.lookAt(p, p + facing)
	local bow = Build.part(model, "Bow", V3(0.32, 0.32, 0.06), frame * CFrame.new(0, 0.18, 0), Palette.Brass, {
		collide = false,
		material = Enum.Material.Metal,
	})
	Build.part(model, "Blade", V3(0.08, 0.5, 0.05), frame * CFrame.new(0, -0.18, 0), Palette.Brass, {
		collide = false,
		material = Enum.Material.Metal,
	})
	Build.part(model, "Tag", V3(0.34, 0.2, 0.02), frame * CFrame.new(0.28, 0.02, 0.01), Palette.Red, {
		collide = false,
	})
	model.PrimaryPart = bow
	built.keys[spot.id] = model
	register(built, spot.id, "Key", bow, model, Text.Prompts.Key, 7)
end

local function buildBattery(built: Built, parent: Instance, spot: Features.Spot)
	local p = vec(spot.position)
	local model = Build.model(parent, spot.id)
	local pack = Build.part(model, "Pack", V3(0.7, 0.18, 0.5), CFrame.new(p), Palette.Ceramic, { collide = false })
	for _, dx in { -0.16, 0.16 } do
		Build.cylinder(
			model,
			"Cell",
			p + V3(dx, 0.17, 0),
			Vector3.xAxis,
			0.55,
			0.22,
			Palette.Hazard,
			{ collide = false, material = Enum.Material.Metal }
		)
	end
	model.PrimaryPart = pack
	built.batteries[spot.id] = model
	register(built, spot.id, "Battery", pack, model, Text.Prompts.Battery, 7)
end

local function buildBreakers(built: Built, parent: Instance)
	local spec = Features.Breakers
	local center = vec(spec.box)
	local model = Build.model(parent, "Breakers")
	-- A caixa fica na parede norte (frente para +Z, sala do gerador).
	local facing = Vector3.zAxis
	local box = Build.part(model, "Box", V3(4.6, 3.4, 0.6), CFrame.new(center), Palette.Metal, {
		material = Enum.Material.Metal,
	})
	Build.part(model, "Frame", V3(4.9, 3.7, 0.4), CFrame.new(center - facing * 0.15), Palette.MetalDark)
	local sign = Build.sign(
		model,
		"Title",
		center + V3(0, 2.35, 0.32),
		facing,
		Vector2.new(4.6, 0.7),
		"DISJUNTORES",
		{ textColor = Palette.Black, background = Palette.Hazard }
	)
	sign.CanQuery = false
	local levers: { BasePart } = {}
	local down: { CFrame } = {}
	local up: { CFrame } = {}
	local lamps: { BasePart } = {}
	for i = 1, Config.Puzzle.Breakers do
		local x = center.X + (i - 2) * spec.spacing
		local pivot = CFrame.new(x, center.Y - 0.2, center.Z + 0.45)
		local downCFrame = pivot * CFrame.Angles(math.rad(35), 0, 0) * CFrame.new(0, -0.45, 0)
		local upCFrame = pivot * CFrame.Angles(math.rad(-35), 0, 0) * CFrame.new(0, 0.45, 0)
		local lever = Build.part(model, `Lever{i}`, V3(0.36, 1.1, 0.36), downCFrame, Palette.Red, {
			collide = false,
		})
		lever.CanQuery = true
		Build.part(
			model,
			"Slot",
			V3(0.5, 1.6, 0.06),
			CFrame.new(x, center.Y - 0.2, center.Z + 0.31),
			Palette.Black,
			{ collide = false }
		)
		local letter = Build.sign(
			model,
			"Letter",
			V3(x, center.Y - 1.35, center.Z + 0.32),
			facing,
			Vector2.new(0.6, 0.5),
			string.char(64 + i),
			{ textColor = Palette.Paper, background = Palette.Black }
		)
		letter.CanQuery = false
		local lamp = Build.part(
			model,
			`Lamp{i}`,
			V3(0.4, 0.4, 0.2),
			CFrame.new(x, center.Y + 1.15, center.Z + 0.36),
			Palette.LampOff,
			{ collide = false, material = Enum.Material.SmoothPlastic }
		)
		lamp.CanQuery = false
		table.insert(levers, lever)
		table.insert(down, downCFrame)
		table.insert(up, upCFrame)
		table.insert(lamps, lamp)
		register(
			built,
			`breaker_{i}`,
			"Breaker",
			lever,
			model,
			string.format(Text.Prompts.Breaker, string.char(64 + i)),
			6
		)
	end

	-- Procedimento (prancheta com a ordem da rodada). O texto vem do servidor a cada rodada.
	local noteSpec = Features.BreakerNote
	local np = vec(noteSpec.position)
	local clipboard = Build.part(model, noteSpec.id, V3(1.5, 2, 0.08), CFrame.new(np), Palette.WoodDark)
	local paper = Build.sign(
		model,
		"Procedure",
		np + V3(0, -0.1, 0.06),
		facing,
		Vector2.new(1.3, 1.6),
		"RELIGAMENTO",
		{ textColor = Palette.Black, background = Palette.Paper, font = Enum.Font.SpecialElite, pixelsPerStud = 60 }
	)
	paper.CanQuery = false
	local gui = paper:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	assert(label, "procedure label")
	register(built, noteSpec.id, "Note", clipboard, clipboard, Text.Prompts.Procedure, 6)

	built.breakers = {
		box = box,
		levers = levers,
		down = down,
		up = up,
		lamps = lamps,
		toggle = clip(box, "Toggle", "BreakerToggle"),
		fail = clip(box, "Fail", "BreakerFail"),
		solved = clip(box, "Solved", "Switch", 0.85),
		diagram = label,
	}
end

-- Monta um objeto que cai (peças soldadas a uma peça principal, ancorada até cair).
local function buildFallable(built: Built, parent: Instance, spec: Features.Fallable)
	local p = vec(spec.position)
	local model = Build.model(parent, spec.id)
	local parts: { BasePart } = {}
	local function add(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): BasePart
		local part = Build.part(model, name, size, cframe, color, { material = material })
		table.insert(parts, part)
		return part
	end
	local primary: BasePart
	if spec.kind == "bucket" then
		primary = Build.cylinder(model, "Bucket", p + V3(0, 0.75, 0), Vector3.yAxis, 1.5, 1.3, Palette.Metal, {
			material = Enum.Material.Metal,
		})
		table.insert(parts, primary)
		add("Mop", V3(0.15, 4.2, 0.15), CFrame.new(p + V3(0.2, 2.6, 0)) * CFrame.Angles(0, 0, 0.25), Palette.WoodDark)
	elseif spec.kind == "cans" then
		primary = add("Can", V3(0.8, 1, 0.8), CFrame.new(p + V3(0, 0.5, 0)), Palette.Red, Enum.Material.Metal)
		add("Can", V3(0.8, 1, 0.8), CFrame.new(p + V3(0.85, 0.5, 0.1)), Palette.Hazard, Enum.Material.Metal)
		add("Can", V3(0.8, 1, 0.8), CFrame.new(p + V3(0.4, 1.5, 0.05)), Palette.Metal, Enum.Material.Metal)
	elseif spec.kind == "bottles" then
		primary = add("Crate", V3(1.6, 0.7, 1.2), CFrame.new(p + V3(0, 0.35, 0)), Palette.WoodDark)
		for i = 0, 3 do
			add(
				"Bottle",
				V3(0.25, 0.9, 0.25),
				CFrame.new(p + V3(-0.5 + i * 0.33, 1.15, (i % 2) * 0.3 - 0.15)),
				Palette.Screen,
				Enum.Material.Glass
			)
		end
	elseif spec.kind == "pipes" then
		primary =
			add("Pipe", V3(0.5, 7, 0.5), CFrame.new(p + V3(0, 3.4, 0.6)) * CFrame.Angles(0.18, 0, 0), Palette.Rust)
		add("Pipe", V3(0.5, 6.4, 0.5), CFrame.new(p + V3(0.7, 3.1, 0.6)) * CFrame.Angles(0.2, 0, 0.05), Palette.Rust)
		add(
			"Pipe",
			V3(0.4, 6.8, 0.4),
			CFrame.new(p + V3(-0.6, 3.3, 0.6)) * CFrame.Angles(0.17, 0, -0.04),
			Palette.Metal
		)
	elseif spec.kind == "extinguisher" then
		Build.part(model, "Bracket", V3(0.9, 0.3, 0.3), CFrame.new(p + V3(0, 1.6, -0.15)), Palette.MetalDark)
		primary = Build.cylinder(model, "Extinguisher", p + V3(0, 0.9, 0.15), Vector3.yAxis, 1.8, 0.6, Palette.Red, {
			material = Enum.Material.Metal,
		})
		table.insert(parts, primary)
		add("Nozzle", V3(0.2, 0.35, 0.2), CFrame.new(p + V3(0, 1.95, 0.15)), Palette.Black)
	else
		primary = add("Box", V3(1.5, 1.1, 1.1), CFrame.new(p + V3(0, 0.55, 0)), Palette.Gravel)
		add("Papers", V3(1.2, 0.3, 0.9), CFrame.new(p + V3(0, 1.25, 0)), Palette.Paper)
	end
	local home: { [BasePart]: CFrame } = {}
	for _, part in parts do
		home[part] = part.CFrame
		part.CanTouch = false
		if part ~= primary then
			part.Anchored = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = primary
			w.Part1 = part
			w.Parent = primary
		end
	end
	model.PrimaryPart = primary
	model:SetAttribute("Fallen", false)
	table.insert(built.fallables, {
		id = spec.id,
		kind = spec.kind :: string,
		model = model,
		primary = primary,
		home = home,
		fall = vec(spec.fall),
		fallen = false,
		sound = clip(primary, "Impact", `Fall_{spec.kind}`),
	})
end

local function buildSurfaces(parent: Instance)
	for _, rect in Features.WoodFloors do
		-- Tábuas em faixas alternadas (madeira velha), 0.06 acima do piso.
		local width = 2
		local index = 0
		local x = rect.x0
		while x < rect.x1 - 0.01 do
			local x1 = math.min(rect.x1, x + width)
			local plank = Build.box(
				parent,
				"Floorboards",
				V3(x, 0, rect.z0),
				V3(x1, 0.06, rect.z1),
				if index % 2 == 0 then Palette.Wood else Palette.WoodDark,
				{ material = Enum.Material.WoodPlanks }
			)
			plank:SetAttribute("Surface", "wood")
			index += 1
			x = x1
		end
	end
	for i, p in Features.Puddles do
		local puddle = Build.part(
			parent,
			"Puddle",
			V3(p.sx, 0.04, p.sz),
			CFrame.new(p.x, 0.08, p.z) * CFrame.Angles(0, i * 0.7, 0),
			Palette.Screen,
			{ collide = false, reflectance = 0.35 }
		)
		puddle.CanQuery = false
	end
	for _, d in Features.Drips do
		local emitter = Build.part(
			parent,
			"Drip",
			V3(0.3, 0.3, 0.3),
			CFrame.new(d.x, d.y, d.z),
			Palette.MetalDark,
			{ collide = false }
		)
		emitter.Transparency = 1
		emitter.CanQuery = false
		local sound = clip(emitter, "Drips", "Drips", nil, true)
		sound.RollOffMaxDistance = 40
		sound.Playing = true
	end
end

-- Moldura, grade arrancada e cabos do vão baixo (a abertura em si é do Layout).
local function buildCrawl(parent: Instance)
	local c = Features.Crawl
	local x, z, w, top = c.wallX, c.centerZ, c.width, c.top
	local model = Build.model(parent, "CrawlDuct")
	for _, side in { -1, 1 } do
		Build.part(model, "Jamb", V3(1.2, top, 0.25), CFrame.new(x, top / 2, z + side * (w / 2 + 0.12)), Palette.Hazard)
	end
	Build.part(model, "Lintel", V3(1.2, 0.3, w + 0.5), CFrame.new(x, top + 0.15, z), Palette.Hazard)
	-- Grade caída no chão do lado do gerador.
	local grate = Build.part(
		model,
		"Grate",
		V3(0.15, 2.6, w - 0.4),
		CFrame.new(x - 2.2, 0.35, z + 0.3) * CFrame.Angles(0, 0, math.rad(80)),
		Palette.MetalDark,
		{ collide = false, material = Enum.Material.DiamondPlate }
	)
	grate.CanQuery = false
	-- Cabos pendurados no vão.
	for i = -1, 1 do
		Build.cylinder(
			model,
			"Cable",
			V3(x, top - 0.25, z + i * 0.9),
			Vector3.xAxis,
			1.4,
			0.18,
			Palette.Black,
			{ collide = false, query = false }
		)
	end
	for _, side in { -1, 1 } do
		local s = Build.sign(
			model,
			"CrawlSign",
			V3(x + side * 0.63, top + 0.9, z),
			V3(side, 0, 0),
			Vector2.new(2.8, 0.6),
			"DUTO DE CABOS",
			{ textColor = Palette.Black, background = Palette.Hazard, thickness = 0.05 }
		)
		s.CanQuery = false
	end
end

local function buildRadio(parent: Instance): BasePart
	local p = vec(Features.Radio)
	local model = Build.model(parent, "GuardRadio")
	local body = Build.part(model, "Radio", V3(1.1, 0.7, 0.45), CFrame.new(p + V3(0, 0.35, 0)), Palette.MetalDark)
	Build.part(model, "Antenna", V3(0.06, 1.1, 0.06), CFrame.new(p + V3(0.4, 1.2, 0)), Palette.Black, {
		collide = false,
	})
	local led = Build.part(model, "Led", V3(0.1, 0.1, 0.05), CFrame.new(p + V3(-0.35, 0.55, 0.23)), Palette.Red, {
		collide = false,
		material = Enum.Material.Neon,
	})
	led:SetAttribute("Indicator", "Blink")
	CollectionService:AddTag(led, "Indicator")
	return body
end

-- Ponteiros e LEDs animados pelo cliente (a 12 Hz, em passos).
local function buildIndicators(parent: Instance)
	local model = Build.model(parent, "Indicators")
	local function gauge(center: Vector3, facing: Vector3, kind: string)
		local frame = CFrame.lookAt(center, center + facing)
		Build.cylinder(model, "GaugeFace", center, facing, 0.06, 0.9, Palette.Paper, { collide = false, query = false })
		Build.cylinder(
			model,
			"GaugeRim",
			center - facing * 0.03,
			facing,
			0.08,
			1.05,
			Palette.MetalDark,
			{ collide = false, query = false }
		)
		local needle = Build.part(
			model,
			"Needle",
			V3(0.05, 0.38, 0.03),
			frame * CFrame.new(0, 0.15, -0.05),
			Palette.Red,
			{ collide = false, query = false }
		)
		needle:SetAttribute("Indicator", kind)
		needle:SetAttribute("Pivot", frame * CFrame.new(0, 0, -0.05))
		CollectionService:AddTag(needle, "Indicator")
	end
	-- Gerador (caixa de controle) e bomba 1.
	gauge(V3(-24.5, 6.1, -39.16), -Vector3.zAxis, "GaugeGenerator")
	gauge(V3(16.56, 4.2, -10), Vector3.xAxis, "GaugePump")
	-- LEDs de status ao lado do quadro: piscam em vermelho sem energia, verde com energia.
	for i = 1, 3 do
		local led = Build.part(
			model,
			"PanelLed",
			V3(0.18, 0.18, 0.06),
			CFrame.new(-13.4, 6.4 - i * 0.35, -48.67),
			Palette.Red,
			{ collide = false, query = false, material = Enum.Material.Neon }
		)
		led:SetAttribute("Indicator", "PanelLed")
		led:SetAttribute("Index", i)
		CollectionService:AddTag(led, "Indicator")
	end
end

-- Zonas (uma por sala do Layout): o cliente escolhe reverb e "onde estou" por elas.
local function buildZones(parent: Instance)
	local folder = Build.folder(parent, "Zones")
	for _, room in Layout.Rooms do
		local zone = Build.box(
			folder,
			room.id,
			V3(room.x0, 0, room.z0),
			V3(room.x1, Layout.CEILING, room.z1),
			Palette.Black,
			{ transparency = 1, collide = false, query = false }
		)
		zone.CanTouch = false
		zone:SetAttribute("Room", room.id)
		zone:SetAttribute("Reverb", Features.Reverb[room.id] or "Room")
	end
end

function FeatureBuilder.build(parent: Instance): Built
	local root = Build.folder(parent, "Features")
	local built: Built = {
		root = root,
		interactables = {},
		keys = {},
		batteries = {},
		lockers = {},
		breakers = nil :: any,
		fallables = {},
		radio = nil :: any,
	}
	local lockers = Build.folder(root, "Lockers")
	for _, spec in Features.Lockers do
		buildLocker(built, lockers, spec)
	end
	local pickups = Build.folder(root, "Pickups")
	for _, spot in Features.KeySpots do
		buildKey(built, pickups, spot)
	end
	for _, spot in Features.BatterySpots do
		buildBattery(built, pickups, spot)
	end
	buildBreakers(built, root)
	local fallables = Build.folder(root, "Fallables")
	for _, spec in Features.Fallables do
		buildFallable(built, fallables, spec)
	end
	buildSurfaces(Build.folder(root, "Surfaces"))
	buildCrawl(root)
	built.radio = buildRadio(root)
	buildIndicators(root)
	buildZones(root)
	return built
end

return FeatureBuilder
