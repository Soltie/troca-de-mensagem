--!strict
--[[
	Corpo do Tung Tung (malha com esqueleto Mixamo importada em ReplicatedStorage.Assets.TungTung)
	animado no cliente: os clipes de TungTungClips viram Bone.Transform a cada quadro, com mistura
	suave entre clipes. Não usa Animator nem assets de animação publicados.

	Os clipes são animados no Blender (tools/tungtung/blender): pés plantados com IK, então o pé só não
	escorrega se o clipe tocar na velocidade certa (feetSpeed). Marcadores de som (passo, batida do bastão)
	saem no quadro exato por markers().

	O pivô do modelo fica entre os pés, olhando para -Z (frente do Roblox).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClipCodec = require("./ClipCodec")
local TungTungClips = require("./TungTungClips")

export type ClipName =
	"idle"
	| "stand"
	| "walk"
	| "searchwalk"
	| "run"
	| "search"
	| "alert"
	| "listen"
	| "peek"
	| "bash"
	| "warn"
	| "grab"
	| "knock3"
	| "stunned"
	| "menuidle"
	| "drag"
	| "throw"
	| "slash"
	| "strafe"
	| "sheath"

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
	headPart: BasePart,
	current: Track?,
	previous: Track?,
	fade: number,
	fadeTime: number,
	breath: number,
	-- Tempo do clipe atual no quadro anterior (para achar marcadores atravessados).
	lastTime: number,
	-- Ação só do tronco para cima (cabeça, braços) por cima do andar: escutar andando, por exemplo.
	overlay: Track?,
	overlayWeight: number,
}

local TungTungRig = {}

-- Altura (e tamanho geral) do visual em relação ao modelo; WIDTH_SCALE alarga só o corpo depois.
local VISUAL_SCALE = 1.24
local WIDTH_SCALE = 1.18
local SKIN_TINT = Color3.fromRGB(170, 140, 106)
-- Olhos: âmbar pré-compensado para o filtro frio da cena (ColorCorrection multiplica ~0,73/0,82/1,0 e tira 35% da
-- saturação). Depois do filtro fica ~(185,123,40), âmbar quente; o amarelo antigo saía esverdeado. Brilho vem do
-- tamanho/alcance, não de mais verde.
local EYE_COLOR = Color3.fromRGB(255, 150, 40)

-- Clipes decodificados uma vez por cliente: quadro -> lista de CFrames por osso.
local cache: { [string]: { frames: { { CFrame } }, decoded: ClipCodec.Decoded } } = {}

-- "idle" (guarda do jumpscare e das cenas antigas) continua sendo o 1º quadro do golpe com respiração procedural;
-- o parado novo do jogo é "stand". Os clipes do Mixamo (golpe, guardar, lateral) ficam exatamente como eram.
local SOURCE: { [string]: string } = { idle = "slash" }
local LEGACY: { [string]: boolean } = { slash = true, sheath = true, strafe = true }

local function clipData(name: string): ({ { CFrame } }, ClipCodec.Decoded)
	name = SOURCE[name] or name
	local hit = cache[name]
	if hit then
		return hit.frames, hit.decoded
	end
	local raw = (TungTungClips.Clips :: any)[name]
	assert(raw, `[TungTungRig] unknown clip {name}`)
	local decoded = ClipCodec.decode(raw, TungTungClips.Bones, TungTungClips.PosRange)
	-- A translação do quadril cresce junto com o modelo (senão o pé flutua quando ele agacha).
	local grow = if LEGACY[name] then 1 else VISUAL_SCALE
	local frames = table.create(decoded.frames)
	for frame = 1, decoded.frames do
		local list = table.create(decoded.boneCount)
		for bone = 1, decoded.boneCount do
			local qx, qy, qz, qw = ClipCodec.rotation(decoded, frame, bone)
			local px, py, pz = ClipCodec.position(decoded, frame, bone)
			list[bone] = CFrame.new(px * grow, py * grow, pz * grow, qx, qy, qz, qw)
		end
		frames[frame] = list
	end
	cache[name] = { frames = frames, decoded = decoded }
	return frames, decoded
end

-- Velocidade (studs/s) que os pés plantados percorrem com o clipe em 1x, já na escala do visual.
function TungTungRig.feetSpeed(name: ClipName): number
	local speeds = (TungTungClips :: any).FeetSpeed :: { [string]: number }
	return (speeds[name] or 0) * VISUAL_SCALE
end

function TungTungRig.duration(name: ClipName): number
	local _, decoded = clipData(name)
	return decoded.duration
end

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
	-- Um pouco mais alto que o jogador maior (Config.Player.BodyScale): só o visual; a raiz do servidor,
	-- o agente de pathfinding e a captura não mudam.
	model:ScaleTo(model:GetScale() * VISUAL_SCALE)
	-- Nome antigo mantido: medo, tensão e câmera de captura procuram "VigiaVisual" no workspace.
	model.Name = "VigiaVisual"
	local body = model:FindFirstChild("Body") :: BasePart
	-- Mais encorpado (pedido do humano): alarga a malha e as raízes do esqueleto só no X/Z.
	body.Size = Vector3.new(body.Size.X * WIDTH_SCALE, body.Size.Y, body.Size.Z * WIDTH_SCALE)
	for _, bone in body:GetChildren() do
		if bone:IsA("Bone") then
			bone.Position = Vector3.new(bone.Position.X * WIDTH_SCALE, bone.Position.Y, bone.Position.Z * WIDTH_SCALE)
		end
	end
	-- Madeira marrom e fosca, não boneco dourado. O próprio Assets/TungTung já vem sem o mapa de metal e com a cor
	-- de madeira; aqui só garante a cor (o Roblox não deixa script de jogo trocar mapas da textura).
	local skin: any = body:FindFirstChildWhichIsA("SurfaceAppearance")
	if skin then
		pcall(function()
			skin.Color = SKIN_TINT
		end)
	end
	-- Sem brilho nos olhos (pedido do usuário, 20/10): peça Neon de olho que venha no modelo vira madeira escura fosca.
	for _, part in model:GetDescendants() do
		if
			part:IsA("BasePart")
			and part.Material == Enum.Material.Neon
			and string.find(string.lower(part.Name), "eye")
		then
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(28, 18, 12)
		end
	end
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
	-- (Histórico) Olhos acesos: o Tung aparecia no escuro antes de chegar perto.
	local light = Instance.new("PointLight")
	light.Color = EYE_COLOR
	-- Alcance curto: acende o rosto, não o corpo todo (senão ele vira um boneco laranja chapado).
	light.Range = 6
	light.Brightness = 1
	light.Shadows = false
	-- Desligada a pedido do usuário (20/10): o Tung não acende os olhos. Fica no rig porque outros controllers mexem em Brightness.
	light.Enabled = false
	light.Parent = emitter
	-- Peça invisível que segue o osso da cabeça (alvo da câmera de captura e dos raycasts de visão).
	local headPart = Instance.new("Part")
	headPart.Name = "Head"
	headPart.Size = Vector3.new(1.4, 1.4, 1.4)
	headPart.Transparency = 1
	headPart.Anchored = true
	headPart.CanCollide = false
	headPart.CanQuery = false
	headPart.CanTouch = false
	headPart.CastShadow = false
	headPart.Parent = model
	model.Parent = parent
	local rig: TungRig = {
		model = model,
		body = body,
		bones = bones,
		head = head,
		emitter = emitter,
		eyeLight = light,
		headPart = headPart,
		current = nil,
		previous = nil,
		fade = 1,
		fadeTime = 0.2,
		breath = 0,
		lastTime = 0,
		overlay = nil,
		overlayWeight = 0,
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
	local frames, decoded = clipData(name)
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
	rig.lastTime = -1e-3
end

-- Recomeça o clipe atual do início (para repetir uma ação curta, como a batida).
function TungTungRig.restart(rig: TungRig)
	if rig.current then
		rig.current.time = 0
		rig.lastTime = -1e-3
	end
end

-- Toca `name` só no tronco, braços e cabeça (as pernas seguem o clipe atual). Some sozinho no fim.
function TungTungRig.overlay(rig: TungRig, name: ClipName, speed: number?)
	local frames, decoded = clipData(name)
	rig.overlay = { name = name, frames = frames, decoded = decoded, time = 0, speed = speed or 1, weight = 1 }
end

-- Marcadores do clipe atual atravessados desde o último step (nomes, na ordem). Clipes em laço dão a volta.
function TungTungRig.markers(rig: TungRig): { string }
	local hits: { string } = {}
	local track = rig.current
	local list = track
		and ((TungTungClips :: any).Markers :: { [string]: { { name: string, time: number } } })[track.name]
	if not track or not list then
		return hits
	end
	local duration = track.decoded.duration
	local from, to = rig.lastTime, track.time
	if to <= from then
		return hits
	end
	local loop = track.decoded.loop and duration > 0
	for _, marker in list do
		local t = marker.time
		if loop then
			-- Conta quantas vezes `t + k·duration` caiu em (from, to].
			local k = math.ceil((from - t) / duration)
			if t + k * duration <= from then
				k += 1
			end
			if t + k * duration <= to then
				table.insert(hits, marker.name)
			end
		elseif t > from and t <= to then
			table.insert(hits, marker.name)
		end
	end
	return hits
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
-- Ossos do tronco para cima (sem quadril e pernas), usados pelo overlay.
local UPPER: { [number]: boolean } = {}
for index, name in TungTungClips.Bones do
	if
		not string.find(name, "Leg")
		and not string.find(name, "Foot")
		and not string.find(name, "Toe")
		and name ~= "mixamorig:Hips"
	then
		UPPER[index] = true
	end
end
local OVERLAY_FADE = 0.15

-- Depuração (Studio, só no cliente): workspace:SetAttribute("AnimSlow", 0.25) deixa o Tung e o jumpscare a 1/4 da
-- velocidade para tirar prints quadro a quadro. Sem o atributo (padrão), 1.
function TungTungRig.slow(): number
	local value = workspace:GetAttribute("AnimSlow")
	return if type(value) == "number" and value > 0 then math.min(value, 1) else 1
end

-- Avança os clipes e escreve Bone.Transform. `lookYaw`/`lookPitch` (graus) viram o pescoço para um alvo
-- (positivo = para a esquerda dele / para baixo); o menu usa para ele olhar o botão sob o mouse.
function TungTungRig.step(rig: TungRig, dt: number, lookYaw: number?, lookPitch: number?)
	local current = rig.current
	if not current then
		return
	end
	dt *= TungTungRig.slow()
	rig.lastTime = current.time
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
	local overlay = rig.overlay
	local overlayAlpha = 0
	if overlay then
		overlay.time += dt * overlay.speed
		local left = overlay.decoded.duration - overlay.time
		if left <= 0 then
			rig.overlay = nil
			overlay = nil
		else
			local w = math.min(1, overlay.time / OVERLAY_FADE, left / OVERLAY_FADE)
			overlayAlpha = w * w * (3 - 2 * w)
		end
	end
	local breathe = if current.name == "idle" then math.sin(rig.breath * 2.2) * 0.04 else 0
	local yaw = math.rad(lookYaw or 0)
	local pitch = math.rad(lookPitch or 0)
	for index, bone in rig.bones do
		local target = sample(current, index)
		if previous then
			target = sample(previous, index):Lerp(target, alpha)
		end
		if overlay and overlayAlpha > 0 and UPPER[index] then
			target = target:Lerp(sample(overlay, index), overlayAlpha)
		end
		if index == SPINE and breathe ~= 0 then
			target *= CFrame.Angles(breathe, 0, 0)
		elseif index == NECK and (yaw ~= 0 or pitch ~= 0) then
			target *= CFrame.Angles(pitch, yaw, 0)
		end
		bone.Transform = target
	end
	local head = rig.head.TransformedWorldCFrame
	rig.emitter.WorldPosition = head.Position
	rig.headPart.CFrame = head
end

-- Coloca o pivô (entre os pés) em `base`.
function TungTungRig.place(rig: TungRig, base: CFrame)
	rig.model:PivotTo(base)
end

return TungTungRig
