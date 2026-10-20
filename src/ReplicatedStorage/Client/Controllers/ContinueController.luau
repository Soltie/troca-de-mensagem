--!strict
--[[
	Tela de derrota da campanha (co-op e história). O servidor já repete o capítulo DE GRAÇA,
	sozinho, depois de alguns segundos (CampaignRuntime). Esta tela deixa isso claro com uma contagem.

	Quem já tem Continuação no estoque (ganha em kits/recompensas) pode voltar na hora, sem esperar
	("use_continue"). Não há botão de compra aqui: derrota não é momento de vender nada para criança.
	Quem valida a derrota e reabre a etapa é o servidor (CampaignRuntime via StoreService).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Create = require("../UI/Create")
local Juice = require("../UI/Juice")
local Noir = require("../UI/NoirHud")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local GameUiController = require("./GameUiController")
local JumpscareController = require("./JumpscareController")
local ThreatFeedbackController = require("./ThreatFeedbackController")

local player = Players.LocalPlayer

local Controller = { Name = "ContinueController" }

local panel: Frame? = nil
local primary: TextButton? = nil
local status: TextLabel? = nil
local body: TextLabel? = nil
local setCountdown: ((number) -> ())? = nil
local busy = false
local shown = false
local shownAt = 0
local mouseWas = false

local function stock(): number
	local raw = player:GetAttribute("Consumables")
	if type(raw) ~= "string" then
		return 0
	end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	return if ok and type(data) == "table" then tonumber(data.continuar) or 0 else 0
end

local function say(key: string?)
	if status then
		status.Text = if key then (Text.Messages :: any)[key] or key else ""
	end
end

local function useContinue()
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Remotes.clientFunction("Store", 5):InvokeServer("use_continue")
	end)
	busy = false
	if not ok or type(result) ~= "table" or not result.ok then
		say("store_error")
		return
	end
	local data = result.data
	if type(data) == "table" then
		say(data.message)
		if data.ok then
			AudioController.play("StingerAwaken", 0.6, 1.2, true)
		end
	end
end

local function build()
	local gui = Create("ScreenGui", {
		Name = "ContinueOffer",
		ResetOnSpawn = false,
		DisplayOrder = 70,
		IgnoreGuiInset = true,
		Parent = player:WaitForChild("PlayerGui"),
	})
	-- Derrota no estilo do HUD (NoirHud): faixa escura em degradê no rodapé, título fino espaçado, texto discreto,
	-- linha fina da contagem e o botão como texto. Tom calmo e nenhuma oferta de compra.
	local p = Create("Frame", {
		Name = "Offer",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 230),
		BackgroundColor3 = Noir.Ink,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		Create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.45, 0.35),
				NumberSequenceKeypoint.new(1, 0.08),
			}),
		}),
	}) :: Frame
	local function label(name: string, size: number, color: Color3, y: number, height: number): TextLabel
		return Create("TextLabel", {
			Name = name,
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y),
			Size = UDim2.new(0.8, 0, 0, height),
			BackgroundTransparency = 1,
			FontFace = Noir.SansLight,
			TextSize = size,
			TextColor3 = color,
			TextWrapped = true,
			Text = "",
			Parent = p,
		}) :: TextLabel
	end
	local title = label("Title", 22, Noir.Paper, 70, 30)
	title.Text = Noir.spaced("O TUNG TUNG PEGOU O TIME", "\u{2009}\u{2009}")
	body = label("Body", 14, Noir.TextDim, 108, 40)
	-- Linha fina da contagem (esvazia até o recomeço grátis).
	local track = Create("Frame", {
		Name = "Countdown",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 156),
		Size = UDim2.fromOffset(260, 2),
		BackgroundColor3 = Noir.Paper,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Parent = p,
	})
	local fillBar = Create("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Noir.Paper,
		BorderSizePixel = 0,
		Parent = track,
	}) :: Frame
	setCountdown = function(alpha: number)
		fillBar.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
	end
	local b = Create("TextButton", {
		Name = "Continue",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 172),
		Size = UDim2.fromOffset(360, 36),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		FontFace = Noir.SansMedium,
		TextSize = 12,
		TextColor3 = Noir.Paper,
		Text = "",
		Visible = false,
		Parent = p,
	}) :: TextButton
	b.Activated:Connect(function()
		AudioController.play("UiBlip", 0.5, 1.1, true)
		task.spawn(useContinue)
	end)
	b.Modal = true
	status = label("Status", 12, Noir.TextDim, 206, 18)
	panel = p
	primary = b
end

function Controller.debugState(): { [string]: any }
	return { shown = shown, stock = stock() }
end

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState")
	build()
	RunService.RenderStepped:Connect(function()
		local p, b, text = panel, primary, body
		if not p or not b or not text then
			return
		end
		local visible = state:GetAttribute("Phase") == "Lost" and player:GetAttribute("CinematicActive") ~= true
		if visible ~= shown then
			shown = visible
			p.Visible = visible
			if visible then
				say(nil)
				shownAt = os.clock()
				mouseWas = UserInputService.MouseIconEnabled
				Juice.appear(p)
				-- Sem legenda velha por cima do texto da derrota.
				GameUiController.muteCaptions(true)
			else
				UserInputService.MouseIconEnabled = mouseWas
				GameUiController.muteCaptions(false)
				if CameraController.isCapturing() then
					CameraController.reset()
				end
			end
		end
		if visible then
			-- Olha o Tung de pé, de um ponto sem parede no meio (caído, a câmera ficava no tapete: o "quadrado
			-- verde"). A captura normal acaba em ~1,5 s e devolve a câmera ao chão; aqui ela volta a olhar. O susto 3D
			-- tem a câmera dele.
			if not CameraController.isCapturing() and not JumpscareController.recent(2.6) then
				CameraController.capture(ThreatFeedbackController.creatureHead)
			end
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			local remaining = math.max(0, math.ceil(Config.Campaign.IntermissionSeconds - (os.clock() - shownAt)))
			text.Text = if remaining > 0
				then `Calma! Todo mundo volta no começo deste capítulo em {remaining}s, de graça. Os capítulos que vocês já terminaram ficam salvos.`
				else "Voltando para o começo do capítulo..."
			local fill = setCountdown
			if fill then
				-- Barra esvazia até o recomeço grátis (mesma contagem do texto).
				fill(remaining / math.max(Config.Campaign.IntermissionSeconds, 1))
			end
			local count = stock()
			b.Visible = count > 0 and remaining > 0
			b.Text = `{Noir.spaced("VOLTAR AGORA")}      ·      {count}`
		end
	end)
end

return Controller
