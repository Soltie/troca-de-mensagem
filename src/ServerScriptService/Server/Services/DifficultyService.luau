--!strict
--[[
	Dificuldade, modificadores e conquistas (opção E; regras em Shared/Game/Difficulty e Shared/Game/Achievements).
	- Lobby: qualquer integrante liga/desliga um modificador (SetModifier); vale para a equipe toda e trava quando a
	  partida começa. Publica CampaignState.Modifiers e CampaignState.CoinBonus.
	- Conquistas: TungTung/serviços chamam DifficultyService.unlock; este serviço também libera as de vitória (pela
	  mudança de fase) e as de lugar (catacumba, ilha do rádio). Publica o jogador: Achievements (JSON com os ids) e
	  AchievementToast ("id:serial") para o aviso na tela.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Achievements = require("@game/ReplicatedStorage/Shared/Game/Achievements")
local CatacombLayout = require("@game/ReplicatedStorage/Shared/Game/CatacombLayout")
local Difficulty = require("@game/ReplicatedStorage/Shared/Game/Difficulty")
local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local ServerNet = require("../Net/ServerNet")
local PlayerDataService = require("./PlayerDataService")

local DifficultyService = {
	Name = "DifficultyService",
}

local log = Logger.new("DifficultyService")
local toastSerial = 0

local function campaign(): Instance?
	return ReplicatedStorage:FindFirstChild("CampaignState")
end

-- Texto dos modificadores da partida (lido por Creature/PlayerState/Store).
function DifficultyService.modifiers(): string
	local state = campaign()
	local value = state and state:GetAttribute("Modifiers")
	return if type(value) == "string" then value else ""
end

local function publish(player: Player)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local ids = {}
	for _, a in Achievements.List do
		if data.house.achievements[a.id] then
			table.insert(ids, a.id)
		end
	end
	player:SetAttribute("Achievements", HttpService:JSONEncode(ids))
end

function DifficultyService.unlock(player: Player, id: string)
	if not Achievements.get(id) then
		return
	end
	local data = PlayerDataService.get(player)
	if not data or data.house.achievements[id] then
		return
	end
	local ok = PlayerDataService.update(player, function(d)
		if not d.house.achievements[id] then
			d.house.achievements[id] = os.time()
		end
	end)
	if ok then
		toastSerial += 1
		player:SetAttribute("AchievementToast", `{id}:{toastSerial}`)
		publish(player)
		log.info("%s unlocked %s", player.Name, id)
	end
end

function DifficultyService.unlockAll(id: string)
	for _, player in Players:GetPlayers() do
		local status = player:GetAttribute("CampaignStatus")
		if status == "Active" or status == "Escaped" then
			DifficultyService.unlock(player, id)
		end
	end
end

local function setModifier(player: Player, id: string): { accepted: boolean, message: string }
	local state = campaign()
	if not state or state:GetAttribute("Phase") ~= "Lobby" then
		return { accepted = false, message = "locked" }
	end
	if not Difficulty.get(id) then
		return { accepted = false, message = "unknown" }
	end
	local text = Difficulty.toggle(DifficultyService.modifiers(), id)
	state:SetAttribute("Modifiers", text)
	state:SetAttribute("CoinBonus", Difficulty.factors(text).bonus)
	log.info("%s set modifiers to '%s'", player.Name, text)
	return { accepted = true, message = text }
end

-- Lugares que valem conquista (checados a cada segundo).
local function places()
	local state = campaign()
	local stage = (state and tonumber(state:GetAttribute("Stage"))) or 0
	local lake = ForestMaps.get(7)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root or not root:IsA("BasePart") or player:GetAttribute("CampaignStatus") ~= "Active" then
			continue
		end
		local p = root.Position
		if
			CatacombLayout.openCatacomb(stage)
			and CatacombLayout.inside(CatacombLayout.Catacomb, { x = p.X, y = p.Y - 3, z = p.Z }, 0)
		then
			DifficultyService.unlock(player, "catacumba")
		end
		local l = lake and lake.lake
		if stage == 7 and l and (p.X - l.island.x) ^ 2 + (p.Z - l.island.z) ^ 2 < (l.island.r - 4) ^ 2 then
			DifficultyService.unlock(player, "jangada")
		end
	end
end

function DifficultyService.Start()
	ServerNet.onInvoke("SetModifier", {
		args = { Guard.string({ maxLength = 16, pattern = "^%a+$" }) },
		rateLimit = { capacity = 6, refillPerSecond = 2 },
	}, setModifier)
	-- Publica as conquistas quando os dados do jogador carregam.
	local function watch(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				if not player.Parent then
					return
				end
				if PlayerDataService.get(player) then
					publish(player)
					return
				end
				task.wait(1)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	-- Vitória de capítulo: libera as conquistas dos modificadores ligados.
	local lastPhase = ""
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if clock < 1 then
			return
		end
		clock = 0
		local state = campaign()
		if not state then
			return
		end
		local phase = tostring(state:GetAttribute("Phase"))
		if
			phase ~= lastPhase
			and (lastPhase == "Playing" or lastPhase == "Extracting")
			and (phase == "Intermission" or phase == "Won")
		then
			for _, id in Achievements.forWin(Difficulty.parse(DifficultyService.modifiers()), #Difficulty.List) do
				DifficultyService.unlockAll(id)
			end
		end
		lastPhase = phase
		local ok: boolean, err: any = pcall(places)
		if not ok then
			log.warn("places failed: %s", tostring(err))
		end
	end)
end

return DifficultyService
