--!strict
--[[
	RewardService: recompensa de fim de partida (Fichas + XP) para cada jogador.

	Não altera os runtimes da rodada: só observa o estado já replicado.
	  solo      GameState.Phase -> Won/Lost (fusíveis e disjuntores do GameState);
	  campanha  ReplicatedStorage.CampaignState (Phase Won/Lost, Stage, Roster com status e
	            contribuições de cada membro).
	Cada partida (GameState.RoundId) paga uma vez só. A tela de resultado do cliente recebe
	os números via StoreService.awardRun -> StoreNotice. O SKU de analytics diz modo e resultado
	(solo_won, solo_lost, campaign_won, campaign_lost): fonte de Fichas por tipo de partida.

	Modo história: cada capítulo vencido (CampaignState Phase -> Intermission ou Won com
	GameMode "Story") paga as recompensas de capítulo (Shared/Game/StoryRewards) a quem participou.
	"Sem quedas" = ninguém da equipe ficou Downed durante o capítulo (lido do Roster replicado).
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
-- História: capítulos já pagos (por rodada + capítulo) e se alguém caiu no capítulo atual.
local storyPaid: { [string]: boolean } = {}
local chapterHadDown = false

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
			}, if won then "campaign_won" else "campaign_lost")
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
			StoreService.awardRun(player, soloSummary(won), if won then "solo_won" else "solo_lost")
		end
	end
	log.info("round %d rewards paid (%s)", round, phase)
end

local function decodeRoster(state: Instance): { any }?
	local ok, roster = pcall(function()
		return HttpService:JSONDecode((state:GetAttribute("Roster") :: string?) or "[]")
	end)
	return if ok and type(roster) == "table" then roster else nil
end

local function payChapter(state: Instance)
	local chapter = tonumber(state:GetAttribute("Stage")) or 0
	local key = `{GameState.get("RoundId") or 0}:{chapter}`
	if chapter < 1 or storyPaid[key] then
		return
	end
	storyPaid[key] = true
	local roster = decodeRoster(state)
	if not roster then
		return
	end
	local flawless = not chapterHadDown
	for _, member in roster do
		local player = Players:GetPlayerByUserId(member.id)
		-- Quem só esperou o capítulo (entrou tarde) não recebe o capítulo.
		if player and member.status ~= "Waiting" then
			StoreService.awardStory(player, chapter, flawless)
		end
	end
	log.info("story chapter %d paid (flawless=%s)", chapter, tostring(flawless))
end

local function watchStory(state: Instance)
	local lastPhase = state:GetAttribute("Phase")
	state:GetAttributeChangedSignal("Roster"):Connect(function()
		local roster = decodeRoster(state)
		if roster and state:GetAttribute("Phase") == "Playing" then
			for _, member in roster do
				if member.status == "Downed" then
					chapterHadDown = true
				end
			end
		end
	end)
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		local phase = state:GetAttribute("Phase")
		if phase == "Playing" and lastPhase ~= "Playing" and lastPhase ~= "Extracting" then
			chapterHadDown = false
		end
		local story = state:GetAttribute("GameMode") == "Story"
		-- Só conta capítulo terminado jogando (a Continuação também passa Lost -> Intermission).
		local finished = lastPhase == "Playing" or lastPhase == "Extracting"
		if story and (phase == "Intermission" or phase == "Won") and finished then
			-- Deixa o runtime publicar Roster/Stage do mesmo quadro.
			task.defer(payChapter, state)
		end
		lastPhase = phase
	end)
end

local RewardService = {
	Name = "RewardService",
}

function RewardService.Start()
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("CampaignState", 30)
		if state then
			watchStory(state)
		end
	end)
	GameState.observe(function(snapshot, changed)
		if changed == "Phase" and (snapshot.phase == "Won" or snapshot.phase == "Lost") then
			-- Deixa o runtime terminar de publicar Roster/Stage do mesmo quadro.
			task.defer(onEnd, snapshot.phase)
		end
	end)
end

return RewardService
