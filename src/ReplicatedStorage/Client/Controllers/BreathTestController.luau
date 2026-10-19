--!strict
--[[
	Revista do armário (ideia C; regras em Shared/Game/BreathTest, servidor em LockerSearchService). Enquanto o
	Tung Tung está parado na porta: um anel fecha sobre o círculo no centro da tela e o jogador aperta (Espaço, Z,
	clique, toque ou botão do controle) quando ele encosta. As bolinhas embaixo mostram acertos e erros; três erros
	e ele abre a porta. Cada batida soa como o coração; errar solta o ar (alto) e a porta sacode.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local BreathTest = require("@game/ReplicatedStorage/Shared/Game/BreathTest")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local SettingsController = require("./SettingsController")

local player = Players.LocalPlayer

local BreathTestController = {
	Name = "BreathTestController",
}

local TARGET = 120
local RING_SPEED = 190
local HIT = Color3.fromRGB(200, 236, 255)
local MISS = Color3.fromRGB(255, 70, 60)

local gui: ScreenGui? = nil
local ring: Frame? = nil
local ringStroke: UIStroke? = nil
local circleStroke: UIStroke? = nil
local dots: { Frame } = {}
local tapButton: TextButton? = nil
local running = false
local startAt = 0
local times: { number } = {}
local lastScore = ""
local nextThump = 1
local lastPressAt = 0

local function press()
	-- Um aperto por vez (clique e toque juntos não contam duas batidas).
	local now = os.clock()
	if not running or now - lastPressAt < 0.15 then
		return
	end
	lastPressAt = now
	task.spawn(function()
		local ok, remote = pcall(Remotes.clientEvent, "BreathPress", 5)
		if ok then
			remote:FireServer(workspace:GetServerTimeNow())
		end
	end)
	-- Resposta imediata: o círculo pisca.
	local stroke = circleStroke
	if stroke then
		stroke.Thickness = 9
	end
end

local function bind()
	ContextActionService:BindActionAtPriority(
		"BreathTestPress",
		function(_, state)
			if state == Enum.UserInputState.Begin then
				press()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value + 3000,
		Enum.KeyCode.Space,
		Enum.KeyCode.Z,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonR1,
		Enum.KeyCode.ButtonL1,
		Enum.UserInputType.MouseButton1
	)
end

local function build()
	local screen = Create("ScreenGui", {
		Name = "BreathTest",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 20,
		Enabled = false,
		Parent = player:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	Create("TextLabel", {
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, -250),
		Size = UDim2.fromOffset(600, 34),
		BackgroundTransparency = 1,
		FontFace = Theme.FontBody,
		Text = "ELE ESTÁ NA PORTA. PRENDA O AR NO RITMO.",
		TextColor3 = Color3.fromRGB(235, 235, 235),
		TextSize = 22,
		Parent = screen,
	})
	Create("TextLabel", {
		Name = "Hint",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, -216),
		Size = UDim2.fromOffset(600, 24),
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		Text = "Aperte Z, ESPAÇO ou clique (toque no celular) quando o anel encostar no círculo",
		TextColor3 = Color3.fromRGB(190, 190, 190),
		TextSize = 16,
		Parent = screen,
	})
	local circle = Create("Frame", {
		Name = "Circle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TARGET, TARGET),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.55,
		Parent = screen,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	}) :: Frame
	local cStroke = Create("UIStroke", { Color = HIT, Thickness = 4, Parent = circle }) :: UIStroke
	circleStroke = cStroke
	local moving = Create("Frame", {
		Name = "Ring",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(TARGET * 3, TARGET * 3),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
	}) :: Frame
	ringStroke = Create("UIStroke", { Color = MISS, Thickness = 3, Parent = moving }) :: UIStroke
	ring = moving
	local row = Create("Frame", {
		Name = "Score",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.5, 200),
		Size = UDim2.fromOffset(BreathTest.Beats * 30, 18),
		BackgroundTransparency = 1,
		Parent = screen,
	}, {
		Create("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 12),
		}),
	})
	for index = 1, BreathTest.Beats do
		local dot = Create("Frame", {
			Name = `Dot{index}`,
			LayoutOrder = index,
			Size = UDim2.fromOffset(16, 16),
			BackgroundColor3 = Color3.fromRGB(70, 70, 70),
			Parent = row,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0.5, 0) }),
		}) :: Frame
		table.insert(dots, dot)
	end
	-- Celular: a tela inteira vira o botão.
	local tap = Create("TextButton", {
		Name = "Tap",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		Parent = screen,
	}) :: TextButton
	tap.Activated:Connect(press)
	tapButton = tap
	gui = screen
end

local function stop()
	running = false
	ContextActionService:UnbindAction("BreathTestPress")
	if gui then
		gui.Enabled = false
	end
	if tapButton then
		tapButton.Visible = false
	end
end

local function begin()
	local at = player:GetAttribute("BreathTestAt")
	local seed = player:GetAttribute("BreathTestSeed")
	if type(at) ~= "number" or type(seed) ~= "number" then
		stop()
		return
	end
	if not gui then
		build()
	end
	startAt, times, lastScore, nextThump = at, BreathTest.times(seed), "", 1
	running = true
	for _, dot in dots do
		dot.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
	end
	if gui then
		gui.Enabled = true
	end
	if tapButton then
		tapButton.Visible = UserInputService.TouchEnabled
	end
	bind()
	-- Ele chegou: a maçaneta mexe.
	AudioController.play("DoorRattle", 1, 0.85)
	if SettingsController.get("shake") then
		CameraController.addTrauma(0.35)
	end
end

local function showScore(score: string)
	for index = 1, math.min(#score, #dots) do
		local mark = string.sub(score, index, index)
		local before = string.sub(lastScore, index, index)
		if mark == "H" then
			dots[index].BackgroundColor3 = HIT
		elseif mark == "M" then
			dots[index].BackgroundColor3 = MISS
			if before ~= "M" then
				-- Soltou o ar: alto, e a porta sacode.
				AudioController.play("Gasp", 0.8)
				AudioController.play("DoorRattle", 0.9, 1.1)
				if SettingsController.get("shake") then
					CameraController.addTrauma(0.3)
				end
			end
		end
	end
	lastScore = score
end

local function update(dt: number)
	if not running then
		return
	end
	local elapsed = workspace:GetServerTimeNow() - startAt
	local score = player:GetAttribute("BreathTestScore")
	if type(score) == "string" and score ~= lastScore then
		showScore(score)
	end
	-- Próxima batida pendente: o anel fecha sobre ela.
	local pending: number? = nil
	if type(score) == "string" then
		for index = 1, #times do
			if string.sub(score, index, index) == "-" then
				pending = index
				break
			end
		end
	end
	local r, rs = ring, ringStroke
	if r and rs then
		if pending then
			local size = TARGET + math.max(0, times[pending] - elapsed) * RING_SPEED
			r.Size = UDim2.fromOffset(size, size)
			local near = math.abs(times[pending] - elapsed) <= BreathTest.Window
			rs.Color = if near then HIT else MISS
			rs.Transparency = math.clamp((size - TARGET) / (RING_SPEED * 1.4), 0, 0.85)
			r.Visible = true
		else
			r.Visible = false
		end
	end
	local cs = circleStroke
	if cs then
		cs.Thickness += (4 - cs.Thickness) * math.min(1, dt * 10)
	end
	-- O coração bate em cada batida.
	if nextThump <= #times and elapsed >= times[nextThump] then
		nextThump += 1
		AudioController.play("Heartbeat", 0.9, 1.3)
	end
end

function BreathTestController.Start()
	player:GetAttributeChangedSignal("BreathTestAt"):Connect(function()
		if type(player:GetAttribute("BreathTestAt")) == "number" then
			begin()
		else
			-- Mostra o placar final por um instante antes de sumir.
			local score = player:GetAttribute("BreathTestScore")
			if type(score) == "string" then
				showScore(score)
			end
			running = false
			ContextActionService:UnbindAction("BreathTestPress")
			task.delay(0.8, function()
				if not running then
					stop()
				end
			end)
		end
	end)
	RunService.Heartbeat:Connect(update)
end

return BreathTestController
