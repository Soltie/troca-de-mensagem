--!strict
--[[
	Visual dos momentos roteirizados (Shared/Game/ChapterMoments; o servidor publica em CampaignState `Moment`,
	`MomentAt` e `MomentSerial`). Nunca machucam: só luz, som, câmera e legenda.
	- blackout: luzes da casa apagam piscando, porta bate lá no fundo, sussurro.
	- shadow: quando a luz volta, um vulto de olhos vermelhos no fim do corredor; some na piscada seguinte.
	- tunnel: só a legenda e o tremor (o Tung de verdade sai do buraco pelo servidor).
	- quake: a casa treme, luz vermelha, ronco lá de baixo.
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local ChapterMoments = require("@game/ReplicatedStorage/Shared/Game/ChapterMoments")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local FearController = require("./FearController")
local GameUiController = require("./GameUiController")
local WorldFxController = require("./WorldFxController")

local MomentController = {
	Name = "MomentController",
}

local player = Players.LocalPlayer

local function myRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- Ponto livre à frente do jogador, na altura do chão (até `reach` studs; para antes de uma parede).
local function ahead(root: BasePart, reach: number): Vector3
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 1e-3 then
		look = Vector3.new(0, 0, -1)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	params.FilterDescendantsInstances = if world then { world } else {}
	local hit = workspace:Raycast(root.Position, look.Unit * reach, params)
	local distance = if hit then math.max(6, (hit.Position - root.Position).Magnitude - 2.5) else reach
	return root.Position + look.Unit * distance - Vector3.new(0, 3, 0)
end

-- Vulto: silhueta escura alta com dois olhos vermelhos (só neste cliente).
local function shadowFigure(at: Vector3, face: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "MomentShadow"
	local dark = Color3.fromRGB(6, 5, 5)
	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.lookAt(at + offset, at + offset + face)
		p.Color = color
		p.Material = material
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = false
		p.Parent = model
		return p
	end
	part("Body", Vector3.new(2.6, 6.2, 1.4), Vector3.new(0, 3.1, 0), dark, Enum.Material.SmoothPlastic)
	local head = part("Head", Vector3.new(2, 2.6, 1.6), Vector3.new(0, 7.4, 0), dark, Enum.Material.SmoothPlastic)
	part("Bat", Vector3.new(0.5, 5, 0.5), Vector3.new(1.9, 3.4, 0.3), dark, Enum.Material.SmoothPlastic)
	for _, side in { -0.45, 0.45 } do
		local eye = part(
			"Eye",
			Vector3.new(0.32, 0.32, 0.1),
			Vector3.new(0, 7.7, 0) + head.CFrame.RightVector * side + face * 0.82,
			Color3.fromRGB(255, 40, 30),
			Enum.Material.Neon
		)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 40, 30), 6, 1.2
		glow.Parent = eye
	end
	model.Parent = workspace
	return model
end

local function play(moment: string, at: Vector3)
	local caption = ChapterMoments.Caption[moment]
	local duration = ChapterMoments.Duration[moment] or 3
	local root = myRoot()
	if moment == "blackout" then
		WorldFxController.blackout(duration)
		-- Painéis e lustres decorativos não têm luz própria: escurece a cena toda junto com as lâmpadas.
		local dark = Instance.new("ColorCorrectionEffect")
		dark.Name = "MomentBlackout"
		dark.Parent = Lighting
		TweenService:Create(dark, TweenInfo.new(0.5), { Brightness = -0.22, Contrast = 0.12 }):Play()
		task.delay(duration - 0.6, function()
			local back = TweenService:Create(dark, TweenInfo.new(0.6), { Brightness = 0, Contrast = 0 })
			back:Play()
			back.Completed:Once(function()
				dark:Destroy()
			end)
		end)
		AudioController.play("LampBuzz", 1.2, 0.6)
		task.delay(1.2, function()
			local where = if root then ahead(root, 40) else at
			AudioController.playAtPosition("DoorBang", where, 0.9, 0.8)
			AudioController.playAtPosition("Whisper", where, 1, 0.8)
			FearController.spike(0.3)
		end)
	elseif moment == "shadow" then
		if not root then
			return
		end
		local spot = ahead(root, 46)
		local face = (root.Position - spot) * Vector3.new(1, 0, 1)
		local figure = shadowFigure(spot, if face.Magnitude > 0.1 then face.Unit else Vector3.zAxis)
		AudioController.playAtPosition("Growl", spot, 0.5, 0.7)
		FearController.spike(0.35)
		task.delay(duration, function()
			WorldFxController.blackout(0.6)
			task.wait(0.25)
			figure:Destroy()
		end)
	elseif moment == "knocks" then
		if not root then
			return
		end
		-- Pancadas pesadas do outro lado da parede: do ponto pedido (se perto) ou de um lado do jogador.
		local side = root.CFrame.RightVector * (if math.random() < 0.5 then 1 else -1)
		local where = if at ~= Vector3.zero and (at - root.Position).Magnitude < 60
			then at
			else root.Position + side * 9 + root.CFrame.LookVector * 4
		task.spawn(function()
			for n, gap in { 0, 0.55, 0.45, 1.1, 0.4 } do
				task.wait(gap)
				AudioController.playAtPosition("DoorBang", where, 1, 0.5 + n * 0.03)
				CameraController.addTrauma(0.12)
				FearController.spike(0.1)
			end
		end)
	elseif moment == "silhouette" then
		if not root then
			return
		end
		-- Fim do corredor (~20 studs): a silhueta cruza de um lado ao outro e some, sem piscar.
		local spot = ahead(root, 20)
		local face = (root.Position - spot) * Vector3.new(1, 0, 1)
		local facing = if face.Magnitude > 0.1 then face.Unit else Vector3.zAxis
		local figure = shadowFigure(spot, facing)
		local sideways = facing:Cross(Vector3.yAxis).Unit
		local from = figure:GetPivot()
		FearController.spike(0.35)
		AudioController.playAtPosition("Growl", spot, 0.45, 0.6)
		task.spawn(function()
			local start = os.clock()
			local crossing = 1.1
			while figure.Parent do
				local t = (os.clock() - start) / crossing
				if t >= 1 then
					break
				end
				figure:PivotTo(from + sideways * ((t - 0.5) * 7))
				task.wait()
			end
			figure:Destroy()
		end)
	elseif moment == "nearmiss" then
		if not root then
			return
		end
		-- Uma pancada forte colada nas costas, poeira e a luz pisca. Não machuca.
		local behind = root.Position - root.CFrame.LookVector * 3
		AudioController.playAtPosition("DoorBang", behind, 1.2, 0.45)
		AudioController.playAtPosition("BeamCrack", behind, 0.8, 0.8)
		CameraController.addTrauma(0.75)
		FearController.spike(0.45)
		WorldFxController.blackout(0.5)
		local anchor = Instance.new("Part")
		anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
		anchor.Transparency = 1
		anchor.Size = Vector3.one * 0.2
		anchor.Position = behind + Vector3.new(0, 2, 0)
		anchor.Parent = workspace
		local dust = Instance.new("ParticleEmitter")
		dust.Color = ColorSequence.new(Color3.fromRGB(196, 168, 120))
		dust.Size = NumberSequence.new(0.5, 0.1)
		dust.Speed = NumberRange.new(2, 5)
		dust.Lifetime = NumberRange.new(1, 1.8)
		dust.Acceleration = Vector3.new(0, -6, 0)
		dust.SpreadAngle = Vector2.new(180, 180)
		dust.Rate = 0
		dust.Parent = anchor
		dust:Emit(50)
		task.delay(3, function()
			anchor:Destroy()
		end)
	elseif moment == "tunnel" then
		CameraController.addTrauma(0.35)
		FearController.spike(0.25)
	elseif moment == "quake" then
		WorldFxController.surge(duration)
		CameraController.addTrauma(0.9)
		AudioController.play("Roar", 0.9, 0.6)
		AudioController.play("BeamCrack", 0.8, 0.7)
		FearController.spike(0.5)
		local tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "MomentQuakeTint"
		tint.TintColor = Color3.fromRGB(255, 150, 140)
		tint.Parent = Lighting
		local back = TweenService:Create(tint, TweenInfo.new(duration), { TintColor = Color3.new(1, 1, 1) })
		back:Play()
		back.Completed:Once(function()
			tint:Destroy()
		end)
		task.spawn(function()
			for _ = 1, 4 do
				task.wait(duration / 5)
				CameraController.addTrauma(0.4)
			end
		end)
	end
	if caption then
		GameUiController.caption(caption, duration + 1.5)
	end
end

function MomentController.Start()
	local campaign = ReplicatedStorage:WaitForChild("CampaignState", 30)
	if not campaign then
		return
	end
	-- Só momentos novos: o valor que já estava lá (entrou no meio da partida) não toca.
	local last = campaign:GetAttribute("MomentSerial")
	campaign:GetAttributeChangedSignal("MomentSerial"):Connect(function()
		local current = campaign:GetAttribute("MomentSerial")
		if current == last then
			return
		end
		last = current
		local moment = campaign:GetAttribute("Moment")
		local at = campaign:GetAttribute("MomentAt")
		if typeof(moment) == "string" then
			play(moment, if typeof(at) == "Vector3" then at else Vector3.zero)
		end
	end)
	-- Legendas dos sustos de cenário (RoomScareService): só texto curto.
	local lastCaption = campaign:GetAttribute("CaptionSerial")
	campaign:GetAttributeChangedSignal("CaptionSerial"):Connect(function()
		local current = campaign:GetAttribute("CaptionSerial")
		if current == lastCaption then
			return
		end
		lastCaption = current
		local text = campaign:GetAttribute("Caption")
		if typeof(text) == "string" then
			GameUiController.caption(text, 4)
		end
	end)
end

return MomentController
