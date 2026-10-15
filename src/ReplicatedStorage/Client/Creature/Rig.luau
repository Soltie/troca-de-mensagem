--!strict
--[[
	Corpo low poly do Vigia (só no cliente) + cinemática direta das poses.

	Silhueta: alto (~7,5 studs), magro, curvado, braços até os joelhos, casaco de vigia escuro,
	cabeça lisa cinzenta com dois olhos pálidos que brilham e uma fenda de boca.
	Peças ancoradas, sem colisão e invisíveis para raycasts (CanQuery = false).
]]

local Poses = require("./Poses")
local AdemirPortrait = require("./AdemirPortrait")

export type Rig = {
	model: Model,
	parts: { [string]: BasePart },
	order: { BasePart },
	head: BasePart,
	emitter: Attachment,
	eyeLight: PointLight,
}

local rgb = Color3.fromRGB
local SKIN = rgb(150, 150, 140)
local COAT = rgb(34, 38, 46)
local PANTS = rgb(26, 26, 28)
local BOOT = rgb(14, 14, 14)
local EYE = rgb(255, 244, 214)

-- Nome -> tamanho, cor, material
local PARTS: { [string]: { size: Vector3, color: Color3, neon: boolean? } } = {
	Pelvis = { size = Vector3.new(1.3, 0.7, 0.75), color = COAT },
	Torso = { size = Vector3.new(1.55, 2.5, 0.85), color = COAT },
	Skirt = { size = Vector3.new(1.75, 1.9, 1.0), color = COAT },
	Collar = { size = Vector3.new(1.3, 0.35, 0.95), color = rgb(48, 52, 60) },
	Neck = { size = Vector3.new(0.35, 0.55, 0.35), color = SKIN },
	Head = { size = Vector3.new(0.85, 1.1, 0.85), color = SKIN },
	EyeL = { size = Vector3.new(0.17, 0.08, 0.05), color = EYE, neon = true },
	EyeR = { size = Vector3.new(0.17, 0.08, 0.05), color = EYE, neon = true },
	Mouth = { size = Vector3.new(0.07, 0.42, 0.05), color = rgb(8, 8, 8) },
	UpperArmL = { size = Vector3.new(0.42, 1.8, 0.42), color = COAT },
	UpperArmR = { size = Vector3.new(0.42, 1.8, 0.42), color = COAT },
	ForearmL = { size = Vector3.new(0.3, 1.9, 0.3), color = SKIN },
	ForearmR = { size = Vector3.new(0.3, 1.9, 0.3), color = SKIN },
	HandL = { size = Vector3.new(0.34, 0.75, 0.16), color = SKIN },
	HandR = { size = Vector3.new(0.34, 0.75, 0.16), color = SKIN },
	ThighL = { size = Vector3.new(0.46, 1.9, 0.46), color = PANTS },
	ThighR = { size = Vector3.new(0.46, 1.9, 0.46), color = PANTS },
	ShinL = { size = Vector3.new(0.36, 1.9, 0.36), color = PANTS },
	ShinR = { size = Vector3.new(0.36, 1.9, 0.36), color = PANTS },
	FootL = { size = Vector3.new(0.46, 0.26, 0.95), color = BOOT },
	FootR = { size = Vector3.new(0.46, 0.26, 0.95), color = BOOT },
}

local HIP_HEIGHT = 3.9
local rad = math.rad

local Rig = {}

function Rig.build(parent: Instance): Rig
	local model = Instance.new("Model")
	model.Name = "VigiaVisual"
	local parts: { [string]: BasePart } = {}
	local order: { BasePart } = {}
	for name, spec in PARTS do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = spec.size
		part.Color = spec.color
		part.Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		parts[name] = part
		table.insert(order, part)
	end
	local head = parts.Head
	local emitter = Instance.new("Attachment")
	emitter.Name = "Emitter"
	emitter.Parent = head
	local light = Instance.new("PointLight")
	light.Color = rgb(255, 214, 170)
	light.Range = 7
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = head
	AdemirPortrait.applyToRig(parts, light)
	model.Parent = parent
	return { model = model, parts = parts, order = order, head = head, emitter = emitter, eyeLight = light }
end

-- Calcula o CFrame de cada peça para `pose`, com a base (pé, no chão) em `base`.
-- `extraNeckYaw` permite virar a cabeça para o jogador (graus).
function Rig.solve(rig: Rig, base: CFrame, pose: Poses.Pose, extraNeckYaw: number): { CFrame }
	local cf: { [string]: CFrame } = {}
	local pelvis = base * CFrame.new(0, HIP_HEIGHT + pose.bob, 0)
	cf.Pelvis = pelvis
	cf.Skirt = pelvis * CFrame.new(0, -0.95, 0.05)

	local chest = pelvis * CFrame.Angles(rad(pose.spine), 0, rad(pose.spineRoll))
	cf.Torso = chest * CFrame.new(0, 1.3, 0)
	cf.Collar = chest * CFrame.new(0, 2.5, 0)

	local neck = chest
		* CFrame.new(0, 2.6, -0.1)
		* CFrame.Angles(rad(pose.neck), rad(pose.neckYaw + extraNeckYaw), rad(pose.neckRoll))
	cf.Neck = neck * CFrame.new(0, 0.2, 0)
	local head = neck * CFrame.new(0, 0.9, -0.12)
	cf.Head = head
	cf.EyeL = head * CFrame.new(-0.2, 0.12, -0.43)
	cf.EyeR = head * CFrame.new(0.2, 0.12, -0.43)
	cf.Mouth = head * CFrame.new(0, -0.27, -0.43)

	for _, side in { "L", "R" } do
		local sign = if side == "L" then -1 else 1
		local shoulderPitch = if side == "L" then pose.lShoulder else pose.rShoulder
		local shoulderRoll = if side == "L" then pose.lShoulderRoll else pose.rShoulderRoll
		local elbowPitch = if side == "L" then pose.lElbow else pose.rElbow
		local shoulder = chest
			* CFrame.new(sign * 0.98, 2.3, 0)
			* CFrame.Angles(rad(shoulderPitch), 0, rad(shoulderRoll))
		-- O braço pende para baixo: girar +pitch em X leva a mão para a frente (-Z).
		cf["UpperArm" .. side] = shoulder * CFrame.new(0, -0.9, 0)
		local elbow = shoulder * CFrame.new(0, -1.8, 0) * CFrame.Angles(rad(-elbowPitch), 0, 0)
		cf["Forearm" .. side] = elbow * CFrame.new(0, -0.95, 0)
		cf["Hand" .. side] = elbow * CFrame.new(0, -2.15, -0.05)

		local hipPitch = if side == "L" then pose.lHip else pose.rHip
		local kneePitch = if side == "L" then pose.lKnee else pose.rKnee
		local hip = pelvis * CFrame.new(sign * 0.42, -0.2, 0) * CFrame.Angles(rad(hipPitch), 0, 0)
		cf["Thigh" .. side] = hip * CFrame.new(0, -0.95, 0)
		local knee = hip * CFrame.new(0, -1.9, 0) * CFrame.Angles(rad(kneePitch), 0, 0)
		cf["Shin" .. side] = knee * CFrame.new(0, -0.95, 0)
		cf["Foot" .. side] = knee * CFrame.new(0, -1.9, -0.25) * CFrame.Angles(-rad(hipPitch + kneePitch) * 0.6, 0, 0)
	end

	local list = table.create(#rig.order)
	for index, part in rig.order do
		list[index] = cf[part.Name] or base
	end
	return list
end

return Rig
