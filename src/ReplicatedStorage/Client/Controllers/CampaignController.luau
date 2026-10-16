--!strict
-- HUD cooperativo: objetivo acionável, orientação progressiva e dossiê sob demanda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Guide = require("@game/ReplicatedStorage/Shared/Game/PlayerGuide")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Hud = require("../UI/FieldHud")
local Character = require("./CharacterController")

local player = Players.LocalPlayer
local Controller = { Name = "CampaignController" }
local messages: { [string]: string } = {
	progress = "ETAPA CONFIRMADA. SIGA O PRÓXIMO BOTÃO NA ESTAÇÃO.",
	solved = "ESTAÇÃO CONCLUÍDA. OBJETIVO ATUALIZADO.",
	need_partner = "CHAME UM COLEGA: ELE PRECISA CONFIRMAR NESTE MESMO RELÉ.",
	wrong_sequence = "BOTÃO INCORRETO. SEUS ACERTOS CONTINUAM SALVOS; SIGA A PLACA.",
	repair_order = "SIGA O BOTÃO ACESO: ISOLAR, ENCAIXAR FUSÍVEL E TESTAR.",
	story_order = "CONCLUA PRIMEIRO O OBJETIVO INDICADO NO HUD.",
	rescuing = "RESGATANDO... FIQUE PERTO DO COLEGA E MANTENHA VISÃO.",
	rescued = "COLEGA RESGATADO.",
	rescue_cancelled = "RESGATE INTERROMPIDO. APROXIME-SE E TENTE NOVAMENTE.",
	too_far = "CHEGUE MAIS PERTO E MIRE NO BOTÃO.",
	vote_recorded = "VOTO REGISTRADO. AGUARDANDO MAIORIA.",
	not_active = "AGUARDE RESGATE OU O PRÓXIMO ESTÁGIO.",
	party_full = "EQUIPE COMPLETA. AGUARDE UMA VAGA.",
	restarting = "NOVA CAMPANHA.",
	wait = "AGUARDE UM INSTANTE.",
	not_available = "AÇÃO INDISPONÍVEL NESTE MOMENTO.",
	not_playing = "AGUARDE O PRÓXIMO ESTÁGIO.",
	door_opened = "PASSAGEM LIBERADA.",
	spawn_failed = "VOCÊ ENTRA NO PRÓXIMO ESTÁGIO.",
	second_chance = "SEGUNDA CHANCE: VOCÊ LEVANTOU.",
	continue_used = "CONTINUAÇÃO USADA: A EQUIPE REPETE A ETAPA.",
}

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState", 15)
	assert(state, "[CampaignUI] missing campaign state")
	local ui = Hud.build(player:WaitForChild("PlayerGui"))
	local helpOpen, teamHeld = false, false
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
		ui.feedback.Text = messages[tostring(player:GetAttribute("CampaignFeedback"))] or "AÇÃO INDISPONÍVEL."
		feedbackUntil = os.clock() + 4
	end)
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
	local elapsed, stageAt, lastStage = 0, 0, ""
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local phase = tostring(state:GetAttribute("Phase"))
		local stage = (state:GetAttribute("Stage") or 0) :: number
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
		end
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local factor = ui.resize(camera.ViewportSize)
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
		local roleTitle, roleDescription = "EQUIPE", ""
		for _, role in Catalog.Roles do
			if role.id == roleId then
				roleTitle, roleDescription = role.title, role.description
			end
		end
		ui.chapter.Text = `{if story then "HISTÓRIA / CAPÍTULO" else "PADRÃO / ETAPA"} {stage}/3  ·  {roleTitle}`
		ui.title.Text = title
		ui.destination.Text = if active and activity
			then `SETOR / {Catalog.RoomNames[activity.room] or activity.room}`
			else "SUBESTAÇÃO 9 / ORDEM DE SERVIÇO"
		ui.action.Text = if active and activity then Guide.instruction(activity, now, activePlayers) else detail
		ui.progress.Text = if active
			then `{state:GetAttribute("Solved") or 0}/{state:GetAttribute("Total") or 0} ESTAÇÕES  ·  {if story
				then "SIGA A ORDEM"
				else "ORDEM LIVRE"}`
			else detail
		if phase == "Intermission" then
			local remaining = math.max(
				0,
				math.ceil(((state:GetAttribute("NextStageAt") or 0) :: number) - workspace:GetServerTimeNow())
			)
			ui.progress.Text = `PRÓXIMO SETOR EM {remaining}s`
		elseif not active then
			ui.progress.Text = "H / REVER GUIA E EQUIPE"
		end
		if briefingRemaining > 0 then
			ui.progress.Text = `INÍCIO EM {briefingRemaining}s`
		end
		if status == "Downed" then
			for _, member in roster do
				if member.id == player.UserId then
					ui.progress.Text = `RESGATE DISPONÍVEL / {math.max(0, math.ceil(member.downedUntil - now))}s`
				end
			end
		end
		ui.dossier.Visible = helpOpen or teamHeld
		player:SetAttribute("FieldGuideOpen", ui.dossier.Visible)
		ui.order.Visible = not ui.dossier.Visible
		ui.tipPanel.Visible = active and not ui.dossier.Visible and camera.ViewportSize.Y / factor >= 570
		local tipAge = os.clock() - stageAt
		ui.tip.Text = if tipAge < 16
			then Guide.StageTips[math.clamp(stage, 1, 3)]
			else Guide.SurvivalTips[(math.floor((tipAge - 16) / 18) % #Guide.SurvivalTips) + 1]
		if downed and active then
			ui.tip.Text =
				`{downed.name} precisa de resgate! Aproxime-se, mire no colega e aperte E. Fique perto e com visão.`
		end
		local stamina, maximum = Character.getStamina()
		local battery = player:GetAttribute("Battery")
		local percent = math.floor(math.clamp(if type(battery) == "number" then battery else 0, 0, 1) * 100)
		ui.equipment.Text =
			`LUZ {percent}%  ·  FÔLEGO {math.floor(math.clamp(stamina / maximum, 0, 1) * 100)}%  ·  {if player:GetAttribute(
					"Stance"
				) == "Crouch"
				then "AGACHADO"
				else "EM PÉ"}`
		ui.footer.Visible = status == "Active"
		if ui.dossier.Visible then
			local lines = {
				`SEU PAPEL / {roleTitle}\n{roleDescription}`,
				if story
					then "MISSÃO\nConcluam as estações na ordem abaixo. O objetivo marcado é o próximo passo. São três capítulos; no último, saiam pelo portão."
					else "MISSÃO\nConcluam todas as estações do setor em qualquer ordem. O marcador sugere uma delas. São três etapas; no final, saiam pelo portão.",
				"PROCEDIMENTO DA EQUIPE",
			}
			for n, item in tasks do
				table.insert(
					lines,
					`{if item.solved then "[OK]" elseif n == index then ">>" else "[  ]"} {n}. {Catalog.RoomNames[item.room] or item.room}\n{item.title or Catalog.KindNames[item.kind]}{if item.solved
						then ""
						else `\n{Guide.instruction(item, now, activePlayers)}`}`
				)
			end
			table.insert(lines, "EQUIPE / RESGATE")
			local statusTitles: { [string]: string } =
				{ Active = "ATIVO", Downed = "PRECISA DE RESGATE", Waiting = "AGUARDA", Escaped = "NA SAÍDA" }
			for _, member in roster do
				local remaining = if member.status == "Downed"
					then ` / {math.max(0, math.ceil(member.downedUntil - workspace:GetServerTimeNow()))}s`
					else ""
				table.insert(lines, `{member.name}: {statusTitles[member.status] or member.status}{remaining}`)
			end
			if roleId == "scout" and active then
				local world = workspace:FindFirstChild("Substation9")
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
							table.insert(lines, `RADAR / {model:GetAttribute("RoomLabel") or "ESTAÇÃO"} PERTO`)
						end
					end
				end
			end
			table.insert(lines, "SOBREVIVÊNCIA\n" .. table.concat(Guide.SurvivalTips, "\n\n"))
			table.insert(
				lines,
				"CONTROLES\nWASD mover · E interagir · F lanterna\nShift correr · C agachar\nH abrir/fechar guia · segure TAB para equipe\nSetas: trocar colega no modo espectador"
			)
			ui.pages.Text = table.concat(lines, "\n\n")
			local bounds =
				TextService:GetTextSize(ui.pages.Text, ui.pages.TextSize, Enum.Font.Code, Vector2.new(296, 100000))
			ui.pages.Size = UDim2.new(1, -16, 0, bounds.Y + 20)
		end
		ui.waypoint.Visible = active and activity ~= nil and not ui.dossier.Visible
		if ui.waypoint.Visible and activity then
			local world = workspace:FindFirstChild("Substation9")
			local stations = world and world:FindFirstChild("CampaignActivities")
			local model = stations and stations:FindFirstChild(activity.id)
			local station = model and model:FindFirstChild("Station")
			if station and station:IsA("BasePart") then
				local point, onScreen = camera:WorldToViewportPoint(station.Position + Vector3.new(0, 4, 0))
				local width, height = camera.ViewportSize.X / factor, camera.ViewportSize.Y / factor
				local x, y = point.X / factor, point.Y / factor
				if point.Z < 0 then
					x, y = width - x, height - y
				end
				x, y = math.clamp(x, 125, width - 125), math.clamp(y, 90, height - 160)
				-- Não sobrepor a ordem de serviço: o marcador ocupa o lado livre da tela.
				if x < 490 and y < 400 then
					x = math.min(width - 125, 490)
				end
				ui.waypoint.Position = UDim2.fromOffset(x, y)
				local distance = math.floor((station.Position - camera.CFrame.Position).Magnitude / 3.57)
				local direction = if onScreen then "◇" elseif x < width / 2 then "←" else "→"
				ui.waypoint.Text =
					`{direction} {Catalog.RoomNames[activity.room] or activity.room}\n{distance} m · {if story
						then "OBJETIVO ATUAL"
						else "SUGESTÃO"}`
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
					Remotes.clientFunction("Interact", 10):InvokeServer(request.id)
				end)
			end
			player:GetAttributeChangedSignal("CampaignQARequest"):Connect(qaRequest)
			qaRequest()
		end
	end
end

return Controller
