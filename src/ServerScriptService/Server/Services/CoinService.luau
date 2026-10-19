--!strict
--[[
	Moedas da casa: a cada capítulo (Seed + Stage da campanha) o servidor espalha moedas douradas
	e uma gema roxa (CoinPlan). Quem passa perto pega: Fichas + XP na hora (StoreService.awardCoin).
	O servidor decide a coleta pela posição do personagem; o cliente só anima (CoinController).

	Efeito no cliente via atributos do jogador: CoinPickupSerial (contador), CoinPickupValue, CoinPickupAt.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CoinPlan = require("../Game/CoinPlan")
local CollectibleFinish = require("../World/HouseCollectibleFinish")
local StoreService = require("./StoreService")

local log = Logger.new("CoinService")
local C = Config.Coins

local CoinService = {
	Name = "CoinService",
	Tag = "HouseCoin",
}

local folder: Folder? = nil
local live: { [BasePart]: boolean } = {}
local currentKey = ""
local collected = 0

local function clear()
	for coin in live do
		coin:Destroy()
	end
	table.clear(live)
end

local function makeCoin(parent: Instance, spec: CoinPlan.Coin): BasePart
	local part = Instance.new("Part")
	part.Name = spec.id
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Metal
	if spec.gem then
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(1.8, 1.8, 1.8)
		part.Color = Color3.fromRGB(200, 110, 255)
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Range = 12
		light.Brightness = 0.35
		light.Parent = part
	else
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(0.35, 2, 2)
		part.Color = Color3.fromRGB(255, 200, 40)
	end
	-- Cilindro em pé: o eixo X do Roblox vira o eixo da moeda; gira no Y para "olhar" pros lados.
	part.CFrame = CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, 0, 0)
	part:SetAttribute("Value", if spec.gem then C.GemValue else C.Value)
	part:SetAttribute("Xp", if spec.gem then C.GemXp else C.Xp)
	part:SetAttribute("Gem", spec.gem)
	CollectibleFinish.coin(part)
	CollectionService:AddTag(part, CoinService.Tag)
	part.Parent = parent
	return part
end

local function spawnCoins(seed: number, stage: number)
	clear()
	local parent = folder
	if not parent then
		return
	end
	local plan = CoinPlan.create(seed + stage * 104729, C.PerRoom, C.YardCoins)
	for _, spec in plan do
		live[makeCoin(parent, spec)] = true
	end
	log.info("spawned %d coins (stage %d)", #plan, stage)
end

local function collect(player: Player, coin: BasePart)
	if not live[coin] then
		return
	end
	live[coin] = nil
	local value = (coin:GetAttribute("Value") :: number?) or C.Value
	local xp = (coin:GetAttribute("Xp") :: number?) or C.Xp
	local position = coin.Position
	local gem = coin:GetAttribute("Gem") == true
	coin:Destroy()
	collected += 1
	player:SetAttribute("CoinPickupValue", value)
	player:SetAttribute("CoinPickupAt", position)
	player:SetAttribute("CoinPickupGem", gem)
	player:SetAttribute("CoinPickupSerial", ((player:GetAttribute("CoinPickupSerial") :: number?) or 0) + 1)
	task.spawn(StoreService.awardCoin, player, value, xp)
end

local function tick()
	if ReplicatedStorage:GetAttribute("PvPActive") == true then
		return
	end
	if next(live) == nil then
		return
	end
	local radius = C.PickupRadius
	for _, player in Players:GetPlayers() do
		if player:GetAttribute("CampaignStatus") ~= "Active" then
			continue
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local position = root.Position
		for coin in live do
			local offset = coin.Position - position
			if math.abs(offset.Y) < 5 and Vector3.new(offset.X, 0, offset.Z).Magnitude < radius then
				collect(player, coin)
			end
		end
	end
end

function CoinService.Start()
	if not C.Enabled or not Config.House.Enabled then
		return
	end
	local container = Instance.new("Folder")
	container.Name = "HouseCoins"
	container.Parent = workspace
	folder = container
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("CampaignState", 60)
		if not state then
			log.warn("no CampaignState; coins disabled")
			return
		end
		local function refresh()
			local phase = state:GetAttribute("Phase")
			local seed = (state:GetAttribute("Seed") :: number?) or 0
			local stage = (state:GetAttribute("Stage") :: number?) or 0
			if phase == "Lobby" or stage <= 0 then
				currentKey = ""
				clear()
				return
			end
			local key = `{seed}:{stage}`
			if phase == "Playing" and key ~= currentKey then
				currentKey = key
				spawnCoins(seed, stage)
			end
		end
		for _, name in { "Phase", "Seed", "Stage" } do
			state:GetAttributeChangedSignal(name):Connect(refresh)
		end
		refresh()
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.1 then
			elapsed = 0
			tick()
		end
	end)
end

-- Moedas ainda no mapa e total pego desde o início do servidor (testes e depuração).
function CoinService.status(): (number, number)
	local count = 0
	for _ in live do
		count += 1
	end
	return count, collected
end

return CoinService
