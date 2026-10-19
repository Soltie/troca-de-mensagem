--!strict
--[[
	Tela de carregamento: cobre as travadas em vez de mostrar quadros congelados.
	- Na entrada do jogo, até o mundo existir e os quadros estabilizarem.
	- Na troca de capítulo: o servidor liga CampaignState.Loading antes de remontar o mundo (milhares de peças) e
	  desliga no fim; a tela só sai depois que o cliente recebeu tudo e os quadros voltaram ao normal.
	Preta, no estilo do jogo, com "CARREGANDO", uma barra que corre e uma dica (das mecânicas novas).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Create = require("../UI/Create")
local Theme = require("../UI/Theme")

local player = Players.LocalPlayer

local LoadingController = {
	Name = "LoadingController",
}

-- Quadros seguidos abaixo de STABLE_DT para considerar que parou de travar; nunca segura mais que MAX_HOLD.
local STABLE_DT = 1 / 24
local STABLE_FRAMES = 10
local MIN_SHOW = 0.8
local MAX_HOLD = 6

local TIPS = {
	"Olhe a fresta antes de entrar num armário: às vezes tem alguém lá dentro.",
	"Quando ele parar na porta do armário, prenda o ar no ritmo do anel.",
	"Luzes do corredor piscando e vento crescendo? Saia da frente ou entre num armário.",
	"No escuro a cabeça pesa. Procure uma vela, uma lamparina ou uma lâmpada acesa.",
	"Se um móvel fugir com a chave, encurrale ele num canto.",
	"Ouça os passos: abafados, ele está em outro andar.",
	"No incêndio, pule as vigas em chamas e não pare no corredor.",
	"Errar um enigma faz barulho. Pense antes de apertar.",
}

local gui: ScreenGui? = nil
local cover: Frame? = nil
local bar: Frame? = nil
local dots: TextLabel? = nil
local tip: TextLabel? = nil
local showing = false
local shownAt = 0
local waitingServer = false
local stableFrames = 0
local rng = Random.new()

local function build()
	local screen = Create("ScreenGui", {
		Name = "Loading",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 130,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local frame = Create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Parent = screen,
	}) :: Frame
	dots = Create("TextLabel", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -64),
		Size = UDim2.fromOffset(320, 30),
		BackgroundTransparency = 1,
		FontFace = Theme.FontBody,
		Text = "CARREGANDO",
		TextColor3 = Color3.fromRGB(230, 226, 218),
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	}) :: TextLabel
	local track = Create("Frame", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -48, 1, -52),
		Size = UDim2.fromOffset(240, 2),
		BackgroundColor3 = Color3.fromRGB(60, 56, 52),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = frame,
	}) :: Frame
	bar = Create("Frame", {
		Size = UDim2.fromScale(0.3, 1),
		BackgroundColor3 = Color3.fromRGB(200, 60, 48),
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	tip = Create("TextLabel", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 48, 1, -52),
		Size = UDim2.new(0.55, 0, 0, 44),
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		Text = "",
		TextColor3 = Color3.fromRGB(170, 164, 156),
		TextSize = 16,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = frame,
	}) :: TextLabel
	gui, cover = screen, frame
end

local function show()
	if not gui then
		build()
	end
	if not showing then
		shownAt = os.clock()
		stableFrames = 0
		local label = tip
		if label then
			label.Text = TIPS[rng:NextInteger(1, #TIPS)]
		end
	end
	showing = true
	local c = cover
	if c then
		c.BackgroundTransparency = 0
		c.Visible = true
	end
	if gui then
		gui.Enabled = true
	end
end

local function hide()
	showing = false
	task.spawn(function()
		local c = cover
		if not c then
			return
		end
		for step = 1, 8 do
			if showing then
				return
			end
			c.BackgroundTransparency = step / 8
			for _, child in c:GetDescendants() do
				if child:IsA("TextLabel") then
					child.TextTransparency = step / 8
				elseif child:IsA("Frame") then
					child.BackgroundTransparency = step / 8
				end
			end
			task.wait(1 / 30)
		end
		if not showing and gui then
			gui.Enabled = false
			for _, child in c:GetDescendants() do
				if child:IsA("TextLabel") then
					child.TextTransparency = 0
				elseif child:IsA("Frame") then
					child.BackgroundTransparency = 0
				end
			end
		end
	end)
end

function LoadingController.isShowing(): boolean
	return showing
end

function LoadingController.Init()
	-- Entrada do jogo: cobre desde o primeiro quadro.
	show()
	waitingServer = true
end

function LoadingController.Start()
	local function watch(state: Instance)
		state:GetAttributeChangedSignal("Loading"):Connect(function()
			if state:GetAttribute("Loading") == true then
				waitingServer = true
				show()
			else
				waitingServer = false
			end
		end)
		waitingServer = state:GetAttribute("Loading") == true
	end
	task.spawn(function()
		local state = ReplicatedStorage:WaitForChild("CampaignState", 30)
		if state then
			watch(state)
		else
			waitingServer = false
		end
	end)
	RunService.RenderStepped:Connect(function(dt: number)
		if not showing then
			return
		end
		local now = os.clock()
		stableFrames = if dt < STABLE_DT then stableFrames + 1 else 0
		local b = bar
		if b then
			b.Position = UDim2.fromScale(((now * 0.8) % 1.3) - 0.3, 0)
		end
		local d = dots
		if d then
			d.Text = "CARREGANDO" .. string.rep(".", math.floor(now * 3) % 4)
		end
		local held = now - shownAt
		local ready = not waitingServer and stableFrames >= STABLE_FRAMES and held >= MIN_SHOW
		if ready or held >= MAX_HOLD + (if waitingServer then 20 else 0) then
			hide()
		end
	end)
end

return LoadingController
