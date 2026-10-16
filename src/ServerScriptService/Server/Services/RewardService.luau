--!strict
--[[
	RewardService: recompensa de fim de partida (Fichas + XP) para cada jogador.

	Não altera os runtimes da rodada: só observa o estado já replicado.
	  solo      GameState.Phase -> Won/Lost (fusíveis e disjuntores do GameState);
	  campanha  ReplicatedStorage.CampaignState (Phase Won/Lost, Stage, Roster com status e
	            contribuições de cada membro).
	Cada partida (GameState.RoundId) paga uma vez só. A tela de resultado do cliente recebe
	os números via StoreService.awardRun -> StoreNotice.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require("@game/ReplicatedStorage/Shared/Game/Economy")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local CampaignMode = require("../Campaign/CampaignMode")
local StoreService = require("./StoreService")

local log = Logger.new("RewardService")
local awarded: { [number]: boolean } = {}

local function soloSummary(won: boolean): Economy.RunSummary
	return {
		won = won,
		escaped = won,
		stages = 0,
		fuses = GameState.get("FusesCollected") or 0,
		breakers = GameState.get("BreakersOn") == true,
		contributions = 0,
	}
end

local function campaignAwards(won: boolean)
	local state = ReplicatedStorage:FindFirstChild("CampaignState")
	if not state then
		return
	end
	local ok, roster = pcall(function()
		return HttpService:JSONDecode((state:GetAttribute("Roster") :: string?) or "[]")
	end)
	if not ok or type(roster) ~= "table" then
		return
	end
	local stage = (state:GetAttribute("Stage") :: number?) or 1
	local cleared = if won then stage else math.max(0, stage - 1)
	for _, member in roster do
		local player = Players:GetPlayerByUserId(member.id)
		if player then
			StoreService.awardRun(player, {
				won = won,
				escaped = won and member.status ~= "Downed",
				stages = cleared,
				fuses = 0,
				breakers = false,
				contributions = tonumber(member.contributions) or 0,
			})
		end
	end
end

local function onEnd(phase: string)
	local round = GameState.get("RoundId") or 0
	if awarded[round] then
		return
	end
	awarded[round] = true
	local won = phase == "Won"
	if CampaignMode.enabled() then
		campaignAwards(won)
	else
		for _, player in Players:GetPlayers() do
			StoreService.awardRun(player, soloSummary(won))
		end
	end
	log.info("round %d rewards paid (%s)", round, phase)
end

local RewardService = {
	Name = "RewardService",
}

function RewardService.Start()
	GameState.observe(function(snapshot, changed)
		if changed == "Phase" and (snapshot.phase == "Won" or snapshot.phase == "Lost") then
			-- Deixa o runtime terminar de publicar Roster/Stage do mesmo quadro.
			task.defer(onEnd, snapshot.phase)
		end
	end)
end

return RewardService
