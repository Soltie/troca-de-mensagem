--!strict
--[[
	Jumpscare do Tung Tung (quando ELE derruba você: pancada ou porta do armário aberta). Só para quem foi pego.
	Pensado como os bons do gênero (DOORS, The Mimic, FNAF): o susto vem do contraste, não do volume o tempo todo.
	  0,00  tudo para: imagem congela, som abafa, silêncio.
	  0,08  "TUM"... 0,36 "TUM" (o bastão no escuro, sem nada na tela).
	  0,62  ele aparece colado, de corpo inteiro, rosto iluminado de baixo, e avança em cima da câmera erguendo o
	        bastão (rugido + estalo da trilha).
	  0,86  a pancada: clarão (se "flashes" estiver ligado), tranco forte, a câmera tomba de lado e cai.
	  1,15  corta para o preto; 1,55 devolve a câmera ao jogo (rastejando ou tela final).
	Usa uma cópia local do mesmo modelo animado (TungTungRig): ninguém mais vê, e não depende de onde o Tung Tung
	real está. Sem o modelo (place sem o asset), não faz nada e a câmera de captura antiga cuida do momento.
]]

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

local DURATION = 1.55
local APPEAR = 0.62
local LUNGE = 0.24
local IMPACT = APPEAR + LUNGE
local BLACKOUT = 1.15

local playing = false
local lastPlayedAt = -math.huge
local overlay: Frame? = nil

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

function JumpscareController.play(): boolean
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
	local shake = SettingsController.get("shake")
	local flashes = SettingsController.get("flashes")
	local fade = screen()
	-- Interface fora do caminho durante o susto (volta igual no fim).
	local hidden: { ScreenGui } = {}
	for _, gui in player:WaitForChild("PlayerGui"):GetDescendants() do
		if gui:IsA("ScreenGui") and gui.Enabled and gui.Name ~= "Jumpscare" then
			gui.Enabled = false
			table.insert(hidden, gui)
		end
	end

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
	local t0 = os.clock()
	local function pose(distance: number): CFrame
		local face = eye + flat * distance
		local feet = Vector3.new(face.X, eye.Y - headHeight + 0.35, face.Z)
		return CFrame.lookAt(feet, Vector3.new(eye.X, feet.Y, eye.Z))
	end

	RunService:BindToRenderStep("TungJumpscare", Enum.RenderPriority.Last.Value + 60, function(dt: number)
		local t = os.clock() - t0
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
		-- Sem a mão com a lanterna na frente do rosto dele.
		for _, item in cam:GetDescendants() do
			if item:IsA("BasePart") then
				item.LocalTransparencyModifier = 1
			end
		end
		cam.CFrame = frame
		cam.FieldOfView = fov
	end)

	task.delay(DURATION, function()
		RunService:UnbindFromRenderStep("TungJumpscare")
		rig.model:Destroy()
		underAt:Destroy()
		CameraController.endCinema()
		for _, gui in hidden do
			gui.Enabled = true
		end
		local current = workspace.CurrentCamera
		if current then
			for _, item in current:GetDescendants() do
				if item:IsA("BasePart") then
					item.LocalTransparencyModifier = 0
				end
			end
		end
		-- Volta do preto devagar.
		local f = screen()
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

return JumpscareController
