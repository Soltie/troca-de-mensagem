--!strict
--[[
	Incêndio da fuga final (regras em Shared/Game/FireSpread). O WorldService liga com os atributos BlazeSeed e
	BlazeStart no mundo; aqui o calor de cada jogador sobe dentro do fogo e esfria fora dele (atributo FireHeat,
	o cliente mostra a tela esquentando). Calor cheio derruba pelo mesmo fluxo da captura (CampaignRuntime).
	Enquanto a casa queima, o barulho do fogo e das vigas guia o Tung Tung até quem está fugindo.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FireSpread = require("@game/ReplicatedStorage/Shared/Game/FireSpread")
local CreatureService = require("./CreatureService")
local WorldService = require("./WorldService")

local FireService = {
	Name = "FireService",
}

local TICK = 0.1
local NOISE_EVERY = 9

local burnCallbacks: { (Player) -> () } = {}
local heat: { [Player]: number } = {}
local nodes: { FireSpread.Node } = {}
local builtSeed = 0
local nextNoiseAt = 0
local rng = Random.new()

-- CampaignRuntime registra aqui o mesmo `capture` do Tung Tung.
function FireService.onBurn(callback: (Player) -> ())
	table.insert(burnCallbacks, callback)
end

local function setHeat(player: Player, value: number)
	heat[player] = value
	local shown = math.floor(value * 20 + 0.5) / 20
	if player:GetAttribute("FireHeat") ~= shown then
		player:SetAttribute("FireHeat", if shown > 0 then shown else nil)
	end
end

local function step(dt: number)
	local root = WorldService.get().root
	local seed = root:GetAttribute("BlazeSeed")
	local start = root:GetAttribute("BlazeStart")
	if type(seed) ~= "number" or type(start) ~= "number" then
		if next(heat) then
			for player in heat do
				setHeat(player, 0)
			end
			table.clear(heat)
		end
		return
	end
	if seed ~= builtSeed then
		nodes, builtSeed = FireSpread.build(seed), seed
	end
	local now = workspace:GetServerTimeNow()
	local t = now - start
	local runners: { Vector3 } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local status = player:GetAttribute("CampaignStatus")
		if not body or not body:IsA("BasePart") or (status ~= "Active" and status ~= nil) then
			if heat[player] then
				setHeat(player, 0)
			end
			continue
		end
		local p = body.Position
		table.insert(runners, p)
		local exposure = FireSpread.exposure(nodes, t, p.X, p.Y - 3, p.Z)
		local value = FireSpread.heat(heat[player] or 0, exposure, dt)
		if value >= 1 then
			setHeat(player, 0)
			for _, callback in burnCallbacks do
				task.spawn(callback, player)
			end
		else
			setHeat(player, value)
		end
	end
	-- Vigas estalando e caindo fazem barulho: o Tung Tung segue quem ainda está dentro de casa.
	if t > FireSpread.HeadStart and now >= nextNoiseAt and #runners > 0 then
		nextNoiseAt = now + NOISE_EVERY
		local target = runners[rng:NextInteger(1, #runners)]
		if target.Z < 64 then
			CreatureService.followScent(target)
		end
	end
end

function FireService.Start()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt: number)
		clock += dt
		if clock < TICK then
			return
		end
		step(clock)
		clock = 0
	end)
	Players.PlayerRemoving:Connect(function(player)
		heat[player] = nil
	end)
end

return FireService
