--!strict
--[[
	Armário com surpresa (ideia G): nos armários marcados pelo servidor (porta com Cursed = true), dois olhos
	vermelhos piscam na fresta e se ouve uma respiração baixa lá dentro. Quem olha antes de entrar se salva;
	quem entra sem olhar é jogado para fora (servidor). Só aparece com o jogador perto (até 14 studs).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local AudioController = require("./AudioController")

local player = Players.LocalPlayer

local CursedLockerController = {
	Name = "CursedLockerController",
}

local RANGE = 14
local EYE = Color3.fromRGB(255, 10, 0)

type Eyes = {
	model: Model,
	gap: BasePart,
	canvas: CanvasGroup,
	pupils: { Frame },
	glow: PointLight,
	breath: Sound?,
	nextBlink: number,
}

local watched: { [BasePart]: boolean } = {}
local eyes: { [BasePart]: Eyes } = {}
local rng = Random.new()

local function clear(door: BasePart)
	local e = eyes[door]
	if e then
		if e.breath then
			e.breath:Destroy()
		end
		e.model:Destroy()
		eyes[door] = nil
	end
end

local function build(door: BasePart)
	clear(door)
	local at = door:GetAttribute("EyesAt")
	local face = door:GetAttribute("EyesFace")
	if typeof(at) ~= "Vector3" or typeof(face) ~= "Vector3" then
		return
	end
	local model = Instance.new("Model")
	model.Name = "LockerEyes"
	-- Fica colado na face da porta, na fresta entre as folhas: atrás dela ninguém veria.
	local half = math.abs(door.CFrame.RightVector:Dot(face)) * door.Size.X / 2
		+ math.abs(door.CFrame.UpVector:Dot(face)) * door.Size.Y / 2
		+ math.abs(door.CFrame.LookVector:Dot(face)) * door.Size.Z / 2
	local front = (door.Position - at):Dot(face) + half + 0.02
	local gap = Instance.new("Part")
	gap.Name = "Gap"
	gap.Anchored, gap.CanCollide, gap.CanQuery, gap.CanTouch = true, false, false, false
	gap.Transparency = 1
	gap.CastShadow = false
	gap.Size = Vector3.new(0.6, 0.3, 0.02)
	gap.CFrame = CFrame.lookAt(at + face * front, at + face * (front + 1))
	gap.Parent = model
	-- A arte é uma SurfaceGui sem influência de luz: o breu da fresta e os olhos não somem sob a lanterna.
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.Brightness = 6
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 400
	gui.Parent = gap
	local canvas = Instance.new("CanvasGroup")
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.BackgroundTransparency = 1
	canvas.GroupTransparency = 1
	canvas.Parent = gui
	local dark = Instance.new("Frame")
	dark.Size = UDim2.fromScale(1, 1)
	dark.BackgroundColor3 = Color3.new(0, 0, 0)
	dark.BackgroundTransparency = 0.05
	dark.BorderSizePixel = 0
	dark.Parent = canvas
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = dark
	local pupils: { Frame } = {}
	for i, x in { 0.3, 0.7 } do
		local pupil = Instance.new("Frame")
		pupil.AnchorPoint = Vector2.new(0.5, 0.5)
		pupil.Position = UDim2.fromScale(x, 0.5)
		pupil.Size = UDim2.fromScale(0.16, 0.17)
		pupil.Rotation = if i == 1 then 12 else -12
		pupil.BackgroundColor3 = EYE
		pupil.BorderSizePixel = 0
		pupil.Parent = canvas
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = pupil
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 60, 0)
		stroke.Thickness = 3
		stroke.Transparency = 0.4
		stroke.Parent = pupil
		table.insert(pupils, pupil)
	end
	local glow = Instance.new("PointLight")
	glow.Color = EYE
	glow.Range = 4
	glow.Brightness = 0
	glow.Shadows = false
	glow.Parent = gap
	model.Parent = workspace
	eyes[door] = {
		model = model,
		gap = gap,
		canvas = canvas,
		pupils = pupils,
		glow = glow,
		breath = nil,
		nextBlink = os.clock() + 2,
	}
end

local function watch(instance: Instance)
	if not instance:IsA("BasePart") or watched[instance] then
		return
	end
	local id = instance:GetAttribute("InteractId")
	if type(id) ~= "string" or string.sub(id, 1, 5) ~= "hide_" then
		return
	end
	watched[instance] = true
	local function refresh()
		if instance:GetAttribute("Cursed") == true then
			build(instance)
		else
			clear(instance)
		end
	end
	instance:GetAttributeChangedSignal("Cursed"):Connect(refresh)
	instance:GetAttributeChangedSignal("EyesAt"):Connect(refresh)
	-- EyesFace chega por último: sem ele a primeira montagem desiste.
	instance:GetAttributeChangedSignal("EyesFace"):Connect(refresh)
	refresh()
end

local function update()
	local character = player.Character
	local body = character and character:FindFirstChild("HumanoidRootPart")
	local hidden = player:GetAttribute("Hidden")
	local inside = type(hidden) == "string" and hidden ~= ""
	local now = os.clock()
	for door, e in eyes do
		if not door.Parent then
			clear(door)
			continue
		end
		local distance = if body and body:IsA("BasePart") then (e.gap.Position - body.Position).Magnitude else math.huge
		local near = not inside and distance < RANGE
		-- Pisca de vez em quando (os olhos somem por um instante; a fresta escura fica), mais forte bem perto.
		local blinking = now >= e.nextBlink and now < e.nextBlink + 0.18
		if now > e.nextBlink + 0.18 then
			e.nextBlink = now + rng:NextNumber(1.8, 4.5)
		end
		local alpha = if near then math.clamp(1 - (distance - 4) / (RANGE - 4), 0.25, 1) else 0
		e.canvas.GroupTransparency = 1 - alpha
		for _, pupil in e.pupils do
			pupil.Visible = not blinking
		end
		e.glow.Brightness = if blinking then 0 else alpha * 1.6
		if near and not e.breath then
			local sound = AudioController.playAt("Breath2", e.gap, 0.5, 0.75)
			sound.Looped = true
			sound.RollOffMinDistance = 3
			sound.RollOffMaxDistance = RANGE
			e.breath = sound
		elseif not near and e.breath then
			e.breath:Destroy()
			e.breath = nil
		end
	end
end

function CursedLockerController.Start()
	-- A porta ganha o InteractId depois de entrar no mundo; a tag Interactable vem por último.
	for _, instance in CollectionService:GetTagged(Tags.Interactable) do
		watch(instance)
	end
	CollectionService:GetInstanceAddedSignal(Tags.Interactable):Connect(watch)
	workspace.DescendantRemoving:Connect(function(instance)
		if instance:IsA("BasePart") and watched[instance] then
			watched[instance] = nil
			clear(instance)
		end
	end)
	local clock, rescan = 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		rescan += dt
		-- Confere de novo a cada 2 s: portas reconstruídas no capítulo às vezes chegam sem disparar o sinal.
		if rescan >= 2 then
			rescan = 0
			for _, instance in CollectionService:GetTagged(Tags.Interactable) do
				watch(instance)
			end
		end
		if clock >= 0.05 then
			clock = 0
			update()
		end
	end)
end

return CursedLockerController
