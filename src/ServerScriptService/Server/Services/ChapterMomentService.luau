--!strict
--[[
	Momentos roteirizados por capítulo (regras em Shared/Game/ChapterMoments). Escuta as tarefas resolvidas da casa
	(HouseActivities.onSolved) e publica o momento em ReplicatedStorage.CampaignState:
	- `Moment` (nome), `MomentAt` (Vector3: onde aconteceu) e `MomentSerial` (sobe a cada momento).
	O MomentController faz o visual em cada cliente. A parte do servidor:
	- túnel (cap. 3): TunnelService.force, ele sai perto de quem pegou a máscara;
	- tremor (cap. 4): ele ouve o coração sair do cofre e vem atrás.
	Presença do Tum Tum no cap. 1 (ele dorme, a casa avisa que ele está perto): "knocks", "silhouette", "nearmiss".
	API para o level design: ChapterMomentService.presence(kind, at?) no servidor, ou uma peça com a tag
	"TungPresenceZone" e o atributo Presence = "knocks" | "silhouette" | "nearmiss" (dispara quando alguém entra
	nela; Once = false repete a cada 30 s). Detalhes em docs/codigo.md.
]]

local CollectionService = game:GetService("CollectionService")
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

-- Presença do Tum Tum (cap. 1): API para o código de nível. `at` é opcional: sem ele o cliente escolhe o ponto
-- olhando para onde o jogador olha; passe `at` só para as batidas virem de um lugar certo.
function ChapterMomentService.presence(kind: string, at: Vector3?)
	if not ChapterMoments.isPresence(kind) then
		log.warn("unknown presence %s", kind)
		return
	end
	ChapterMomentService.play(kind, at or Vector3.zero)
end

local ZONE_TAG = "TungPresenceZone"
local REPEAT_AFTER = 30
local zoneFired: { [BasePart]: number } = {}

local function inside(zone: BasePart, position: Vector3): boolean
	local relative = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function watchZones()
	local stage: any = nil
	while true do
		task.wait(0.25)
		local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
		local current = if campaign then campaign:GetAttribute("Stage") else nil
		if current ~= stage then
			-- Capítulo novo (ou saiu da partida): as zonas valem de novo.
			stage = current
			table.clear(zoneFired)
		end
		if current ~= 1 then
			continue
		end
		for _, zone in CollectionService:GetTagged(ZONE_TAG) do
			if not zone:IsA("BasePart") then
				continue
			end
			local last = zoneFired[zone]
			if last and (zone:GetAttribute("Once") ~= false or os.clock() - last < REPEAT_AFTER) then
				continue
			end
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") and inside(zone, root.Position) then
					local kind = zone:GetAttribute("Presence")
					if typeof(kind) == "string" then
						zoneFired[zone] = os.clock()
						ChapterMomentService.presence(kind, zone.Position)
					end
					break
				end
			end
		end
	end
end

local keysSeen = 0
local keysPlan: any = nil

function ChapterMomentService.Start()
	task.spawn(watchZones)
	-- Presença contínua no cap. 1: depois da 1ª chave, a cada 35 a 60 s ele bate nas paredes de novo (ou passa o vulto
	-- depois da 2ª chave). Ele dorme, mas a casa não deixa o jogador esquecer dele.
	task.spawn(function()
		local rng = Random.new()
		while true do
			task.wait(rng:NextNumber(35, 60))
			local campaign = ReplicatedStorage:FindFirstChild("CampaignState")
			if
				campaign
				and campaign:GetAttribute("Stage") == 1
				and campaign:GetAttribute("GameMode") == "Story"
				and campaign:GetAttribute("Phase") == "Playing"
				and keysSeen >= 1
			then
				ChapterMomentService.presence(
					if keysSeen >= 2 and rng:NextNumber() < 0.5 then "silhouette" else "knocks"
				)
			end
		end
	end)
	-- Cap. 1, gatilhos padrão: 1ª chave = batidas na parede; 2ª chave = silhueta no fim do corredor;
	-- 4ª tarefa resolvida = um quase-acerto.
	Activities.onSolved(function(plan, index)
		if plan.stage == 1 and plan.mode == "Story" then
			if keysPlan ~= plan then
				keysPlan = plan
				keysSeen = 0
			end
			local spec = plan.activities[index]
			if spec and type(spec.item) == "string" and string.find(spec.item, "key_", 1, true) then
				keysSeen += 1
				if keysSeen == 1 then
					ChapterMomentService.presence("knocks")
				elseif keysSeen == 2 then
					ChapterMomentService.presence("silhouette")
				end
			end
			if index == 4 then
				ChapterMomentService.presence("nearmiss")
			end
		end
		local moment = ChapterMoments.forTask(plan.stage, index)
		local spec = plan.activities[index]
		if moment and spec then
			ChapterMomentService.play(moment, Vector3.new(spec.x, spec.y or 0, spec.z))
		end
	end)
end

return ChapterMomentService
