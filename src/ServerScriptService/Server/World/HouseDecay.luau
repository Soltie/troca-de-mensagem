--!strict
--[[
	A casa muda a cada capítulo (opção A, docs/AVALIACAO_20-10-2026.md). Só enfeite sem colisão (não mexe em rota):
	- 2 · Ele Acordou: cadeiras tombadas, papéis no chão, garras no corredor, quadros caídos.
	- 3 · A Maldição: quadros tortos, símbolos vermelhos pintados no chão, marcas de mão nas paredes.
	- 4 · O Porão: poças d'água e canos pingando no porão.
	- 5 · A Última Noite: velas no corredor, janelas tapadas com tábuas e "SAIAM" escrito na parede do hall.
	Cada capítulo herda o estrago dos anteriores. Quadros entortados voltam ao lugar fora dos capítulos 3 a 5.
]]

local House = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Build = require("./Build")

local Decay = {}

type Tilt = { model: Model, pivot: CFrame }
local tiltedByRoot: { [Instance]: { Tilt } } = {}

local BLOOD = Color3.fromRGB(120, 16, 16)
local PAPER = Color3.fromRGB(214, 204, 178)
local WOOD = Color3.fromRGB(78, 54, 36)

local function room(id: string): House.Room?
	for _, r in House.Rooms do
		if r.id == id then
			return r
		end
	end
	return nil
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
)
	local p = Build.part(parent, name, size, cframe, color, {
		material = material or Enum.Material.SmoothPlastic,
		collide = false,
		query = false,
	})
	p.CastShadow = false
	return p
end

-- Cadeira tombada de lado (assento, encosto e pernas).
local function fallenChair(parent: Instance, at: Vector3, yaw: number)
	local base = CFrame.new(at + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.rad(88))
	piece(parent, "ChairSeat", Vector3.new(1.8, 0.25, 1.8), base, WOOD, Enum.Material.Wood)
	piece(parent, "ChairBack", Vector3.new(0.25, 2.2, 1.8), base * CFrame.new(-0.9, 1.1, 0), WOOD, Enum.Material.Wood)
	for _, dx in { -0.75, 0.75 } do
		for _, dz in { -0.75, 0.75 } do
			piece(
				parent,
				"ChairLeg",
				Vector3.new(0.2, 1.6, 0.2),
				base * CFrame.new(dx, -0.9, dz),
				WOOD,
				Enum.Material.Wood
			)
		end
	end
end

local function papers(parent: Instance, at: Vector3, rng: Random)
	for _ = 1, 6 do
		piece(
			parent,
			"Paper",
			Vector3.new(0.9, 0.03, 1.2),
			CFrame.new(at + Vector3.new(rng:NextNumber(-2.5, 2.5), 0.03, rng:NextNumber(-2.5, 2.5)))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
			PAPER
		)
	end
end

-- Três riscos de garra numa parede (normal = para onde a parede olha).
local function claws(parent: Instance, at: Vector3, normal: Vector3)
	local right = normal:Cross(Vector3.yAxis).Unit
	for i = -1, 1 do
		local p = at + right * (i * 0.55) + normal * 0.06
		piece(
			parent,
			"Claw",
			Vector3.new(0.18, 2.8, 0.06),
			CFrame.lookAt(p, p + normal) * CFrame.Angles(0, 0, math.rad(20)),
			Color3.fromRGB(30, 20, 16)
		)
	end
end

local function handprint(parent: Instance, at: Vector3, normal: Vector3, rng: Random)
	local p = at + normal * 0.05
	local frame = CFrame.lookAt(p, p + normal) * CFrame.Angles(0, 0, rng:NextNumber(-0.4, 0.4))
	piece(parent, "Palm", Vector3.new(0.7, 0.8, 0.04), frame, BLOOD)
	for i = -2, 1 do
		piece(parent, "Finger", Vector3.new(0.14, 0.55, 0.04), frame * CFrame.new(i * 0.17 + 0.08, 0.62, 0), BLOOD)
	end
	piece(
		parent,
		"Thumb",
		Vector3.new(0.14, 0.4, 0.04),
		frame * CFrame.new(-0.42, 0.1, 0) * CFrame.Angles(0, 0, 0.7),
		BLOOD
	)
end

-- Símbolo do ritual no chão: círculo com um triângulo dentro.
local function symbol(parent: Instance, at: Vector3, radius: number)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		piece(
			parent,
			"Symbol",
			Vector3.new(0.18, 0.03, radius * 0.48),
			CFrame.new(at + Vector3.new(math.cos(a) * radius, 0.04, math.sin(a) * radius)) * CFrame.Angles(0, -a, 0),
			BLOOD,
			Enum.Material.Neon
		)
	end
	for i = 0, 2 do
		local a0, a1 = i / 3 * math.pi * 2, (i + 1) / 3 * math.pi * 2
		local p0 = at + Vector3.new(math.cos(a0) * radius * 0.85, 0.04, math.sin(a0) * radius * 0.85)
		local p1 = at + Vector3.new(math.cos(a1) * radius * 0.85, 0.04, math.sin(a1) * radius * 0.85)
		piece(
			parent,
			"Symbol",
			Vector3.new(0.16, 0.03, (p1 - p0).Magnitude),
			CFrame.lookAt((p0 + p1) / 2, p1),
			BLOOD,
			Enum.Material.Neon
		)
	end
end

local function puddle(parent: Instance, at: Vector3, rng: Random)
	local p = piece(
		parent,
		"Puddle",
		Vector3.new(0.06, rng:NextNumber(4, 7), rng:NextNumber(4, 7)),
		CFrame.new(at + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(30, 44, 48),
		Enum.Material.Glass
	)
	local shaped: any = p
	shaped.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.25
	p.Reflectance = 0.35
end

local function pipe(parent: Instance, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local p = piece(
		parent,
		"Pipe",
		Vector3.new(length, 0.5, 0.5),
		CFrame.lookAt((from + to) / 2, to) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(70, 66, 60),
		Enum.Material.CorrodedMetal
	)
	local shaped: any = p
	shaped.Shape = Enum.PartType.Cylinder
	-- Gotejando no meio.
	local drip = Instance.new("Attachment")
	drip.Position = Vector3.new(0, -0.3, 0)
	drip.Parent = p
	local water = Instance.new("ParticleEmitter")
	water.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	water.Color = ColorSequence.new(Color3.fromRGB(150, 180, 190))
	water.Size = NumberSequence.new(0.12)
	water.Lifetime = NumberRange.new(0.9, 1.2)
	water.Speed = NumberRange.new(0)
	water.Acceleration = Vector3.new(0, -25, 0)
	water.Rate = 3
	water.LightEmission = 0.3
	water.Parent = drip
end

local function candle(parent: Instance, at: Vector3, h: number)
	piece(
		parent,
		"Candle",
		Vector3.new(0.35, h, 0.35),
		CFrame.new(at + Vector3.new(0, h / 2, 0)),
		Color3.fromRGB(226, 214, 186)
	)
	local flame = piece(
		parent,
		"Flame",
		Vector3.new(0.16, 0.3, 0.16),
		CFrame.new(at + Vector3.new(0, h + 0.15, 0)),
		Color3.fromRGB(255, 170, 70),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = Color3.fromRGB(255, 160, 80), 9, 0.7
	light.Parent = flame
end

-- Quadros tortos (ou caídos no chão, no capítulo 2).
local function tiltFrames(root: Instance, stage: number, rng: Random)
	local list: { Tilt } = tiltedByRoot[root] or {}
	tiltedByRoot[root] = list
	local props = root:FindFirstChild("Props")
	if not props then
		return
	end
	for _, model in props:GetChildren() do
		if
			model:IsA("Model")
			and (model.Name == "FrameRococo" or model.Name == "FrameLandscape" or model.Name == "FrameOval")
			and rng:NextNumber() < (if stage >= 3 then 0.75 else 0.3)
		then
			local pivot = model:GetPivot()
			table.insert(list, { model = model, pivot = pivot })
			model:PivotTo(
				pivot
					* CFrame.Angles(0, 0, math.rad(rng:NextNumber(9, 22) * (if rng:NextNumber() < 0.5 then -1 else 1)))
			)
		end
	end
end

local function untilt(root: Instance)
	local tilted: { Tilt } = tiltedByRoot[root] or {}
	for _, t in tilted do
		if t.model.Parent then
			t.model:PivotTo(t.pivot)
		end
	end
	tiltedByRoot[root] = nil
	for other in tiltedByRoot do
		if not other:IsDescendantOf(game) then
			tiltedByRoot[other] = nil
		end
	end
end

function Decay.setStage(root: Instance, stage: number)
	local old = root:FindFirstChild("Decay")
	if old then
		old:Destroy()
	end
	untilt(root)
	if stage < 2 or stage > 5 then
		return
	end
	local folder = Build.folder(root, "Decay")
	local rng = Random.new(stage * 977)
	-- 2+: ele acordou e revirou a casa.
	for _, spot in
		{
			{ id = "Dining", dx = -6, dz = 8, yaw = 0.6 },
			{ id = "Living", dx = 7, dz = -9, yaw = 2.2 },
			{ id = "Kitchen", dx = -6, dz = 10, yaw = 1.1 },
			{ id = "Office", dx = 7, dz = 9, yaw = 2.8 },
		}
	do
		local r = room(spot.id)
		if r then
			fallenChair(folder, Vector3.new(r.x + spot.dx, r.y, r.z + spot.dz), spot.yaw)
		end
	end
	for _, id in { "Living", "Library", "Office", "Bedroom" } do
		local r = room(id)
		if r then
			papers(folder, Vector3.new(r.x + rng:NextNumber(-6, 6), r.y, r.z + rng:NextNumber(-8, 8)), rng)
		end
	end
	-- Garras nas paredes do corredor central, nos três andares.
	for _, y in { 0, 16 } do
		for z = -70, 0, 22 do
			local side = if (z // 22) % 2 == 0 then 1 else -1
			claws(folder, Vector3.new(side * 7.4, y + 4.5, z + rng:NextNumber(-3, 3)), Vector3.new(-side, 0, 0))
		end
	end
	tiltFrames(root, stage, rng)
	if stage >= 3 then
		-- 3+: a maldição.
		for _, id in { "Hall", "Dining", "Library", "Office", "Locked" } do
			local r = room(id)
			if r then
				local dx = if id == "Hall" then 0 else rng:NextNumber(-4, 4)
				local dz = if id == "Hall" then -24 else rng:NextNumber(-4, 4)
				symbol(folder, Vector3.new(r.x + dx, r.y, r.z + dz), 2.6)
			end
		end
		for _, y in { 0, 16 } do
			for i = 1, 4 do
				local side = if i % 2 == 0 then 1 else -1
				handprint(
					folder,
					Vector3.new(side * 7.4, y + rng:NextNumber(3, 6), -10 - i * 15),
					Vector3.new(-side, 0, 0),
					rng
				)
			end
		end
	end
	if stage >= 4 then
		-- 4+: o porão alagando.
		for _, id in { "Basement", "Symbols", "Safe", "Tunnel" } do
			local r = room(id)
			if r then
				for _ = 1, 2 do
					puddle(folder, Vector3.new(r.x + rng:NextNumber(-8, 8), r.y, r.z + rng:NextNumber(-9, 9)), rng)
				end
				pipe(folder, Vector3.new(r.x - 14, r.y + 13.6, r.z + 12), Vector3.new(r.x + 14, r.y + 13.6, r.z + 12))
			end
		end
	end
	if stage >= 5 then
		-- 5: a última noite.
		for z = -60, 4, 8 do
			for _, side in { -1, 1 } do
				candle(folder, Vector3.new(side * 6.2, 0, z + rng:NextNumber(-1.5, 1.5)), rng:NextNumber(0.6, 1.4))
			end
		end
		local hall = room("Hall")
		if hall then
			Build.sign(
				folder,
				"Warning",
				Vector3.new(hall.x - 7.3, 7.5, hall.z - 6),
				Vector3.xAxis,
				Vector2.new(8, 2.6),
				"SAIAM",
				{ textColor = BLOOD, backgroundTransparency = 1, thickness = 0.05, font = Enum.Font.Creepster }
			)
		end
		-- Tábuas atravessadas nas janelas das fachadas (por dentro).
		local Layout = require("@game/ReplicatedStorage/Shared/Game/HouseLayout")
		for _, hole in Layout.facadeWindows(House.Rooms) do
			local x = hole.side * 43.3
			for i = 1, 2 do
				local y = hole.y + Layout.Window.y0 + i * 1.9
				piece(
					folder,
					"WindowBoard",
					Vector3.new(0.2, 0.7, Layout.Window.halfWidth * 2 + 1.4),
					CFrame.new(x, y, hole.z) * CFrame.Angles(math.rad(if i == 1 then 12 else -9), 0, 0),
					WOOD,
					Enum.Material.WoodPlanks
				)
			end
		end
	end
end

return Decay
