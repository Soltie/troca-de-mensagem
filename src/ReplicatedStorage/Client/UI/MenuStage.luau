--!strict
--[[
	Palco 3D do menu inicial (cena de verdade no Workspace, só no cliente, longe do mapa).

	Um quarto fechado e preto com uma parede de tábuas atrás. O Tung Tung fica no meio, iluminado de
	baixo por UMA lamparina fora do quadro que balança devagar. A luz cai rápido: só o Tung, o chão perto
	dele e um pedaço da parede aparecem; o resto da tela é preto.

	Sombra: a sombra dinâmica de luz pontual some na qualidade gráfica média/baixa (e no celular). Por isso a
	sombra na parede é FALSA e sempre igual: uma cópia preta e maior do Tung, colada na parede, que copia os
	ossos do Tung a cada quadro e anda com o balanço da lamparina.

	  build()              cria a cena (pasta "MenuStage" no Workspace).
	  frame(u, aspect)     CFrame e FOV da câmera para o Tung aparecer na fração horizontal `u` da tela.
	  step(dt)             anima Tung, sombra, olhos, lamparina e câmera; true no quadro de uma batida do bastão.
	  look(yaw)            vira a cabeça (graus) para o botão em foco; 0 = olha a câmera.
	  react(name)          gesto curto (bater o bastão ao abrir ou ao entrar no JOGAR).
	  setActive(on)        liga/desliga luz e animação (menu fechado = cena parada e apagada).

	Coreografia: "menuidle" do Animador em laço (curvado, bastão arrastando, TUM a cada volta). Sem braços abertos.
	A cabeça é livre no clipe: look(yaw) vira o pescoço para o botão em foco.
]]

local TungTungRig = require("../Creature/TungTungRig")

local MenuStage = {}

export type Stage = {
	folder: Folder,
	rig: TungTungRig.TungRig?,
	shadow: TungTungRig.TungRig?,
	eyes: { BasePart },
	lamp: PointLight,
	lampPart: BasePart,
	clock: number,
	nextAct: number,
	pulse: number,
	acting: boolean,
	yaw: number,
	targetYaw: number,
	active: boolean,
}

-- Longe de tudo (casa, floresta, lobby): o quarto do menu não aparece no jogo nem é visto do jogo.
local ORIGIN = CFrame.new(4200, 650, -4200)
local BASE_CLIP: TungTungRig.ClipName = "menuidle"
-- O "menuidle" já bate o bastão sozinho (TUM aos 3,7 s); gestos extras só por react (abrir, JOGAR).
local ACTS: { TungTungRig.ClipName } = {}
local FOV = 30
local EYE = Vector3.new(0, 3.2, -27)
local TARGET = Vector3.new(0, 5.5, 0)
local LAMP_BRIGHTNESS = 3
local LAMP = Vector3.new(1.4, 0.8, -4.2)
-- Lamparina pendurada num fio de 3 studs: balança ±4° num ciclo de 5 s (página do menu).
local LAMP_CORD = 3
local LAMP_SWING = math.rad(4)
-- Parede de tábuas: face da frente em z = 6.75. A sombra falsa fica logo à frente dela.
local WALL_Z = 7
local SHADOW_SCALE = 2
local SHADOW_Z = 6.2
-- Brilho dos olhos: no espaço do osso da cabeça (medida do Animador na malha; z conferido por print, 20/10).
local EYE_OFFSETS = { Vector3.new(-0.26, 0.45, -0.93), Vector3.new(0.26, 0.45, -0.93) }
-- Amarelo quente da página. O LightingController deixa a cena do menu sem a correção fria (que esverdeava).
local EYE_COLOR = Color3.fromRGB(255, 210, 122)

local rgb = Color3.fromRGB

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = ORIGIN * cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function room(folder: Folder)
	local black = rgb(2, 2, 2)
	-- Caixa fechada e de paredes GROSSAS (8 studs): a luz do céu do Future vaza por parede fina (voxel de 4 studs)
	-- e acende o quarto todo por igual. A câmera fica longe (z = -27), dentro da caixa.
	part(folder, "Floor", Vector3.new(80, 8, 80), CFrame.new(0, -4, -12), rgb(28, 19, 13), Enum.Material.WoodPlanks)
	-- O teto aceita raycast: o LightingController testa "sob teto" pela câmera e usa a luz de interior.
	part(folder, "Ceiling", Vector3.new(80, 8, 80), CFrame.new(0, 30, -12), black).CanQuery = true
	part(folder, "WallLeft", Vector3.new(8, 40, 80), CFrame.new(-36, 13, -12), black)
	part(folder, "WallRight", Vector3.new(8, 40, 80), CFrame.new(36, 13, -12), black)
	part(folder, "WallFront", Vector3.new(80, 40, 8), CFrame.new(0, 13, -48), black)
	-- Parede de tábuas verticais atrás do Tung (escura: só acende onde a lamparina alcança).
	local random = Random.new(31)
	local x = -28
	while x < 28 do
		local width = random:NextNumber(1.1, 1.7)
		local shade = random:NextNumber(0, 1)
		part(
			folder,
			"Plank",
			Vector3.new(width - 0.1, 26, 0.5),
			CFrame.new(x + width / 2, 13, WALL_Z + random:NextNumber(-0.08, 0.08)),
			rgb(26, 17, 12):Lerp(rgb(58, 40, 28), shade),
			Enum.Material.WoodPlanks
		)
		x += width
	end
	part(folder, "WallBack", Vector3.new(80, 40, 8), CFrame.new(0, 13, 11.6), black)
	-- Sombra elíptica no chão, sob os pés (a lamparina baixa a espicha para trás).
	local pool = part(
		folder,
		"FloorShadow",
		Vector3.new(0.04, 7, 3.6),
		CFrame.new(0, 0.03, 0.8) * CFrame.Angles(0, 0, math.rad(90)),
		rgb(0, 0, 0)
	)
	pool.Shape = Enum.PartType.Cylinder
	pool.Transparency = 0.2
	pool.CastShadow = false
	part(folder, "Baseboard", Vector3.new(56, 0.6, 0.3), CFrame.new(0, 0.3, 6.7), rgb(18, 12, 8), Enum.Material.Wood)
end

local function dust(folder: Folder)
	-- Serragem caindo devagar; LightInfluence 1 = só aparece onde a lamparina ilumina.
	local box = part(folder, "Sawdust", Vector3.new(12, 0.2, 6), CFrame.new(0, 15, -2), rgb(0, 0, 0))
	box.Transparency = 1
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Sawdust"
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(8, 12)
	emitter.Speed = NumberRange.new(0.3, 0.7)
	emitter.SpreadAngle = Vector2.new(25, 25)
	emitter.EmissionDirection = Enum.NormalId.Bottom
	emitter.Acceleration = Vector3.new(0, -0.04, 0)
	emitter.RotSpeed = NumberRange.new(-40, 40)
	emitter.Size = NumberSequence.new(0.05, 0.03)
	emitter.Color = ColorSequence.new(rgb(255, 228, 186))
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.35),
		NumberSequenceKeypoint.new(0.85, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightInfluence = 1
	emitter.LightEmission = 0.15
	emitter.Parent = box
end

-- Cópia preta e maior do Tung, colada na parede: a sombra que aparece em qualquer qualidade gráfica.
local function fakeShadow(folder: Folder): TungTungRig.TungRig?
	local shadow = TungTungRig.build(folder)
	if not shadow then
		return nil
	end
	shadow.model.Name = "MenuTungShadow"
	shadow.model:ScaleTo(shadow.model:GetScale() * SHADOW_SCALE)
	shadow.eyeLight.Enabled = false
	for _, item in shadow.model:GetDescendants() do
		if item:IsA("SurfaceAppearance") or item:IsA("Decal") or item:IsA("Texture") then
			item:Destroy()
		elseif item:IsA("MeshPart") then
			item.TextureID = ""
		end
		if item:IsA("BasePart") then
			item.Color = Color3.new(0, 0, 0)
			item.Material = Enum.Material.SmoothPlastic
			item.Reflectance = 0
			item.CastShadow = false
			if item.Transparency < 1 then
				item.Transparency = 0.3
			end
		end
	end
	return shadow
end

local function eyeGlints(folder: Folder): { BasePart }
	local eyes: { BasePart } = {}
	for index = 1, #EYE_OFFSETS do
		local eye = part(folder, `Eye{index}`, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), EYE_COLOR)
		eye.Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.Neon
		eye.CastShadow = false
		eyes[index] = eye
	end
	return eyes
end

function MenuStage.build(): Stage
	local old = workspace:FindFirstChild("MenuStage")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MenuStage"
	room(folder)
	dust(folder)
	-- A única luz: lamparina fora do quadro, embaixo e à frente, um pouco à direita. Alcance curto = resto preto.
	local lampPart = part(folder, "Lamp", Vector3.new(0.4, 0.4, 0.4), CFrame.new(LAMP), rgb(0, 0, 0))
	lampPart.Transparency = 1
	local lamp = Instance.new("PointLight")
	-- Brasa da página (226,114,63) puxada para o âmbar: na madeira pura ela saturava em vermelho.
	lamp.Color = rgb(240, 150, 92)
	lamp.Brightness = LAMP_BRIGHTNESS
	lamp.Range = 16
	-- A sombra é a falsa (sempre igual em PC e celular); a dinâmica dobraria a silhueta na qualidade alta.
	lamp.Shadows = false
	lamp.Parent = lampPart
	folder.Parent = workspace
	local rig = TungTungRig.build(folder)
	if rig then
		-- Nome próprio: medo/tensão/captura procuram "VigiaVisual" no Workspace e não podem achar este.
		rig.model.Name = "MenuTung"
		-- A luz dos olhos acenderia o rosto todo de laranja; o brilho vem das esferas neon.
		rig.eyeLight.Enabled = false
		TungTungRig.play(rig, BASE_CLIP, 0)
		TungTungRig.place(rig, ORIGIN)
	end
	local shadow = fakeShadow(folder)
	if shadow then
		TungTungRig.play(shadow, BASE_CLIP, 0)
	end
	return {
		folder = folder,
		rig = rig,
		shadow = shadow,
		eyes = eyeGlints(folder),
		lamp = lamp,
		lampPart = lampPart,
		clock = 0,
		nextAct = 5,
		pulse = 0,
		acting = false,
		yaw = 0,
		targetYaw = 0,
		active = true,
	}
end

-- Câmera baixa (ele parece maior) e girada para o Tung cair na fração `u` (0..1) da largura da tela.
-- `fov` é o que a câmera vai usar de fato (o ajuste "FOV dinâmico" desligado força o padrão do jogo):
-- a distância compensa para o enquadramento ficar igual.
function MenuStage.frame(stage: Stage, u: number, aspect: number, fov: number?): (CFrame, number)
	local lens = math.clamp(fov or FOV, 10, 100)
	local clock = stage.clock
	local drift = math.sin(clock * 0.21) * 0.05
	local reach = math.tan(math.rad(FOV / 2)) / math.tan(math.rad(lens / 2))
	local offset = (EYE - TARGET) * reach
	local eye = TARGET
		+ Vector3.new(-math.sin(drift) * offset.Z, offset.Y + math.sin(clock * 0.33) * 0.12, math.cos(drift) * offset.Z)
	local shake = stage.pulse * stage.pulse * 0.08
	local base = CFrame.lookAt(eye + Vector3.new(0, shake * math.sin(clock * 80), 0), TARGET)
	-- Girar a câmera para a esquerda empurra o Tung para a direita da tela (e vice-versa).
	local half = math.tan(math.rad(lens / 2)) * aspect
	local turn = math.atan((2 * math.clamp(u, 0, 1) - 1) * half)
	return ORIGIN * base * CFrame.Angles(0, turn, 0), FOV
end

function MenuStage.look(stage: Stage, yaw: number)
	stage.targetYaw = yaw
end

function MenuStage.react(stage: Stage, name: TungTungRig.ClipName)
	local rig = stage.rig
	if rig then
		stage.acting = true
		stage.nextAct = stage.clock + 9
		TungTungRig.play(rig, name, 0.25)
	end
end

function MenuStage.setActive(stage: Stage, active: boolean)
	if stage.active == active then
		return
	end
	stage.active = active
	stage.lamp.Enabled = active
end

function MenuStage.step(stage: Stage, dt: number): boolean
	if not stage.active then
		return false
	end
	stage.clock += dt
	local clock = stage.clock
	local beat = false
	-- Lamparina pendurada balançando; a chama tremula de leve.
	local angle = LAMP_SWING * math.sin(clock * math.pi * 2 / 5)
	local lampOffset = LAMP + Vector3.new(math.sin(angle) * LAMP_CORD, LAMP_CORD * (1 - math.cos(angle)), 0)
	stage.lampPart.CFrame = ORIGIN * CFrame.new(lampOffset)
	local rig = stage.rig
	if rig then
		if stage.acting and TungTungRig.finished(rig) then
			stage.acting = false
			TungTungRig.play(rig, BASE_CLIP, 0.45)
		elseif not stage.acting and #ACTS > 0 and clock >= stage.nextAct then
			stage.acting = true
			stage.nextAct = clock + 7 + (clock * 7.3) % 4
			TungTungRig.play(rig, ACTS[math.floor(clock) % #ACTS + 1], 0.35)
		end
		stage.yaw += (stage.targetYaw - stage.yaw) * (1 - math.exp(-dt * 4))
		local sway = math.sin(clock * 0.3) * 0.06
		TungTungRig.place(rig, ORIGIN * CFrame.Angles(0, sway, 0))
		TungTungRig.step(rig, dt, stage.yaw)
		for _, marker in TungTungRig.markers(rig) do
			if marker == "tap" then
				beat = true
			end
		end
		-- Sombra: mesma pose, projetada da lamparina (baixa, à direita) para cima e para a esquerda na parede.
		local shadow = stage.shadow
		if shadow then
			for index, bone in rig.bones do
				shadow.bones[index].Transform = bone.Transform
			end
			local reach = (WALL_Z - lampOffset.Z) / (0 - lampOffset.Z)
			local base = Vector3.new(lampOffset.X * (1 - reach), lampOffset.Y * (1 - reach), SHADOW_Z)
			TungTungRig.place(shadow, ORIGIN * CFrame.new(base) * CFrame.Angles(0, sway, 0))
		end
		-- Brilho nos olhos: segue o osso da cabeça (o único ponto quente além da lamparina).
		local head = rig.head.TransformedWorldCFrame
		-- Pisca a cada 6 s (fecha por 0,1 s).
		local blink = clock % 6 < 0.1
		for index, eye in stage.eyes do
			eye.CFrame = head * CFrame.new(EYE_OFFSETS[index])
			eye.Transparency = if blink then 1 else 0
		end
	end
	if beat then
		stage.pulse = 1
	end
	stage.pulse = math.max(0, stage.pulse - dt * 2.5)
	local flicker = math.noise(clock * 3.1, 0.5) * 0.3 + math.noise(clock * 11, 2.5) * 0.1
	stage.lamp.Brightness = LAMP_BRIGHTNESS * (1 + flicker) + stage.pulse * 0.8
	return beat
end

function MenuStage.destroy(stage: Stage)
	stage.folder:Destroy()
end

return MenuStage
