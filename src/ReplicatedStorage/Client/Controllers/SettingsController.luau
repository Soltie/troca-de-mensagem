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

local HttpService = game:GetService("HttpService")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Create = require("../UI/Create")

export type Key = "retro" | "vhs" | "bob" | "tilt" | "shake" | "fov" | "flashes" | "haptics"

-- Ordem do menu.
local KEYS: { Key } = { "bob", "tilt", "shake", "fov", "flashes", "retro", "vhs", "haptics" }

-- Tabela "aberta" (chave dinâmica): o tipo Key garante as chaves válidas na API.
local values: { [string]: boolean } = {}
for _, key in KEYS do
	values[key] = (Config.Comfort :: any)[key] ~= false
end
local listeners: { (key: Key, value: boolean) -> () } = {}
local menu: TextLabel? = nil
local buttons: { [string]: TextButton } = {}
local mixes: { [string]: number } = { master = 1, music = 1, effects = 1, breathing = 1, ambient = 1 }
local syncing = false

local function refreshMenu()
	for index, key in KEYS do
		if buttons[key] then
			buttons[key].Text = `[{index}] {(Text.Options :: any)[key]}: {if values[key] then Text.On else Text.Off}`
		end
	end
	local labels =
		{ master = "GERAL", music = "MÚSICA", effects = "EFEITOS", breathing = "RESPIRAÇÃO", ambient = "AMBIENTE" }
	for key, value in mixes do
		if buttons[key] then
			buttons[key].Text = `{labels[key]} {math.floor(value * 100)}%`
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
		DisplayOrder = 90,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	menu = Create("TextLabel", {
		Name = "Options",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 350),
		Text = "CONFORTO E ÁUDIO / O FECHAR",
		BackgroundColor3 = Color3.fromRGB(15, 19, 17),
		BackgroundTransparency = 0.08,
		TextColor3 = Color3.fromRGB(215, 225, 205),
		TextSize = 16,
		Font = Enum.Font.Code,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Visible = false,
		Parent = gui,
	}, { Create("UIPadding", { PaddingLeft = UDim.new(0, 18) }) }) :: TextLabel
	local panel = menu :: TextLabel
	Create("UISizeConstraint", { MaxSize = Vector2.new(640, 350), Parent = panel })
	local function option(key: string, index: number, column: number, callback: () -> ())
		local button = Create("TextButton", {
			Name = key,
			Modal = true,
			Parent = panel,
			Position = UDim2.new(column * 0.5, 4, 0, 38 + (index - 1) * 34),
			Size = UDim2.new(0.5, -15, 0, 30),
			BackgroundColor3 = Color3.fromRGB(30, 35, 31),
			TextColor3 = Color3.fromRGB(230, 216, 180),
			TextSize = 12,
			TextWrapped = true,
			Font = Enum.Font.Code,
			Text = key,
		}) :: TextButton
		buttons[key] = button
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
	buttons.close.Text = "FECHAR"
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
