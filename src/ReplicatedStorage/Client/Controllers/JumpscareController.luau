--!strict
--[[
	Jumpscare do Tung Tung (quando ELE derruba você: pancada ou porta do armário aberta). Só para quem foi pego.
	Pensado como os bons do gênero (DOORS, The Mimic, FNAF): o susto vem do contraste, não do volume o tempo todo.
	Sem sangue: o fim é a pessoa virando móvel, como na história (a madeira fecha a tela).

	Três versões (as novas são sorteadas sem repetir; "classic" é a de 20/10, guardada para comparação):
	- "grab" (2,2 s): 0,5 s de aviso (a imagem escurece, TUM TUM, os olhos acendem longe); ele surge colado, as duas
	  mãos de pau fecham, o rosto entalhado enche a tela e a cabeça estala de lado; a madeira fecha (vira móvel).
	- "above" (2,0 s): 0,5 s de aviso (a lanterna falha duas vezes); escuro; o rosto desce de cima, de ponta-cabeça,
	  iluminado pela lanterna, para colado e avança; a madeira fecha.
	- "classic" (1,55 s): silêncio, duas batidas, ele avança de corpo inteiro com o bastão, pancada e queda.
	Para comparar no Studio: atributo do jogador "JumpscareVariant" = "classic" | "grab" | "above".
	Usa uma cópia local do mesmo modelo animado (TungTungRig): ninguém mais vê, e não depende de onde o Tung Tung
	real está. Sem o modelo (place sem o asset), não faz nada e a câmera de captura antiga cuida do momento.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local TungTungRig = require("../Creature/TungTungRig")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local SettingsController = require("./SettingsController")

local player = Players.LocalPlayer

local JumpscareController = {
	Name = "JumpscareController",
}

export type Variant = "classic" | "grab" | "above"

local DURATION = 1.55
local APPEAR = 0.62
local LUNGE = 0.24
local IMPACT = APPEAR + LUNGE
local BLACKOUT = 1.15
local GRAB_DURATION = 2.2
local ABOVE_DURATION = 2.0

local playing = false
local lastPlayedAt = -math.huge
local lastVariant: Variant? = nil
local overlay: Frame? = nil
local rng = Random.new()

local function screen(): Frame
	local existing = overlay
	if existing then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Jumpscare"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 1
	frame.ZIndex = 10
	frame.Parent = gui
	overlay = frame
	return frame
end

function JumpscareController.available(): boolean
	return TungTungRig.available()
end

-- Tocou há pouco? (a tela final não repete o susto em cima dele)
function JumpscareController.recent(seconds: number): boolean
	return os.clock() - lastPlayedAt < seconds
end

-- Interface fora do caminho durante o susto (volta igual no fim).
local function hideInterface(): { ScreenGui }
	local hidden: { ScreenGui } = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetDescendants() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "Jumpscare" then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end
	return hidden
end

-- Sem a mão com a lanterna na frente do rosto dele.
local function showViewmodel(camera: Camera?, visible: boolean)
	if camera then
		for _, item in camera:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
end

-- Versão de 20/10 (mantida igual para comparação). Devolve a duração.
local function classic(camera: Camera, rig: TungTungRig.TungRig): (number, () -> ())
	local shake = SettingsController.get("shake")
	local flashes = SettingsController.get("flashes")
	local fade = screen()
	local hidden = hideInterface()

	local start = camera.CFrame
	local fov0 = camera.FieldOfView
	local flat = Vector3.new(start.LookVector.X, 0, start.LookVector.Z)
	flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis
	local eye = start.Position
	local view = CFrame.lookAt(eye, eye + flat)
	CameraController.setCinema(view, fov0)

	-- Modelo escondido até aparecer; mede a altura da cabeça para o rosto ficar na altura do olho.
	rig.model.Name = "JumpscareTung"
	rig.model.Parent = workspace
	TungTungRig.place(rig, CFrame.new(0, -500, 0))
	TungTungRig.play(rig, "idle", 0)
	TungTungRig.step(rig, 0, 0)
	local headHeight = rig.headPart.Position.Y - rig.model:GetPivot().Position.Y
	-- Luz de baixo, quente e forte: o rosto "acende" no escuro.
	local under = Instance.new("PointLight")
	under.Color = Color3.fromRGB(255, 120, 70)
	under.Range = 9
	under.Brightness = 0
	under.Shadows = false
	local underAt = Instance.new("Attachment")
	underAt.Parent = workspace.Terrain
	under.Parent = underAt

	AudioController.muffle(DURATION + 0.6)
	local faceDistance: number? = nil
	local thumps = 0
	local roared, struck = false, false
	local t = 0
	local function pose(distance: number): CFrame
		local face = eye + flat * distance
		local feet = Vector3.new(face.X, eye.Y - headHeight + 0.35, face.Z)
		return CFrame.lookAt(feet, Vector3.new(eye.X, feet.Y, eye.Z))
	end

	RunService:BindToRenderStep("TungJumpscare", Enum.RenderPriority.Last.Value + 60, function(dt: number)
		t += dt * TungTungRig.slow()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		local frame = view
		local fov = fov0
		-- Silêncio e as duas batidas no escuro (a imagem só escurece).
		if thumps == 0 and t >= 0.08 then
			thumps = 1
			AudioController.play("StepWood", 2.2, 0.38, true)
		elseif thumps == 1 and t >= 0.36 then
			thumps = 2
			AudioController.play("StepWood", 2.6, 0.34, true)
		end
		if t < APPEAR then
			fade.BackgroundTransparency = 1 - math.clamp(t / APPEAR, 0, 1) * 0.55
		elseif t < IMPACT then
			-- Avança: de 6 para 1,3 studs, acelerando; o golpe começa no meio do avanço.
			local k = (t - APPEAR) / LUNGE
			local distance = 6 - 4.7 * k * k
			faceDistance = distance
			if not roared then
				roared = true
				fade.BackgroundTransparency = 1
				TungTungRig.play(rig, "slash", 0, 1.9)
				AudioController.play("Roar", 1.3, 0.85, true)
				AudioController.play("StingerCapture", 1.1, nil, true)
			end
			under.Brightness = 3
			underAt.WorldPosition = eye + flat * (distance - 0.6) - Vector3.new(0, 1.6, 0)
			fov = fov0 - 18 * k
			if shake then
				local a = math.rad(1.6) * k
				frame = view * CFrame.Angles(a * math.noise(t * 40, 1), a * math.noise(t * 40, 2), 0)
			end
		elseif t < BLACKOUT then
			-- A pancada: clarão, tranco, a câmera tomba de lado e cai.
			if not struck then
				struck = true
				AudioController.play("Fall_box", 1.6, 0.8, true)
				AudioController.play("DoorBang", 1.4, 0.6, true)
				if flashes then
					fade.BackgroundColor3 = Color3.new(1, 1, 1)
					fade.BackgroundTransparency = 0.15
				end
			end
			local k = (t - IMPACT) / (BLACKOUT - IMPACT)
			fade.BackgroundColor3 = Color3.new(1, 1, 1):Lerp(Color3.new(0, 0, 0), math.min(1, k * 4))
			fade.BackgroundTransparency = if flashes then 0.15 + 0.5 * k else 1 - k
			local roll = math.rad(if shake then 28 else 14) * (1 - (1 - k) ^ 3)
			local drop = 2.4 * k * k
			local kick = if shake then math.rad(6) * (1 - k) * math.noise(t * 60, 3) else 0
			frame = view * CFrame.new(0, -drop, 0) * CFrame.Angles(math.rad(-10) * k + kick, 0, roll)
			fov = fov0 - 18 + 8 * k
			faceDistance = 1.3
		else
			fade.BackgroundColor3 = Color3.new(0, 0, 0)
			fade.BackgroundTransparency = 0
			faceDistance = nil
			TungTungRig.place(rig, CFrame.new(0, -500, 0))
			under.Brightness = 0
		end
		local d = faceDistance
		if d then
			TungTungRig.place(rig, pose(d))
		end
		TungTungRig.step(rig, dt, 0)
		if d then
			-- A pose do golpe inclina a cabeça: corrige o corpo todo para o rosto ficar no meio da tela.
			local want = eye + flat * d - Vector3.new(0, 0.15, 0)
			local delta = want - rig.headPart.Position
			delta -= flat * delta:Dot(flat)
			rig.model:PivotTo(rig.model:GetPivot() + delta)
		end
		showViewmodel(cam, false)
		cam.CFrame = frame
		cam.FieldOfView = fov
	end)

	return DURATION, function()
		underAt:Destroy()
		for _, gui in hidden do
			gui.Enabled = true
		end
	end
end

-- Duas portas de madeira fecham a tela como um armário: a pessoa vira móvel (sem sangue, como na história).
local function woodPanels(): (Frame, Frame, Frame)
	local gui = screen().Parent :: ScreenGui
	local function plank(name: string, anchorX: number): Frame
		local panel = Instance.new("Frame")
		panel.Name = name
		panel.AnchorPoint = Vector2.new(anchorX, 0)
		panel.Size = UDim2.fromScale(0.52, 1)
		panel.Position = UDim2.fromScale(anchorX, 0)
		panel.BackgroundColor3 = Color3.fromRGB(92, 58, 34)
		panel.BorderSizePixel = 0
		panel.Visible = false
		panel.ZIndex = 5
		local grain = Instance.new("UIGradient")
		grain.Rotation = 90
		grain.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 78, 46)),
			ColorSequenceKeypoint.new(0.18, Color3.fromRGB(84, 52, 30)),
			ColorSequenceKeypoint.new(0.42, Color3.fromRGB(112, 72, 42)),
			ColorSequenceKeypoint.new(0.63, Color3.fromRGB(76, 46, 26)),
			ColorSequenceKeypoint.new(0.85, Color3.fromRGB(108, 70, 40)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 42, 24)),
		})
		grain.Parent = panel
		-- Frestas entre as tábuas.
		for i = 1, 3 do
			local gap = Instance.new("Frame")
			gap.Size = UDim2.new(0, 3, 1, 0)
			gap.Position = UDim2.fromScale(i / 4, 0)
			gap.BackgroundColor3 = Color3.fromRGB(28, 16, 8)
			gap.BorderSizePixel = 0
			gap.ZIndex = 6
			gap.Parent = panel
		end
		panel.Parent = gui
		return panel
	end
	local left = plank("WoodLeft", 0)
	local right = plank("WoodRight", 1)
	-- Fresta de luz entre as portas que se fecham.
	local slit = Instance.new("Frame")
	slit.Name = "Slit"
	slit.AnchorPoint = Vector2.new(0.5, 0)
	slit.Size = UDim2.fromScale(0, 1)
	slit.Position = UDim2.fromScale(0.5, 0)
	slit.BackgroundColor3 = Color3.fromRGB(255, 196, 120)
	slit.BackgroundTransparency = 0.4
	slit.BorderSizePixel = 0
	slit.Visible = false
	slit.ZIndex = 7
	slit.Parent = gui
	return left, right, slit
end

-- k = 0 (aberta) .. 1 (fechada), com freio no fim.
local function closePanels(left: Frame, right: Frame, slit: Frame, k: number)
	local e = 1 - (1 - math.clamp(k, 0, 1)) ^ 3
	left.Visible = k > 0
	right.Visible = k > 0
	slit.Visible = k > 0 and k < 1
	left.Position = UDim2.fromScale(-0.52 + 0.52 * e, 0)
	right.Position = UDim2.fromScale(1.52 - 0.52 * e, 0)
	slit.Size = UDim2.new(0, math.floor(18 * (1 - e)), 1, 0)
end

type Scene = {
	view: CFrame,
	eye: Vector3,
	flat: Vector3,
	fov0: number,
	headHeight: number,
	shake: boolean,
	fade: Frame,
	light: PointLight,
	lightAt: Attachment,
	tint: ColorCorrectionEffect,
	left: Frame,
	right: Frame,
	slit: Frame,
	hidden: { ScreenGui },
}

local function setup(camera: Camera, rig: TungTungRig.TungRig): Scene
	local start = camera.CFrame
	local flat = Vector3.new(start.LookVector.X, 0, start.LookVector.Z)
	flat = if flat.Magnitude > 0.05 then flat.Unit else Vector3.zAxis
	local eye = start.Position
	local view = CFrame.lookAt(eye, eye + flat)
	CameraController.setCinema(view, camera.FieldOfView)
	rig.model.Name = "JumpscareTung"
	rig.model.Parent = workspace
	TungTungRig.place(rig, CFrame.new(0, -500, 0))
	TungTungRig.play(rig, "stand", 0)
	TungTungRig.step(rig, 0, 0)
	local headHeight = rig.headPart.Position.Y - rig.model:GetPivot().Position.Y
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 150, 90)
	light.Range = 8
	light.Brightness = 0
	light.Shadows = false
	local lightAt = Instance.new("Attachment")
	lightAt.Parent = workspace.Terrain
	light.Parent = lightAt
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "JumpscareTint"
	tint.Parent = Lighting
	local left, right, slit = woodPanels()
	return {
		view = view,
		eye = eye,
		flat = flat,
		fov0 = camera.FieldOfView,
		headHeight = headHeight,
		shake = SettingsController.get("shake"),
		fade = screen(),
		light = light,
		lightAt = lightAt,
		tint = tint,
		left = left,
		right = right,
		slit = slit,
		hidden = hideInterface(),
	}
end

local function cleanup(s: Scene)
	s.lightAt:Destroy()
	s.tint:Destroy()
	s.left:Destroy()
	s.right:Destroy()
	s.slit:Destroy()
	for _, gui in s.hidden do
		gui.Enabled = true
	end
end

-- Põe o Tung de modo que o rosto fique a `distance` studs do olho, `lift` acima do centro da tela.
local function faceAt(s: Scene, rig: TungTungRig.TungRig, distance: number, lift: number, yaw: number)
	local face = s.eye + s.flat * distance
	local feet = Vector3.new(face.X, s.eye.Y - s.headHeight + lift, face.Z)
	TungTungRig.place(rig, CFrame.lookAt(feet, Vector3.new(s.eye.X, feet.Y, s.eye.Z)))
	TungTungRig.step(rig, 0, yaw)
	-- A pose inclina a cabeça: corrige o corpo todo para o rosto ficar onde a cena quer.
	local want = s.eye + s.flat * distance + Vector3.new(0, lift - 0.15, 0)
	local delta = want - rig.headPart.Position
	delta -= s.flat * delta:Dot(s.flat)
	rig.model:PivotTo(rig.model:GetPivot() + delta)
end

-- Fim comum: a madeira fecha (vira móvel), rangido, TUM final.
local function becomeFurniture(s: Scene, t: number, start: number, state: { [string]: boolean })
	local k = (t - start) / 0.5
	if not state.close then
		state.close = true
		AudioController.play("WoodSplinter", 1.2, 0.8, true)
		AudioController.play("CreakWood", 1.6, 0.6, true)
	end
	closePanels(s.left, s.right, s.slit, k)
	local c = math.clamp(k, 0, 1)
	s.tint.Saturation = -0.4 * c
	s.tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 214, 170), c)
	if k >= 1 and not state.slam then
		state.slam = true
		AudioController.play("StepWood", 2.6, 0.3, true)
		AudioController.play("DoorBang", 1.2, 0.55, true)
		if s.shake then
			CameraController.addTrauma(0.4)
		end
	end
end

-- "grab": aviso, surge colado, as duas mãos fecham, a cabeça estala, vira móvel.
local function grab(camera: Camera, rig: TungTungRig.TungRig): (number, () -> ())
	local s = setup(camera, rig)
	AudioController.muffle(GRAB_DURATION + 0.6)
	local state: { [string]: boolean } = {}
	local t = 0
	RunService:BindToRenderStep("TungJumpscare", Enum.RenderPriority.Last.Value + 60, function(dt: number)
		t += dt * TungTungRig.slow()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		local frame = s.view
		local fov = s.fov0
		if t < 0.5 then
			-- Aviso (0,5 s): a imagem escurece, TUM... TUM, e os olhos acendem longe no escuro.
			if not state.tum1 and t >= 0.06 then
				state.tum1 = true
				AudioController.play("StepWood", 2.2, 0.36, true)
			elseif not state.tum2 and t >= 0.32 then
				state.tum2 = true
				AudioController.play("StepWood", 2.6, 0.32, true)
			end
			s.fade.BackgroundTransparency = 1 - 0.7 * (t / 0.5)
			s.tint.Brightness = -0.15 * (t / 0.5)
			TungTungRig.step(rig, dt, 0)
			faceAt(s, rig, 14, 0.2, 0)
			s.light.Brightness = if t > 0.3 then 0.6 else 0
			s.lightAt.WorldPosition = s.eye + s.flat * 13.4
		elseif t < 1.3 then
			-- Surge colado: as mãos vêm dos lados, o rosto enche a tela, a cabeça estala de lado.
			local k = math.clamp((t - 0.5) / 0.18, 0, 1)
			if not state.appear then
				state.appear = true
				s.fade.BackgroundTransparency = 1
				s.tint.Brightness = 0
				TungTungRig.play(rig, "grab", 0)
				AudioController.play("Roar", 1.3, 0.8, true)
				AudioController.play("StingerCapture", 1.1, nil, true)
			end
			-- O rig do jogo é grande (escala 1,24 e corpo 1,18 mais largo): as mãos do agarrão vão ~2,5 studs à frente do
			-- rosto. Mais perto que 3 studs a câmera entra na malha.
			local distance = 4.2 - 1.2 * (1 - (1 - k) ^ 2)
			local yaw = 0
			if t > 0.85 then
				yaw = if t < 1.05 then 14 else -10
				if not state.crack1 then
					state.crack1 = true
					AudioController.play("CreakWood", 1.8, 0.9, true)
				end
				if t >= 1.05 and not state.crack2 then
					state.crack2 = true
					AudioController.play("CreakWood", 1.8, 0.75, true)
				end
			end
			TungTungRig.step(rig, dt, 0)
			faceAt(s, rig, distance, 0, yaw)
			s.light.Brightness = 2.6
			s.lightAt.WorldPosition = s.eye + s.flat * (distance - 0.7) - Vector3.new(0, 1.4, 0)
			fov = s.fov0 - 14 * k
			if s.shake then
				local a = math.rad(1.2) * (1 - (t - 0.5) / 0.8)
				frame = s.view * CFrame.Angles(a * math.noise(t * 35, 1), a * math.noise(t * 35, 2), 0)
			end
			-- Ele puxa você para perto (a câmera vai um pouco para frente e para baixo).
			frame = frame * CFrame.new(0, -0.25 * k, -0.2 * k)
		elseif t < 1.8 then
			faceAt(s, rig, 3.0, 0, -10)
			becomeFurniture(s, t, 1.3, state)
			fov = s.fov0 - 14
			frame = s.view * CFrame.new(0, -0.25, -0.2)
		else
			s.fade.BackgroundColor3 = Color3.new(0, 0, 0)
			s.fade.BackgroundTransparency = math.max(0, 1 - (t - 1.8) / 0.2)
			closePanels(s.left, s.right, s.slit, 1)
			TungTungRig.place(rig, CFrame.new(0, -500, 0))
			s.light.Brightness = 0
		end
		showViewmodel(cam, false)
		cam.CFrame = frame
		cam.FieldOfView = fov
	end)
	return GRAB_DURATION, function()
		cleanup(s)
	end
end

-- "above": a lanterna falha, escuro; o rosto desce de cima, de ponta-cabeça, para e avança; vira móvel.
local function above(camera: Camera, rig: TungTungRig.TungRig): (number, () -> ())
	local s = setup(camera, rig)
	AudioController.muffle(ABOVE_DURATION + 0.6)
	local state: { [string]: boolean } = {}
	local t = 0
	-- Ele se curva por cima de você: o corpo todo gira 180° em volta do rosto, que fica de ponta-cabeça.
	local function hang(distance: number, drop: number, wobble: number)
		TungTungRig.place(rig, CFrame.new(s.eye + s.flat * 30))
		TungTungRig.step(rig, 0, 0)
		local rel = rig.headPart.CFrame:ToObjectSpace(rig.model:GetPivot())
		local face = s.eye + s.flat * distance + Vector3.new(0, drop, 0)
		local head = CFrame.lookAt(face, face - s.flat) * CFrame.Angles(0, 0, math.pi + wobble)
		rig.model:PivotTo(head * rel)
	end
	RunService:BindToRenderStep("TungJumpscare", Enum.RenderPriority.Last.Value + 60, function(dt: number)
		t += dt * TungTungRig.slow()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		cam.CameraType = Enum.CameraType.Scriptable
		local frame = s.view
		local fov = s.fov0
		if t < 0.5 then
			-- Aviso (0,5 s): a imagem pisca duas vezes como a lanterna falhando, e escurece.
			local flicker = (t > 0.08 and t < 0.16) or (t > 0.3 and t < 0.42)
			s.fade.BackgroundTransparency = if flicker then 0.05 else 1 - 0.5 * (t / 0.5)
			if not state.click and t >= 0.08 then
				state.click = true
				AudioController.play("StepWood", 1.6, 0.5, true)
			end
			if not state.breath and t >= 0.3 then
				state.breath = true
				AudioController.play("Gasp", 1, 1, true)
			end
		elseif t < 1.45 then
			if not state.appear then
				state.appear = true
				s.fade.BackgroundTransparency = 1
				TungTungRig.play(rig, "warn", 0, 0.6)
				AudioController.play("CreakWood", 2, 0.5, true)
			end
			TungTungRig.step(rig, dt, 0)
			-- Desce de cima até a altura do olho, para um instante e avança colado.
			local d = t - 0.5
			local drop = 3.2 * math.max(0, 1 - d / 0.3) ^ 2
			local distance = 2.2
			if d > 0.55 then
				local k = math.clamp((d - 0.55) / 0.16, 0, 1)
				distance = 2.2 - 0.4 * k
				if not state.roar then
					state.roar = true
					AudioController.play("Roar", 1.3, 0.75, true)
					AudioController.play("StingerCapture", 1.1, nil, true)
				end
				fov = s.fov0 - 16 * k
				if s.shake then
					local a = math.rad(1.4) * k
					frame = s.view * CFrame.Angles(a * math.noise(t * 40, 1), a * math.noise(t * 40, 2), 0)
				end
			end
			hang(distance, drop, math.rad(6) * math.sin(t * 3))
			-- Só a lanterna ilumina o rosto (luz fria, de frente).
			s.light.Color = Color3.fromRGB(230, 225, 210)
			s.light.Brightness = 2.2
			s.lightAt.WorldPosition = s.eye + s.flat * 0.4
		elseif t < 1.95 then
			hang(1.8, 0, 0)
			becomeFurniture(s, t, 1.45, state)
			fov = s.fov0 - 16
		else
			closePanels(s.left, s.right, s.slit, 1)
			s.fade.BackgroundTransparency = 0
			TungTungRig.place(rig, CFrame.new(0, -500, 0))
			s.light.Brightness = 0
		end
		showViewmodel(cam, false)
		cam.CFrame = frame
		cam.FieldOfView = fov
	end)
	return ABOVE_DURATION, function()
		cleanup(s)
	end
end

local function pick(): Variant
	local forced = player:GetAttribute("JumpscareVariant")
	if forced == "classic" or forced == "grab" or forced == "above" then
		return forced :: Variant
	end
	-- Sorteia entre as novas sem repetir a última.
	if lastVariant == "grab" then
		return "above"
	elseif lastVariant == "above" then
		return "grab"
	end
	return (if rng:NextNumber() < 0.5 then "grab" else "above") :: Variant
end

function JumpscareController.play(variant: Variant?): boolean
	if playing or not TungTungRig.available() then
		return false
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end
	local rig = TungTungRig.build(nil)
	if not rig then
		return false
	end
	playing = true
	lastPlayedAt = os.clock()
	-- Marca local para o som da derrota e a tela final não repetirem o susto em cima dele.
	player:SetAttribute("JumpscareAt", lastPlayedAt)
	local chosen: Variant = variant or pick()
	lastVariant = chosen
	local duration, finish
	if chosen == "classic" then
		duration, finish = classic(camera, rig)
	elseif chosen == "above" then
		duration, finish = above(camera, rig)
	else
		duration, finish = grab(camera, rig)
	end

	-- AnimSlow (depuração, só no cliente): a cena inteira anda mais devagar para prints quadro a quadro.
	task.delay(duration / TungTungRig.slow(), function()
		RunService:UnbindFromRenderStep("TungJumpscare")
		finish()
		rig.model:Destroy()
		CameraController.endCinema()
		showViewmodel(workspace.CurrentCamera, true)
		-- Volta do preto devagar.
		local f = screen()
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 0
		for step = 1, 12 do
			f.BackgroundTransparency = step / 12
			task.wait(1 / 30)
		end
		f.BackgroundTransparency = 1
		playing = false
	end)
	return true
end

function JumpscareController.isPlaying(): boolean
	return playing
end

-- Última versão tocada (testes; a tela final pode variar o texto).
function JumpscareController.lastVariant(): Variant?
	return lastVariant
end

return JumpscareController
