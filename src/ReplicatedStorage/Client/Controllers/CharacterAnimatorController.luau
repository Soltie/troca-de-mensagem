--!strict
-- Poses procedurais locais sobre o Animator, sem alterar física, velocidade ou autoridade.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Pose = require("@game/ReplicatedStorage/Shared/Game/CharacterPose")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Camera = require("./CameraController")

type Joint = Motor6D | AnimationConstraint
type Rig = {
	model: Model,
	motors: { [string]: Joint },
	bases: { [Joint]: CFrame },
	pitch: number,
	crouch: number,
	lamp: BasePart?,
	light: SpotLight?,
	hipHeight: number,
}
local rigs: { [Player]: Rig } = {}
local player = Players.LocalPlayer
local lastPitch: number? = nil
local since = 10
local step = 0
local Controller = { Name = "CharacterAnimatorController" }

-- Avatares novos usam AnimationConstraint; o offset base vive no Attachment0.
local function writeBase(joint: Joint, frame: CFrame)
	if joint:IsA("Motor6D") then
		joint.C0 = frame
	elseif joint.Attachment0 then
		joint.Attachment0.CFrame = frame
	end
end

local function readBase(joint: Joint): CFrame
	if joint:IsA("Motor6D") then
		return joint.C0
	end
	return if joint.Attachment0 then joint.Attachment0.CFrame else CFrame.identity
end

local function remove(other: Player)
	local rig = rigs[other]
	if not rig then
		return
	end
	for motor, base in rig.bases do
		if motor.Parent then
			writeBase(motor, base)
		end
	end
	if rig.lamp then
		rig.lamp:Destroy()
	end
	rigs[other] = nil
end

local function getRig(other: Player): Rig?
	local model = other.Character
	-- A Roblox monta attachments/offsets depois do CharacterAdded; aguarde o rig completo.
	if not model or not other:HasAppearanceLoaded() then
		return nil
	end
	local old = rigs[other]
	-- Avatar pode chegar em partes: não congele um cache criado antes dos Motor6Ds.
	if old and old.model == model and old.motors.Neck then
		return old
	end
	remove(other)
	local h = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not h then
		return nil
	end
	local rig: Rig = {
		model = model,
		motors = {},
		bases = {},
		pitch = 0,
		crouch = 0,
		lamp = nil,
		light = nil,
		hipHeight = math.max(h.HipHeight, 1.8),
	}
	for _, inst in model:GetDescendants() do
		if inst:IsA("Motor6D") or (inst:IsA("AnimationConstraint") and inst.Attachment0 and inst.Attachment1) then
			rig.motors[inst.Name] = inst
			rig.bases[inst] = readBase(inst)
		end
	end
	if other ~= player then
		local lamp = Instance.new("Part")
		lamp.Name = `TeammateFlashlight_{other.UserId}`
		lamp.Size = Vector3.new(0.24, 0.24, 0.65)
		lamp.Color = Color3.fromRGB(55, 60, 53)
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.CanTouch = false
		lamp.CastShadow = false
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 28
		light.Angle = 42
		light.Brightness = 1.4
		light.Shadows = false
		light.Color = Color3.fromRGB(255, 230, 182)
		light.Parent = lamp
		lamp.Parent = workspace
		rig.lamp, rig.light = lamp, light
	end
	rigs[other] = rig
	return rig
end

local function joint(rig: Rig, name: string, frame: CFrame)
	local motor = rig.motors[name]
	if motor then
		writeBase(motor, rig.bases[motor] * frame)
	end
end

local function animate(other: Player, dt: number)
	local rig = getRig(other)
	if not rig then
		return
	end
	local root = rig.model:FindFirstChild("HumanoidRootPart")
	local h = rig.model:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not h then
		return
	end
	local crouch = other:GetAttribute("Stance") == "Crouch"
	rig.crouch = Pose.approach(rig.crouch, if crouch then 1 else 0, 12, dt)
	rig.pitch = Pose.approach(rig.pitch, (other:GetAttribute("LookPitch") :: number?) or 0, 12, dt)
	local down = other:GetAttribute("CampaignStatus") == "Downed"
	local rescue = other:GetAttribute("CampaignFeedback") == "rescuing"
	local on = other:GetAttribute(Tags.Attr.Flashlight) == true
		and (other:GetAttribute("Hidden") == nil or other:GetAttribute("Hidden") == "")
	local neck, waist = Pose.split(rig.pitch)
	local angle, lift = Pose.crouch(2.2, math.max(0, rig.hipHeight - h.HipHeight))
	angle *= rig.crouch
	local lean = Pose.lean(root.AssemblyLinearVelocity.Magnitude, Config.Player.WalkSpeed, Config.Player.SprintSpeed)
	for motor, base in rig.bases do
		if motor.Parent then
			writeBase(motor, base)
		end
	end
	joint(rig, "Neck", CFrame.Angles(math.rad(neck), 0, 0))
	joint(rig, "Waist", CFrame.Angles(math.rad(waist - lean - (if rescue then 25 else 0)), 0, 0))
	joint(rig, "LeftHip", CFrame.Angles(angle, 0, 0))
	joint(rig, "RightHip", CFrame.Angles(if rescue then math.rad(75) else angle, 0, 0))
	joint(rig, "LeftKnee", CFrame.Angles(-2 * angle, 0, 0))
	joint(rig, "RightKnee", CFrame.Angles(if rescue then math.rad(-110) else -2 * angle, 0, 0))
	joint(rig, "LeftAnkle", CFrame.Angles(angle, 0, 0))
	joint(rig, "RightAnkle", CFrame.Angles(angle, 0, 0))
	if on then
		joint(rig, "RightShoulder", CFrame.Angles(math.rad(65 + rig.pitch * 0.5), 0, math.rad(8)))
		joint(rig, "RightElbow", CFrame.Angles(math.rad(-35), 0, 0))
	end
	if down then
		joint(rig, "Root", CFrame.new(0, -1.25, 0) * CFrame.Angles(0, 0, math.rad(82)))
		joint(rig, "RootJoint", CFrame.Angles(0, 0, math.rad(82)))
	else
		joint(rig, "Root", CFrame.new(0, lift * rig.crouch, 0))
	end
	local lamp, light = rig.lamp, rig.light
	if lamp and light then
		local camera = workspace.CurrentCamera
		local near = camera ~= nil and (camera.CFrame.Position - root.Position).Magnitude < 100
		local visible = on and near and not down and h.Health > 0
		lamp.Transparency = if visible then 0 else 1
		light.Enabled = visible
		local hand = rig.model:FindFirstChild("RightHand") or rig.model:FindFirstChild("Right Arm")
		if hand and hand:IsA("BasePart") then
			lamp.CFrame = CFrame.new(hand.Position)
				* root.CFrame.Rotation
				* CFrame.Angles(math.rad(rig.pitch), 0, 0)
				* CFrame.new(0, -0.1, -0.3)
		end
	end
end

function Controller.debugState(): { [string]: any }
	local count, lamps = 0, 0
	local joints = 0
	local constraints = 0
	for _, rig in rigs do
		count += 1
		if rig.lamp then
			lamps += 1
		end
		for _, motor in rig.motors do
			joints += 1
			if motor:IsA("AnimationConstraint") then
				constraints += 1
			end
		end
	end
	return { rigs = count, lamps = lamps, lastPitch = lastPitch, joints = joints, constraints = constraints }
end

function Controller.Start()
	Players.PlayerRemoving:Connect(remove)
	player.CharacterAdded:Connect(function()
		lastPitch = nil
		since = 10
	end)
	RunService.PreSimulation:Connect(function(dt)
		since += dt
		local camera = workspace.CurrentCamera
		local mode = Camera.debugState().mode
		if camera and mode ~= "cinema" and mode ~= "spectate" then
			local pitch = Pose.quantizePitch(math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))))
			if Pose.shouldSend(lastPitch, pitch, since) then
				lastPitch, since = pitch, 0
				Remotes.clientEvent("SetLook", 5):FireServer(pitch)
			end
		end
		step += dt
		if step < 1 / 12 then
			return
		end
		local elapsed = step
		step = 0
		for _, other in Players:GetPlayers() do
			animate(other, elapsed)
		end
	end)
end
return Controller
