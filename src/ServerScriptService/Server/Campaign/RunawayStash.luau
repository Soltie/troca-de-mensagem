--!strict
--[[
	Móvel fujão: o móvel que guarda a chave (HiddenStash, o certo) acorda quando alguém chega perto com a tarefa
	liberada. Ganha olhinhos e quatro perninhas, chacoalha as gavetas e foge pelo cômodo aos pulinhos, sempre de
	olho em quem está mais perto. Depois de `MaxHops` pulos ele cansa, senta e fica ofegando; se alguém encostar nele
	numa pausa ou no meio do pulo, cansa na hora. Cansado, abre normalmente. Os pulos fazem barulho (o Tung Tung
	pode ouvir), então perseguir tem risco.
	Tudo acontece no servidor (peças ancoradas movidas por CFrame), então todo mundo vê o mesmo móvel.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local CreatureService = require("../Services/CreatureService")

local Runaway = {}

local WAKE_RANGE = 7.5
-- Também acorda quando alguém olha para ele de longe (veredito 20/10: quem chegava correndo abria antes do susto).
local SEE_RANGE = 22
local SEE_DOT = 0.8
local CATCH_RANGE = 2.8
local SPEED = 10
local HOP_MIN, HOP_MAX = 6, 9
local PAUSE = 0.55
Runaway.MaxHops = 4
local ROOM_RADIUS = 22
local LIFT = 1.2

export type State = "asleep" | "awake" | "tired"

type Runner = {
	target: any,
	model: Model,
	state: State,
	center: Vector3,
	frame: CFrame,
	offsets: { [BasePart]: CFrame },
	legs: { { part: BasePart, foot: BasePart, hip: CFrame } },
	eyes: { { white: BasePart, pupil: BasePart, at: Vector3 } },
	hingeOffset: CFrame?,
	hops: number,
	goal: Vector3?,
	pauseUntil: number,
	clock: number,
	lift: number,
	panting: Sound?,
}

local runners: { Runner } = {}
local rng = Random.new()
local loop: RBXScriptConnection? = nil

local function sound(parent: Instance, clip: { id: string, volume: number }, volume: number, speed: number): Sound
	local s = Instance.new("Sound")
	s.SoundId = clip.id
	s.Volume = clip.volume * volume
	s.PlaybackSpeed = speed
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = 70
	s.Parent = parent
	s:Play()
	return s
end

local function part(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = model
	return p
end

-- Liga o fujão no móvel certo da chave. `center` = centro do cômodo (ele não foge para longe dele).
function Runaway.attach(target: any, center: Vector3)
	local focus: BasePart = target.focus
	local model = focus.Parent
	if not model or not model:IsA("Model") then
		return
	end
	local chest = focus.Size.Y < 2.5
	local frame = focus.CFrame * CFrame.new(0, -(if chest then 0.95 else 1.6), 0)
	local width = if chest then 3.4 else 3.8
	local depth = if chest then 2 else 1.8
	local runner: Runner = {
		target = target,
		model = model,
		state = "asleep",
		center = center,
		frame = frame,
		offsets = {},
		legs = {},
		eyes = {},
		hingeOffset = if target.hinge then frame:ToObjectSpace(target.hinge) else nil,
		hops = 0,
		goal = nil,
		pauseUntil = 0,
		clock = 0,
		lift = 0,
		panting = nil,
	}
	-- Perninhas de desenho animado nos quatro cantos: cilindros pretos finos com uma bolinha preta na ponta,
	-- virada para a frente (escondidas até acordar).
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local leg = part(
				model,
				"RunawayLeg",
				Enum.PartType.Cylinder,
				Vector3.new(LIFT - 0.15, 0.16, 0.16),
				Color3.fromRGB(14, 12, 12)
			)
			local foot =
				part(model, "RunawayLeg", Enum.PartType.Ball, Vector3.new(0.46, 0.46, 0.46), Color3.fromRGB(14, 12, 12))
			table.insert(
				runner.legs,
				{ part = leg, foot = foot, hip = CFrame.new(x * (width / 2 - 0.35), 0.05, z * (depth / 2 - 0.3)) }
			)
		end
	end
	-- Olhinhos de desenho na frente, olhando para quem está perto.
	local eyeY = if chest then 1.15 else 2.72
	for _, x in { -0.55, 0.55 } do
		local white =
			part(model, "RunawayEye", Enum.PartType.Ball, Vector3.new(0.78, 0.78, 0.78), Color3.fromRGB(245, 242, 232))
		local pupil =
			part(model, "RunawayPupil", Enum.PartType.Ball, Vector3.new(0.34, 0.34, 0.34), Color3.fromRGB(12, 10, 10))
		table.insert(runner.eyes, { white = white, pupil = pupil, at = Vector3.new(x, eyeY, -depth / 2 - 0.12) })
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name ~= "RunawayLeg" and d.Name ~= "RunawayEye" and d.Name ~= "RunawayPupil" then
			runner.offsets[d] = frame:ToObjectSpace(d.CFrame)
		end
	end
	focus:SetAttribute("Runaway", "asleep")
	table.insert(runners, runner)
	if not loop then
		loop = RunService.Heartbeat:Connect(function(dt)
			Runaway.step(dt)
		end)
	end
end

local function nearestPlayer(position: Vector3): (Vector3?, number)
	local best: Vector3?, bestD = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		if body and body:IsA("BasePart") and player:GetAttribute("CampaignStatus") == "Active" then
			local offset = body.Position - position
			if math.abs(offset.Y - 3) < 6 then
				local d = Vector3.new(offset.X, 0, offset.Z).Magnitude
				if d < bestD then
					best, bestD = body.Position, d
				end
			end
		end
	end
	return best, bestD
end

-- Alguém no mesmo andar olhando para o móvel, sem parede no meio?
local function watched(runner: Runner): boolean
	local position = runner.frame.Position
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		if not body or not body:IsA("BasePart") or player:GetAttribute("CampaignStatus") ~= "Active" then
			continue
		end
		local eye = body.Position + Vector3.new(0, 1.5, 0)
		local offset = position + Vector3.new(0, 1.5, 0) - eye
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if math.abs(body.Position.Y - 3 - position.Y) > 6 or flat.Magnitude > SEE_RANGE or flat.Magnitude < 0.5 then
			continue
		end
		local look = body.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 1e-3 or look.Unit:Dot(flat.Unit) < SEE_DOT then
			continue
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { character :: Instance, runner.model }
		if not workspace:Raycast(eye, offset * 0.9, params) then
			return true
		end
	end
	return false
end

-- Próximo pulo: para longe de quem está perto, sem atravessar parede nem móvel, sem sair do cômodo.
local function chooseGoal(runner: Runner, threat: Vector3): Vector3?
	local position = runner.frame.Position
	local away = Vector3.new(position.X - threat.X, 0, position.Z - threat.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.xAxis
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { runner.model }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	local best: Vector3?, bestScore = nil, -math.huge
	local now = (threat - position).Magnitude
	-- Todas as direções (encostado na parede, "para longe" é a parede: vai de lado ou na diagonal); nunca chega
	-- mais perto de quem persegue.
	for step = 0, 15 do
		local angle = step * math.pi / 8 + rng:NextNumber(-0.15, 0.15)
		local dir = CFrame.Angles(0, angle, 0):VectorToWorldSpace(away)
		-- Pulo longo se couber; senão um mais curto na mesma direção.
		for _, distance in { rng:NextNumber(HOP_MIN, HOP_MAX), 4.5 } do
			local goal = position + dir * distance
			-- De lado vale; só não pode chegar mais perto de quem persegue.
			if (goal - threat).Magnitude < now - 0.5 then
				continue
			end
			local flat = Vector3.new(goal.X - runner.center.X, 0, goal.Z - runner.center.Z)
			if flat.Magnitude > ROOM_RADIUS then
				continue
			end
			-- Caminho livre na altura do corpo (com folga para a largura) e chão embaixo do destino.
			local clear = true
			for _, side in { -1.4, 0, 1.4 } do
				local origin = position + Vector3.new(0, 1.2, 0) + Vector3.new(-dir.Z, 0, dir.X) * side
				if workspace:Raycast(origin, dir * (distance + 2.2), params) then
					clear = false
					break
				end
			end
			if not clear then
				continue
			end
			local floor = workspace:Raycast(goal + Vector3.new(0, 2, 0), Vector3.new(0, -5, 0), params)
			if not floor or math.abs(floor.Position.Y - position.Y) > 0.8 then
				continue
			end
			local score = (goal - threat).Magnitude
			if score > bestScore then
				best, bestScore = goal, score
			end
			break
		end
	end
	return best
end

local function place(runner: Runner, frame: CFrame, legSwing: number, look: Vector3?)
	for p, offset in runner.offsets do
		if p.Parent then
			p.CFrame = frame * offset
		end
	end
	for index, leg in runner.legs do
		local swing = if index % 2 == 0 then legSwing else -legSwing
		local knee = frame * leg.hip * CFrame.Angles(swing, 0, 0)
		-- O cilindro deitado no eixo X vira de pé; o pezinho fica um pouco à frente (o móvel olha para -Z).
		leg.part.CFrame = knee * CFrame.new(0, -(LIFT - 0.15) / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		leg.foot.CFrame = knee * CFrame.new(0, -(LIFT - 0.15), -0.16)
	end
	for _, eye in runner.eyes do
		local center = frame * eye.at
		eye.white.CFrame = CFrame.new(center)
		local toward = if look then look - center else frame.LookVector
		toward = if toward.Magnitude > 0.01 then toward.Unit else frame.LookVector
		eye.pupil.CFrame = CFrame.new(center + toward * 0.3)
	end
end

local function setVisible(runner: Runner, visible: boolean)
	for _, leg in runner.legs do
		leg.part.Transparency = if visible then 0 else 1
		leg.foot.Transparency = if visible then 0 else 1
	end
	for _, eye in runner.eyes do
		eye.white.Transparency = if visible then 0 else 1
		eye.pupil.Transparency = if visible then 0 else 1
	end
end

-- Depois de mover, a dobradiça do baú e o sentido da gaveta acompanham o móvel.
local function syncOpening(runner: Runner)
	local target = runner.target
	if runner.hingeOffset then
		target.hinge = runner.frame * runner.hingeOffset
	end
	if target.opening then
		target.opening = CFrame.new(runner.frame.LookVector * 1.4)
	end
end

local function tire(runner: Runner)
	runner.state = "tired"
	runner.goal = nil
	syncOpening(runner)
	runner.target.focus:SetAttribute("Runaway", "tired")
	if runner.panting then
		runner.panting:Destroy()
	end
	local pant = sound(runner.target.focus, Audio.Breath2, 1.4, 1.5)
	pant.Looped = true
	runner.panting = pant
end

local function wake(runner: Runner)
	if runner.state ~= "asleep" then
		return
	end
	runner.state = "awake"
	runner.hops = 0
	runner.pauseUntil = os.clock() + 0.6
	runner.target.focus:SetAttribute("Runaway", "awake")
	setVisible(runner, true)
	sound(runner.target.focus, Audio.DoorRattle, 1.2, 1.5)
	sound(runner.target.focus, Audio.CreakWood, 1.4, 1.6)
	CreatureService.makeNoise(runner.frame.Position, 35)
end

-- Fugindo? (enquanto isso não dá para abrir). Interagir com ele dormindo também o acorda.
function Runaway.fleeing(target: any): boolean
	for _, runner in runners do
		if runner.target == target then
			if runner.state == "asleep" then
				wake(runner)
			end
			return runner.state == "awake"
		end
	end
	return false
end

function Runaway.step(dt: number)
	local now = os.clock()
	for index = #runners, 1, -1 do
		local runner = runners[index]
		if not runner.model.Parent or runner.target.opened then
			if runner.panting then
				runner.panting:Destroy()
			end
			if runner.model.Parent then
				-- Aberto: os olhinhos e as perninhas somem (a gaveta/tampa já está abrindo onde ele sentou).
				setVisible(runner, false)
			end
			table.remove(runners, index)
			continue
		end
		local threat, distance = nearestPlayer(runner.frame.Position)
		if runner.state == "asleep" then
			if
				threat
				and (distance <= WAKE_RANGE or watched(runner))
				and runner.target.focus:GetAttribute(Tags.Attr.InteractEnabled) == true
			then
				wake(runner)
			end
			continue
		end
		runner.clock += dt
		if runner.state == "tired" then
			-- Senta devagar e fica arfando, de olho em quem chegou.
			runner.lift = math.max(0, runner.lift - dt * 1.5)
			local breathe = math.sin(runner.clock * 9) * 0.04
			place(runner, runner.frame * CFrame.new(0, runner.lift + breathe, 0), 0, threat)
			continue
		end
		-- Acordado: levanta nas perninhas.
		runner.lift = math.min(LIFT, runner.lift + dt * 4)
		if threat and distance <= CATCH_RANGE and now >= runner.pauseUntil - 0.3 then
			tire(runner)
			continue
		end
		local goal = runner.goal
		if not goal then
			if now >= runner.pauseUntil then
				if runner.hops >= Runaway.MaxHops then
					tire(runner)
					continue
				end
				goal = if threat then chooseGoal(runner, threat) else nil
				if not goal then
					-- Encurralado: não tem para onde ir.
					tire(runner)
					continue
				end
				runner.goal = goal
				runner.hops += 1
			end
			place(runner, runner.frame * CFrame.new(0, runner.lift, 0), math.sin(runner.clock * 6) * 0.15, threat)
			continue
		end
		local position = runner.frame.Position
		local delta = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z)
		local stepLength = math.min(delta.Magnitude, SPEED * dt)
		local nextPosition = position + (if delta.Magnitude > 0.01 then delta.Unit * stepLength else Vector3.zero)
		-- Vira a frente (os olhos) para quem persegue enquanto corre de costas.
		local face = if threat
			then Vector3.new(threat.X - nextPosition.X, 0, threat.Z - nextPosition.Z)
			else runner.frame.LookVector
		face = if face.Magnitude > 0.01 then face.Unit else runner.frame.LookVector
		local turned = runner.frame.LookVector:Lerp(face, math.min(1, dt * 8))
		runner.frame = CFrame.lookAt(nextPosition, nextPosition + turned)
		local hop = math.abs(math.sin(runner.clock * 14)) * 0.35
		place(runner, runner.frame * CFrame.new(0, runner.lift + hop, 0), math.sin(runner.clock * 22) * 0.7, threat)
		if delta.Magnitude - stepLength < 0.05 then
			runner.goal = nil
			runner.pauseUntil = now + PAUSE
			syncOpening(runner)
			sound(runner.target.focus, Audio.StepWood, 1, 1.8)
			CreatureService.makeNoise(nextPosition, 18)
		end
	end
	if #runners == 0 and loop then
		loop:Disconnect()
		loop = nil
	end
end

return Runaway
