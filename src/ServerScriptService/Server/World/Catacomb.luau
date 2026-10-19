--!strict
--[[
	Catacumba e capela embaixo do jardim leste (dados em Shared/Game/CatacombLayout).
	A casa e o solo são peças inteiras; para abrir o túnel, cada peça que cruza um espaço é trocada por até seis
	caixas que cobrem tudo menos o vão (a original fica guardada e volta quando o capítulo fecha o túnel).
	Por dentro, o espaço ganha piso, paredes e teto próprios (pedra), escoras, raízes, marcas de garra, brinquedos
	velhos, nichos com crânios, velas, a capela com bancos e altar, e uma grade que só abre no capítulo 5.
]]

local ServerStorage = game:GetService("ServerStorage")

local Layout = require("@game/ReplicatedStorage/Shared/Game/CatacombLayout")
local Build = require("./Build")

local Catacomb = {}

type Box = Layout.Box

local STONE = Color3.fromRGB(74, 70, 64)
local DARK_STONE = Color3.fromRGB(52, 49, 45)
local SOIL = Color3.fromRGB(58, 46, 34)
local WOOD = Color3.fromRGB(70, 52, 36)
local BONE = Color3.fromRGB(206, 196, 170)
local CLOTH = Color3.fromRGB(110, 22, 24)

type Carved = { original: Instance, parent: Instance, pieces: { BasePart } }
-- Por raiz: a casa da partida e a casa de teste (fixture) não se misturam.
local carvedByRoot: { [Instance]: { Carved } } = {}
local stash: Folder? = nil

local function holder(): Folder
	if stash and stash.Parent then
		return stash
	end
	local f = Instance.new("Folder")
	f.Name = "CatacombOriginals"
	f.Parent = ServerStorage
	stash = f
	return f
end

local function expand(b: Box, m: number): Box
	return { x0 = b.x0 - m, x1 = b.x1 + m, y0 = b.y0 - m, y1 = b.y1 + m, z0 = b.z0 - m, z1 = b.z1 + m }
end

local function center(b: Box): Vector3
	return Vector3.new((b.x0 + b.x1) / 2, (b.y0 + b.y1) / 2, (b.z0 + b.z1) / 2)
end

local function size(b: Box): Vector3
	return Vector3.new(b.x1 - b.x0, b.y1 - b.y0, b.z1 - b.z0)
end

local function aligned(part: BasePart): boolean
	if part:IsA("Part") and (part :: Part).Shape ~= Enum.PartType.Block then
		return false
	end
	local r = part.CFrame.Rotation
	local function axis(v: Vector3): boolean
		return math.abs(math.abs(v.X) + math.abs(v.Y) + math.abs(v.Z) - 1) < 1e-3
			and (math.abs(v.X) > 0.999 or math.abs(v.Y) > 0.999 or math.abs(v.Z) > 0.999)
	end
	return axis(r.XVector) and axis(r.YVector) and axis(r.ZVector)
end

local function bounds(part: BasePart): Box
	local cf, s = part.CFrame, part.Size
	local half = Vector3.new(
		math.abs(cf.XVector.X) * s.X + math.abs(cf.YVector.X) * s.Y + math.abs(cf.ZVector.X) * s.Z,
		math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z,
		math.abs(cf.XVector.Z) * s.X + math.abs(cf.YVector.Z) * s.Y + math.abs(cf.ZVector.Z) * s.Z
	) / 2
	local p = cf.Position
	return {
		x0 = p.X - half.X,
		x1 = p.X + half.X,
		y0 = p.Y - half.Y,
		y1 = p.Y + half.Y,
		z0 = p.Z - half.Z,
		z1 = p.Z + half.Z,
	}
end

local function overlaps(a: Box, b: Box): boolean
	return a.x0 < b.x1 and a.x1 > b.x0 and a.y0 < b.y1 and a.y1 > b.y0 and a.z0 < b.z1 and a.z1 > b.z0
end

-- Caixa A menos a caixa B: até seis pedaços (esquerda/direita em x, embaixo/em cima em y, frente/trás em z).
local function subtract(a: Box, b: Box): { Box }
	local i = {
		x0 = math.max(a.x0, b.x0),
		x1 = math.min(a.x1, b.x1),
		y0 = math.max(a.y0, b.y0),
		y1 = math.min(a.y1, b.y1),
		z0 = math.max(a.z0, b.z0),
		z1 = math.min(a.z1, b.z1),
	}
	local out: { Box } = {}
	local function add(box: Box)
		if box.x1 - box.x0 > 0.05 and box.y1 - box.y0 > 0.05 and box.z1 - box.z0 > 0.05 then
			table.insert(out, box)
		end
	end
	add({ x0 = a.x0, x1 = i.x0, y0 = a.y0, y1 = a.y1, z0 = a.z0, z1 = a.z1 })
	add({ x0 = i.x1, x1 = a.x1, y0 = a.y0, y1 = a.y1, z0 = a.z0, z1 = a.z1 })
	add({ x0 = i.x0, x1 = i.x1, y0 = a.y0, y1 = i.y0, z0 = a.z0, z1 = a.z1 })
	add({ x0 = i.x0, x1 = i.x1, y0 = i.y1, y1 = a.y1, z0 = a.z0, z1 = a.z1 })
	add({ x0 = i.x0, x1 = i.x1, y0 = i.y0, y1 = i.y1, z0 = a.z0, z1 = i.z0 })
	add({ x0 = i.x0, x1 = i.x1, y0 = i.y0, y1 = i.y1, z0 = i.z1, z1 = a.z1 })
	return out
end

-- Recorta `boxes` de todas as peças fixas e alinhadas da casa (paredes, solo). Móveis soltos no caminho vão para o
-- depósito também (o caixote encostado na parede).
local function carve(root: Instance, boxes: { Box })
	local carved: { Carved } = carvedByRoot[root] or {}
	carvedByRoot[root] = carved
	local victims: { BasePart } = {}
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") and d.Anchored and d:GetAttribute("CatacombPiece") == nil then
			local b = bounds(d)
			for _, box in boxes do
				if overlaps(b, box) then
					table.insert(victims, d)
					break
				end
			end
		end
	end
	local movedProps: { [Instance]: boolean } = {}
	for _, part in victims do
		-- Móvel no caminho: guarda o modelo inteiro (não só a peça que encosta no vão).
		local props = part:FindFirstAncestor("Props")
		if props then
			local top: Instance = part
			while top.Parent and top.Parent ~= props do
				top = top.Parent :: Instance
			end
			if not movedProps[top] then
				movedProps[top] = true
				table.insert(carved, { original = top, parent = props, pieces = {} })
				top.Parent = holder()
			end
			continue
		end
		local record: Carved = { original = part, parent = part.Parent :: Instance, pieces = {} }
		if aligned(part) and part:IsA("Part") then
			local remaining = { bounds(part) }
			for _, box in boxes do
				local nextList: { Box } = {}
				for _, piece in remaining do
					if overlaps(piece, box) then
						for _, rest in subtract(piece, box) do
							table.insert(nextList, rest)
						end
					else
						table.insert(nextList, piece)
					end
				end
				remaining = nextList
			end
			for _, piece in remaining do
				local copy = part:Clone()
				for _, child in copy:GetChildren() do
					if not child:IsA("Texture") then
						child:Destroy()
					end
				end
				copy.Size = size(piece)
				copy.CFrame = CFrame.new(center(piece))
				copy:SetAttribute("CatacombPiece", true)
				copy.Parent = record.parent
				table.insert(record.pieces, copy)
			end
		end
		part.Parent = holder()
		table.insert(carved, record)
	end
end

local function restore(root: Instance)
	local carved: { Carved } = carvedByRoot[root] or {}
	carvedByRoot[root] = nil
	for _, record in carved do
		for _, piece in record.pieces do
			piece:Destroy()
		end
		if record.parent.Parent then
			record.original.Parent = record.parent
		else
			record.original:Destroy()
		end
	end
end

local function block(parent: Instance, name: string, b: Box, color: Color3, material: Enum.Material, collide: boolean?)
	local p = Build.part(parent, name, size(b), CFrame.new(center(b)), color, {
		material = material,
		collide = if collide == nil then true else collide,
	})
	p:SetAttribute("CatacombPiece", true)
	return p
end

local function candle(parent: Instance, at: Vector3, tall: number?)
	local h = tall or 0.9
	block(
		parent,
		"Candle",
		{ x0 = at.X - 0.18, x1 = at.X + 0.18, y0 = at.Y, y1 = at.Y + h, z0 = at.Z - 0.18, z1 = at.Z + 0.18 },
		Color3.fromRGB(226, 214, 186),
		Enum.Material.SmoothPlastic,
		false
	)
	local flame = block(
		parent,
		"Flame",
		{ x0 = at.X - 0.08, x1 = at.X + 0.08, y0 = at.Y + h, y1 = at.Y + h + 0.3, z0 = at.Z - 0.08, z1 = at.Z + 0.08 },
		Color3.fromRGB(255, 170, 70),
		Enum.Material.Neon,
		false
	)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 160, 80), 11, 0.9, true
	light.Parent = flame
end

local function skull(parent: Instance, at: Vector3, facing: Vector3)
	local head = Build.part(parent, "Skull", Vector3.new(0.9, 0.85, 0.95), CFrame.lookAt(at, at + facing), BONE, {
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	local headPart = head :: Part
	headPart.Shape = Enum.PartType.Ball
	head:SetAttribute("CatacombPiece", true)
	for _, side in { -0.2, 0.2 } do
		local eye = Build.part(
			parent,
			"Socket",
			Vector3.new(0.2, 0.22, 0.1),
			head.CFrame * CFrame.new(side, 0.05, -0.44),
			Color3.fromRGB(20, 16, 14),
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
		eye:SetAttribute("CatacombPiece", true)
	end
end

-- Casca de pedra de um espaço: piso, teto e quatro paredes com os vãos pedidos (aberturas em x ou z).
type Opening = { side: string, a: number, b: number, top: number }
local function shell(parent: Instance, name: string, b: Box, openings: { Opening }, wallColor: Color3)
	local t = 0.6
	block(
		parent,
		name .. "Floor",
		{ x0 = b.x0, x1 = b.x1, y0 = b.y0 - t, y1 = b.y0 + 0.05, z0 = b.z0, z1 = b.z1 },
		DARK_STONE,
		Enum.Material.Slate
	)
	block(
		parent,
		name .. "Ceiling",
		{ x0 = b.x0 - t, x1 = b.x1 + t, y0 = b.y1, y1 = b.y1 + t, z0 = b.z0 - t, z1 = b.z1 + t },
		SOIL,
		Enum.Material.Ground
	)
	type Wall = { x0: number, x1: number, z0: number, z1: number, along: string }
	local walls: { [string]: Wall } = {
		W = { x0 = b.x0 - t, x1 = b.x0, z0 = b.z0 - t, z1 = b.z1 + t, along = "z" },
		E = { x0 = b.x1, x1 = b.x1 + t, z0 = b.z0 - t, z1 = b.z1 + t, along = "z" },
		S = { x0 = b.x0, x1 = b.x1, z0 = b.z0 - t, z1 = b.z0, along = "x" },
		N = { x0 = b.x0, x1 = b.x1, z0 = b.z1, z1 = b.z1 + t, along = "x" },
	}
	for side, w in walls do
		local gaps = {}
		for _, o in openings do
			if o.side == side then
				table.insert(gaps, o)
			end
		end
		table.sort(gaps, function(p, q)
			return p.a < q.a
		end)
		local from = if w.along == "z" then w.z0 else w.x0
		local stop = if w.along == "z" then w.z1 else w.x1
		local function segment(a0: number, a1: number, y0: number, y1: number)
			if a1 - a0 < 0.05 or y1 - y0 < 0.05 then
				return
			end
			if w.along == "z" then
				block(
					parent,
					name .. "Wall",
					{ x0 = w.x0, x1 = w.x1, y0 = y0, y1 = y1, z0 = a0, z1 = a1 },
					wallColor,
					Enum.Material.Cobblestone
				)
			else
				block(
					parent,
					name .. "Wall",
					{ x0 = a0, x1 = a1, y0 = y0, y1 = y1, z0 = w.z0, z1 = w.z1 },
					wallColor,
					Enum.Material.Cobblestone
				)
			end
		end
		local cursor = from
		for _, g in gaps do
			segment(cursor, g.a, b.y0, b.y1)
			segment(g.a, g.b, g.top, b.y1)
			cursor = g.b
		end
		segment(cursor, stop, b.y0, b.y1)
	end
end

local function build(root: Instance, chapel: boolean): Model
	local model = Instance.new("Model")
	model.Name = "Catacomb"
	model:SetAttribute("CatacombPiece", true)
	local c, k, p, h = Layout.Corridor, Layout.Catacomb, Layout.Passage, Layout.Chapel
	local rng = Random.new(4040)
	-- Túnel de minhoca: estreito, com escoras de madeira, raízes, garras e brinquedos velhos.
	shell(model, "Tunnel", c, {
		{ side = "W", a = c.z0, b = c.z1, top = c.y1 },
		{ side = "E", a = c.z0, b = c.z1, top = c.y1 },
	}, SOIL)
	for x = c.x0 + 4, c.x1 - 2, 6.5 do
		for _, z in { c.z0 + 0.3, c.z1 - 0.3 } do
			block(
				model,
				"Prop",
				{ x0 = x - 0.35, x1 = x + 0.35, y0 = c.y0, y1 = c.y1, z0 = z - 0.35, z1 = z + 0.35 },
				WOOD,
				Enum.Material.Wood,
				false
			)
		end
		block(
			model,
			"Beam",
			{ x0 = x - 0.4, x1 = x + 0.4, y0 = c.y1 - 0.7, y1 = c.y1, z0 = c.z0, z1 = c.z1 },
			WOOD,
			Enum.Material.Wood,
			false
		)
	end
	for _ = 1, 9 do
		local x, z = rng:NextNumber(c.x0 + 2, c.x1 - 1), rng:NextNumber(c.z0 + 1, c.z1 - 1)
		local len = rng:NextNumber(1.2, 3)
		local root_ = Build.part(
			model,
			"Root",
			Vector3.new(0.18, len, 0.18),
			CFrame.new(x, c.y1 - len / 2, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)),
			Color3.fromRGB(64, 46, 30),
			{ material = Enum.Material.Wood, collide = false }
		)
		root_:SetAttribute("CatacombPiece", true)
	end
	for i = 1, 5 do
		local x = c.x0 + 3 + i * 4.2
		local z = if i % 2 == 0 then c.z0 + 0.05 else c.z1 - 0.05
		for j = -1, 1 do
			local claw = Build.part(
				model,
				"Claw",
				Vector3.new(0.2, 2.6, 0.08),
				CFrame.new(x + j * 0.55, c.y0 + 4, z) * CFrame.Angles(0, 0, math.rad(22)),
				Color3.fromRGB(26, 18, 14),
				{ material = Enum.Material.SmoothPlastic, collide = false }
			)
			claw:SetAttribute("CatacombPiece", true)
		end
	end
	local toyColors = { Color3.fromRGB(190, 60, 50), Color3.fromRGB(60, 110, 190), Color3.fromRGB(210, 180, 60) }
	for i = 1, 6 do
		local x, z = rng:NextNumber(c.x0 + 3, c.x1 - 3), if i % 2 == 0 then c.z0 + 1 else c.z1 - 1
		local cube = Build.part(
			model,
			"ToyBlock",
			Vector3.new(0.7, 0.7, 0.7),
			CFrame.new(x, c.y0 + 0.35, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			toyColors[(i - 1) % 3 + 1],
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
		cube:SetAttribute("CatacombPiece", true)
	end
	local ball = Build.part(
		model,
		"ToyBall",
		Vector3.new(1.1, 1.1, 1.1),
		CFrame.new(c.x0 + 9, c.y0 + 0.55, c.z1 - 1.6),
		toyColors[1],
		{
			material = Enum.Material.SmoothPlastic,
			collide = false,
		}
	)
	local ballPart = ball :: Part
	ballPart.Shape = Enum.PartType.Ball
	ball:SetAttribute("CatacombPiece", true)
	-- Parede arrombada: tijolos quebrados saltando da borda do vão (dos dois lados da fachada) e o arco irregular.
	local mouth = Layout.Mouth
	for i = 0, 22 do
		local edge = i % 3
		local x = if i % 2 == 0 then mouth.x0 - 0.25 else mouth.x1 + 0.25
		local y, z
		if edge == 0 then
			y, z = rng:NextNumber(mouth.y0, mouth.y1), mouth.z0 + rng:NextNumber(-0.2, 0.6)
		elseif edge == 1 then
			y, z = rng:NextNumber(mouth.y0, mouth.y1), mouth.z1 + rng:NextNumber(-0.6, 0.2)
		else
			y, z = mouth.y1 + rng:NextNumber(-0.7, 0.1), rng:NextNumber(mouth.z0, mouth.z1)
		end
		local chunk = Build.part(
			model,
			"BrokenBrick",
			Vector3.new(rng:NextNumber(0.5, 1.1), rng:NextNumber(0.4, 0.8), rng:NextNumber(0.6, 1.6)),
			CFrame.new(x, y, z)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.5, 0.5)),
			Color3.fromRGB(120, 92, 70),
			{ material = Enum.Material.Brick, collide = false }
		)
		chunk:SetAttribute("CatacombPiece", true)
	end
	-- Lampião velho pendurado no meio do túnel (luz fraca e trêmula).
	local lantern = block(
		model,
		"TunnelLantern",
		{ x0 = 57.6, x1 = 58.4, y0 = c.y1 - 2.2, y1 = c.y1 - 1.2, z0 = -36.4, z1 = -35.6 },
		Color3.fromRGB(255, 176, 90),
		Enum.Material.Neon,
		false
	)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Shadows = Color3.fromRGB(255, 150, 70), 14, 0.7, true
	glow.Parent = lantern
	-- Entulho na boca, do lado da casa.
	for _ = 1, 8 do
		local piece = Build.part(
			model,
			"Rubble",
			Vector3.new(rng:NextNumber(0.5, 1.4), rng:NextNumber(0.3, 0.7), rng:NextNumber(0.5, 1.4)),
			CFrame.new(rng:NextNumber(40, 46), c.y0 + 0.3, rng:NextNumber(c.z0, c.z1))
				* CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0),
			Color3.fromRGB(96, 86, 72),
			{ material = Enum.Material.Slate, collide = false }
		)
		piece:SetAttribute("CatacombPiece", true)
	end
	-- Catacumba: nichos nas paredes leste e oeste com crânios, sarcófago e velas.
	shell(model, "Catacomb", k, {
		{ side = "W", a = c.z0, b = c.z1, top = c.y1 },
		{ side = "N", a = p.x0, b = p.x1, top = p.y1 },
	}, STONE)
	for _, side in { -1, 1 } do
		local wallX = if side < 0 then k.x0 else k.x1
		for z = k.z0 + 3, k.z1 - 3, 5 do
			if side < 0 and z > c.z0 - 2 and z < c.z1 + 2 then
				continue
			end
			for _, y in { k.y0 + 2.2, k.y0 + 5 } do
				block(model, "Niche", {
					x0 = wallX - (if side < 0 then 0 else 1.6),
					x1 = wallX + (if side < 0 then 1.6 else 0),
					y0 = y - 0.2,
					y1 = y,
					z0 = z - 2,
					z1 = z + 2,
				}, DARK_STONE, Enum.Material.Slate, false)
				for n = -1, 1, 2 do
					skull(model, Vector3.new(wallX - side * 0.8, y + 0.45, z + n * 1.1), Vector3.new(-side, 0, 0))
				end
			end
			candle(model, Vector3.new(wallX - side * 0.8, k.y0 + 7.8 - 2.6, z), 0.7)
		end
	end
	local sarc = { x0 = 86, x1 = 90, y0 = k.y0, y1 = k.y0 + 2.6, z0 = -32, z1 = -24 }
	block(model, "Sarcophagus", sarc, STONE, Enum.Material.Granite)
	block(
		model,
		"SarcophagusLid",
		{ x0 = 85.7, x1 = 90.3, y0 = sarc.y1, y1 = sarc.y1 + 0.5, z0 = -32.3, z1 = -23.7 },
		DARK_STONE,
		Enum.Material.Granite
	)
	for _, at in
		{
			Vector3.new(85.3, k.y0, -33),
			Vector3.new(90.7, k.y0, -33),
			Vector3.new(76, k.y0, -48),
			Vector3.new(92, k.y0, -48),
		}
	do
		candle(model, at, 1.6)
	end
	-- Passagem para a capela, com grade de ferro (fechada até o capítulo 5).
	shell(model, "Passage", p, {
		{ side = "S", a = p.x0, b = p.x1, top = p.y1 },
		{ side = "N", a = p.x0, b = p.x1, top = p.y1 },
	}, STONE)
	local gate = Instance.new("Model")
	gate.Name = "ChapelGate"
	gate.Parent = model
	for x = p.x0 + 0.5, p.x1 - 0.4, 0.75 do
		local bar = block(
			gate,
			"Bar",
			{ x0 = x - 0.08, x1 = x + 0.08, y0 = p.y0, y1 = p.y1, z0 = -19.6, z1 = -19.4 },
			Color3.fromRGB(40, 38, 36),
			Enum.Material.Metal
		)
		bar.CanCollide = not chapel
		bar.Transparency = if chapel then 1 else 0
	end
	for _, y in { p.y0 + 1, p.y1 - 1 } do
		local rail = block(
			gate,
			"Rail",
			{ x0 = p.x0, x1 = p.x1, y0 = y - 0.1, y1 = y + 0.1, z0 = -19.6, z1 = -19.4 },
			Color3.fromRGB(40, 38, 36),
			Enum.Material.Metal
		)
		rail.CanCollide = false
		rail.Transparency = if chapel then 1 else 0
	end
	-- Capela do ritual: bancos, círculo vermelho no chão e o altar com pano e velas.
	shell(model, "Chapel", h, { { side = "S", a = p.x0, b = p.x1, top = p.y1 } }, DARK_STONE)
	for _, x in { 75.5, 90.5 } do
		for z = h.z0 + 4, h.z0 + 12, 4 do
			block(
				model,
				"Pew",
				{ x0 = x - 3, x1 = x + 3, y0 = h.y0, y1 = h.y0 + 1.6, z0 = z, z1 = z + 1.2 },
				WOOD,
				Enum.Material.Wood
			)
			block(
				model,
				"PewBack",
				{ x0 = x - 3, x1 = x + 3, y0 = h.y0 + 1.6, y1 = h.y0 + 3.6, z0 = z - 0.3, z1 = z },
				WOOD,
				Enum.Material.Wood,
				false
			)
		end
	end
	local ringCenter = Vector3.new(83, h.y0 + 0.08, -7)
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local seg = Build.part(
			model,
			"RitualRing",
			Vector3.new(0.3, 0.06, 1.7),
			CFrame.new(ringCenter + Vector3.new(math.cos(a) * 4.2, 0, math.sin(a) * 4.2)) * CFrame.Angles(0, -a, 0),
			Color3.fromRGB(160, 20, 20),
			{ material = Enum.Material.Neon, collide = false }
		)
		seg:SetAttribute("CatacombPiece", true)
	end
	block(
		model,
		"Altar",
		{ x0 = 79.5, x1 = 86.5, y0 = h.y0, y1 = h.y0 + 3, z0 = 1, z1 = 3.6 },
		STONE,
		Enum.Material.Granite
	)
	block(
		model,
		"AltarCloth",
		{ x0 = 80, x1 = 86, y0 = h.y0 + 3, y1 = h.y0 + 3.1, z0 = 0.8, z1 = 3.8 },
		CLOTH,
		Enum.Material.Fabric,
		false
	)
	block(
		model,
		"AltarRunner",
		{ x0 = 82.4, x1 = 83.6, y0 = h.y0 + 1, y1 = h.y0 + 3.05, z0 = 0.75, z1 = 0.85 },
		CLOTH,
		Enum.Material.Fabric,
		false
	)
	for _, x in { 80.6, 82, 84, 85.4 } do
		candle(model, Vector3.new(x, h.y0 + 3.1, 2.7), 1.1)
	end
	for _, at in
		{
			Vector3.new(73.5, h.y0, 3.5),
			Vector3.new(92.5, h.y0, 3.5),
			Vector3.new(73.5, h.y0, -15),
			Vector3.new(92.5, h.y0, -15),
		}
	do
		candle(model, at, 2.2)
	end
	model.Parent = root
	return model
end

-- Abre ou fecha conforme o capítulo (WorldService.setHouseStage). Sempre refaz do zero: a casa pode ter sido
-- reconstruída entre um capítulo e outro.
function Catacomb.setStage(root: Instance, stage: number)
	local old = root:FindFirstChild("Catacomb")
	if old then
		old:Destroy()
	end
	restore(root)
	-- Casa reconstruída: registros de raízes que saíram do jogo só ocupam o depósito.
	for other, records in carvedByRoot do
		if not other:IsDescendantOf(game) then
			for _, record in records do
				record.original:Destroy()
			end
			carvedByRoot[other] = nil
		end
	end
	if not Layout.openCatacomb(stage) then
		return
	end
	local m = 0.7
	carve(root, {
		expand(Layout.Mouth, 0),
		expand(Layout.Corridor, m),
		expand(Layout.Catacomb, m),
		expand(Layout.Passage, m),
		expand(Layout.Chapel, m),
	})
	build(root, Layout.openChapel(stage))
end

return Catacomb
