--!strict
--[[
	Sopro que varre o corredor (ideia J; regras em Shared/Game/GustRules). Escolhe o corredor de um jogador (o eixo
	com a maior distância livre entre paredes, dentro de casa), publica o trilho em Workspace.Gusts (o cliente pisca
	as luzes, sopra o vento e desenha a frente) e, quando a frente passa, derruba quem está na faixa fora de um
	armário pelo mesmo fluxo da captura (CampaignRuntime registra o callback).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GustRules = require("@game/ReplicatedStorage/Shared/Game/GustRules")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")

local GustService = {
	Name = "GustService",
}

type Gust = {
	part: Part,
	from: Vector3,
	dir: Vector3,
	length: number,
	startAt: number,
	lastFront: number,
	hit: { [Player]: boolean },
}

local hitCallbacks: { (Player) -> () } = {}
local active: { Gust } = {}
local lastGustAt = -math.huge
local rng = Random.new()
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Include
params.RespectCanCollide = true

-- CampaignRuntime registra aqui o mesmo `capture` do Tung Tung.
function GustService.onHit(callback: (Player) -> ())
	table.insert(hitCallbacks, callback)
end

local function folder(): Folder
	local existing = workspace:FindFirstChild("Gusts")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "Gusts"
	created.Parent = workspace
	return created
end

local function refreshFilter()
	local world = workspace:FindFirstChild(Tags.WorldFolder)
	params.FilterDescendantsInstances = if world then { world } else {}
end

local function reach(origin: Vector3, direction: Vector3): number
	local hit = workspace:Raycast(origin, direction * 140, params)
	return if hit then (hit.Position - origin).Magnitude else 140
end

-- Corredor em volta de `position`: o eixo (X ou Z) com mais espaço livre de parede a parede.
local function laneAround(position: Vector3): (Vector3?, Vector3?)
	-- Dentro de casa (tem teto logo acima).
	if not workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, 30, 0), params) then
		return nil, nil
	end
	local startAt: Vector3?, endAt: Vector3?, bestLength = nil, nil, 0
	for _, axis in { Vector3.xAxis, Vector3.zAxis } do
		local ahead = reach(position, axis)
		local behind = reach(position, -axis)
		local length = ahead + behind - 2
		if length >= GustRules.MinLength and length > bestLength then
			startAt, endAt, bestLength = position - axis * (behind - 1), position + axis * (ahead - 1), length
		end
	end
	-- Começa de um lado ou do outro, sorteado.
	if rng:NextNumber() < 0.5 then
		return endAt, startAt
	end
	return startAt, endAt
end

-- Solta um sopro no corredor do jogador. Retorna se achou um corredor.
function GustService.trigger(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	refreshFilter()
	local from, to = laneAround(root.Position)
	if not from or not to then
		return false
	end
	local now = workspace:GetServerTimeNow()
	lastGustAt = os.clock()
	local delta = to - from
	local part = Instance.new("Part")
	part.Name = "Gust"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(from)
	part:SetAttribute("From", from)
	part:SetAttribute("To", to)
	part:SetAttribute("StartAt", now)
	part.Parent = folder()
	table.insert(active, {
		part = part,
		from = from,
		dir = delta.Unit,
		length = delta.Magnitude,
		startAt = now,
		lastFront = -math.huge,
		hit = {},
	})
	return true
end

local function step()
	local now = workspace:GetServerTimeNow()
	for index = #active, 1, -1 do
		local gust = active[index]
		local elapsed = now - gust.startAt
		if elapsed > GustRules.duration(gust.length) then
			gust.part:Destroy()
			table.remove(active, index)
			continue
		end
		local front = GustRules.front(elapsed)
		local previous = gust.lastFront
		gust.lastFront = front
		if front < 0 then
			continue
		end
		local side = Vector3.new(-gust.dir.Z, 0, gust.dir.X)
		for _, player in Players:GetPlayers() do
			if gust.hit[player] or player:GetAttribute("CampaignStatus") ~= "Active" then
				continue
			end
			local hidden = player:GetAttribute("Hidden")
			if type(hidden) == "string" and hidden ~= "" then
				continue
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root or not root:IsA("BasePart") then
				continue
			end
			local offset = root.Position - gust.from
			local along = offset:Dot(gust.dir)
			if
				GustRules.inLane(along, offset:Dot(side), offset.Y, gust.length)
				and GustRules.crossed(along, previous, front)
			then
				gust.hit[player] = true
				for _, callback in hitCallbacks do
					task.spawn(callback, player)
				end
			end
		end
	end
end

function GustService.Start()
	local stage, stageAt = -1, os.clock()
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		if #active > 0 then
			step()
		end
		clock += dt
		if clock < GustRules.RollEvery then
			return
		end
		clock = 0
		local state = ReplicatedStorage:FindFirstChild("CampaignState")
		if not state then
			return
		end
		local current = (tonumber(state:GetAttribute("Stage")) or 0) :: number
		if current ~= stage then
			stage, stageAt = current, os.clock()
		end
		local now = os.clock()
		if
			state:GetAttribute("Phase") ~= "Playing"
			or not GustRules.allowed(current)
			or not GustRules.canRoll(now - stageAt, now - lastGustAt)
			or rng:NextNumber() >= GustRules.Chance
		then
			return
		end
		-- Escolhe alguém ativo e fora de armário; se o corredor dele não serve, tenta na próxima rolagem.
		local candidates = {}
		for _, player in Players:GetPlayers() do
			local hidden = player:GetAttribute("Hidden")
			if
				player:GetAttribute("CampaignStatus") == "Active"
				and player:GetAttribute("CinematicActive") ~= true
				and not (type(hidden) == "string" and hidden ~= "")
			then
				table.insert(candidates, player)
			end
		end
		if #candidates > 0 then
			GustService.trigger(candidates[rng:NextInteger(1, #candidates)])
		end
	end)
end

return GustService
