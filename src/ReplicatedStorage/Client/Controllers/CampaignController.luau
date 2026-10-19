--!strict
-- HUD cooperativo: objetivo acionável, orientação progressiva, barras, inventário e guia sob demanda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local HouseCatalog = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Guide = require("@game/ReplicatedStorage/Shared/Game/PlayerGuide")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Hud = require("../UI/FieldHud")
local Juice = require("../UI/Juice")
local Theme = require("../UI/Theme")
local Character = require("./CharacterController")
local AudioController = require("./AudioController")

type FieldSlot = Hud.Slot

local player = Players.LocalPlayer
local Controller = { Name = "CampaignController" }
local guideToggle: (() -> ())? = nil
function Controller.toggleGuide()
	if guideToggle then
		guideToggle()
	end
end
local messages: { [string]: string } = {
	progress = "Etapa certa! Continue seguindo a pista.",
	solved = "Objetivo concluído!",
	need_partner = "Chame um amigo para apertar este mesmo botão!",
	wrong_sequence = "Ops! Botão errado, mas seus acertos continuam salvos.",
	repair_order = "Aperte o botão aceso: desligar, trocar o fusível e ligar.",
	story_order = "Complete as pistas e os itens necessários. H abre o guia.",
	rescuing = "Ajudando... fique pertinho do seu amigo!",
	rescued = "Amigo de pé de novo!",
	rescue_cancelled = "Ajuda interrompida. Chegue perto e tente de novo.",
	too_far = "Chegue mais perto e mire no objeto.",
	vote_recorded = "Voto registrado! Esperando o time.",
	not_active = "Espere um amigo te ajudar ou o próximo capítulo.",
	party_full = "O time está cheio. Espere uma vaga.",
	restarting = "Nova aventura!",
	wait = "Só um instante...",
	occupied = "Já tem alguém escondido aí!",
	hide_enter = "Escondido! E para sair · Espaço para espiar · Z para prender o ar",
	hide_exit = "Você saiu do esconderijo.",
	not_available = "Isso não dá para fazer agora.",
	not_playing = "Espere o próximo capítulo.",
	door_opened = "Passagem aberta!",
	spawn_failed = "Você entra no próximo capítulo.",
	second_chance = "Segunda chance: você levantou!",
	continue_used = "O time volta para o começo deste capítulo.",
	checkpoint_restored = "Tentando de novo deste capítulo!",
	supply_full = "Já está cheio. Seu item continua na mochila.",
	need_flashlight = "Recolha a lanterna antes de usar uma pilha.",
}

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState", 15)
	assert(state, "[CampaignUI] missing campaign state")
	local ui = Hud.build(player:WaitForChild("PlayerGui"))
	local helpOpen, teamHeld = false, false
	guideToggle = function()
		helpOpen = not helpOpen
	end
	local actions = game:GetService("ContextActionService")
	actions:BindAction("HouseGuideTouch", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			helpOpen = not helpOpen
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonSelect)
	ui.close.Activated:Connect(function()
		helpOpen, teamHeld = false, false
	end)
	local tasks: { Guide.Activity } = {}
	local roster: { any } = {}
	local function decodeTasks()
		tasks = HttpService:JSONDecode((state:GetAttribute("Tasks") or "[]") :: string)
	end
	local function decodeRoster()
		roster = HttpService:JSONDecode((state:GetAttribute("Roster") or "[]") :: string)
	end
	state:GetAttributeChangedSignal("Tasks"):Connect(decodeTasks)
	state:GetAttributeChangedSignal("Roster"):Connect(decodeRoster)
	decodeTasks()
	decodeRoster()
	local feedbackUntil = 0
	player:GetAttributeChangedSignal("CampaignFeedbackSerial"):Connect(function()
		ui.feedback.Text = messages[tostring(player:GetAttribute("CampaignFeedback"))]
			or "Isso não dá para fazer agora."
		feedbackUntil = os.clock() + 4
		Juice.pop(ui.feedback, 0.25)
	end)

	-- Moedas e nível: animam quando sobem.
	local shownCoins = (tonumber(player:GetAttribute("Fichas")) or 0) :: number
	local function refreshCoins()
		local value = (tonumber(player:GetAttribute("Fichas")) or 0) :: number
		if value > shownCoins then
			local gain = value - shownCoins
			Juice.count(shownCoins, value, 0.6, function(current)
				ui.coins.Text = `{current}`
			end)
			Juice.pop(ui.wallet, 0.2)
			Juice.floatText(ui.canvas, `+{gain}`, UDim2.new(1, -100, 0, 80), Theme.Coin, 30)
		else
			ui.coins.Text = `{value}`
		end
		shownCoins = value
	end
	local shownLevel = (tonumber(player:GetAttribute("Level")) or 1) :: number
	local function refreshLevel()
		local value = (tonumber(player:GetAttribute("Level")) or 1) :: number
		ui.level.Text = `NÍVEL {value}`
		if value > shownLevel then
			Juice.pop(ui.level.Parent :: GuiObject, 0.3)
			Juice.confetti(ui.canvas, Vector2.new(0.5, 0.35), 48)
			Juice.floatText(ui.canvas, `NÍVEL {value}!`, UDim2.fromScale(0.5, 0.62), Theme.Good, 40, 1.6)
		end
		shownLevel = value
	end
	-- Moedas pegas no capítulo atual (para o resumo da comemoração).
	local chapterCoins = 0
	player:GetAttributeChangedSignal("CoinPickupSerial"):Connect(function()
		chapterCoins += 1
	end)
	local function celebrate(big: boolean, title: string, detail: string)
		Juice.confetti(ui.canvas, Vector2.new(0.5, 0.3), if big then 90 else 50)
		if big then
			Juice.confetti(ui.canvas, Vector2.new(0.2, 0.35), 40)
			Juice.confetti(ui.canvas, Vector2.new(0.8, 0.35), 40)
		end
		Juice.floatText(ui.canvas, title, UDim2.fromScale(0.5, 0.4), Theme.Hazard, if big then 54 else 44, 2.2)
		task.delay(0.35, function()
			Juice.floatText(ui.canvas, detail, UDim2.fromScale(0.5, 0.5), Theme.Text, 26, 2)
		end)
		AudioController.play("StingerWin", if big then 0.9 else 0.6, 1, true)
	end
	-- Legenda das batidas do Tung Tung (vem do CreatureVisualController quando ele está perto).
	player:GetAttributeChangedSignal("TungKnockSerial"):Connect(function()
		if ui.gui.Enabled then
			Juice.floatText(ui.canvas, "TUM... TUM... TUM...", UDim2.fromScale(0.5, 0.3), Theme.Accent, 30, 1.2)
		end
	end)
	player:GetAttributeChangedSignal("Fichas"):Connect(refreshCoins)
	player:GetAttributeChangedSignal("Level"):Connect(refreshLevel)
	refreshCoins()
	refreshLevel()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not ui.gui.Enabled then
			return
		end
		if input.KeyCode == Enum.KeyCode.H then
			helpOpen = not helpOpen
		elseif input.KeyCode == Enum.KeyCode.Tab then
			teamHeld = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Tab then
			teamHeld = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		teamHeld = false
	end)
	local function setSlot(slot: FieldSlot, count: number, text: string)
		slot.count.Text = text
		slot.icon.TextTransparency = if count > 0 then 0 else 0.6
	end
	local elapsed, stageAt, lastStage, lastObjective, lastSolved = 0, 0, "", "", -1
	local lastPhase = ""
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local phase = tostring(state:GetAttribute("Phase"))
		local stage = (state:GetAttribute("Stage") or 0) :: number
		if phase ~= lastPhase then
			if phase == "Intermission" then
				celebrate(false, `CAPÍTULO {stage} CONCLUÍDO!`, `{chapterCoins} moedas neste capítulo`)
			elseif phase == "Won" then
				celebrate(true, "VOCÊS ESCAPARAM!", `{chapterCoins} moedas no último capítulo`)
			end
			lastPhase = phase
		end
		local story = state:GetAttribute("GameMode") == "Story"
		local status = player:GetAttribute("CampaignStatus") :: string?
		local cinema = player:GetAttribute("CinematicActive") == true
		ui.gui.Enabled = phase ~= "Lobby" and not cinema and state:GetAttribute("Building") ~= true
		local legacy = player.PlayerGui:FindFirstChild("GameUi")
		if legacy and legacy:IsA("ScreenGui") then
			legacy.Enabled = false
		end
		if not ui.gui.Enabled then
			teamHeld = false
			player:SetAttribute("FieldGuideOpen", false)
			return
		end
		local key = `{state:GetAttribute("Seed")}:{stage}:{story}`
		if key ~= lastStage then
			lastStage, stageAt, helpOpen = key, os.clock(), false
			chapterCoins = 0
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local factor = ui.resize(camera.ViewportSize)
		local touch = UserInputService.TouchEnabled
		local activity, index = Guide.current(tasks)
		local now = workspace:GetServerTimeNow()
		local briefingRemaining =
			math.max(0, math.ceil(((state:GetAttribute("StorySceneEndsAt") or 0) :: number) - now))
		local title, detail = Guide.objective(if briefingRemaining > 0 then "Briefing" else phase, status, activity)
		local active = status == "Active" and phase == "Playing" and briefingRemaining == 0
		local activePlayers = 0
		local downed: any = nil
		for _, member in roster do
			if member.status == "Active" then
				activePlayers += 1
			end
			if member.status == "Downed" then
				downed = member
			end
		end
		local roleId = player:GetAttribute("CampaignRole")
		local roleTitle, roleDescription = "TIME", ""
		for _, role in Catalog.Roles do
			if role.id == roleId then
				roleTitle, roleDescription = role.title, role.description
			end
		end
		-- O papel completo fica no guia; o cabeçalho divide espaço com o destino da floresta.
		ui.chapter.Text = `{if story then "CAPÍTULO" else "NOITE"} {stage}/{#HouseCatalog.Chapters}`
		ui.title.Text = title
		if title ~= lastObjective then
			lastObjective = title
			Juice.pop(ui.order, 0.08)
		end
		ui.destination.Text = if active and activity then `{Guide.roomName(activity.room)}` else "CASA DO TUNG TUNG"
		ui.action.Text = if active and activity then Guide.instruction(activity, now, activePlayers) else detail
		if touch then
			ui.action.Text = ui.action.Text
				:gsub("aperte E", "toque AÇÃO")
				:gsub("Aperte E", "Toque AÇÃO")
				:gsub("H abre o guia", "GUIA mostra as pistas")
		end
		if phase == "Won" then
			local remaining = math.max(0, math.ceil((tonumber(state:GetAttribute("LobbyReturnAt")) or now) - now))
			ui.action.Text = `Voltando ao lobby com a equipe em {remaining}s`
		end
		local solved = (state:GetAttribute("Solved") or 0) :: number
		local total = math.max(1, (state:GetAttribute("Total") or 1) :: number)
		ui.progressFill.Size = UDim2.fromScale(math.clamp(solved / total, 0, 1), 1)
		ui.progress.Text = `{solved}/{total}`
		if solved > lastSolved and lastSolved >= 0 then
			Juice.pop(ui.progress, 0.6)
		end
		lastSolved = solved
		if phase == "Intermission" then
			local remaining = math.max(
				0,
				math.ceil(((state:GetAttribute("NextStageAt") or 0) :: number) - workspace:GetServerTimeNow())
			)
			ui.action.Text = `Próximo capítulo em {remaining}s`
		end
		if briefingRemaining > 0 then
			ui.action.Text = `Começa em {briefingRemaining}s...`
		end
		if status == "Downed" and phase ~= "Lost" then
			for _, member in roster do
				if member.id == player.UserId then
					ui.action.Text = `Espere um amigo te levantar: {math.max(0, math.ceil(member.downedUntil - now))}s`
				end
			end
		end
		ui.dossier.Visible = helpOpen or teamHeld
		player:SetAttribute("FieldGuideOpen", ui.dossier.Visible)
		ui.order.Visible = not ui.dossier.Visible
		ui.tipPanel.Visible = not touch and active and not ui.dossier.Visible and camera.ViewportSize.Y / factor >= 560
		local tipAge = os.clock() - stageAt
		ui.tip.Text = if tipAge < 16
			then Guide.StageTips[math.clamp(stage, 1, #Guide.StageTips)]
			else Guide.SurvivalTips[(math.floor((tipAge - 16) / 18) % #Guide.SurvivalTips) + 1]
		if downed and active then
			ui.tip.Text = `{downed.name} caiu! Chegue perto, mire e aperte E para ajudar.`
		end

		-- Barras de fôlego, lanterna e ar.
		local stamina, maximum = Character.getStamina()
		local battery = player:GetAttribute("Battery")
		local light = math.clamp(if type(battery) == "number" then battery else 0, 0, 1)
		local oxygen = math.clamp((tonumber(player:GetAttribute("Oxygen")) or 100) :: number, 0, 100)
		local breath = math.clamp(stamina / math.max(maximum, 1e-3), 0, 1)
		ui.setBar(ui.bars.stamina, breath, `FÔLEGO {math.floor(breath * 100)}%`, breath < 0.2)
		ui.setBar(ui.bars.battery, light, `LANTERNA {math.floor(light * 100)}%`, light < 0.15)
		ui.setBar(ui.bars.oxygen, oxygen / 100, `AR {math.floor(oxygen)}%`, oxygen < 25)
		ui.equipment.Text = if player:GetAttribute("Stance") == "Crouch" then "AGACHADO (silencioso)" else ""
		if phase == "Extracting" then
			ui.action.Text = `{if stage >= 6 then "CORRA PARA O RESGATE!" else "FUJA PARA O PORTÃO!"} {math.max(
				0,
				math.ceil(((state:GetAttribute("EscapeEndsAt") or 0) :: number) - now)
			)}s`
		end
		if oxygen < 15 then
			ui.action.Text = "O AR ESTÁ ACABANDO! Solte a respiração!"
		end

		-- Inventário do time e itens pessoais.
		local inventory = HttpService:JSONDecode((state:GetAttribute("Inventory") or "{}") :: string)
		local stock = HttpService:JSONDecode((player:GetAttribute("HouseSupplies") or "{}") :: string)
		local keys = (inventory.key_living or 0) + (inventory.key_kitchen or 0) + (inventory.key_dining or 0)
		local fuses = (inventory.fuse_1 or 0) + (inventory.fuse_2 or 0) + (inventory.fuse_3 or 0)
		setSlot(ui.slots.keys, keys, `{keys}/3`)
		setSlot(ui.slots.fuses, fuses, `{fuses}/3`)
		setSlot(ui.slots.artifact, inventory.artifact or 0, `{inventory.artifact or 0}`)
		setSlot(ui.slots.battery, stock.battery or 0, `{stock.battery or 0}`)
		setSlot(ui.slots.oxygen, stock.oxygen or 0, `{stock.oxygen or 0}`)
		setSlot(ui.slots.decoy, stock.decoy or 0, `{stock.decoy or 0}`)
		ui.inventory.Text =
			`CHAVES {keys}/3 · FUSÍVEIS {fuses}/3 · ARTEFATO {inventory.artifact or 0}\n1 PILHA {stock.battery or 0} · 2 AR {stock.oxygen or 0} · 3 ISCA {stock.decoy or 0}`
		ui.footer.Visible = status == "Active" and not ui.dossier.Visible
		ui.bars.battery.frame.Visible = player:GetAttribute("HasFlashlight") == true
		ui.tray.Visible = not touch and status == "Active" and not ui.dossier.Visible
		ui.controls.Visible = not touch and active and not ui.dossier.Visible and camera.ViewportSize.X / factor >= 900

		if ui.dossier.Visible then
			local lines = {
				`SEU PAPEL: {roleTitle}\n{roleDescription}`,
				if story
					then "MISSÃO\nFaçam os objetivos na ordem abaixo. O marcado é o próximo. São oito capítulos: fujam da casa, atravessem a floresta e alcancem o resgate!"
					else "DESAFIO\nDividam as tarefas disponíveis entre colegas. Coletem em qualquer ordem; mecanismos exigem as pistas e os itens. A seta é uma sugestão.",
				"OBJETIVOS",
			}
			for n, item in tasks do
				table.insert(
					lines,
					`{if item.solved
						then "[FEITO]"
						elseif item.available == false then "[TRANCADO]"
						elseif n == index then "[AGORA]"
						else "-"} {n}. {Guide.roomName(item.room)}\n{item.title or Catalog.KindNames[item.kind]}{if item.solved
						then ""
						elseif item.available == false then "\nComplete as pistas e os itens anteriores."
						else `\n{Guide.instruction(item, now, activePlayers)}`}`
				)
			end
			table.insert(lines, "TIME")
			local statusTitles: { [string]: string } = {
				Active = "na ativa",
				Downed = "precisa de ajuda",
				Waiting = "esperando",
				Escaped = "a salvo",
			}
			for _, member in roster do
				local remaining = if member.status == "Downed"
					then ` ({math.max(0, math.ceil(member.downedUntil - workspace:GetServerTimeNow()))}s)`
					else ""
				table.insert(lines, `{member.name}: {statusTitles[member.status] or member.status}{remaining}`)
			end
			if roleId == "scout" and active then
				local world = workspace:FindFirstChild("CursedHouse")
				local stations = world and world:FindFirstChild("CampaignActivities")
				local character = player.Character
				if stations and character then
					for _, model in stations:GetChildren() do
						local point = model:FindFirstChild("Station")
						if
							point
							and point:IsA("BasePart")
							and (point.Position - character:GetPivot().Position).Magnitude
								<= Config.Campaign.ScoutRange
						then
							table.insert(lines, `RADAR: {model:GetAttribute("RoomLabel") or "objetivo"} por perto!`)
						end
					end
				end
			end
			table.insert(lines, "COMO SOBREVIVER\n" .. table.concat(Guide.SurvivalTips, "\n\n"))
			table.insert(
				lines,
				"CONTROLES\nWASD andar · E usar · F lanterna\nShift correr · C agachar · Z/LB prender o ar\n1 pilha · 2 ar extra · 3 isca\nH guia · segure TAB para ver o time\nSetas: trocar de amigo quando estiver assistindo"
			)
			ui.pages.Text = table.concat(lines, "\n\n")
			if touch then
				ui.pages.Text = ui.pages.Text:gsub("aperte E", "toque AÇÃO"):gsub("Aperte E", "Toque AÇÃO")
				local controlsAt = ui.pages.Text:find("CONTROLES", 1, true)
				if controlsAt then
					ui.pages.Text = ui.pages.Text:sub(1, controlsAt - 1)
						.. "CONTROLES DE TOQUE\nArraste no lado livre da tela para olhar. Use o direcional para andar e o botão do Roblox para pular.\nAÇÃO usa o objeto na mira, ajuda colegas e sai do armário.\nCORRER liga/desliga a corrida; AGACHAR reduz o barulho.\nNo armário, segure O AR e solte para respirar.\nMOCHILA abre pilhas, ar extra e iscas. GUIA mostra objetivos e time; AJUSTES controla efeitos e áudio."
				end
			end
			local bounds = TextService:GetTextSize(
				ui.pages.Text,
				ui.pages.TextSize,
				Enum.Font.GothamMedium,
				Vector2.new(math.max(120, ui.pages.AbsoluteSize.X), 100000)
			)
			ui.pages.Size = UDim2.new(1, -16, 0, bounds.Y + 24)
		end
		ui.waypoint.Visible = active and (activity ~= nil or phase == "Extracting") and not ui.dossier.Visible
		if ui.waypoint.Visible then
			local world = workspace:FindFirstChild("CursedHouse")
			local stations = world and world:FindFirstChild("CampaignActivities")
			local model = stations and activity and stations:FindFirstChild(activity.id)
			local station = model and model:FindFirstChild("Station")
			local target = if phase == "Extracting"
				then Vector3.new(0, 4, if stage >= 6 then 870 else 106)
				elseif station and station:IsA("BasePart") then station.Position + Vector3.new(0, 4, 0)
				else nil
			if target then
				local point, onScreen = camera:WorldToViewportPoint(target)
				local viewport = ui.viewport()
				local width, height = viewport.X / factor, viewport.Y / factor
				local x, y =
					(point.X - ui.canvas.AbsolutePosition.X) / factor, (point.Y - ui.canvas.AbsolutePosition.Y) / factor
				if point.Z < 0 then
					x, y = width - x, height - y
				end
				local margin = if touch then 80 else 130
				local top = if touch then math.min(height * 0.52, 180) else 170
				x, y =
					math.clamp(x, margin, math.max(margin, width - margin)),
					math.clamp(y, top, math.max(top, height - (if touch then 140 else 170)))
				ui.waypoint.Position = UDim2.fromOffset(x, y)
				local distance = math.floor((target - camera.CFrame.Position).Magnitude / 3.57)
				local direction = if onScreen then "" elseif x < width / 2 then "" else ""
				local name = if phase == "Extracting"
					then (if stage >= 6 then "RESGATE" else "SAÍDA DA CASA")
					else Guide.roomName((activity :: Guide.Activity).room)
				ui.waypoint.Text = `{direction} {name}\n{distance} m`
			else
				ui.waypoint.Visible = false
			end
		end
		if os.clock() > feedbackUntil then
			ui.feedback.Text = ""
		end
		local storyUi = player.PlayerGui:FindFirstChild("StoryUi")
		local recording = storyUi and storyUi:FindFirstChild("RecoveredRecording")
		ui.feedback.Visible = not ui.dossier.Visible
			and not (
				storyUi
				and storyUi:IsA("ScreenGui")
				and storyUi.Enabled
				and recording
				and recording:IsA("GuiObject")
				and recording.Visible
			)
	end)
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		if ok and type(args) == "table" and args.campaignQA then
			local function qaRequest()
				local command = player:GetAttribute("CampaignQARequest")
				if type(command) ~= "string" then
					return
				end
				local request = HttpService:JSONDecode(command)
				task.spawn(function()
					local result: any
					if request.restart then
						result = Remotes.clientFunction("RequestRestart", 10):InvokeServer()
					elseif request.select then
						local selected = require("./InteractionController").testInteract(request.id)
						result = {
							ok = true,
							data = {
								accepted = selected and player:GetAttribute("CampaignAccepted") == true,
								message = if selected
									then player:GetAttribute("CampaignFeedback")
									else "client_target_unavailable",
							},
						}
					elseif request.breath ~= nil then
						Remotes.clientEvent("SetHoldBreath", 10):FireServer(request.breath)
						result = { ok = true }
					else
						result = Remotes.clientFunction("Interact", 10):InvokeServer(request.id)
					end
					player:SetAttribute(
						"CampaignQAResponse",
						HttpService:JSONEncode({ serial = request.serial, result = result })
					)
				end)
			end
			player:GetAttributeChangedSignal("CampaignQARequest"):Connect(qaRequest)
			qaRequest()
		end
	end
end

return Controller
