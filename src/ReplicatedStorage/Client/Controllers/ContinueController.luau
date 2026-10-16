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
local Theme = require("../UI/Theme")
local AudioController = require("./AudioController")

local player = Players.LocalPlayer

local Controller = { Name = "ContinueController" }

local panel: Frame? = nil
local primary: TextButton? = nil
local status: TextLabel? = nil
local body: TextLabel? = nil
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
	local p = Create("Frame", {
		Name = "Offer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.fromOffset(600, 150),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
		Create("UIStroke", { Color = Theme.Accent, Thickness = 3 }),
	}) :: Frame
	Create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(18, 12),
		Size = UDim2.new(1, -36, 0, 30),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = "💥 O TUNG TUNG PEGOU O TIME!",
		TextColor3 = Theme.Accent,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	})
	body = Create("TextLabel", {
		Name = "Body",
		Position = UDim2.fromOffset(18, 46),
		Size = UDim2.new(1, -36, 0, 44),
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = 15,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = p,
	}) :: TextLabel
	local b = Create("TextButton", {
		Name = "Continue",
		Position = UDim2.fromOffset(18, 98),
		Size = UDim2.fromOffset(330, 38),
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Good,
		BorderSizePixel = 0,
		FontFace = Theme.Font,
		Text = "",
		TextColor3 = Theme.Ink,
		TextSize = Theme.SizeBody,
		Visible = false,
		Parent = p,
	}, { Create("UICorner", { CornerRadius = Theme.CornerSmall }) }) :: TextButton
	b.Activated:Connect(function()
		AudioController.play("UiBlip", 0.5, 1.1, true)
		task.spawn(useContinue)
	end)
	status = Create("TextLabel", {
		Name = "Status",
		Position = UDim2.fromOffset(360, 98),
		Size = UDim2.new(1, -378, 0, 38),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = Theme.SizeSmall,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	}) :: TextLabel
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
			else
				UserInputService.MouseIconEnabled = mouseWas
			end
		end
		if visible then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			local remaining = math.max(0, math.ceil(Config.Campaign.IntermissionSeconds - (os.clock() - shownAt)))
			text.Text = if remaining > 0
				then `Calma! Todo mundo volta no começo deste capítulo em {remaining}s, de graça. Os capítulos que vocês já terminaram ficam salvos.`
				else "Voltando para o começo do capítulo..."
			local count = stock()
			b.Visible = count > 0 and remaining > 0
			b.Text = `⏩ VOLTAR AGORA (CONTINUAÇÕES: {count})`
		end
	end)
end

return Controller
