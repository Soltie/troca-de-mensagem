--!strict
-- HUD específico do modo coop. O HUD solo fica preservado e só é ocultado quando o servidor ativa campanha.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Catalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Create = require("../UI/Create")

local player = Players.LocalPlayer
local Controller = { Name = "CampaignController" }
local messages = {
	progress = "ETAPA CONCLUÍDA.",
	solved = "ESTAÇÃO CONCLUÍDA.",
	need_partner = "OUTRA PESSOA PRECISA CONFIRMAR O RELÉ.",
	wrong_sequence = "SEQUÊNCIA ERRADA. CONSULTE A PLACA.",
	rescuing = "RESGATANDO... FIQUE PERTO E MANTENHA VISÃO.",
	rescued = "COLEGA RESGATADO.",
	rescue_cancelled = "RESGATE INTERROMPIDO.",
	too_far = "CHEGUE MAIS PERTO / CONFIRA A VISÃO.",
	vote_recorded = "VOTO REGISTRADO. AGUARDANDO MAIORIA.",
	not_active = "AGUARDE RESGATE OU O PRÓXIMO ESTÁGIO.",
	party_full = "EQUIPE COMPLETA (8). AGUARDE UMA VAGA.",
	restarting = "NOVA CAMPANHA.",
	wait = "AGUARDE UM INSTANTE.",
	not_available = "ESTA AÇÃO NÃO ESTÁ DISPONÍVEL.",
	not_playing = "AGUARDE O PRÓXIMO ESTÁGIO.",
	door_opened = "PASSAGEM LIBERADA.",
	spawn_failed = "CARREGAMENTO INTERROMPIDO. VOCÊ ENTRA NO PRÓXIMO ESTÁGIO.",
}

local function text(parent: Instance, name: string, position: UDim2, size: UDim2, fontSize: number): TextLabel
	return Create("TextLabel", {
		Name = name,
		Parent = parent,
		Position = position,
		Size = size,
		BackgroundTransparency = 1,
		Text = "",
		TextColor3 = Color3.fromRGB(222, 216, 198),
		Font = Enum.Font.Code,
		TextSize = fontSize,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}) :: TextLabel
end

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState", 15)
	assert(state, "[CampaignUI] missing campaign state")
	local gui = Create("ScreenGui", {
		Name = "CampaignUi",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 60,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local function cinemaChanged()
		gui.Enabled = player:GetAttribute("CinematicActive") ~= true
	end
	player:GetAttributeChangedSignal("CinematicActive"):Connect(cinemaChanged)
	cinemaChanged()
	Create("Frame", {
		Name = "Crosshair",
		Parent = gui,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(222, 216, 198),
	})
	local header = Create("Frame", {
		Name = "Header",
		Parent = gui,
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.new(1, -32, 0, 98),
		BackgroundColor3 = Color3.fromRGB(12, 16, 18),
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	})
	local title = text(header, "Title", UDim2.fromOffset(12, 8), UDim2.new(1, -24, 0, 24), 20)
	local objective = text(header, "Objective", UDim2.fromOffset(12, 36), UDim2.new(1, -24, 0, 54), 15)
	local taskPanel = Create("Frame", {
		Name = "TaskPanel",
		Parent = gui,
		Position = UDim2.fromOffset(16, 126),
		Size = UDim2.fromOffset(300, 242),
		BackgroundColor3 = Color3.fromRGB(12, 16, 18),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}) :: Frame
	local taskText = text(taskPanel, "Tasks", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 1, -16), 14)
	local roster = text(gui, "Roster", UDim2.new(0, 20, 1, -164), UDim2.fromOffset(420, 140), 13)
	local feedbackLabel = text(gui, "Feedback", UDim2.new(0.15, 0, 1, -215), UDim2.new(0.7, 0, 0, 48), 16)
	feedbackLabel.TextColor3 = Color3.fromRGB(230, 190, 90)
	feedbackLabel.TextXAlignment = Enum.TextXAlignment.Center
	local feedbackUntil = 0
	player:GetAttributeChangedSignal("CampaignFeedbackSerial"):Connect(function()
		local key = player:GetAttribute("CampaignFeedback")
		feedbackLabel.Text = PixelText.normalize(messages[key :: any] or "AÇÃO INDISPONÍVEL.")
		feedbackUntil = os.clock() + 4
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			taskPanel.Visible = not taskPanel.Visible
		end
	end)
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		local legacy = player.PlayerGui:FindFirstChild("GameUi")
		if legacy and legacy:IsA("ScreenGui") then
			legacy.Enabled = false
		end
		local phase = state:GetAttribute("Phase")
		local stage = state:GetAttribute("Stage") or 0
		local roleId = player:GetAttribute("CampaignRole")
		local roleTitle = "EQUIPE"
		for _, role in Catalog.Roles do
			if role.id == roleId then
				roleTitle = role.title
			end
		end
		title.Text = PixelText.normalize(`{stage}/3 {state:GetAttribute("Title") or ""} · {roleTitle}`)
		if phase == "Lobby" then
			objective.Text = "AGUARDANDO EQUIPE: 3–8 JOGADORES\nTAB: tarefas e equipe"
		elseif phase == "Intermission" then
			local remaining =
				math.max(0, math.ceil((state:GetAttribute("NextStageAt") or 0) - workspace:GetServerTimeNow()))
			objective.Text =
				`ESTÁGIO CONCLUÍDO. REAGRUPANDO EM {remaining}s.\nColegas fora de combate voltam no próximo estágio.`
		elseif phase == "Extracting" then
			objective.Text =
				"PORTÃO LIBERADO. REÚNAM OS SOBREVIVENTES NA SAÍDA.\nResgatem os colegas antes de evacuar."
		elseif phase == "Won" or phase == "Lost" then
			objective.Text = (if phase == "Won" then "EQUIPE EVACUADA." else "EQUIPE FORA DE COMBATE.")
				.. "\n[R] VOTAR NOVA CAMPANHA (maioria)"
		else
			objective.Text =
				`ESTAÇÕES {state:GetAttribute("Solved") or 0}/{state:GetAttribute("Total") or 0} · {state:GetAttribute(
					"Threat"
				) or ""}\nE: interagir · F: lanterna · TAB: tarefas/equipe`
		end
		objective.Text = PixelText.normalize(objective.Text)
		local decodedRoster = HttpService:JSONDecode((state:GetAttribute("Roster") or "[]") :: string)
		local lines = {}
		local statusTitles = { Active = "ATIVO", Downed = "RESGATAR", Waiting = "AGUARDA", Escaped = "SAIU" }
		for _, member in decodedRoster do
			local status = statusTitles[member.status] or member.status
			if member.status == "Downed" then
				status ..= ` {math.max(0, math.ceil(member.downedUntil - workspace:GetServerTimeNow()))}s`
			end
			table.insert(lines, `{member.name}: {status} · {member.contributions}`)
		end
		roster.Text = PixelText.normalize(table.concat(lines, "\n"))
		local tasks = HttpService:JSONDecode((state:GetAttribute("Tasks") or "[]") :: string)
		lines = { "TAREFAS DA EQUIPE [TAB]" }
		for _, activity in tasks do
			table.insert(
				lines,
				`{if activity.solved then "[OK]" else "[ ]"} {Catalog.RoomNames[activity.room] or "SETOR"} / {Catalog.KindNames[activity.kind] or "ATIVIDADE"}`
			)
		end
		if roleId == "scout" and player:GetAttribute("CampaignStatus") == "Active" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local world = workspace:FindFirstChild("Substation9")
			local stations = world and world:FindFirstChild("CampaignActivities")
			if root and root:IsA("BasePart") and stations then
				for _, model in stations:GetChildren() do
					local point = model:FindFirstChild("Station")
					if
						point
						and point:IsA("BasePart")
						and (point.Position - root.Position).Magnitude <= Config.Campaign.ScoutRange
					then
						table.insert(lines, `RADAR: {model:GetAttribute("RoomLabel") or "ESTAÇÃO"} / PERTO`)
					end
				end
			end
		end
		taskText.Text = PixelText.normalize(table.concat(lines, "\n"))
		if os.clock() > feedbackUntil then
			feedbackLabel.Text = ""
		end
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
