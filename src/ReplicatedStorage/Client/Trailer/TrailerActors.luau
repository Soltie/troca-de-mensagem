--!strict
--[[
	Atores do trailer (só cliente, só Studio; ver TrailerController).

	  Equipe  cópias do personagem local com lanterna na mão (luz própria, sem colisão) e poses
	          procedurais: andar, correr, parado, alcançar, ajoelhar e caído.
	  Vigia   o mesmo corpo low poly do jogo (Client/Creature/Rig) com as poses de Client/Creature/Poses,
	          trocadas a 12 quadros/s como no jogo (stop-motion).
	Tudo é local: ninguém mais vê, nada colide e nada vira regra de jogo.
]]

local Players = game:GetService("Players")

local Poses = require("../Creature/Poses")
local Rig = require("../Creature/Rig")

type Joint = Motor6D | AnimationConstraint

export type Member = {
	model: Model,
	root: BasePart,
	joints: { [string]: Joint },
	bases: { [Joint]: CFrame },
	lamp: Part,
	light: SpotLight,
	standHeight: number,
	floorToPivot: number,
}

export type Creature = {
	rig: Rig.Rig,
	frame: number,
	clock: number,
}

export type PoseName = "walk" | "run" | "idle" | "reach" | "kneel" | "downed"

local rad = math.rad
local TrailerActors = {}

local function readBase(joint: Joint): CFrame
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	return if joint.Attachment0 then joint.Attachment0.CFrame else CFrame.identity
end

local function writeBase(joint: Joint, frame: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = frame
	elseif joint.Attachment0 then
		joint.Attachment0.CFrame = frame
	end
end

local function setJoint(member: Member, name: string, rotation: CFrame)
	local joint = member.joints[name]
	if joint then
		writeBase(joint, member.bases[joint] * rotation)
	end
end

-- Cópia do personagem local, limpa de scripts e placas, com lanterna própria.
function TrailerActors.member(parent: Instance, shirt: Color3?): Member?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local wasArchivable = character.Archivable
	character.Archivable = true
	local model = character:Clone()
	character.Archivable = wasArchivable
	if not model then
		return nil
	end
	model.Name = "TrailerMember"
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.PlatformStand = true
	end
	if shirt then
		for _, name in { "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm" } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = shirt
			end
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	root.Transparency = 1
	local joints: { [string]: Joint } = {}
	local bases: { [Joint]: CFrame } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") or (d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1) then
			joints[d.Name] = d :: Joint
			bases[d :: Joint] = readBase(d :: Joint)
		end
	end
	local lamp = Instance.new("Part")
	lamp.Name = "Lamp"
	lamp.Size = Vector3.new(0.24, 0.24, 0.7)
	lamp.Color = Color3.fromRGB(40, 42, 44)
	lamp.Material = Enum.Material.Metal
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.CastShadow = false
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Front
	light.Angle = 44
	light.Range = 42
	light.Brightness = 3.2
	light.Color = Color3.fromRGB(255, 232, 196)
	light.Shadows = true
	light.Parent = lamp
	lamp.Parent = model
	local hip = if humanoid then humanoid.HipHeight else 1.84
	model.Parent = parent
	return {
		model = model,
		root = root,
		joints = joints,
		bases = bases,
		lamp = lamp,
		light = light,
		standHeight = hip + root.Size.Y / 2,
		floorToPivot = hip + root.Size.Y / 2,
	}
end

--[[
	Põe o ator em `position` (no chão) olhando para `look`, na pose pedida.
	`phase` anda o ciclo das pernas (radianos); `pitch` (graus) mira a lanterna.
]]
function TrailerActors.pose(
	member: Member,
	position: Vector3,
	look: Vector3,
	name: PoseName,
	phase: number,
	pitch: number?
)
	local flat = Vector3.new(look.X - position.X, 0, look.Z - position.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local pivot = position + Vector3.new(0, member.standHeight, 0)
	member.root.CFrame = CFrame.lookAt(pivot, pivot + flat.Unit)
	for joint, base in member.bases do
		writeBase(joint, base)
	end
	local aim = pitch or 0
	local s = math.sin(phase)
	if name == "walk" or name == "run" then
		local amp = if name == "run" then 38 else 24
		setJoint(member, "LeftHip", CFrame.Angles(rad(amp * s), 0, 0))
		setJoint(member, "RightHip", CFrame.Angles(rad(-amp * s), 0, 0))
		setJoint(member, "LeftKnee", CFrame.Angles(rad(-math.max(0, -s) * amp * 1.4), 0, 0))
		setJoint(member, "RightKnee", CFrame.Angles(rad(-math.max(0, s) * amp * 1.4), 0, 0))
		setJoint(member, "LeftShoulder", CFrame.Angles(rad(-amp * 0.8 * s), 0, 0))
		setJoint(member, "Waist", CFrame.Angles(rad(if name == "run" then -14 else -4), rad(4 * s), 0))
		setJoint(member, "RightShoulder", CFrame.Angles(rad(68 + aim * 0.5), 0, rad(6)))
		setJoint(member, "RightElbow", CFrame.Angles(rad(-25), 0, 0))
		member.root.CFrame *= CFrame.new(0, math.abs(math.cos(phase)) * (if name == "run" then 0.25 else 0.12), 0)
	elseif name == "reach" then
		setJoint(member, "Waist", CFrame.Angles(rad(-10), 0, 0))
		setJoint(member, "LeftShoulder", CFrame.Angles(rad(85), 0, rad(-6)))
		setJoint(member, "LeftElbow", CFrame.Angles(rad(-10), 0, 0))
		setJoint(member, "RightShoulder", CFrame.Angles(rad(60 + aim * 0.5), 0, rad(6)))
		setJoint(member, "RightElbow", CFrame.Angles(rad(-30), 0, 0))
	elseif name == "kneel" then
		local thigh = 0.88
		setJoint(member, "Root", CFrame.new(0, -thigh, 0))
		setJoint(member, "Waist", CFrame.Angles(rad(-24), 0, 0))
		setJoint(member, "Neck", CFrame.Angles(rad(-22), 0, 0))
		setJoint(member, "LeftHip", CFrame.Angles(rad(85), 0, 0))
		setJoint(member, "LeftKnee", CFrame.Angles(rad(-85), 0, 0))
		setJoint(member, "RightHip", CFrame.Angles(rad(-4), 0, 0))
		setJoint(member, "RightKnee", CFrame.Angles(rad(-88), 0, 0))
		setJoint(member, "RightAnkle", CFrame.Angles(rad(30), 0, 0))
		setJoint(member, "LeftShoulder", CFrame.Angles(rad(55), 0, 0))
		setJoint(member, "RightShoulder", CFrame.Angles(rad(40 + aim * 0.5), 0, 0))
	elseif name == "downed" then
		local drop = member.standHeight - 0.95
		setJoint(member, "Root", CFrame.new(0, -drop, 0) * CFrame.Angles(rad(-8), 0, rad(84)))
		setJoint(member, "Neck", CFrame.Angles(rad(-18), rad(20), 0))
		setJoint(member, "LeftHip", CFrame.Angles(rad(35), 0, 0))
		setJoint(member, "LeftKnee", CFrame.Angles(rad(-55), 0, 0))
		setJoint(member, "RightHip", CFrame.Angles(rad(12), 0, 0))
		setJoint(member, "RightKnee", CFrame.Angles(rad(-25), 0, 0))
		setJoint(member, "RightShoulder", CFrame.Angles(rad(70), 0, 0))
	else
		setJoint(member, "RightShoulder", CFrame.Angles(rad(66 + aim * 0.5), 0, rad(6)))
		setJoint(member, "RightElbow", CFrame.Angles(rad(-28), 0, 0))
		setJoint(member, "Waist", CFrame.Angles(rad(2 * math.sin(phase * 0.3)), 0, 0))
	end
end

-- Lanterna na mão direita, apontando para onde o corpo olha (+ pitch). Chame depois de pose().
function TrailerActors.placeLamp(member: Member, pitch: number?, on: boolean?)
	local hand = member.model:FindFirstChild("RightHand")
	local origin = if hand and hand:IsA("BasePart") then hand.Position else member.root.Position
	member.lamp.CFrame = CFrame.new(origin)
		* member.root.CFrame.Rotation
		* CFrame.Angles(rad(pitch or -4), 0, 0)
		* CFrame.new(0, -0.05, -0.3)
	member.light.Enabled = on ~= false
	member.lamp.Transparency = 0
end

function TrailerActors.hide(member: Member)
	member.root.CFrame = CFrame.new(0, -500, 0)
	member.light.Enabled = false
end

-- O Vigia do trailer (mesmo corpo e rosto do jogo).
function TrailerActors.creature(parent: Instance): Creature
	local rig = Rig.build(parent)
	rig.model.Name = "TrailerVigia"
	rig.eyeLight.Range = 9
	return { rig = rig, frame = 1, clock = 0 }
end

-- Pose do Vigia em `position` (pés no chão) olhando para `look`. Troca de quadro a `rate` poses/s.
function TrailerActors.creaturePose(
	creature: Creature,
	position: Vector3,
	look: Vector3,
	animation: string,
	dt: number,
	rate: number,
	headYaw: number?
)
	local frames = (Poses :: any)[animation] or Poses.Idle
	creature.clock += dt
	if creature.clock >= 1 / rate then
		creature.clock = 0
		creature.frame = creature.frame % #frames + 1
	end
	local index = math.clamp(creature.frame, 1, #frames)
	local flat = Vector3.new(look.X - position.X, 0, look.Z - position.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local base = CFrame.lookAt(position, position + flat.Unit)
	local cframes = Rig.solve(creature.rig, base, frames[index], headYaw or 0)
	workspace:BulkMoveTo(creature.rig.order, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

function TrailerActors.hideCreature(creature: Creature)
	local base = CFrame.new(0, -500, 0)
	local cframes = Rig.solve(creature.rig, base, Poses.Idle[1], 0)
	workspace:BulkMoveTo(creature.rig.order, cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

return TrailerActors
