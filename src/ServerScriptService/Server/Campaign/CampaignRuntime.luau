--!strict
-- Runtime alternativo registrado pelo ponto de entrada RoundService: nunca roda junto com a rodada solo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local StarterPlayer = game:GetService("StarterPlayer")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local FireSpread = require("@game/ReplicatedStorage/Shared/Game/FireSpread")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local Modes = require("@game/ReplicatedStorage/Shared/Game/GameModes")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local Story = require("@game/ReplicatedStorage/Shared/Game/StoryCatalog")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local TaskRewards = require("@game/ReplicatedStorage/Shared/Game/TaskRewards")
local Preferences = require("@game/ReplicatedStorage/Shared/Game/HousePreferences")
local Guard = require("@game/ReplicatedStorage/Shared/Net/Guard")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local ServerNet = require("../Net/ServerNet")
local WorldService = require("../Services/WorldService")
local CreatureService = require("../Services/CreatureService")
local LightningService = require("../Services/LightningService")
local FireService = require("../Services/FireService")
local CollectibleService = require("../Services/CollectibleService")
-- Vantagens pagas (Claude): Segunda Chance, tempo de resgate e Continuação.
local PerkService = require("../Services/PerkService")
local StoreService = require("../Services/StoreService")
local Builder = require("./ActivityBuilder")
local Build = require("../World/Build")
local Session = require("./CoopSession")

local Endings = require("./Endings")
local PlayerData = require("../Services/PlayerDataService")

local C = Config.Campaign
local log = Logger.new("Campaign")
local session = Session.new(1, C, nil, true)
local taskPayments: TaskRewards.Ledger = {}
local pendingTaskPayments: { [string]: { [number]: boolean } } = {}
local rewardCampaign = 0
local replicated: Configuration? = nil
local built: Builder.Built? = nil
local version = 0
local startedAt = 0
local nextStageAt = 0
local nextThreatAt = 0
local blackoutUntil = 0
local building = false
local escapeEndsAt = 0
local lostRetryAt = 0
local lobbyReturnAt = 0
local tutorialHeld: { [number]: number } = {}
local supplies: { [number]: { [string]: number } } = {}
-- Sem kit inicial: a mochila só tem o que o jogador coletar na casa (pedido do humano).
local function starterSupplies(): { [string]: number }
	return { battery = 0, oxygen = 0, decoy = 0 }
end
local endingPaid: { [number]: boolean } = {}
local endingShown = false
local spawning: { [Player]: boolean } = {}
local spawnedVersion: { [Player]: number } = {}
local spawnSlots: { [number]: number } = {}
local playerAdapter: any = nil
local channels: { [number]: { target: number, endsAt: number } } = {}
local nextActionAt: { [number]: number } = {}
local rescueParts: { [number]: BasePart } = {}
-- Quem já levou a primeira pancada neste capítulo (versão da etapa): a próxima é captura de verdade.
local wounded: { [number]: number } = {}
local modeVotes: Modes.Votes = {}
local selectedMode: Modes.Id? = nil
local sceneSerial = 0
local sceneStartedAt = 0
local sceneEndsAt = 0
local qaMode: Modes.Id? = nil
if RunService:IsStudio() then
	local ok, args = pcall(function()
		return game:GetService("StudioTestService"):GetTestArgs()
	end)
	if ok and type(args) == "table" and args.campaignQA and not args.modeMenuQA then
		qaMode = if args.storyQA then "Story" else "Standard"
	end
end

local Runtime = { Name = "RoundService" }

local function slotFor(id: number): number
	if spawnSlots[id] then
		return spawnSlots[id]
	end
	local used: { [number]: boolean } = {}
	for _, slot in spawnSlots do
		used[slot] = true
	end
	for slot = 1, C.maxPlayers do
		if not used[slot] then
			spawnSlots[id] = slot
			return slot
		end
	end
	error("[Campaign] no spawn slot available")
end

local function parts(player: Player): (Model?, BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character,
		if root and root:IsA("BasePart") then root else nil,
		character and character:FindFirstChildOfClass("Humanoid")
end

local function feedback(player: Player, message: string)
	player:SetAttribute("CampaignFeedback", message)
	local serial = player:GetAttribute("CampaignFeedbackSerial")
	player:SetAttribute("CampaignFeedbackSerial", (if type(serial) == "number" then serial else 0) + 1)
end

local function freeze(player: Player, value: boolean)
	local _, root, humanoid = parts(player)
	-- Derrubado pelo Tung Tung no meio do capítulo: não fica travado, rasteja devagar até alguém resgatar.
	local member = session.members[player.UserId]
	local crawling = value
		and member ~= nil
		and member.status == "Downed"
		and (session.phase == "Playing" or session.phase == "Extracting")
	if root then
		root.Anchored = value and not crawling
	end
	if humanoid and crawling then
		humanoid.WalkSpeed, humanoid.JumpHeight = C.CrawlSpeed, 0
	end
	player:SetAttribute("Crawling", crawling)
end

local function publish()
	if not replicated then
		return
	end
	if session.phase == "Won" and lobbyReturnAt == 0 then
		lobbyReturnAt = workspace:GetServerTimeNow() + C.EndingSeconds
	end
	replicated:SetAttribute("LobbyReturnAt", lobbyReturnAt)
	local roster = {}
	for _, player in Players:GetPlayers() do
		local member = session.members[player.UserId]
		if member then
			player:SetAttribute("CampaignStatus", member.status)
			player:SetAttribute("CampaignRole", member.role)
			table.insert(roster, {
				id = member.id,
				name = player.DisplayName,
				role = member.role,
				status = member.status,
				contributions = member.contributions,
				downedUntil = member.downedUntil,
				deathCause = player:GetAttribute("DeathCause"),
			})
		end
	end
	table.sort(roster, function(a, b)
		return a.id < b.id
	end)
	local tasks = {}
	local plan = session.plan
	if plan then
		for _, spec in plan.activities do
			local state = session.tasks[spec.id]
			table.insert(tasks, {
				id = spec.id,
				room = spec.room,
				kind = spec.kind,
				title = spec.title,
				solved = state.solved,
				progress = state.progress,
				required = #spec.order,
				available = Session.taskReady(session, spec.id),
				relayUntil = state.relayUntil,
			})
		end
	end
	replicated:SetAttribute("Roster", HttpService:JSONEncode(roster))
	replicated:SetAttribute("Tasks", HttpService:JSONEncode(tasks))
	replicated:SetAttribute("Inventory", HttpService:JSONEncode(session.inventory))
	replicated:SetAttribute("EscapeEndsAt", escapeEndsAt)
	replicated:SetAttribute("Stage", session.stage)
	replicated:SetAttribute("ForestActive", session.stage >= 6)
	replicated:SetAttribute("Seed", session.seed)
	replicated:SetAttribute("Title", if plan then plan.title else "REUNINDO A EQUIPE")
	replicated:SetAttribute("Threat", if plan then Catalog.Threats[plan.threat].title else "")
	replicated:SetAttribute("Solved", Session.solvedCount(session))
	replicated:SetAttribute("Total", if plan then #plan.activities else 0)
	replicated:SetAttribute("NextStageAt", nextStageAt)
	replicated:SetAttribute("Phase", session.phase)
	local _, standardVotes, storyVotes = Modes.winner(modeVotes, session.members, C.minPlayers)
	replicated:SetAttribute("GameMode", selectedMode or "")
	replicated:SetAttribute("StandardVotes", standardVotes)
	replicated:SetAttribute("StoryVotes", storyVotes)
	replicated:SetAttribute("Players", Session.count(session))
	replicated:SetAttribute("Building", building)
	replicated:SetAttribute("StorySceneSerial", sceneSerial)
	replicated:SetAttribute("StorySceneStartedAt", sceneStartedAt)
	replicated:SetAttribute("StorySceneEndsAt", sceneEndsAt)
	local phase = if building
		then "Intro"
		elseif session.phase == "Won" then "Won"
		elseif session.phase == "Lost" then "Lost"
		elseif session.phase == "Playing" or session.phase == "Extracting" then "Playing"
		else "Intro"
	GameState.set("RoundStartedAt", startedAt)
	if phase == "Won" or phase == "Lost" then
		GameState.set("RoundEndedAt", workspace:GetServerTimeNow())
	end
	GameState.set("Phase", phase)
	GameState.set("PowerOn", WorldService.isPowered())
	GameState.set("CreatureActive", CreatureService.isActive())
	if built and session.plan then
		Builder.refresh(built, session.tasks)
	end
end

local function clearRescues()
	for _, part in rescueParts do
		part:Destroy()
	end
	rescueParts, channels = {}, {}
end

local function spawnMember(player: Player)
	if not player.Parent or not session.members[player.UserId] then
		return
	end
	-- Pedidos de join/restart podem ficar enfileirados enquanto o avatar carrega.
	-- Um personagem pronto para esta versão já satisfaz todos esses pedidos.
	local existing = player.Character
	local existingHumanoid = existing and existing:FindFirstChildOfClass("Humanoid")
	if spawnedVersion[player] == version and existingHumanoid and existingHumanoid.Health > 0 then
		return
	end
	if spawning[player] then
		task.delay(0.2, spawnMember, player)
		return
	end
	spawning[player] = true
	local thisVersion = version
	local ok, reason = pcall(function(): any
		player:LoadCharacterAsync()
		if not player.Parent or not session.members[player.UserId] then
			return nil
		end
		-- O avatar recém-carregado serve ao capítulo vigente, mesmo se ele mudou durante o yield.
		thisVersion = version
		local character = player.Character
		assert(character, "[Campaign] character missing after load")
		local root = character:WaitForChild("HumanoidRootPart", C.SpawnTimeout)
		local humanoid = character:WaitForChild("Humanoid", C.SpawnTimeout)
		assert(
			root and root:IsA("BasePart") and humanoid and humanoid:IsA("Humanoid"),
			"[Campaign] character parts missing"
		)
		if not player.Parent or not session.members[player.UserId] then
			return nil
		end
		thisVersion = version
		root.Anchored = true
		if character then
			local index = slotFor(player.UserId)
			local offset = Vector3.new(((index - 1) % 4) * 4 - 6, 0, math.floor((index - 1) / 4) * 4)
			local member = session.members[player.UserId]
			if member and member.status == "Waiting" then
				offset += Vector3.new(-28, 0, -8)
			end
			character:PivotTo(WorldService.spawnCFrame() + offset)
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		end
		if humanoid then
			humanoid.WalkSpeed, humanoid.UseJumpPower, humanoid.JumpHeight =
				Config.Player.WalkSpeed, false, Config.Player.JumpHeight
			humanoid.Died:Connect(function()
				if thisVersion == version then
					local member = session.members[player.UserId]
					if member and member.status == "Active" then
						local id = playerAdapter and playerAdapter.hiddenId(player)
						local locker = id and WorldService.locker(id)
						if locker then
							locker.occupant = nil
						end
						if playerAdapter then
							playerAdapter.exitHide(player)
						end
						Session.eliminate(session, player.UserId)
						publish()
					end
				end
			end)
		end
		player:SetAttribute("HasFlashlight", session.inventory.flashlight == 1)
		player:SetAttribute("DeathCause", "")
		player:SetAttribute(Tags.Attr.Flashlight, session.inventory.flashlight == 1)
		if playerAdapter then
			playerAdapter.resetForSpawn(player)
		end
		player:SetAttribute("CampaignGraceUntil", workspace:GetServerTimeNow() + C.SpawnGrace)
		local member = session.members[player.UserId]
		freeze(player, building or not member or member.status ~= "Active")
		spawnedVersion[player] = thisVersion
		return nil
	end)
	spawning[player] = nil
	if not ok then
		log.error("spawn failed for %s: %s", player.Name, tostring(reason))
	end
end

local function stage()
	if building then
		return
	end
	local ok, reason = Session.beginStage(session)
	if not ok then
		if reason ~= "need_players" then
			log.warn("stage refused: %s", reason or "?")
		end
		return
	end
	building = true
	version += 1
	for _, player in Players:GetPlayers() do
		freeze(player, true)
	end
	channels, nextActionAt, tutorialHeld = {}, {}, {}
	escapeEndsAt, lostRetryAt, lobbyReturnAt = 0, 0, 0
	clearRescues()
	CreatureService.reset()
	local plan = session.plan
	assert(plan, "[Campaign] missing stage plan")
	WorldService.resetRound(
		Random.new(if selectedMode == "Story" then Story.MapSeed else session.seed + session.stage),
		plan.sector
	)
	WorldService.setHouseStage(session.stage, session.seed, selectedMode)
	local world = WorldService.get()
	-- As trancas da missão solo não podem invalidar o grafo da campanha.
	local worldAdapter: any = WorldService
	if type(worldAdapter.doorSnapshot) == "function" and type(worldAdapter.applyDoors) == "function" then
		local states = worldAdapter.doorSnapshot()
		worldAdapter.applyDoors(states, {})
	end
	for _, focus in CollectionService:GetTagged(Tags.Interactable) do
		if focus:IsDescendantOf(world.root) then
			focus:SetAttribute(Tags.Attr.InteractEnabled, false)
		end
	end
	for id in world.interactables do
		WorldService.setInteractEnabled(id, world.interactables[id].kind == "Door")
	end
	-- Esconderijos usam a mesma seleção de alvo do jogador; precisam ser reativados após o reset.
	for _, locker in WorldService.features().lockers do
		WorldService.setInteractEnabled(locker.id, true)
	end
	built = Builder.build(world.root, plan, Config.Game.InteractDistance)
	WorldService.setPower(session.stage >= 3 and session.stage < 6)
	startedAt = if session.stage == 1 then workspace:GetServerTimeNow() else startedAt
	nextStageAt, nextThreatAt, blackoutUntil = 0, workspace:GetServerTimeNow() + C.ThreatInterval, 0
	for _, player in Players:GetPlayers() do
		freeze(player, true)
		task.spawn(spawnMember, player)
	end
	local thisVersion = version
	task.delay(if selectedMode == "Story" then 0 else C.StageIntroSeconds, function()
		if thisVersion ~= version then
			return
		end
		local deadline = os.clock() + C.SpawnTimeout
		local function everyoneReady(): boolean
			for _, player in Players:GetPlayers() do
				local member = session.members[player.UserId]
				if member and member.status == "Active" and spawnedVersion[player] ~= thisVersion then
					return false
				end
			end
			return true
		end
		while thisVersion == version and not everyoneReady() and os.clock() < deadline do
			task.wait(0.1)
		end
		if thisVersion ~= version then
			return
		end
		for _, player in Players:GetPlayers() do
			local member = session.members[player.UserId]
			if member and member.status == "Active" and spawnedVersion[player] ~= thisVersion then
				member.status = "Waiting"
				feedback(player, "spawn_failed")
				log.warn("spawn timed out for %s", player.Name)
			end
		end
		if selectedMode == "Story" then
			sceneSerial += 1
			sceneStartedAt = workspace:GetServerTimeNow()
			sceneEndsAt = sceneStartedAt + Story.SceneSeconds
			publish()
			task.wait(Story.SceneSeconds)
			if thisVersion ~= version then
				return
			end
		end
		building = false
		for _, player in Players:GetPlayers() do
			local member = session.members[player.UserId]
			freeze(player, not member or member.status ~= "Active")
		end
		if session.stage >= 3 then
			CreatureService.activate(nil)
		end
		CreatureService.setHunt(false)
		publish()
	end)
	publish()
	log.info("stage=%d seed=%d players=%d tasks=%d", session.stage, session.seed, plan.players, #plan.activities)
end

local function hasSight(player: Player, focus: BasePart, range: number): boolean
	local character, root, humanoid = parts(player)
	if not character or not root or not humanoid or humanoid.Health <= 0 or not focus.Parent then
		return false
	end
	if (root.Position - focus.Position).Magnitude > range then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	local head = character:FindFirstChild("Head")
	local origin = if head and head:IsA("BasePart") then head.Position else root.Position + Vector3.yAxis * 1.5
	local hit = workspace:Raycast(origin, focus.Position - origin, params)
	return hit == nil or hit.Instance == focus or (hit.Position - focus.Position).Magnitude < 1.5
end

-- Consumível Segunda Chance (PerkService): levanta sem ajudante, com a mesma carência do resgate.
local function selfRevive(player: Player, expectedVersion: number, message: string?)
	if expectedVersion ~= version or not player.Parent then
		return
	end
	local now = workspace:GetServerTimeNow()
	if not Session.selfRevive(session, player.UserId, now) then
		return
	end
	player:SetAttribute("CampaignGraceUntil", now + C.ReviveGrace)
	freeze(player, false)
	local beacon = rescueParts[player.UserId]
	if beacon then
		beacon:Destroy()
		rescueParts[player.UserId] = nil
	end
	for helperId, channel in channels do
		if channel.target == player.UserId then
			channels[helperId] = nil
		end
	end
	feedback(player, message or "second_chance")
	publish()
end

local function capture(player: Player, cause: string?)
	if playerAdapter then
		local id = playerAdapter.hiddenId(player)
		local locker = id and WorldService.locker(id)
		if locker then
			locker.occupant = nil
		end
		playerAdapter.exitHide(player)
	end
	local now = workspace:GetServerTimeNow()
	local member = session.members[player.UserId]
	if not member or member.status ~= "Active" or (session.phase ~= "Playing" and session.phase ~= "Extracting") then
		return
	end
	local captureVersion = version
	-- Primeira pancada do Tung Tung no capítulo: cai e rasteja por CrawlSeconds e levanta sozinho (colegas podem
	-- resgatar antes). A segunda pancada no mesmo capítulo é captura de verdade. Raio e fogo não dão essa chance.
	local wound = cause ~= "lightning" and cause ~= "fire" and wounded[player.UserId] ~= captureVersion
	local rising = false
	if wound then
		wounded[player.UserId] = captureVersion
		task.delay(C.CrawlSeconds, function()
			selfRevive(player, captureVersion, "crawl_up")
		end)
	else
		-- Segunda Chance no kit (PerkService): gasta agora e agenda o levantar; a derrota espera a janela.
		rising = PerkService.secondChance(player, function()
			selfRevive(player, captureVersion)
		end)
	end
	local delay = if wound then C.CrawlSeconds + 2 elseif rising then Perks.SECOND_CHANCE_DELAY + 2 else nil
	if not Session.capture(session, player.UserId, now, delay) then
		return
	end
	if wound then
		feedback(player, "crawl_start")
	end
	freeze(player, true)
	local _, root = parts(player)
	if root then
		local beacon = Build.part(
			WorldService.get().root,
			`Rescue_{player.UserId}`,
			Vector3.new(1, 1, 1),
			CFrame.new(root.Position + Vector3.new(0, 3.3, 0)),
			Color3.fromRGB(90, 220, 160),
			{ transparency = 0.4, collide = false }
		)
		beacon:SetAttribute(Tags.Attr.InteractId, `rescue_{player.UserId}`)
		beacon:SetAttribute(Tags.Attr.InteractPrompt, `RESGATAR {player.DisplayName}`)
		beacon:SetAttribute(Tags.Attr.InteractDistance, Config.Game.InteractDistance)
		beacon:SetAttribute(Tags.Attr.InteractEnabled, true)
		CollectionService:AddTag(beacon, Tags.Interactable)
		rescueParts[player.UserId] = beacon
		-- Rastejando: o ponto de resgate acompanha o corpo.
		task.spawn(function()
			while beacon.Parent and rescueParts[player.UserId] == beacon do
				local _, current = parts(player)
				if current then
					beacon.Position = current.Position + Vector3.new(0, 1.2, 0)
				end
				task.wait(0.15)
			end
		end)
	end
	publish()
	-- O cérebro legado termina em Capture; recolocar o Vigia permite continuar caçando a equipe.
	local thisVersion = version
	task.delay(C.CaptureRecovery, function()
		if
			cause ~= "lightning"
			and cause ~= "fire"
			and thisVersion == version
			and (session.phase == "Playing" or session.phase == "Extracting")
		then
			CreatureService.reset()
			CreatureService.activate(nil)
			CreatureService.setFuses(math.min(2, session.stage - 1))
			CreatureService.setHunt(false)
		end
	end)
end

local function payCompletedTasks()
	for key, recipients in pendingTaskPayments do
		for id, contributed in recipients do
			local player = Players:GetPlayerByUserId(id)
			if not player then
				recipients[id] = nil
			elseif player:GetAttribute("StoreReady") == true then
				if
					TaskRewards.claim(taskPayments, key, id, function()
						return StoreService.awardTask(player, contributed) ~= nil
					end)
				then
					recipients[id] = nil
				end
			end
		end
		if next(recipients) == nil then
			pendingTaskPayments[key] = nil
		end
	end
end

local function afterActivity(previous: Session.Phase)
	if session.phase ~= previous then
		if session.phase == "Intermission" then
			nextStageAt = workspace:GetServerTimeNow() + C.IntermissionSeconds
			CreatureService.freeze()
			for _, player in Players:GetPlayers() do
				freeze(player, true)
			end
		elseif session.phase == "Extracting" then
			escapeEndsAt = workspace:GetServerTimeNow() + Config.House.EscapeSeconds
			WorldService.setHouseDestruction(session.stage == 5)
			-- Capítulo 5: a gasolina que o time espalhou vira os primeiros focos (FireSpread).
			local fuel: { { number } } = {}
			if session.plan then
				for _, spec in session.plan.activities do
					if spec.item == "gas_pour" or spec.item == "gas_ignite" then
						table.insert(fuel, { spec.x, spec.y or 0, spec.z })
					end
				end
			end
			WorldService.setHouseFire(session.stage == 5, FireSpread.encodeFuel(fuel))
			CreatureService.makeNoise(
				if session.stage >= 6 then Vector3.new(0, 0, 850) else Vector3.new(26, -16, -68),
				500
			)
			CreatureService.setFrozen(false)
			if session.stage == 5 then
				-- O estouro da gasolina assusta o Tung Tung: ele recua das chamas por uns segundos e dá a largada
				-- para quem acendeu (antes ele era chamado para o mecanismo e derrubava na hora quem estava ali).
				CreatureService.holdOff(FireSpread.HeadStart + 2)
			end
			WorldService.setPower(false)
			WorldService.openGate()
		end
	end
	publish()
end

local function interact(player: Player, id: string, _action: string?): { accepted: boolean, message: string }
	-- Fita VHS colecionável (Claude, monetização/progressão): mesma validação nos dois modos.
	if id == CollectibleService.TAPE_ID then
		return CollectibleService.collect(player)
	end
	local member = session.members[player.UserId]
	local now = workspace:GetServerTimeNow()
	local function response(ok: boolean, message: string)
		player:SetAttribute("CampaignAccepted", ok)
		feedback(player, message)
		return { accepted = ok, message = message }
	end
	if building or not member or member.status ~= "Active" then
		return response(false, "not_active")
	end
	if session.phase ~= "Playing" and session.phase ~= "Extracting" then
		return response(false, "not_playing")
	end
	if now < (nextActionAt[player.UserId] or 0) then
		return response(false, "wait")
	end
	local station = built and built.targets[id]
	local targetId = tonumber(string.match(id, "^rescue_([%-]?%d+)$"))
	local focus = if station then station.focus elseif targetId then rescueParts[targetId] else nil
	if focus then
		if not hasSight(player, focus, Config.Game.InteractDistance + Config.Game.InteractTolerance) then
			return response(false, "too_far")
		end
		nextActionAt[player.UserId] = now + C.ActionCooldown
		if targetId then
			local target = session.members[targetId]
			if not target or target.status ~= "Downed" then
				return response(false, "not_available")
			end
			if channels[player.UserId] then
				return response(false, "rescuing")
			end
			channels[player.UserId] = {
				target = targetId,
				-- Melhoria "Mãos de Socorrista" (nível publicado pelo StoreService) encurta o resgate.
				endsAt = now
					+ (if member.role == "medic" then C.MedicReviveSeconds else C.ReviveSeconds)
						* Perks.factor("socorro", tonumber(player:GetAttribute("PerkSocorro")) or 0),
			}
			return response(true, "rescuing")
		end
		assert(station, "[Campaign] missing activity target")
		local spec = session.tasks[station.taskId].spec
		if spec.kind == "explore" or spec.kind == "hide" or spec.kind == "breath" then
			return response(false, "not_available")
		end
		local previous: Session.Phase = session.phase
		local ok, message = Session.act(session, player.UserId, station.taskId, station.button, now)
		if message == "wrong_sequence" then
			CreatureService.makeNoise(focus.Position, 45)
		end
		if ok then
			-- Gasolina espalhada faz barulho (galão batendo, líquido): o Tung Tung vem ver.
			CreatureService.makeNoise(focus.Position, if spec.item == "gas_pour" then 60 else 22)
		end
		if ok and message == "solved" then
			WorldService.houseEvent(spec.event)
			if spec.event == "silhouette" then
				CreatureService.silhouette()
				WorldService.upperNoise()
			end
			if spec.item == "flashlight" and playerAdapter then
				for _, teammate in Players:GetPlayers() do
					playerAdapter.grantFlashlight(teammate)
				end
			end
			if spec.kind == "clue" then
				local clue = station.focus.Parent and station.focus.Parent:FindFirstChild("Clue")
				local text = clue and clue:FindFirstChildWhichIsA("TextLabel", true)
				if text and replicated then
					replicated:SetAttribute("LastClue", text.Text)
				end
			end
			local activity = session.tasks[station.taskId]
			local key = `{rewardCampaign}:{session.stage}:{station.taskId}`
			local recipients: { [number]: boolean } = {}
			for _, teammate in Players:GetPlayers() do
				local participant = session.members[teammate.UserId]
				if
					participant
					and (
						participant.status == "Active"
						or participant.status == "Downed"
						or activity.contributors[teammate.UserId]
					)
				then
					if not (taskPayments[key] and taskPayments[key][teammate.UserId]) then
						recipients[teammate.UserId] = activity.contributors[teammate.UserId] == true
					end
				end
			end
			-- Dados ainda carregando? A fila paga assim que o perfil estiver pronto, inclusive após a etapa.
			local pending = pendingTaskPayments[key] or {}
			for recipientId, contributed in recipients do
				pending[recipientId] = pending[recipientId] == true or contributed
			end
			pendingTaskPayments[key] = pending
			payCompletedTasks()
		end
		afterActivity(previous)
		return response(ok, message)
	end
	if playerAdapter then
		local currentHide = playerAdapter.hiddenId(player)
		if currentHide then
			if currentHide ~= id then
				return response(false, "not_available")
			end
			local locker = WorldService.locker(currentHide)
			playerAdapter.exitHide(player)
			if locker then
				locker.occupant = nil
			end
			return response(true, "hide_exit")
		end
		local locker = WorldService.locker(id)
		if locker then
			if locker.occupant and locker.occupant ~= player then
				return response(false, "occupied")
			end
			if
				not hasSight(player, locker.door, 10.5)
				or playerAdapter.sinceExit(player) < Config.Hide.ExitCooldown
			then
				return response(false, "too_far")
			end
			local seen = CreatureService.sawEntry(player)
			if playerAdapter.enterHide(player, id, locker.inside, locker.eye, locker.exit, locker.front, seen) then
				locker.occupant = player
				return response(true, "hide_enter")
			end
		end
	end
	local item = WorldService.interactable(id)
	if
		item
		and item.kind == "Door"
		and hasSight(player, item.focus, Config.Game.InteractDistance + Config.Game.InteractTolerance)
	then
		nextActionAt[player.UserId] = now + C.ActionCooldown
		local door = WorldService.door(id)
		if door then
			WorldService.useDoor(id)
			CreatureService.makeNoise(door.center, 30)
			return response(true, "door_opened")
		end
	end
	return response(false, "not_available")
end

-- Consumível Continuação (StoreService "use_continue"): depois da derrota, a equipe repete a etapa.
local function retryStage(player: Player): (boolean, string?)
	if building or not session.members[player.UserId] then
		return false, "not_member"
	end
	local ok, reason = Session.retryStage(session)
	if not ok then
		return false, reason
	end
	version += 1
	clearRescues()
	CreatureService.reset()
	-- O checkpoint mantém a identidade da campanha: não repete pagamentos por derrota.
	GameState.set("RoundEndedAt", 0)
	nextStageAt = workspace:GetServerTimeNow() + C.IntermissionSeconds
	for _, other in Players:GetPlayers() do
		feedback(other, "checkpoint_restored")
	end
	publish()
	log.info("%s used a continue: stage %d again", player.Name, session.stage + 1)
	return true, nil
end

local function restartCampaign()
	if built then
		built.root:Destroy()
		built = nil
	end
	rewardCampaign += 1
	taskPayments, supplies, endingPaid = {}, {}, {}
	endingShown = false
	escapeEndsAt, lostRetryAt, lobbyReturnAt = 0, 0, 0
	version += 1
	building = false
	clearRescues()
	CreatureService.reset()
	selectedMode, modeVotes = qaMode, {}
	sceneStartedAt, sceneEndsAt = 0, 0
	local seed = if selectedMode == "Story"
		then Story.MapSeed
		else C.Seed or ((os.time() + version * 7919) % 2147483646)
	session = Session.new(seed, C, selectedMode, true)
	spawnSlots = {}
	for _, player in Players:GetPlayers() do
		Session.join(session, player.UserId)
		player:SetAttribute("GameModeVote", "")
		supplies[player.UserId] = starterSupplies()
		slotFor(player.UserId)
		player:SetAttribute("HasFlashlight", false)
		player:SetAttribute(Tags.Attr.Flashlight, false)
		if playerAdapter then
			playerAdapter.resetForSpawn(player)
		end
		local character, root = parts(player)
		if character and root then
			-- O lobby usa as câmeras da casa; reúne os avatares no pátio de entrada.
			character:PivotTo(CFrame.new((slotFor(player.UserId) - 1) * 4 - 10, 3, 77))
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			if playerAdapter then
				playerAdapter.markTeleported(player)
			end
		end
		freeze(player, true)
	end
	WorldService.setHouseStage(1, seed, "Story")
	nextStageAt, startedAt = 0, 0
	GameState.set("RoundId", version)
	GameState.set("RoundEndedAt", 0)
	if replicated then
		replicated:SetAttribute("Ending", "")
		replicated:SetAttribute("LastClue", "")
	end
	publish()
end

local function tick()
	payCompletedTasks()
	local now = workspace:GetServerTimeNow()
	local before = session.phase .. ":" .. Session.count(session, "Downed")
	local relayExpired = false
	for _, activity in session.tasks do
		if not activity.solved and activity.relayBy and now >= activity.relayUntil then
			relayExpired = true
		end
	end
	Session.tick(session, now)
	for helperId, channel in channels do
		local helper = Players:GetPlayerByUserId(helperId)
		local target = Players:GetPlayerByUserId(channel.target)
		local beacon = rescueParts[channel.target]
		local member = session.members[helperId]
		if
			not helper
			or not target
			or not beacon
			or not member
			or member.status ~= "Active"
			or not hasSight(helper, beacon, Config.Game.InteractDistance)
		then
			channels[helperId] = nil
			if helper then
				feedback(helper, "rescue_cancelled")
			end
		elseif now >= channel.endsAt then
			channels[helperId] = nil
			if Session.revive(session, helperId, channel.target, now) then
				target:SetAttribute("CampaignGraceUntil", now + C.ReviveGrace)
				freeze(target, false)
				beacon:Destroy()
				rescueParts[channel.target] = nil
				feedback(helper, "rescued")
				publish()
			end
		end
	end
	for id, beacon in rescueParts do
		local member = session.members[id]
		if not member or member.status ~= "Downed" then
			beacon:Destroy()
			rescueParts[id] = nil
		end
	end
	if session.phase == "Lobby" then
		local winner: Modes.Id? = qaMode or (Modes.winner(modeVotes, session.members, C.minPlayers))
		if Session.count(session) >= C.minPlayers and winner then
			if selectedMode ~= winner then
				selectedMode = winner
				session.mode = winner
				session.seed = if winner == "Story"
					then Story.MapSeed
					else C.Seed or ((os.time() + version * 7919) % 2147483646)
				nextStageAt = 0
			end
			if nextStageAt == 0 then
				nextStageAt = now + C.LobbySeconds
				publish()
			end
			if now >= nextStageAt then
				stage()
			end
		elseif nextStageAt ~= 0 then
			nextStageAt = 0
			selectedMode = nil
			publish()
		end
	elseif session.phase == "Intermission" then
		if now >= nextStageAt then
			stage()
		end
	elseif session.phase == "Extracting" then
		for _, player in Players:GetPlayers() do
			local _, root = parts(player)
			if root and WorldService.isInExitZone(root.Position) and Session.escape(session, player.UserId) then
				freeze(player, true)
				publish()
			end
		end
	end
	if session.phase == "Playing" and not building and session.plan then
		for _, spec in session.plan.activities do
			if session.tasks[spec.id].solved then
				continue
			end
			for _, player in Players:GetPlayers() do
				local member = session.members[player.UserId]
				local _, root = parts(player)
				if not member or member.status ~= "Active" or not root then
					continue
				end
				local hidden = playerAdapter and playerAdapter.hiddenId(player)
				local complete = spec.kind == "explore"
					and (root.Position - Vector3.new(spec.x, spec.y or 0, spec.z)).Magnitude < 9
				if not Session.taskReady(session, spec.id) then
					continue
				end
				if spec.kind == "hide" then
					complete = if session.stage >= 6
						then hidden ~= nil and string.sub(hidden, 1, 12) == "hide_Forest_"
						else hidden == "hide_Library"
				end
				if spec.kind == "breath" then
					local inHide = if session.stage >= 6
						then hidden ~= nil and string.sub(hidden, 1, 12) == "hide_Forest_"
						else hidden == "hide_Library"
					if inHide and player:GetAttribute("HoldBreath") == true then
						tutorialHeld[player.UserId] = (tutorialHeld[player.UserId] or 0) + 0.2
						complete = tutorialHeld[player.UserId] >= 2
					else
						tutorialHeld[player.UserId] = 0
					end
				end
				if complete then
					local previous: Session.Phase = session.phase
					Session.act(session, player.UserId, spec.id, 1, now)
					WorldService.houseEvent(spec.event)
					if spec.event == "awaken" then
						CreatureService.activate(Vector3.new(0, 0, -68))
						CreatureService.holdOff(10)
					end
					afterActivity(previous)
					break
				end
			end
			break
		end
	end
	if session.phase == "Playing" and not building then
		WorldService.forestPressure(now, true)
		if built then
			Builder.refresh(built, session.tasks, now, Session.count(session, "Active"))
		end
		if blackoutUntil > 0 and now >= blackoutUntil then
			WorldService.setPower(session.stage < 6)
			blackoutUntil = 0
			publish()
		end
		if now >= nextThreatAt then
			nextThreatAt = now + C.ThreatInterval
			if session.stage == 2 then
				local plan = session.plan
				if plan then
					local point = plan.activities[(math.floor(now) % #plan.activities) + 1]
					CreatureService.makeNoise(Vector3.new(point.x, 0, point.z), 100)
				end
			elseif session.stage >= 3 then
				WorldService.setPower(false)
				blackoutUntil = now + C.BlackoutSeconds
				publish()
			end
		end
	end
	if session.phase == "Extracting" and escapeEndsAt > 0 and now >= escapeEndsAt then
		for _, member in session.members do
			if member.status == "Active" or member.status == "Downed" then
				member.status, member.risingUntil = "Waiting", nil
			end
		end
		Session.tick(session, now)
		publish()
	end
	if session.phase == "Lost" and not building then
		if lostRetryAt == 0 then
			lostRetryAt = now + C.IntermissionSeconds
		end
		if now >= lostRetryAt then
			retryStage(Players:GetPlayers()[1])
			lostRetryAt = 0
		end
	end
	if
		session.phase == "Won"
		and Endings.resolve(Session.count(session, "Escaped"), math.min(now, escapeEndsAt), escapeEndsAt, session.stage)
	then
		if not endingShown then
			endingShown = true
			if session.stage < 6 then
				WorldService.houseRuins()
			end
			if session.stage >= 6 then
				CreatureService.freeze()
			else
				CreatureService.endingPose()
			end
		end
		if replicated then
			replicated:SetAttribute("Ending", if session.stage >= 6 then "forest_rescue" else "house_fire")
		end
		for _, player in Players:GetPlayers() do
			if
				not endingPaid[player.UserId]
				and session.members[player.UserId]
				and session.members[player.UserId].status == "Escaped"
			then
				endingPaid[player.UserId] = PlayerData.update(player, function(data)
					data.house.endings[if session.stage >= 6 then "forest_rescue" else "house_fire"] = os.time()
					data.house.achievements.escaped = os.time()
				end)
			end
		end
	end
	if before:sub(1, 10) == "Extracting" and session.phase == "Intermission" then
		nextStageAt = now + C.IntermissionSeconds
		escapeEndsAt = 0
		CreatureService.freeze()
		publish()
	end
	if session.phase == "Won" or session.phase == "Lost" then
		CreatureService.freeze()
		for _, player in Players:GetPlayers() do
			freeze(player, true)
		end
	end
	if session.phase == "Won" and lobbyReturnAt > 0 and now >= lobbyReturnAt then
		restartCampaign()
		return
	end
	if relayExpired or before ~= session.phase .. ":" .. Session.count(session, "Downed") then
		publish()
	end
end

function Runtime.Init()
	Players.CharacterAutoLoads = false
	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	StarterPlayer.CameraMaxZoomDistance = 0.5
	StarterPlayer.CameraMinZoomDistance = 0.5
	local gameState = GameState.serverCreate()
	gameState:SetAttribute("CampaignActive", true)
	local state = Instance.new("Configuration")
	state.Name = "CampaignState"
	state.Parent = ReplicatedStorage
	replicated = state
	if not PhysicsService:IsCollisionGroupRegistered("CampaignPlayers") then
		PhysicsService:RegisterCollisionGroup("CampaignPlayers")
	end
	PhysicsService:CollisionGroupSetCollidable("CampaignPlayers", "CampaignPlayers", false)
	CreatureService.onCapture(capture)
	-- Raio ao ar livre derruba pelo mesmo caminho da captura (resgate, segunda chance).
	LightningService.onStrike(function(player)
		capture(player, "lightning")
	end)
	-- Incêndio da fuga final: ficar no fogo derruba pelo mesmo caminho (resgate, segunda chance).
	FireService.onBurn(function(player)
		capture(player, "fire")
	end)
	restartCampaign()
end

function Runtime.Start()
	ServerNet.onEvent("SetHousePreference", {
		args = {
			Guard.literal(
				"bob",
				"tilt",
				"shake",
				"fov",
				"flashes",
				"retro",
				"vhs",
				"haptics",
				"master",
				"music",
				"effects",
				"breathing",
				"ambient",
				"shaders",
				"quality"
			),
			Guard.number({ min = 0, max = 1 }),
		},
		rateLimit = { capacity = 12, refillPerSecond = 4 },
	}, function(player: Player, key: string, value: number)
		if not Preferences.valid(key, value) then
			return
		end
		if PlayerData.update(player, function(data)
			data.house.preferences[key] = value
		end) then
			local data = PlayerData.get(player)
			if data then
				player:SetAttribute("HousePreferences", HttpService:JSONEncode(data.house.preferences))
			end
		end
	end)

	if playerAdapter then
		playerAdapter.setNoiseHandler(CreatureService.makeNoise)
		-- Sem ar no armário: libera o armário e a porta abre (o corpo cai para fora).
		if playerAdapter.setExpelHandler then
			playerAdapter.setExpelHandler(function(_player: Player, lockerId: string)
				local locker = WorldService.locker(lockerId)
				if locker then
					locker.occupant = nil
				end
				WorldService.swingLocker(lockerId, true)
			end)
		end
	end
	ServerNet.onInvoke(
		"UseHouseItem",
		{ args = { Guard.literal("battery", "oxygen", "decoy") }, rateLimit = { capacity = 3, refillPerSecond = 0.5 } },
		function(player: Player, item: string)
			local member = session.members[player.UserId]
			if
				building
				or not member
				or member.status ~= "Active"
				or (session.phase ~= "Playing" and session.phase ~= "Extracting")
			then
				return false
			end
			local stock = supplies[player.UserId]
			if not stock or (stock[item] or 0) <= 0 or not playerAdapter then
				return false
			end
			local _, root = parts(player)
			if not root then
				return false
			end
			if item == "battery" and player:GetAttribute("HasFlashlight") ~= true then
				feedback(player, "need_flashlight")
				return false
			end
			if
				(item == "battery" and playerAdapter.battery(player) >= 0.98)
				or (item == "oxygen" and (tonumber(player:GetAttribute("Oxygen")) or 100) >= 99.9)
			then
				feedback(player, "supply_full")
				return false
			end
			stock[item] -= 1
			if item == "battery" then
				playerAdapter.addBattery(player, 0.5)
			elseif item == "oxygen" then
				playerAdapter.addOxygen(player, 25)
			else
				CreatureService.makeNoise(root.Position + root.CFrame.LookVector * 6, 50)
			end
			player:SetAttribute("HouseSupplies", HttpService:JSONEncode(stock))
			return true
		end
	)

	StoreService.setContinueHandler(retryStage)
	ServerNet.onInvoke("SelectGameMode", {
		args = { Guard.literal("Standard", "Story") },
		rateLimit = { capacity = 4, refillPerSecond = 1 },
	}, function(player: Player, mode: Modes.Id)
		if session.phase ~= "Lobby" or not session.members[player.UserId] then
			return { accepted = false, message = "mode_locked" }
		end
		if modeVotes[player.UserId] == mode then
			return { accepted = true, message = "vote_recorded" }
		end
		modeVotes[player.UserId] = mode
		player:SetAttribute("GameModeVote", mode)
		nextStageAt = 0
		publish()
		return { accepted = true, message = "vote_recorded" }
	end)
	ServerNet.onInvoke("Interact", {
		args = {
			Guard.string({ maxLength = 32, pattern = "^[%w_%-]+$" }),
			Guard.optional(Guard.literal("use", "alt")),
		},
		rateLimit = { capacity = 6, refillPerSecond = 3 },
	}, interact)
	ServerNet.onInvoke("RequestRestart", {
		args = { Guard.optional(Guard.literal("full", "checkpoint")) },
		rateLimit = { capacity = 2, refillPerSecond = 0.5 },
	}, function(player: Player)
		local passed, reason = Session.voteRestart(session, player.UserId)
		if passed then
			restartCampaign()
		end
		feedback(player, if passed then "restarting" else (reason or "vote_recorded"))
		return { accepted = reason == nil, message = reason or "vote_recorded" }
	end)
	-- Compatível com o template anterior e com PlayerStateService (dono da bateria no polish).
	task.defer(function()
		if not ServerNet.isRegistered("SetFlashlight") then
			ServerNet.onEvent(
				"SetFlashlight",
				{ args = { Guard.boolean() }, rateLimit = { capacity = 10, refillPerSecond = 5 } },
				function(player: Player, on: boolean)
					player:SetAttribute(Tags.Attr.Flashlight, on)
				end
			)
		end
	end)
	local function join(player: Player)
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMaxZoomDistance, player.CameraMinZoomDistance = 0.5, 0.5
		local ok = session.members[player.UserId] ~= nil or Session.join(session, player.UserId)
		if not ok then
			player:SetAttribute("CampaignStatus", "Waiting")
			feedback(player, "party_full")
			return
		end
		slotFor(player.UserId)
		if not supplies[player.UserId] then
			supplies[player.UserId] = starterSupplies()
		end
		player:SetAttribute("HouseSupplies", HttpService:JSONEncode(supplies[player.UserId]))
		player:SetAttribute("GameModeVote", "")
		player.CharacterAdded:Connect(function(character)
			local function assign(instance: Instance)
				if instance:IsA("BasePart") then
					instance.CollisionGroup = "CampaignPlayers"
				end
			end
			for _, descendant in character:GetDescendants() do
				assign(descendant)
			end
			character.DescendantAdded:Connect(assign)
		end)
		task.spawn(spawnMember, player)
		publish()
	end
	Players.PlayerAdded:Connect(join)
	Players.PlayerRemoving:Connect(function(player)
		if playerAdapter then
			local id = playerAdapter.hiddenId(player)
			local locker = id and WorldService.locker(id)
			if locker then
				locker.occupant = nil
			end
		end
		modeVotes[player.UserId] = nil
		Session.leave(session, player.UserId)
		if Session.count(session) == 0 then
			rewardCampaign += 1
			taskPayments = {}
			version += 1
			building = false
			-- Servidor vazio também encerra a partida: a próxima equipe recebe outro mapa.
			session = Session.new(
				if qaMode == "Story" then Story.MapSeed else C.Seed or ((os.time() + version * 7919) % 2147483646),
				C,
				qaMode,
				true
			)
			selectedMode, modeVotes = qaMode, {}
			sceneStartedAt, sceneEndsAt = 0, 0
			nextStageAt, startedAt = 0, 0
			clearRescues()
			CreatureService.reset()
		end
		channels[player.UserId], nextActionAt[player.UserId], spawning[player] = nil, nil, nil
		spawnedVersion[player] = nil
		spawnSlots[player.UserId] = nil
		if rescueParts[player.UserId] then
			rescueParts[player.UserId]:Destroy()
			rescueParts[player.UserId] = nil
		end
		publish()
	end)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, reason = pcall(tick :: () -> any)
			if not ok then
				log.error("tick failed: %s", tostring(reason))
			end
		end
	end)
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		if ok and type(args) == "table" and args.campaignQA then
			task.spawn(function()
				require("../../Tests/CampaignHarness").run(Runtime, args)
			end)
		end
	end
end

function Runtime.restart()
	restartCampaign()
end

-- Salto de QA apenas no Studio: exercita o runtime real, sem fabricar estado replicado no cliente.
function Runtime.debugForest(chapter: number): boolean
	assert(RunService:IsStudio(), "Studio-only forest preview")
	assert(chapter >= 6 and chapter <= 8 and chapter % 1 == 0, "Invalid forest preview chapter")
	if building or #Players:GetPlayers() == 0 then
		return false
	end
	selectedMode, modeVotes = "Story", {}
	session = Session.new(Story.MapSeed, C, "Story", true)
	for _, player in Players:GetPlayers() do
		Session.join(session, player.UserId)
	end
	session.stage, session.phase = chapter - 1, "Intermission"
	session.inventory.flashlight = 1
	endingShown = false
	stage()
	return true
end

-- Depuração (Studio): começa direto num capítulo da casa (1–5), com o que os anteriores dariam.
function Runtime.debugChapter(chapter: number): boolean
	assert(RunService:IsStudio(), "Studio-only chapter preview")
	assert(chapter >= 1 and chapter <= 5 and chapter % 1 == 0, "Invalid house chapter")
	if building or #Players:GetPlayers() == 0 then
		return false
	end
	selectedMode, modeVotes = "Story", {}
	session = Session.new(Story.MapSeed, C, "Story", true)
	for _, player in Players:GetPlayers() do
		Session.join(session, player.UserId)
	end
	session.stage, session.phase = chapter - 1, "Intermission"
	session.inventory.flashlight = 1
	if chapter >= 5 then
		session.inventory.artifact = 1
	end
	endingShown = false
	stage()
	return true
end

function Runtime.setPlayerAdapter(adapter: any)
	playerAdapter = adapter
end
function Runtime.lose(player: Player)
	capture(player)
end
function Runtime.win(player: Player)
	if Session.escape(session, player.UserId) then
		publish()
	end
end
function Runtime.getPhase(): "Loading" | "Intro" | "Playing" | "Won" | "Lost"
	return GameState.get("Phase")
end
function Runtime.snapshot(): { [string]: any }
	return {
		mode = selectedMode,
		building = building,
		tasks = session.tasks,
		phase = session.phase,
		stage = session.stage,
		seed = session.seed,
		players = Session.count(session),
		active = Session.count(session, "Active"),
		downed = Session.count(session, "Downed"),
		solved = Session.solvedCount(session),
		plan = session.plan,
		members = session.members,
	}
end

return Runtime
