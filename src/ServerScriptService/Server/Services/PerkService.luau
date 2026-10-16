--!strict
--[[
	PerkService: aplica na partida os consumíveis de uso automático (kit) comprados na loja.
	Regras e preços em Shared/Game/Perks; estoque e kit nos dados (StoreService).

	  Pilha Extra     no começo de cada etapa (ou da missão solo) arma uma pilha reserva (atributo
	                  SpareBattery) em quem tem no kit; o PlayerStateService a coloca quando a lanterna apaga.
	  Segunda Chance  na campanha, quem é pego com ela no kit levanta sozinho depois de
	                  Perks.SECOND_CHANCE_DELAY s (uma por etapa). O CampaignRuntime chama secondChance().

	As melhorias permanentes não passam por aqui: cada sistema lê o atributo Perk<Id> publicado pelo
	StoreService (bateria: PlayerStateService; barulho: CreatureService; resgate: CampaignRuntime;
	fôlego: CharacterController no cliente).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local StoreService = require("./StoreService")

local log = Logger.new("PerkService")
-- Etapa em que cada consumível já foi usado por jogador (uma vez por etapa).
local usedAt: { [Player]: { [string]: string } } = {}
-- Espera o renascimento/congelamento do começo de etapa antes de somar a pilha.
local BATTERY_DELAY = 4

local PerkService = {
	Name = "PerkService",
}

-- Identifica a etapa atual: campanha (id + etapa) ou rodada solo.
local function stageKey(): string
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	if campaign and GameState.get("CampaignActive") then
		return `c{GameState.get("RoundId")}:{campaign:GetAttribute("Stage")}`
	end
	return `s{GameState.get("RoundId")}`
end

local function markUsed(player: Player, id: string, key: string): boolean
	local used = usedAt[player] or {}
	usedAt[player] = used
	if used[id] == key then
		return false
	end
	used[id] = key
	return true
end

local function giveExtraBattery(key: string)
	for _, player in Players:GetPlayers() do
		local status = player:GetAttribute("CampaignStatus")
		if (status == nil or status == "Active") and StoreService.inLoadout(player, "pilha_extra") then
			-- Uma reserva por vez: quem ainda tem a da etapa anterior não gasta outra.
			if
				player:GetAttribute("SpareBattery") ~= true
				and markUsed(player, "pilha_extra", key)
				and StoreService.consume(player, "pilha_extra")
			then
				player:SetAttribute("SpareBattery", true)
				log.info("%s armed a spare battery", player.Name)
			end
		end
	end
end

--[[
	Chamado pelo CampaignRuntime logo depois de alguém ser pego. Com Segunda Chance no kit (e ainda
	não usada nesta etapa), gasta uma e agenda `revive` (o runtime valida e levanta o jogador).
]]
function PerkService.secondChance(player: Player, revive: () -> ()): boolean
	if not StoreService.inLoadout(player, "segunda_chance") then
		return false
	end
	if not markUsed(player, "segunda_chance", stageKey()) then
		return false
	end
	if not StoreService.consume(player, "segunda_chance") then
		return false
	end
	player:SetAttribute("SecondChanceAt", workspace:GetServerTimeNow() + Perks.SECOND_CHANCE_DELAY)
	log.info("%s second chance in %ds", player.Name, Perks.SECOND_CHANCE_DELAY)
	task.delay(Perks.SECOND_CHANCE_DELAY, revive)
	return true
end

function PerkService.Start()
	GameState.observe(function(snapshot, changed)
		-- Começo de etapa: a fase entra em Playing (campanha: a cada etapa; solo: depois da cartela).
		if changed == "Phase" and snapshot.phase == "Playing" then
			local key = stageKey()
			task.delay(BATTERY_DELAY, function()
				if GameState.get("Phase") == "Playing" and stageKey() == key then
					giveExtraBattery(key)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		usedAt[player] = nil
	end)
end

return PerkService
