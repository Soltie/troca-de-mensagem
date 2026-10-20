--!strict
--[[
	Momentos roteirizados por capítulo (regras em Shared/Game/ChapterMoments). Escuta as tarefas resolvidas da casa
	(HouseActivities.onSolved) e publica o momento em ReplicatedStorage.CampaignState:
	- `Moment` (nome), `MomentAt` (Vector3: onde aconteceu) e `MomentSerial` (sobe a cada momento).
	O MomentController faz o visual em cada cliente. A parte do servidor:
	- túnel (cap. 3): TunnelService.force, ele sai perto de quem pegou a máscara;
	- tremor (cap. 4): ele ouve o coração sair do cofre e vem atrás.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChapterMoments = require("@game/ReplicatedStorage/Shared/Game/ChapterMoments")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Activities = require("../Campaign/HouseActivities")
local CreatureService = require("./CreatureService")
local TunnelService = require("./TunnelService")

local ChapterMomentService = {
	Name = "ChapterMomentService",
}

local log = Logger.new("ChapterMoments")
local serial = 0

local function nearestPlayer(at: Vector3): Player?
	local best, bestDistance = nil, math.huge
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and player:GetAttribute("CampaignStatus") == "Active" then
			local d = (root.Position - at).Magnitude
			if d < bestDistance then
				best, bestDistance = player, d
			end
		end
	end
	return best
end

-- Dispara o momento `moment` em `at` (também usado pela ponte de depuração).
function ChapterMomentService.play(moment: string, at: Vector3)
	local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
	if not campaign then
		return
	end
	serial += 1
	campaign:SetAttribute("Moment", moment)
	campaign:SetAttribute("MomentAt", at)
	campaign:SetAttribute("MomentSerial", serial)
	if moment == "tunnel" then
		local player = nearestPlayer(at)
		local forced = player ~= nil and TunnelService.force(player)
		log.info("moment tunnel (forced=%s)", tostring(forced))
	elseif moment == "quake" then
		if CreatureService.isActive() then
			CreatureService.makeNoise(at, 120)
		end
		log.info("moment quake")
	else
		log.info("moment %s", moment)
	end
end

function ChapterMomentService.Start()
	Activities.onSolved(function(plan, index)
		local moment = ChapterMoments.forTask(plan.stage, index)
		local spec = plan.activities[index]
		if moment and spec then
			ChapterMomentService.play(moment, Vector3.new(spec.x, spec.y or 0, spec.z))
		end
	end)
end

return ChapterMomentService
