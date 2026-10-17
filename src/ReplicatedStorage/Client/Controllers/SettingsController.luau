--!strict
--[[
	Opções de conforto do jogador (só no cliente, por sessão). Valores iniciais em Config.Comfort.
	  retro    scanlines, granulação, vinheta fixa            (atalho V)
	  vhs      carimbo de hora, tracking, aberração cromática
	  bob      balanço ao andar e respiração parada           (atalho B liga/desliga bob+tilt+shake)
	  tilt     inclinação lateral
	  shake    tremores
	  fov      FOV dinâmico (corrida, medo, susto)
	  flashes  clarões e falhas de tela fortes
	  haptics  vibração do controle
	O menu (tecla O) fica no GameUiController; os outros controllers leem com get().
]]

local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HttpService = game:GetService("HttpService")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")

export type Key = "retro" | "vhs" | "bob" | "tilt" | "shake" | "fov" | "flashes" | "haptics"

-- Ordem do menu.
local KEYS: { Key } = { "bob", "tilt", "shake", "fov", "flashes", "retro", "vhs", "haptics" }

-- Tabela "aberta" (chave dinâmica): o tipo Key garante as chaves válidas na API.
local values: { [string]: boolean } = {}
for _, key in KEYS do
	values[key] = (Config.Comfort :: any)[key] ~= false
end
local listeners: { (key: Key, value: boolean) -> () } = {}
local menu: Frame? = nil
local buttons: { [string]: TextButton } = {}
local mixes: { [string]: number } = { master = 1, music = 1, effects = 1, breathing = 1, ambient = 1 }
local syncing = false

local ON_COLOR = Color3.fromRGB(70, 190, 110)
local OFF_COLOR = Color3.fromRGB(70, 60, 96)

local function refreshMenu()
	for index, key in KEYS do
		local button = buttons[key]
		if button then
			button.Text = `{index}  {(Text.Options :: any)[key]}: {if values[key] then Text.On else Text.Off}`
			button.BackgroundColor3 = if values[key] then ON_COLOR else OFF_COLOR
		end
	end
	local labels = {
		master = "🔊 GERAL",
		music = "🎵 MÚSICA",
		effects = "💥 EFEITOS",
		breathing = "😮‍💨 RESPIRAÇÃO",
		ambient = "🌙 AMBIENTE",
	}
	for key, value in mixes do
		local button = buttons[key]
		if button then
			button.Text = `{labels[key]} {math.floor(value * 100)}%`
			button.BackgroundColor3 = if value > 0 then Theme.PanelLight else OFF_COLOR
		end
	end
end

local SettingsController = {
	Name = "SettingsController",
	KEYS = KEYS,
}

function SettingsController.toggleMenu()
	if menu then
		menu.Visible = not menu.Visible
		Players.LocalPlayer:SetAttribute("ComfortMenuOpen", menu.Visible)
	end
end
function SettingsController.get(key: Key): boolean
	return values[key]
end

function SettingsController.set(key: Key, value: boolean)
	if values[key] == value then
		return
	end
	values[key] = value
	if not syncing then
		Remotes.clientEvent("SetHousePreference"):FireServer(key, if value then 1 else 0)
	end
	refreshMenu()
	for _, listener in listeners do
		task.spawn(listener, key, value)
	end
end

function SettingsController.toggle(key: Key): boolean
	SettingsController.set(key, not values[key])
	return values[key]
end

-- Atalho B: movimento de câmera inteiro (balanço, inclinação e tremor) de uma vez.
function SettingsController.toggleMotion(): boolean
	local next = not (values["bob"] or values["tilt"] or values["shake"])
	SettingsController.set("bob", next)
	SettingsController.set("tilt", next)
	SettingsController.set("shake", next)
	return next
end

function SettingsController.motionEnabled(): boolean
	return values["bob"] or values["tilt"] or values["shake"]
end

function SettingsController.onChanged(listener: (key: Key, value: boolean) -> ())
	table.insert(listeners, listener)
end

function SettingsController.Init()
	local gui = Create("ScreenGui", {
		Name = "ComfortOptions",
		ResetOnSpawn = false,
		DisplayOrder = 250,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local safe = Create(
		"Frame",
		{ Name = "SafeArea", Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }
	) :: Frame
	local panel = Create("Frame", {
		Name = "Options",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 420),
		BackgroundColor3 = Theme.Panel,
		BackgroundTransparency = 0.04,
		Visible = false,
		Parent = safe,
	}, {
		Create("UICorner", { CornerRadius = Theme.Corner }),
		Create("UIStroke", { Color = Theme.Stroke, Thickness = 3 }),
		Create("UISizeConstraint", { MaxSize = Vector2.new(680, 600) }),
	}) :: Frame
	menu = panel
	Create("TextLabel", {
		Name = "Title",
		Position = UDim2.fromOffset(20, 12),
		Size = UDim2.new(1, -140, 0, 34),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextSize = 26,
		TextColor3 = Theme.Hazard,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "⚙️ AJUSTES",
		Parent = panel,
	})
	Create("TextLabel", {
		Name = "Hint",
		Position = UDim2.fromOffset(20, 46),
		Size = UDim2.new(1, -40, 0, 18),
		BackgroundTransparency = 1,
		FontFace = Theme.FontNote,
		TextSize = 13,
		TextColor3 = Theme.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "Toque para alternar. Volume: cada toque baixa 25%.",
		Parent = panel,
	})
	local scroll = Create("ScrollingFrame", {
		Name = "OptionsScroll",
		Parent = panel,
		Position = UDim2.fromOffset(12, 74),
		Size = UDim2.new(1, -24, 1, -86),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}) :: ScrollingFrame
	local entries: { TextButton } = {}
	local function option(key: string, index: number, column: number, callback: () -> ())
		local button = Create("TextButton", {
			Name = key,
			Modal = true,
			Parent = scroll,
			Position = UDim2.new(column * 0.5, if column == 0 then 16 else 6, 0, 74 + (index - 1) * 40),
			Size = UDim2.new(0.5, -22, 0, 34),
			BackgroundColor3 = OFF_COLOR,
			TextColor3 = Theme.Text,
			TextSize = 14,
			TextWrapped = true,
			FontFace = Theme.Font,
			AutoButtonColor = true,
			Text = key,
		}, { Create("UICorner", { CornerRadius = Theme.CornerSmall }) }) :: TextButton
		buttons[key] = button
		table.insert(entries, button)
		button.Activated:Connect(callback)
	end
	for index, key in KEYS do
		option(key, index, 0, function()
			SettingsController.toggle(key :: Key)
		end)
	end
	for index, key in { "master", "music", "effects", "breathing", "ambient" } do
		option(key, index, 1, function()
			mixes[key] = if mixes[key] <= 0 then 1 else math.max(0, mixes[key] - 0.25)
			Players.LocalPlayer:SetAttribute("Mix_" .. key, mixes[key])
			Remotes.clientEvent("SetHousePreference"):FireServer(key, mixes[key])
			refreshMenu()
		end)
	end
	option("close", 8, 1, function()
		panel.Visible = false
		Players.LocalPlayer:SetAttribute("ComfortMenuOpen", false)
	end)
	buttons.close.Text = "✖ FECHAR"
	buttons.close.BackgroundColor3 = Theme.Accent
	buttons.close.Parent = panel
	buttons.close.Position, buttons.close.Size = UDim2.new(1, -110, 0, 10), UDim2.fromOffset(96, 44)
	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		panel.Size = UDim2.new(0.94, 0, 0, math.max(180, math.min(600, safe.AbsoluteSize.Y - 20)))
		local columns = if panel.AbsoluteSize.X >= 560 then 2 else 1
		for index, b in entries do
			if b ~= buttons.close then
				local row, column = math.floor((index - 1) / columns), (index - 1) % columns
				b.Position, b.Size = UDim2.new(column / columns, 0, 0, row * 52), UDim2.new(1 / columns, -8, 0, 44)
			end
		end
		scroll.CanvasSize = UDim2.fromOffset(0, math.ceil((#entries - 1) / columns) * 52)
	end)
	refreshMenu()
end

function SettingsController.Start()
	local function load()
		local raw = Players.LocalPlayer:GetAttribute("HousePreferences")
		if type(raw) ~= "string" then
			return
		end
		local ok, prefs = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then
			return
		end
		syncing = true
		for _, key in KEYS do
			if prefs[key] ~= nil then
				SettingsController.set(key :: Key, prefs[key] >= 0.5)
			end
		end
		syncing = false
		for key in mixes do
			if type(prefs[key]) == "number" then
				mixes[key] = prefs[key]
				Players.LocalPlayer:SetAttribute("Mix_" .. key, mixes[key])
			end
		end
		refreshMenu()
	end
	Players.LocalPlayer:GetAttributeChangedSignal("HousePreferences"):Connect(load)
	load()
	ContextActionService:BindAction("HouseOptionsTouch", function(_, state)
		if state == Enum.UserInputState.Begin and menu then
			menu.Visible = not menu.Visible
			Players.LocalPlayer:SetAttribute("ComfortMenuOpen", menu.Visible)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonR3)

	-- O também é zoom da câmera padrão; InputBegan chega processado e perdia o atalho.
	ContextActionService:BindActionAtPriority("S9ComfortOptions", function(_, state)
		if UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and menu then
			menu.Visible = not menu.Visible
			Players.LocalPlayer:SetAttribute("ComfortMenuOpen", menu.Visible)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.O)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.V then
			SettingsController.toggle("retro")
		elseif input.KeyCode == Enum.KeyCode.B then
			SettingsController.toggleMotion()
		elseif menu and menu.Visible then
			local numberKeys = {
				Enum.KeyCode.One,
				Enum.KeyCode.Two,
				Enum.KeyCode.Three,
				Enum.KeyCode.Four,
				Enum.KeyCode.Five,
				Enum.KeyCode.Six,
				Enum.KeyCode.Seven,
				Enum.KeyCode.Eight,
			}
			local index = table.find(numberKeys, input.KeyCode)
			if index then
				SettingsController.toggle(KEYS[index])
			end
		end
	end)
end

return SettingsController
