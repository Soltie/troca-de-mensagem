--!strict
--[[
	Corpo do Tung Tung (malha com esqueleto Mixamo importada em ReplicatedStorage.Assets.TungTung)
	animado no cliente: os clipes de TungTungClips viram Bone.Transform a cada quadro, com mistura
	suave entre clipes. Não usa Animator nem assets de animação publicados.

	O pivô do modelo fica entre os pés, olhando para -Z (frente do Roblox).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClipCodec = require("./ClipCodec")
local TungTungClips = require("./TungTungClips")

export type ClipName = "idle" | "walk" | "run" | "slash" | "strafe" | "sheath"

type Track = {
	name: ClipName,
	frames: { { CFrame } },
	decoded: ClipCodec.Decoded,
	time: number,
	speed: number,
	weight: number,
}

export type TungRig = {
	model: Model,
	body: BasePart,
	bones: { Bone },
	head: Bone,
	emitter: Attachment,
	eyeLight: PointLight,
	current: Track?,
	previous: Track?,
	fade: number,
	fadeTime: number,
	breath: number,
}

local TungTungRig = {}

-- Clipes decodificados uma vez por cliente: quadro -> lista de CFrames por osso.
local cache: { [string]: { frames: { { CFrame } }, decoded: ClipCodec.Decoded } } = {}

local function clipData(name: string): ({ { CFrame } }, ClipCodec.Decoded)
	local hit = cache[name]
	if hit then
		return hit.frames, hit.decoded
	end
	local raw = (TungTungClips.Clips :: any)[name]
	assert(raw, `[TungTungRig] unknown clip {name}`)
	local decoded = ClipCodec.decode(raw, TungTungClips.Bones, TungTungClips.PosRange)
	local frames = table.create(decoded.frames)
	for frame = 1, decoded.frames do
		local list = table.create(decoded.boneCount)
		for bone = 1, decoded.boneCount do
			local qx, qy, qz, qw = ClipCodec.rotation(decoded, frame, bone)
			local px, py, pz = ClipCodec.position(decoded, frame, bone)
			list[bone] = CFrame.new(px, py, pz, qx, qy, qz, qw)
		end
		frames[frame] = list
	end
	cache[name] = { frames = frames, decoded = decoded }
	return frames, decoded
end

-- "idle" não veio do Mixamo: é o primeiro quadro do golpe (bastão em guarda) com respiração procedural.
local SOURCE: { [ClipName]: string } = {
	idle = "slash",
	walk = "walk",
	run = "run",
	slash = "slash",
	strafe = "strafe",
	sheath = "sheath",
}

function TungTungRig.available(): boolean
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local template = assets and assets:FindFirstChild("TungTung")
	return template ~= nil and template:IsA("Model") and template:FindFirstChild("Body") ~= nil
end

function TungTungRig.build(parent: Instance?): TungRig?
	if not TungTungRig.available() then
		return nil
	end
	local template = (ReplicatedStorage :: any).Assets.TungTung :: Model
	local model = template:Clone()
	model.Name = "TungTungVisual"
	local body = model:FindFirstChild("Body") :: BasePart
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	local bones: { Bone } = {}
	for index, name in TungTungClips.Bones do
		local bone = body:FindFirstChild(name, true)
		assert(bone and bone:IsA("Bone"), `[TungTungRig] missing bone {name}`)
		bones[index] = bone
	end
	local head = bones[table.find(TungTungClips.Bones, "mixamorig:Head") :: number]
	local emitter = Instance.new("Attachment")
	emitter.Name = "Emitter"
	emitter.Parent = body
	-- Olhos acesos: o Tung Tung aparece no escuro antes de chegar perto (justo para quem joga).
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 196, 120)
	light.Range = 9
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = emitter
	model.Parent = parent
	local rig: TungRig = {
		model = model,
		body = body,
		bones = bones,
		head = head,
		emitter = emitter,
		eyeLight = light,
		current = nil,
		previous = nil,
		fade = 1,
		fadeTime = 0.2,
		breath = 0,
	}
	TungTungRig.play(rig, "idle", 0)
	return rig
end

function TungTungRig.playing(rig: TungRig): ClipName?
	return if rig.current then rig.current.name else nil
end

-- Troca para `name` misturando em `fadeTime` segundos. Repetir o mesmo clipe só ajusta a velocidade.
function TungTungRig.play(rig: TungRig, name: ClipName, fadeTime: number?, speed: number?)
	local current = rig.current
	if current and current.name == name then
		current.speed = speed or current.speed
		return
	end
	local frames, decoded = clipData(SOURCE[name])
	rig.previous = current
	rig.current = {
		name = name,
		frames = frames,
		decoded = decoded,
		time = 0,
		speed = speed or 1,
		weight = 1,
	}
	rig.fadeTime = fadeTime or 0.2
	rig.fade = if rig.previous and rig.fadeTime > 0 then 0 else 1
end

function TungTungRig.setSpeed(rig: TungRig, speed: number)
	if rig.current then
		rig.current.speed = speed
	end
end

-- Fração (0..1) do ciclo do clipe atual; útil para sons de passo.
function TungTungRig.cycle(rig: TungRig): number
	local track = rig.current
	if not track or track.decoded.duration <= 0 then
		return 0
	end
	return (track.time % track.decoded.duration) / track.decoded.duration
end

-- O clipe atual (sem laço) terminou?
function TungTungRig.finished(rig: TungRig): boolean
	local track = rig.current
	return track ~= nil and not track.decoded.loop and track.time >= track.decoded.duration
end

local function sample(track: Track, bone: number): CFrame
	if track.name == "idle" then
		return track.frames[1][bone]
	end
	local a, b, alpha = ClipCodec.locate(track.decoded, track.time)
	return track.frames[a][bone]:Lerp(track.frames[b][bone], alpha)
end

local SPINE = table.find(TungTungClips.Bones, "mixamorig:Spine2") :: number
local NECK = table.find(TungTungClips.Bones, "mixamorig:Neck") :: number

-- Avança os clipes e escreve Bone.Transform. `lookYaw` (graus) vira a cabeça para um alvo.
function TungTungRig.step(rig: TungRig, dt: number, lookYaw: number?)
	local current = rig.current
	if not current then
		return
	end
	current.time += dt * current.speed
	local previous = rig.previous
	if previous then
		previous.time += dt * previous.speed
		rig.fade = math.min(1, rig.fade + dt / math.max(rig.fadeTime, 1e-3))
		if rig.fade >= 1 then
			rig.previous = nil
			previous = nil
		end
	end
	rig.breath += dt
	local alpha = rig.fade * rig.fade * (3 - 2 * rig.fade)
	local breathe = if current.name == "idle" then math.sin(rig.breath * 2.2) * 0.04 else 0
	local yaw = math.rad(lookYaw or 0)
	for index, bone in rig.bones do
		local target = sample(current, index)
		if previous then
			target = sample(previous, index):Lerp(target, alpha)
		end
		if index == SPINE and breathe ~= 0 then
			target *= CFrame.Angles(breathe, 0, 0)
		elseif index == NECK and yaw ~= 0 then
			target *= CFrame.Angles(0, yaw, 0)
		end
		bone.Transform = target
	end
	rig.emitter.WorldPosition = rig.head.TransformedWorldCFrame.Position
end

-- Coloca o pivô (entre os pés) em `base`.
function TungTungRig.place(rig: TungRig, base: CFrame)
	rig.model:PivotTo(base)
end

return TungTungRig
