--!strict
-- Uma partida por servidor. Os votos são validados e contados no servidor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Create = require("../UI/Create")
local Cinema = require("./CinematicController")

local Controller = { Name = "ModeMenuController" }
local player = Players.LocalPlayer
local ink = Color3.fromRGB(222, 216, 198)
local gold = Color3.fromRGB(209, 173, 100)
local function label(parent: Instance, name: string, value: string, y: number, height: number, size: number): TextLabel
	return Create("TextLabel", {
		Name = name,
		Parent = parent,
		Position = UDim2.fromScale(0.04, y),
		Size = UDim2.fromScale(0.92, height),
		BackgroundTransparency = 1,
		Text = value,
		TextColor3 = ink,
		Font = Enum.Font.Code,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}) :: TextLabel
end

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState")
	local gui = Create("ScreenGui", {
		Name = "ModeMenu",
		Parent = player:WaitForChild("PlayerGui"),
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 200,
		Enabled = false,
	}) :: ScreenGui
	local backdrop = Create("Frame", {
		Name = "Backdrop",
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.fromRGB(7, 12, 14),
	})
	local panel = Create("Frame", {
		Name = "Panel",
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.9),
		BackgroundColor3 = Color3.fromRGB(13, 20, 22),
		BorderSizePixel = 0,
	})
	Create("UISizeConstraint", { Parent = panel, MaxSize = Vector2.new(920, 620) })
	label(panel, "Eyebrow", "ARQUIVO 009 / COOPERATIVO / 3–8 JOGADORES", 0.02, 0.07, 14).TextColor3 = gold
	label(panel, "Title", "SUBESTAÇÃO 9", 0.1, 0.12, 38)
	label(panel, "Introduction", "Escolha o turno que a equipe vai enfrentar.", 0.23, 0.07, 17)
	local buttons: { [string]: TextButton } = {}
	local busy = false
	local status = label(panel, "Status", "", 0.77, 0.1, 16)
	for index, definition in
		{
			{
				id = "Story",
				title = "01 / MODO HISTÓRIA",
				description = "O ÚLTIMO TURNO\nA origem do Vigia em 3 capítulos.\nMapa fixo · cenas · objetivos em ordem",
			},
			{
				id = "Standard",
				title = "02 / MODO PADRÃO",
				description = "MAIS UMA NOITE\nAs partidas cooperativas atuais.\nMapas e tarefas sorteados · O Vigia",
			},
		}
	do
		local button = Create("TextButton", {
			Name = definition.id,
			Parent = panel,
			Position = UDim2.fromScale(0.04 + (index - 1) * 0.47, 0.34),
			Size = UDim2.fromScale(0.45, 0.39),
			BackgroundColor3 = Color3.fromRGB(22, 33, 35),
			BorderSizePixel = 1,
			BorderColor3 = gold,
			Text = "",
			Modal = true,
			Selectable = true,
			AutoButtonColor = true,
		}) :: TextButton
		label(button, "Heading", definition.title, 0.03, 0.21, 19).TextColor3 = gold
		label(button, "Description", definition.description, 0.26, 0.5, 16)
		label(button, "Choose", "ESCOLHER ESTE MODO →", 0.8, 0.15, 14)
		buttons[definition.id] = button
		button.Activated:Connect(function()
			if busy then
				return
			end
			busy = true
			task.spawn(function()
				local ok, response = pcall(function()
					return Remotes.clientFunction("SelectGameMode"):InvokeServer(definition.id)
				end)
				busy = false
				if not ok or type(response) ~= "table" or not response.accepted then
					status.Text = "Não foi possível registrar. Aguarde e escolha novamente."
				end
			end)
		end)
	end
	label(
		panel,
		"Rules",
		"A maioria escolhe o modo deste servidor. Empate aguarda novos votos.\nNa próxima partida, a equipe pode escolher novamente.",
		0.89,
		0.09,
		13
	)
	local previous = false
	if RunService:IsStudio() then
		local ok, args = pcall(function()
			return game:GetService("StudioTestService"):GetTestArgs()
		end)
		if ok and type(args) == "table" and args.modeMenuQA then
			local function qaVote()
				local command = player:GetAttribute("ModeQARequest")
				local mode = if type(command) == "string" then string.match(command, "^([%a]+):%d+$") else nil
				if mode == "Story" or mode == "Standard" then
					task.spawn(function()
						Remotes.clientFunction("SelectGameMode"):InvokeServer(mode)
					end)
				end
			end
			player:GetAttributeChangedSignal("ModeQARequest"):Connect(qaVote)
			qaVote()
		end
	end
	RunService:BindToRenderStep("S9ModeMenu", Enum.RenderPriority.Last.Value, function()
		local open = state:GetAttribute("Phase") == "Lobby"
		gui.Enabled = open
		player:SetAttribute("ModeMenuOpen", open)
		if open and not previous then
			Cinema.stop()
		end
		if open then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			local count = state:GetAttribute("Players") or 0
			local vote = player:GetAttribute("GameModeVote")
			local remaining =
				math.max(0, math.ceil((state:GetAttribute("NextStageAt") or 0) - workspace:GetServerTimeNow()))
			status.Text = if remaining > 0
				then `EQUIPE REUNIDA / INICIANDO EM {remaining}s`
				else `SERVIDOR: {count}/8 · MÍNIMO: 3\nVOTOS / HISTÓRIA: {state:GetAttribute("StoryVotes") or 0} · PADRÃO: {state:GetAttribute(
					"StandardVotes"
				) or 0}`
			for id, button in buttons do
				button.BackgroundColor3 = if id == vote then Color3.fromRGB(55, 65, 48) else Color3.fromRGB(22, 33, 35)
			end
		elseif previous then
			UserInputService.MouseIconEnabled = false
		end
		previous = open
	end)
end
return Controller
