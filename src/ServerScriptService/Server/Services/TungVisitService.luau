--!strict
--[[
	A Visita do Tum Tum (cap. 1, nota 9): ameaça jogável. Regras e rota em Shared/Game/TungVisit; esconderijos em
	docs/level.md. Fluxo: aviso (20 s; 10 s se `early`) → ele aparece no pé da escada, passa pelo hall, entra no cômodo
	da equipe, para no meio, olha o armário e vai embora. Quem ele vê (fora do armário, com lanterna ou correndo) é
	capturado pelo mesmo caminho de um golpe do Tum Tum (CreatureService.forceCapture). Só 1 vez por capítulo.
	Usa o corpo real dele (CreatureService.visitShow/visitMove/visitHide), então o modelo e as animações são os do
	Assets.TungTung no cliente. O cérebro de perseguição continua desligado.

	API: TungVisitService.start({ early = true?, room = "Living"|"Kitchen"|"Dining"? }) -> boolean
	O estado vai para ReplicatedStorage.CampaignState: VisitPhase ("warning" | "patrol" | "caught" | "gone" | ""),
	VisitEndsAt (fim do aviso), VisitRoom, VisitSerial. O TungVisitController faz o som, as legendas e a luz.
	Gatilho padrão: 25 s depois da 2ª chave do cap. 1 (a silhueta do ChapterMomentService é o primeiro sinal).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local TungVisit = require("@game/ReplicatedStorage/Shared/Game/TungVisit")
local Activities = require("../Campaign/HouseActivities")
local CreatureService = require("./CreatureService")
local PlayerStateService = require("./PlayerStateService")

local TungVisitService = {
	Name = "TungVisitService",
}

local log = Logger.new("TungVisit")

local running = false
local done = false
local token = 0
local keysSeen = 0
local keysPlan: any = nil

local function campaign(): Instance?
	return ReplicatedStorage:FindFirstChild("CampaignState")
end

local function publish(phase: string, endsAt: number?, room: string?)
	local state = campaign()
	if not state then
		return
	end
	state:SetAttribute("VisitPhase", phase)
	state:SetAttribute("VisitEndsAt", endsAt or 0)
	state:SetAttribute("VisitRoom", room or "")
	state:SetAttribute("VisitSerial", ((state:GetAttribute("VisitSerial") :: number?) or 0) + 1)
end

local function inChapterOne(): boolean
	local state = campaign()
	return state ~= nil
		and state:GetAttribute("Stage") == 1
		and state:GetAttribute("GameMode") == "Story"
		and state:GetAttribute("Phase") == "Playing"
end

local function activePlayers(): { Player }
	local out: { Player } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if
			player:GetAttribute("CampaignStatus") == "Active"
			and character
			and character:FindFirstChild("HumanoidRootPart")
		then
			table.insert(out, player)
		end
	end
	return out
end

local function vec(p: TungVisit.Point): Vector3
	return Vector3.new(p.x, 0, p.z)
end

-- Linha de visão da cabeça dele até a do jogador; colisores invisíveis de móvel e lençóis não bloqueiam.
local function clearSight(from: Vector3, player: Player): boolean
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return false
	end
	local exclude: { Instance } = { CreatureService.rootPart() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	for _ = 1, 4 do
		local hit = workspace:Raycast(from, head.Position - from, params)
		if not hit then
			return true
		end
		if hit.Instance.Name ~= "FurnitureCollider" and not string.find(hit.Instance.Name, "Sheet", 1, true) then
			return false
		end
		table.insert(exclude, hit.Instance)
		params.FilterDescendantsInstances = exclude
	end
	return false
end

local function seenPlayers(at: Vector3, atCloset: boolean, sinceSpawn: number): { Player }
	local seen: { Player } = {}
	for _, player in activePlayers() do
		local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		local distance = (root.Position - at).Magnitude
		if distance > TungVisit.SightLight + 2 then
			continue
		end
		local flat = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
		local sees = TungVisit.sees({
			hidden = PlayerStateService.isHidden(player),
			flashlight = player:GetAttribute(Tags.Attr.Flashlight) == true,
			speed = flat,
			distance = distance,
			clear = clearSight(at + Vector3.new(0, 6, 0), player),
			atCloset = atCloset,
			sinceSpawn = sinceSpawn,
		})
		if sees then
			table.insert(seen, player)
		end
	end
	return seen
end

local function stillValid(myToken: number): boolean
	return token == myToken and inChapterOne()
end

local function finish(myToken: number, phase: string)
	if token ~= myToken then
		return
	end
	CreatureService.visitHide()
	publish(phase)
	running = false
	task.delay(6, function()
		if token == myToken and not running then
			publish("")
		end
	end)
end

local function patrol(myToken: number, room: TungVisit.Room)
	local steps = TungVisit.route(room)
	local position = vec(steps[1].at)
	local look = vec(steps[2].at) - position
	CreatureService.visitShow(position, look)
	publish("patrol", nil, room)
	local spawnedAt = os.clock()
	local caught = false
	local last = os.clock()
	local function tick(atCloset: boolean): boolean
		local dt = os.clock() - last
		last = os.clock()
		if not stillValid(myToken) then
			return false
		end
		if not caught then
			local seen = seenPlayers(position, atCloset, os.clock() - spawnedAt)
			if #seen > 0 then
				caught = true
				publish("caught", nil, room)
				for _, player in seen do
					log.info("seen %s", player.Name)
					CreatureService.forceCapture(player)
				end
			end
		end
		return dt >= 0
	end
	for index = 2, #steps do
		local step = steps[index]
		local goal = vec(step.at)
		while (goal - position).Magnitude > 0.4 do
			local direction = (goal - position).Unit
			local stepLength = math.min(TungVisit.Speed * (RunService.Heartbeat:Wait()), (goal - position).Magnitude)
			position += direction * stepLength
			CreatureService.visitMove(position, direction)
			if not tick(false) then
				return finish(myToken, "gone")
			end
		end
		local pauseEnds = os.clock() + (if caught and step.pause < 2 then 2 else step.pause)
		while os.clock() < pauseEnds do
			if step.kind == "closet" then
				-- Olha para o armário (a frente dele é +Z; ele chega por +Z do cômodo e para diante da porta).
				CreatureService.visitMove(position, Vector3.new(-math.sign(position.X), 0, 0.2))
			end
			RunService.Heartbeat:Wait()
			if not tick(step.kind == "closet") then
				return finish(myToken, "gone")
			end
		end
		if caught and index < #steps then
			-- Depois de achar alguém ele não segue a ronda: fica um instante e some.
			task.wait(1.5)
			return finish(myToken, "gone")
		end
	end
	finish(myToken, "gone")
end

-- Começa a visita. Devolve false se já foi feita neste capítulo, se está em andamento ou se não é o cap. 1.
function TungVisitService.start(options: { early: boolean?, room: string? }?): boolean
	if running or done or not inChapterOne() then
		return false
	end
	local players = activePlayers()
	if #players == 0 then
		return false
	end
	running, done = true, true
	token += 1
	local myToken = token
	local positions: { TungVisit.Point } = {}
	for _, player in players do
		local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
		table.insert(positions, { x = root.Position.X, z = root.Position.Z })
	end
	local room: TungVisit.Room = (
		if options and options.room then options.room else TungVisit.pickRoom(positions, "Living")
	) :: any
	local warning = if options and options.early then TungVisit.EarlyWarningSeconds else TungVisit.WarningSeconds
	publish("warning", workspace:GetServerTimeNow() + warning, room)
	log.info("visit: warning %ds, room %s", warning, room)
	task.spawn(function()
		local endsAt = os.clock() + warning
		while os.clock() < endsAt do
			task.wait(0.25)
			if not stillValid(myToken) then
				return finish(myToken, "")
			end
		end
		-- A equipe pode ter mudado de cômodo durante o aviso: ele vai para onde a maioria está agora.
		local now: { TungVisit.Point } = {}
		for _, player in activePlayers() do
			local root = (player.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
			table.insert(now, { x = root.Position.X, z = root.Position.Z })
		end
		patrol(myToken, TungVisit.pickRoom(now, room))
	end)
	return true
end

function TungVisitService.reset()
	token += 1
	if running then
		CreatureService.visitHide()
	end
	running, done = false, false
	publish("")
end

function TungVisitService.Start()
	-- Ponte de depuração (só no Studio): o `execute_luau` do MCP roda em outra VM; ServerStorage.TungVisitBridge:Invoke().
	if RunService:IsStudio() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "TungVisitBridge"
		bridge.OnInvoke = function(options: any)
			return TungVisitService.start(options)
		end
		bridge.Parent = game:GetService("ServerStorage")
	end
	-- Gatilho padrão: 25 s depois da 2ª chave do cap. 1.
	Activities.onSolved(function(plan, index)
		if plan.stage ~= 1 or plan.mode ~= "Story" then
			return
		end
		if keysPlan ~= plan then
			keysPlan = plan
			keysSeen = 0
		end
		local spec = plan.activities[index]
		if spec and type(spec.item) == "string" and string.find(spec.item, "key_", 1, true) then
			keysSeen += 1
			if keysSeen == 2 then
				task.delay(25, function()
					TungVisitService.start()
				end)
			end
		end
	end)
	-- Capítulo novo ou partida reiniciada (fase Intro/Lobby): a visita vale de novo.
	task.spawn(function()
		local lastPhase: any = nil
		while true do
			task.wait(0.5)
			local state = campaign()
			local phase = if state then state:GetAttribute("Phase") else nil
			if phase ~= lastPhase then
				lastPhase = phase
				if phase == "Intro" or phase == "Lobby" then
					TungVisitService.reset()
				end
			end
			if running and not inChapterOne() then
				TungVisitService.reset()
			end
		end
	end)
end

return TungVisitService
