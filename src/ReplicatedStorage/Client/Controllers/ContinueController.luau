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
local Components = require("../UI/Components")
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
	-- Cartão da derrota: tom calmo (terror leve), contagem visível e nenhuma oferta de compra.
	local p = Components.panel({
		Name = "Offer",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(1, -32, 0, 176),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = gui,
	}, {
		Create("UISizeConstraint", { MaxSize = Vector2.new(620, 220) }),
	})
	local outline = p:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color, outline.Thickness, outline.Transparency = Theme.Danger:Lerp(Theme.Gold, 0.4), 2, 0
	end
	Components.padding(p, 16, 14)
	Components.icon(p, "Replay", 36, Theme.GoldLight)
	Components.title({
		Name = "Title",
		Position = UDim2.fromOffset(48, 0),
		Size = UDim2.new(1, -48, 0, 36),
		Text = "O TUNG TUNG PEGOU O TIME!",
		TextColor3 = Theme.GoldLight,
		TextSize = 24,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Parent = p,
	})
	body = Components.text({
		Name = "Body",
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 40),
		FontFace = Theme.FontNote,
		Text = "",
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = p,
	}) :: TextLabel
	local track, setTrack = Components.progress({
		Name = "Countdown",
		Position = UDim2.fromOffset(0, 88),
		Size = UDim2.new(1, 0, 0, 8),
	}, Theme.Gold)
	track.Parent = p
	setCountdown = setTrack
	local b = Components.button("success", {
		Name = "Continue",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.6, -6, 0, Theme.TouchMin),
		Text = "",
		TextSize = 15,
		Visible = false,
		Parent = p,
	}, function()
		AudioController.play("UiBlip", 0.5, 1.1, true)
		task.spawn(useContinue)
	end)
	b.Modal = true
	status = Components.text({
		Name = "Status",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.4, -6, 0, Theme.TouchMin),
		FontFace = Theme.Font,
		Text = "",
		TextSize = 13,
		TextColor3 = Theme.TextSecondary,
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
			local fill = setCountdown
			if fill then
				-- Barra esvazia até o recomeço grátis (mesma contagem do texto).
				fill(remaining / math.max(Config.Campaign.IntermissionSeconds, 1))
			end
			local count = stock()
			b.Visible = count > 0 and remaining > 0
			-- Sem Continuação no estoque não há botão: o cartão encolhe em vez de sobrar espaço vazio.
			p.Size = UDim2.new(1, -32, 0, if b.Visible then 176 else 124)
			b.Text = `VOLTAR AGORA · CONTINUAÇÕES: {count}`
		end
	end)
end

return Controller
