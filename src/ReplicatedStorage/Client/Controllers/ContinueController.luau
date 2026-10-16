--!strict
--[[
	Oferta de Continuação na derrota da campanha (co-op e história): a equipe repete a etapa perdida
	em vez de voltar ao menu. Qualquer integrante pode usar.

	  Tem Continuação no estoque -> "USAR CONTINUAÇÃO" (Store "use_continue").
	  Não tem -> "CONTINUAR · R$" compra o produto continuar_1; quando a unidade entra no estoque
	  (Studio: na hora; ao vivo: depois do recibo), usa sozinho.
	Quem valida a derrota e reabre a etapa é o servidor (CampaignRuntime via StoreService).
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local StoreCatalog = require("@game/ReplicatedStorage/Shared/Game/StoreCatalog")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local AudioController = require("./AudioController")

local player = Players.LocalPlayer
local PRODUCT = "continuar_1"
-- Depois de pedir a compra, usa sozinho se a unidade chegar dentro deste prazo (s).
local PENDING_SECONDS = 90

local Controller = { Name = "ContinueController" }

local panel: Frame? = nil
local primary: TextButton? = nil
local status: TextLabel? = nil
local busy = false
local pendingUntil = 0
local shown = false
local mouseWas = false

local function px(value: string): string
	return PixelText.normalize(value)
end

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
		status.Text = px(if key then (Text.Messages :: any)[key] or key else "")
	end
end

local function request(action: string, arg: string?): any
	if busy then
		return nil
	end
	busy = true
	local ok, result = pcall(function()
		return Remotes.clientFunction("Store", 5):InvokeServer(action, arg)
	end)
	busy = false
	if not ok or type(result) ~= "table" or not result.ok then
		say("store_error")
		return nil
	end
	local data = result.data
	if type(data) == "table" then
		say(data.message)
	end
	return data
end

local function useContinue()
	local data = request("use_continue")
	if type(data) == "table" and data.ok then
		pendingUntil = 0
		AudioController.play("StingerAwaken", 0.6, 1.2, true)
	end
end

local function onPrimary()
	if stock() > 0 then
		useContinue()
		return
	end
	local data = request("buy_product", PRODUCT)
	if type(data) == "table" and data.ok then
		pendingUntil = os.clock() + PENDING_SECONDS
		-- Studio: a compra simulada já entregou; usa na hora.
		if stock() > 0 then
			useContinue()
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
		Size = UDim2.fromOffset(600, 132),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.05,
		BorderSizePixel = 0,
		Visible = false,
		Parent = gui,
	}, {
		Create("UIStroke", { Color = Theme.Hazard, Thickness = 2 }),
	}) :: Frame
	Create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.new(1, -32, 0, 24),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		Text = px("A EQUIPE CAIU. CONTINUAR DESTA ETAPA?"),
		TextColor3 = Theme.Hazard,
		TextSize = Theme.SizeLarge,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = p,
	})
	Create("TextLabel", {
		Name = "Body",
		Position = UDim2.fromOffset(16, 36),
		Size = UDim2.new(1, -32, 0, 34),
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		Text = "Todos voltam no começo da etapa perdida, com o progresso das anteriores. Ou vote [R] para recomeçar a campanha.",
		TextColor3 = Theme.TextDim,
		TextSize = 14,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = p,
	})
	local b = Create("TextButton", {
		Name = "Continue",
		Position = UDim2.fromOffset(16, 80),
		Size = UDim2.fromOffset(330, 38),
		AutoButtonColor = true,
		BackgroundColor3 = Color3.fromRGB(28, 44, 30),
		BorderSizePixel = 0,
		FontFace = Theme.Font,
		Text = "",
		TextColor3 = Theme.Text,
		TextSize = Theme.SizeBody,
		Parent = p,
	}, {
		Create("UIStroke", { Color = Color3.fromRGB(120, 200, 140), Thickness = 1 }),
	}) :: TextButton
	b.Activated:Connect(function()
		AudioController.play("UiBlip", 0.5, 1.1, true)
		task.spawn(onPrimary)
	end)
	status = Create("TextLabel", {
		Name = "Status",
		Position = UDim2.fromOffset(356, 80),
		Size = UDim2.new(1, -372, 0, 38),
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
	return { shown = shown, stock = stock(), pending = pendingUntil > os.clock() }
end

function Controller.Start()
	if GameState.wait():GetAttribute("CampaignActive") ~= true then
		return
	end
	local state = ReplicatedStorage:WaitForChild("CampaignState")
	build()
	-- Compra real confirmada depois do recibo: a unidade entra no estoque e é usada sozinha.
	player:GetAttributeChangedSignal("Consumables"):Connect(function()
		if pendingUntil > os.clock() and shown and stock() > 0 then
			task.spawn(useContinue)
		end
	end)
	local product = StoreCatalog.ProductByKey[PRODUCT]
	RunService.RenderStepped:Connect(function()
		local p, b = panel, primary
		if not p or not b then
			return
		end
		local visible = state:GetAttribute("Phase") == "Lost" and player:GetAttribute("CinematicActive") ~= true
		if visible ~= shown then
			shown = visible
			p.Visible = visible
			if visible then
				say(nil)
				mouseWas = UserInputService.MouseIconEnabled
			else
				UserInputService.MouseIconEnabled = mouseWas
				pendingUntil = 0
			end
		end
		if visible then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
			local count = stock()
			b.Text = px(
				if count > 0
					then `USAR CONTINUAÇÃO (VOCÊ TEM {count})`
					else `CONTINUAR · R$ {if product then product.robux else 49}`
			)
		end
	end)
end

return Controller
