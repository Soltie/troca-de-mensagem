--!strict
--[[
	Raio ao ar livre (regras em Shared/Game/LightningRules). Durante a campanha, quem está fora de casa pode virar
	alvo: o chão onde ele está ganha um brilho com estalo (Workspace.LightningMarks, o cliente desenha o raio) e,
	WarnTime segundos depois, quem ainda estiver ali é derrubado pelo mesmo fluxo da captura (resgate, segunda
	chance). No último capítulo (a fuga) a chance é maior. Quem se mexe ao ver o aviso escapa.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local HouseCatalog = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local LightningRules = require("@game/ReplicatedStorage/Shared/Game/LightningRules")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")

local LightningService = {
	Name = "LightningService",
}

local strikeCallbacks: { (Player) -> () } = {}
local lastStrike: { [Player]: number } = {}
local rng = Random.new()

-- CampaignRuntime registra aqui o mesmo `capture` do Tung Tung.
function LightningService.onStrike(callback: (Player) -> ())
	table.insert(strikeCallbacks, callback)
end

local function folder(): Folder
	local existing = workspace:FindFirstChild("LightningMarks")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "LightningMarks"
	created.Parent = workspace
	return created
end

-- Marca o chão, espera o aviso e derruba quem continuar no ponto.
function LightningService.strike(player: Player, ground: Vector3)
	local now = workspace:GetServerTimeNow()
	lastStrike[player] = os.clock()
	local mark = Instance.new("Part")
	mark.Name = "LightningMark"
	mark.Shape = Enum.PartType.Cylinder
	mark.Anchored, mark.CanCollide, mark.CanQuery, mark.CanTouch = true, false, false, false
	mark.CastShadow = false
	-- A peça é invisível: o aviso é a luz azulada piscando no chão e as faíscas subindo (o cliente pulsa a luz).
	mark.Transparency = 1
	mark.Size = Vector3.new(0.08, LightningRules.KillRadius * 2, LightningRules.KillRadius * 2)
	mark.CFrame = CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90))
	mark:SetAttribute("StrikeAt", now + LightningRules.WarnTime)
	local glow = Instance.new("PointLight")
	glow.Name = "WarnGlow"
	glow.Color = Color3.fromRGB(176, 200, 255)
	glow.Range = LightningRules.KillRadius * 2.6
	glow.Brightness = 2
	glow.Shadows = false
	glow.Parent = mark
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "WarnSparks"
	sparks.Shape = Enum.ParticleEmitterShape.Disc
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	sparks.EmissionDirection = Enum.NormalId.Right
	sparks.Rate = 26
	sparks.Lifetime = NumberRange.new(0.25, 0.6)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(18, 18)
	sparks.Size = NumberSequence.new(0.09, 0)
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(Color3.fromRGB(214, 228, 255))
	sparks.Parent = mark
	-- Aviso sonoro: trovão roncando perto (o estrondo forte toca no cliente quando o raio cai).
	local crackle = Instance.new("Sound")
	crackle.Name = "Rumble"
	crackle.SoundId = Audio.AmbThunder.id
	crackle.Volume = 0.9
	crackle.PlaybackSpeed = 0.8
	crackle.TimePosition = rng:NextNumber(0, 60)
	crackle.RollOffMaxDistance = 120
	crackle.Parent = mark
	mark.Parent = folder()
	crackle:Play()
	task.delay(LightningRules.WarnTime, function()
		mark:SetAttribute("Struck", true)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and LightningRules.hits(ground.X, ground.Z, root.Position.X, root.Position.Z)
		then
			for _, callback in strikeCallbacks do
				task.spawn(callback, player)
			end
		end
		task.delay(1.2, function()
			mark:Destroy()
		end)
	end)
end

function LightningService.Start()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.RespectCanCollide = true
	local stage, stageAt = -1, os.clock()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < LightningRules.RollEvery then
			return
		end
		clock = 0
		local state = ReplicatedStorage:FindFirstChild("CampaignState")
		if not state then
			return
		end
		local current = (tonumber(state:GetAttribute("Stage")) or 0) :: number
		if current ~= stage then
			stage, stageAt = current, os.clock()
		end
		local phase = state:GetAttribute("Phase")
		if phase ~= "Playing" and phase ~= "Extracting" then
			return
		end
		local world = workspace:FindFirstChild(Tags.WorldFolder)
		params.FilterDescendantsInstances = if world then { world } else {}
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if
				not root
				or not root:IsA("BasePart")
				or player:GetAttribute("CampaignStatus") ~= "Active"
				or not LightningRules.canRoll(now - stageAt, now - (lastStrike[player] or -math.huge))
			then
				continue
			end
			local hidden = player:GetAttribute("Hidden")
			if type(hidden) == "string" and hidden ~= "" then
				continue
			end
			-- Só ao ar livre (nada acima da cabeça).
			if workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, 120, 0), params) then
				continue
			end
			if rng:NextNumber() < LightningRules.chance(current, #HouseCatalog.Chapters) then
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
				local ground = if hit then hit.Position else root.Position - Vector3.new(0, 3, 0)
				LightningService.strike(player, ground)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastStrike[player] = nil
	end)
end

return LightningService
