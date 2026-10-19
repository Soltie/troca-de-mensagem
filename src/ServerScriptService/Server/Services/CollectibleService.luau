--!strict
--[[
	CollectibleService: fitas VHS colecionáveis (12, em Shared/Game/StoreCatalog.Tapes).

	- Uma fita aparece a cada partida (no solo) ou a cada estágio (campanha), num ponto sorteado
	  longe dos jogadores. O ponto é achado por raycast de cima para baixo: a fita fica sobre o
	  que houver ali (piso, mesa, caixote), sem depender da posição exata dos móveis.
	- Escolhe a fita que MENOS jogadores presentes têm (empate: sorteio). Todos já têm todas: não aparece.
	- Quem pega (mire + E, id "tape") dá a fita para a EQUIPE inteira: cooperação, não disputa.
	  Cada membro ganha também XP de temporada; Fichas/XP e o analytics vêm de StoreService.awardTape.
	  Os runtimes da rodada encaminham o id "tape" para CollectibleService.collect.
	- Validação no servidor: fase Playing, membro ativo, vivo, distância e linha de visão.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local ForestMaps = require("@game/ReplicatedStorage/Shared/Game/ForestMaps")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local StoreService = require("./StoreService")

local log = Logger.new("CollectibleService")
local TAPE_ID = "tape"
local REACH = 7
local MIN_PLAYER_DISTANCE = 24

-- Pontos candidatos (x, z) no meio das salas, longe das paredes (a altura vem do raycast).
local SPOTS: { { number } } = {
	{ 1.5, -8.5 }, -- recepção
	{ -16, -12 }, -- escritório
	{ -33, -19.5 }, -- corredor
	{ 38, -11 }, -- bombas
	{ -10, -32 }, -- gerador
	{ 12, -42 }, -- depósito
	{ -60, -10 }, -- oficina
	{ -50, -40 }, -- oficina (fundo)
	{ -60, -70 }, -- galeria de cabos
	{ -30, -60 }, -- sala de controle
	{ -6, -70 }, -- sala de controle (fundo)
	{ 14, -60 }, -- arquivo técnico
	{ 32, -72 }, -- arquivo técnico (fundo)
	{ 60, -40 }, -- pátio de transformadores
}

local current: BasePart? = nil
local currentTape: string? = nil
local spawnedFor = ""
local rng = Random.new()

local function clear()
	local model = if current then current.Parent else nil
	if model then
		model:Destroy()
	end
	current = nil
	currentTape = nil
end

local function exclusions(): { Instance }
	local list: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, name in { "Vigia", "VigiaVisual" } do
		local model = workspace:FindFirstChild(name)
		if model then
			table.insert(list, model)
		end
	end
	return list
end

local function farFromPlayers(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and (character:GetPivot().Position - position).Magnitude < MIN_PLAYER_DISTANCE then
			return false
		end
	end
	return true
end

-- Ponto de apoio: raycast de cima para baixo; precisa ser superfície horizontal e baixa.
local function findSpot(): CFrame?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions()
	params.RespectCanCollide = true
	local order = {}
	for i = 1, #SPOTS do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	for _, index in order do
		local spot = SPOTS[index]
		local hit = workspace:Raycast(Vector3.new(spot[1], 10.5, spot[2]), Vector3.new(0, -12, 0), params)
		if hit and hit.Normal.Y > 0.8 and hit.Position.Y < 6 and farFromPlayers(hit.Position) then
			return CFrame.new(hit.Position + Vector3.new(0, 0.09, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		end
	end
	return nil
end

-- Fita que menos jogadores presentes têm (nil se todos já têm todas).
local function chooseTape(): string?
	local best: { string } = {}
	local bestMissing = 0
	for _, tape in StoreCatalog.Tapes do
		local missing = 0
		for _, player in Players:GetPlayers() do
			if not StoreService.ownedTapes(player)[tape.id] then
				missing += 1
			end
		end
		if missing > bestMissing then
			best = { tape.id }
			bestMissing = missing
		elseif missing == bestMissing and missing > 0 then
			table.insert(best, tape.id)
		end
	end
	if #best == 0 then
		return nil
	end
	return best[rng:NextInteger(1, #best)]
end

local function build(at: CFrame, tapeId: string): BasePart
	local model = Instance.new("Model")
	model.Name = "VhsTape"
	local case = Instance.new("Part")
	case.Name = "Case"
	case.Size = Vector3.new(0.9, 0.16, 0.55)
	case.CFrame = at
	case.Color = Color3.fromRGB(18, 18, 20)
	case.Material = Enum.Material.SmoothPlastic
	case.Reflectance = 0.15
	case.Anchored = true
	case.CanCollide = false
	case.CastShadow = false
	case.Parent = model
	local label = case:Clone()
	label.Name = "Label"
	label.Size = Vector3.new(0.6, 0.02, 0.3)
	label.CFrame = at * CFrame.new(0, 0.09, 0)
	label.Color = Color3.fromRGB(220, 214, 196)
	label.Reflectance = 0
	label.CanQuery = false
	label.Parent = model
	local rec = case:Clone()
	rec.Name = "Rec"
	rec.Size = Vector3.new(0.08, 0.03, 0.08)
	rec.CFrame = at * CFrame.new(0.36, 0.09, -0.18)
	rec.Color = Color3.fromRGB(255, 50, 40)
	rec.Material = Enum.Material.Neon
	rec.Reflectance = 0
	rec.CanQuery = false
	rec.Parent = model
	case:SetAttribute(Tags.Attr.InteractId, TAPE_ID)
	case:SetAttribute(Tags.Attr.InteractPrompt, Text.Prompts.Tape)
	case:SetAttribute(Tags.Attr.InteractDistance, REACH)
	case:SetAttribute(Tags.Attr.InteractEnabled, true)
	case:SetAttribute("Tape", tapeId)
	CollectionService:AddTag(case, Tags.Interactable)
	model.PrimaryPart = case
	model.Parent = workspace
	return case
end

-- Floresta (caps. 6–8): a casa fica longe; a fita vai para perto de um dos lugares do mapa do capítulo, no chão.
local function forestSpot(stage: number): CFrame?
	local map = ForestMaps.get(stage)
	if not map then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclusions()
	params.RespectCanCollide = true
	for _ = 1, 24 do
		local room = map.rooms[rng:NextInteger(1, #map.rooms)]
		local x, z = room.x + rng:NextNumber(-9, 9), room.z + rng:NextNumber(-9, 9)
		if ForestMaps.inLake(map, x, z) or ForestMaps.inRavine(map, x, z) then
			continue
		end
		local hit = workspace:Raycast(Vector3.new(x, room.y + 30, z), Vector3.new(0, -60, 0), params)
		if hit and hit.Normal.Y > 0.8 and hit.Material ~= Enum.Material.Water and farFromPlayers(hit.Position) then
			return CFrame.new(hit.Position + Vector3.new(0, 0.09, 0))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
		end
	end
	return nil
end

local function spawnTape()
	clear()
	local tapeId = chooseTape()
	if not tapeId then
		return
	end
	local state = game:GetService("ReplicatedStorage"):FindFirstChild("CampaignState")
	local stage = if state then (tonumber(state:GetAttribute("Stage")) or 0) else 0
	local at = if stage >= 6 then forestSpot(stage) else findSpot()
	if not at then
		log.warn("no free spot for a tape this round")
		return
	end
	current = build(at, tapeId)
	currentTape = tapeId
	log.info("tape %s placed at (%d, %d, %d)", tapeId, at.Position.X, at.Position.Y, at.Position.Z)
end

local function canReach(character: Model, part: BasePart): boolean
	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else character:GetPivot().Position
	if (origin - part.Position).Magnitude > REACH + Config.Game.InteractTolerance then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(origin, part.Position - origin, params)
	return hit == nil
		or hit.Instance:IsDescendantOf(part.Parent :: Instance)
		or (hit.Position - part.Position).Magnitude < 1
end

local CollectibleService = {
	Name = "CollectibleService",
	TAPE_ID = TAPE_ID,
}

function CollectibleService.Start()
	GameState.observe(function(snapshot, changed)
		if snapshot.phase == "Playing" and (changed == "Phase" or changed == nil) then
			-- Uma fita por partida (RoundId) e por estágio da campanha.
			local state = game:GetService("ReplicatedStorage"):FindFirstChild("CampaignState")
			local stage = if state then (state:GetAttribute("Stage") :: number?) or 0 else 0
			local key = `{snapshot.roundId}:{stage}`
			if key ~= spawnedFor then
				spawnedFor = key
				task.defer(spawnTape)
			end
		elseif
			changed == "Phase" and (snapshot.phase == "Intro" or snapshot.phase == "Won" or snapshot.phase == "Lost")
		then
			clear()
		end
	end)
end

-- Encaminhado pelos runtimes (solo e campanha) quando o id é "tape".
function CollectibleService.collect(player: Player): Types.InteractResponse
	local part = current
	local tapeId = currentTape
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local status = player:GetAttribute("CampaignStatus")
	if GameState.get("Phase") ~= "Playing" or (status ~= nil and status ~= "Active") then
		return { accepted = false, message = "not_available" }
	end
	if not part or not tapeId or not character or not humanoid or humanoid.Health <= 0 then
		return { accepted = false, message = "not_available" }
	end
	if not canReach(character, part) then
		return { accepted = false, message = "too_far" }
	end
	clear()
	for _, member in Players:GetPlayers() do
		StoreService.awardTape(member, tapeId, player.DisplayName)
	end
	log.info("%s found %s for the team", player.Name, tapeId)
	return { accepted = true, message = "tape_found", kind = "Tape" }
end

-- Depuração: posição e id da fita atual.
function CollectibleService.debugState(): { [string]: any }
	return {
		tape = currentTape,
		position = if current then current.Position else nil,
	}
end

return CollectibleService
