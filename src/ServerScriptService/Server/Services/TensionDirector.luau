--!strict
--[[
	Diretor de tensão (ideia D; regras em Shared/Game/TensionModel). Camada acima da IA do Tung Tung, só com a partida
	rodando (fase Playing). A cada meio segundo mede a tensão (ele perto, perseguindo, pancadas, sopros e revistas) e:
	- na folga (Relax) manda o Tung Tung se afastar e segura os eventos opcionais (sopro);
	- calmo demais por muito tempo, manda ele investigar perto de alguém (sem ir direto em cima).
	Publica em ReplicatedStorage.CampaignState: Tension (0..1) e TensionPhase ("Build" | "Peak" | "Relax"); o
	ScareController não solta susto no pico.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local TensionModel = require("@game/ReplicatedStorage/Shared/Game/TensionModel")
local CreatureService = require("./CreatureService")

local TensionDirector = {
	Name = "TensionDirector",
}

local TICK = 0.5
local log = Logger.new("TensionDirector")

local state = TensionModel.new(os.clock())
local stage = -1
local pendingHits = 0
local pendingEvents = 0
local rng = Random.new()

-- Sopro e outros eventos opcionais perguntam aqui antes de acontecer.
function TensionDirector.allowsEvents(): boolean
	return TensionModel.allowsEvents(state)
end

function TensionDirector.phase(): TensionModel.Phase
	return state.phase
end

local function activePlayers(): { { player: Player, at: Vector3 } }
	local out = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local body = character and character:FindFirstChild("HumanoidRootPart")
		local hidden = player:GetAttribute("Hidden")
		if
			player:GetAttribute("CampaignStatus") == "Active"
			and body
			and body:IsA("BasePart")
			and not (type(hidden) == "string" and hidden ~= "")
		then
			table.insert(out, { player = player, at = body.Position })
		end
	end
	return out
end

local function publish(campaign: Instance)
	campaign:SetAttribute("Tension", math.floor(state.tension * 20 + 0.5) / 20)
	campaign:SetAttribute("TensionPhase", state.phase)
end

local function step(dt: number)
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	if not campaign then
		return
	end
	local current = (tonumber(campaign:GetAttribute("Stage")) or 0) :: number
	if current ~= stage then
		-- Capítulo novo: começa do zero.
		stage = current
		state = TensionModel.new(os.clock())
		pendingHits, pendingEvents = 0, 0
	end
	if campaign:GetAttribute("Phase") ~= "Playing" or not CreatureService.isActive() then
		publish(campaign)
		return
	end
	local players = activePlayers()
	local feet = CreatureService.feetPosition()
	local distance = math.huge
	if feet then
		for _, entry in players do
			distance = math.min(distance, (entry.at - feet).Magnitude)
		end
	end
	local out = TensionModel.step(state, dt, {
		now = os.clock(),
		distance = distance,
		chasing = CreatureService.isChasing(),
		hits = pendingHits,
		events = pendingEvents,
	})
	pendingHits, pendingEvents = 0, 0
	if out.entered then
		log.debug("phase %s (tension %.2f)", out.entered, state.tension)
		if out.entered == "Relax" then
			CreatureService.retreat(TensionModel.RelaxTime * 0.6)
		end
	end
	if out.provoke and #players > 0 then
		-- Investiga um ponto perto de alguém (10 a 16 studs de distância), sem saber exatamente onde ele está.
		local target = players[rng:NextInteger(1, #players)].at
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(10, 16)
		CreatureService.followScent(target + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		log.debug("provoke near a player")
	end
	publish(campaign)
end

local function watchPlayer(player: Player)
	player:GetAttributeChangedSignal("LastCaptureAt"):Connect(function()
		pendingHits += 1
	end)
	player:GetAttributeChangedSignal("BreathTestAt"):Connect(function()
		if player:GetAttribute("BreathTestAt") ~= nil then
			pendingEvents += 1
		end
	end)
end

function TensionDirector.Start()
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Gusts" then
			child.ChildAdded:Connect(function()
				pendingEvents += 1
			end)
		end
	end)
	local existing = workspace:FindFirstChild("Gusts")
	if existing then
		existing.ChildAdded:Connect(function()
			pendingEvents += 1
		end)
	end
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < TICK then
			return
		end
		step(clock)
		clock = 0
	end)
end

return TensionDirector
