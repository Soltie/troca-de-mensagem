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
local Components = require("../UI/Components")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local Quality = require("@game/ReplicatedStorage/Shared/Game/VisualQuality")
local Preferences = require("@game/ReplicatedStorage/Shared/Game/HousePreferences")
local Logger = require("@game/ReplicatedStorage/Shared/Logger")
local log = Logger.new("VisualQA")

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
local shaders = true
local visualQuality = 0
local autoLevel = 2
local status: TextLabel? = nil
local pending: { [string]: number } = {}
local acknowledged: { [string]: number } = {}
local qualityNames = { [0] = "Automática", [0.25] = "Baixa", [0.5] = "Média", [1] = "Alta" }

local function refreshMenu()
	for index, key in KEYS do
		local button = buttons[key]
		if button then
			-- [n] = atalho numérico do teclado; o estado também vem por texto, não só por cor.
			button.Text = `[{index}] {(Text.Options :: any)[key]}: {if values[key] then Text.On else Text.Off}`
			Components.setVariant(button, if values[key] then "success" else "secondary")
		end
	end
	local labels = {
		master = "VOLUME GERAL",
		music = "MÚSICA",
		effects = "EFEITOS",
		breathing = "RESPIRAÇÃO",
		ambient = "AMBIENTE",
	}
	for key, value in mixes do
		local button = buttons[key]
		if button then
			button.Text = `{labels[key]} {math.floor(value * 100)}%`
			local fill = button:FindFirstChild("Fill", true)
			if fill and fill:IsA("Frame") then
				fill.Size = UDim2.fromScale(math.clamp(value, 0, 1), 1)
			end
		end
	end
	if buttons.shaders then
		buttons.shaders.Text = `EFEITOS DE LUZ (SHADERS): {if shaders then "LIGADO" else "DESLIGADO"}`
		Components.setVariant(buttons.shaders, if shaders then "success" else "secondary")
	end
	if buttons.quality then
		-- string.upper não converte letras acentuadas (UTF-8): nomes já em maiúsculas.
		local upper = { [0] = "AUTOMÁTICA", [0.25] = "BAIXA", [0.5] = "MÉDIA", [1] = "ALTA" }
		buttons.quality.Text = `QUALIDADE VISUAL: {upper[visualQuality] or qualityNames[visualQuality]}`
	end
	if status then
		local saved = Players.LocalPlayer:GetAttribute("HousePreferencesSaved")
		local current = Players.LocalPlayer:GetAttribute("HousePreferences")
		status.Text = if next(pending)
			then "Aplicado localmente · aguardando servidor"
			elseif saved ~= nil and saved == current then (if Players.LocalPlayer:GetAttribute(
					"HousePreferencesSaveMode"
				) == "mock"
				then "Salvo na simulação local do Studio"
				else "Preferências salvas")
			else "Aplicado · aceito na sessão; aguardando salvamento"
	end
end

local SettingsController = {
	Name = "SettingsController",
	KEYS = KEYS,
}

function SettingsController.visualBudget(): Quality.Budget
	return Quality.budget(Quality.resolve(visualQuality, false, autoLevel), shaders)
end
function SettingsController.shadersEnabled(): boolean
	return shaders
end
function SettingsController.setVisual(key: string, value: number)
	if (key ~= "shaders" and key ~= "quality") or not Preferences.valid(key, value) then
		return
	end
	if key == "shaders" then
		shaders = value == 1
	else
		visualQuality = value
	end
	if not syncing then
		if acknowledged[key] ~= value then
			pending[key] = value
			Remotes.clientEvent("SetHousePreference"):FireServer(key, value)
		else
			pending[key] = nil
		end
	end
	Players.LocalPlayer:SetAttribute("VisualQualityApplied", SettingsController.visualBudget().name)
	Players.LocalPlayer:SetAttribute("ShadersApplied", shaders)
	refreshMenu()
end

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
		pending[key] = if value then 1 else 0
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
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
	local safe = Create(
		"Frame",
		{ Name = "SafeArea", Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }
	) :: Frame
	local panel = Components.panel({
		Name = "Options",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.92, 0, 0, 420),
		BackgroundColor3 = Theme.Bg,
		BackgroundTransparency = 0.03,
		Visible = false,
		Parent = safe,
	}, {
		Create("UISizeConstraint", { MaxSize = Vector2.new(760, 640) }),
	})
	local outline = panel:FindFirstChildOfClass("UIStroke")
	if outline then
		outline.Color, outline.Transparency = Theme.Gold, 0.45
	end
	menu = panel
	Components.icon(panel, "Settings", 24, Theme.Gold, { Position = UDim2.fromOffset(18, 18) })
	Components.title({
		Name = "Title",
		Position = UDim2.fromOffset(50, 12),
		Size = UDim2.new(1, -200, 0, 34),
		TextSize = 26,
		TextColor3 = Theme.GoldLight,
		Text = "AJUSTES",
		Parent = panel,
	})
	Components.text({
		Name = "Hint",
		Position = UDim2.fromOffset(18, 48),
		Size = UDim2.new(1, -36, 0, 18),
		FontFace = Theme.FontNote,
		TextSize = 13,
		TextColor3 = Theme.TextSecondary,
		Text = "Toque numa opção para mudar. Pistas e sinais de perigo continuam visíveis em qualquer qualidade.",
		Parent = panel,
	})
	status = Components.text({
		Name = "SaveStatus",
		Position = UDim2.fromOffset(18, 68),
		Size = UDim2.new(1, -36, 0, 16),
		FontFace = Theme.FontNote,
		TextSize = 11,
		TextColor3 = Theme.TextMuted,
		Text = "Aplicado localmente · salvamento não confirmado",
		Parent = panel,
	}) :: TextLabel
	local scroll = Create("ScrollingFrame", {
		Name = "OptionsScroll",
		Parent = panel,
		Position = UDim2.fromOffset(14, 92),
		Size = UDim2.new(1, -28, 1, -104),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Gold,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, {
		Create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Create("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 8) }),
	}) :: ScrollingFrame
	local grids: { UIGridLayout } = {}
	local function section(order: number, icon: string, title: string): Frame
		local head = Create("Frame", {
			Name = `Section_{title}`,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = order,
			Parent = scroll,
		})
		Components.icon(head, icon, 24, Theme.Gold)
		Components.title({
			Position = UDim2.fromOffset(32, 0),
			Size = UDim2.new(1, -32, 1, 0),
			Text = title,
			TextSize = 16,
			TextColor3 = Theme.Gold,
			Parent = head,
		})
		local grid = Create("Frame", {
			Name = `Grid_{title}`,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = order + 1,
			Parent = scroll,
		}) :: Frame
		local layout = Create("UIGridLayout", {
			CellSize = UDim2.new(0.5, -4, 0, Theme.TouchMin + 4),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		}) :: UIGridLayout
		table.insert(grids, layout)
		return grid
	end
	local function option(parent: Instance, key: string, order: number, callback: () -> ())
		local button = Components.button("secondary", {
			Name = key,
			LayoutOrder = order,
			Text = key,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = parent,
		}, callback)
		-- Modal: libera o cursor da primeira pessoa enquanto o painel está aberto.
		button.Modal = true
		Components.padding(button, 12, 0)
		buttons[key] = button
	end
	local graphics = section(1, "Star", "GRÁFICOS")
	option(graphics, "shaders", 1, function()
		SettingsController.setVisual("shaders", if shaders then 0 else 1)
	end)
	option(graphics, "quality", 2, function()
		local order = { 0, 0.25, 0.5, 1 }
		local index = table.find(order, visualQuality) or 1
		SettingsController.setVisual("quality", order[index % #order + 1])
	end)
	local comfort = section(3, "Heart", "CONFORTO E TELA")
	for index, key in KEYS do
		option(comfort, key, index, function()
			SettingsController.toggle(key :: Key)
		end)
	end
	local audio = section(5, "Drum", "ÁUDIO (TOQUE PARA BAIXAR 25%)")
	for index, key in { "master", "music", "effects", "breathing", "ambient" } do
		option(audio, key, index, function()
			mixes[key] = if mixes[key] <= 0 then 1 else math.max(0, mixes[key] - 0.25)
			Players.LocalPlayer:SetAttribute("Mix_" .. key, mixes[key])
			pending[key] = mixes[key]
			Remotes.clientEvent("SetHousePreference"):FireServer(key, mixes[key])
			refreshMenu()
		end)
		local track = Create("Frame", {
			Name = "Level",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(70, 6),
			BackgroundColor3 = Theme.BgSunken,
			BorderSizePixel = 0,
			Parent = buttons[key],
		})
		Components.corner(track, Theme.CornerPill)
		local fill = Create("Frame", {
			Name = "Fill",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Theme.Success,
			BorderSizePixel = 0,
			Parent = track,
		})
		Components.corner(fill, Theme.CornerPill)
	end
	local close = Components.iconButton("secondary", "Close", "FECHAR", {
		Name = "close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(124, 44),
		TextSize = 15,
		Parent = panel,
	}, function()
		panel.Visible = false
		Players.LocalPlayer:SetAttribute("ComfortMenuOpen", false)
	end)
	close.Modal = true
	buttons.close = close
	RunService.RenderStepped:Connect(function()
		if not panel.Visible then
			return
		end
		panel.Size = UDim2.new(0.94, 0, 0, math.max(180, math.min(640, safe.AbsoluteSize.Y - 20)))
		-- Uma coluna em telas estreitas; duas a partir de 560 px.
		local columns = if panel.AbsoluteSize.X >= 560 then 2 else 1
		for _, layout in grids do
			layout.CellSize = UDim2.new(1 / columns, if columns == 2 then -4 else 0, 0, Theme.TouchMin + 4)
		end
	end)
	refreshMenu()
end

function SettingsController.Start()
	local qualityOk, saved = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	-- Amostra única ao iniciar; não oscila conforme FPS ou reconstruções do mundo.
	autoLevel = if qualityOk and saved > 0 then saved else (if UserInputService.TouchEnabled then 2 else 6)
	local function load()
		local raw = Players.LocalPlayer:GetAttribute("HousePreferences")
		if type(raw) ~= "string" then
			return
		end
		local ok, prefs = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok then
			return
		end
		prefs = Preferences.sanitize(prefs)
		acknowledged = prefs
		for key, value in pending do
			if prefs[key] == value then
				pending[key] = nil
			end
		end
		syncing = true
		for _, key in { "shaders", "quality" } do
			if pending[key] == nil then
				SettingsController.setVisual(key, prefs[key] or (if key == "shaders" then 1 else 0))
			end
		end
		for _, key in KEYS do
			if prefs[key] ~= nil and pending[key] == nil then
				SettingsController.set(key :: Key, prefs[key] >= 0.5)
			end
		end
		syncing = false
		for key in mixes do
			if type(prefs[key]) == "number" and pending[key] == nil then
				mixes[key] = prefs[key]
				Players.LocalPlayer:SetAttribute("Mix_" .. key, mixes[key])
			end
		end
		refreshMenu()
	end
	Players.LocalPlayer:GetAttributeChangedSignal("HousePreferences"):Connect(load)
	Players.LocalPlayer:GetAttributeChangedSignal("HousePreferencesSaved"):Connect(refreshMenu)
	Players.LocalPlayer:GetAttributeChangedSignal("HousePreferencesSaveMode"):Connect(refreshMenu)
	load()
	if RunService:IsStudio() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "VisualQA"
		bridge.OnInvoke = function(key: string, value: number?): any
			if value ~= nil then
				SettingsController.setVisual(key, value)
			end
			return {
				shaders = shaders,
				preference = visualQuality,
				budget = SettingsController.visualBudget(),
				pending = pending,
			}
		end
		bridge.Parent = Players.LocalPlayer.PlayerGui:WaitForChild("ComfortOptions")
		local function qaVisualRequest()
			local raw = Players.LocalPlayer:GetAttribute("VisualQARequest")
			if type(raw) ~= "string" then
				return
			end
			local request = HttpService:JSONDecode(raw)
			SettingsController.setVisual("shaders", request.shaders)
			SettingsController.setVisual("quality", request.quality)
			task.spawn(function()
				-- O primeiro pedido pode anteceder o Start dos demais controllers e a adaptação suave.
				local state: any = nil
				local deadline = os.clock() + 15
				repeat
					task.wait(0.25)
					local probe = Players.LocalPlayer.PlayerGui:FindFirstChild("Probe", true) :: BindableFunction?
					state = if probe then probe:Invoke("state") else nil
				until (state and (request.shaders == 1 or (state.bloom < 0.001 and state.depth == 0)))
					or os.clock() > deadline
				assert(state, "Missing real lighting QA bridge")
				assert(state.shaders == (request.shaders == 1), "Shader preference crossed clients")
				assert(state.quality == SettingsController.visualBudget().name, "Visual budget not applied")
				assert(state.fixtures.shadows <= SettingsController.visualBudget().shadows, "Shadow budget exceeded")
				if request.shaders == 0 then
					assert(state.bloom < 0.001 and state.depth == 0, "Optional post still active")
				end
				log.info(
					"PASS serial=%s shaders=%s quality=%s fixtures=%d shadows=%d",
					tostring(request.serial),
					tostring(state.shaders),
					state.quality,
					state.fixtures.fixtures,
					state.fixtures.shadows
				)
			end)
		end
		Players.LocalPlayer:GetAttributeChangedSignal("VisualQARequest"):Connect(qaVisualRequest)
		qaVisualRequest()
	end
	-- Reenvia somente valores locais ainda não reconhecidos, respeitando o rate limit existente.
	task.spawn(function()
		while true do
			task.wait(2)
			for key, value in pending do
				if acknowledged[key] ~= value then
					Remotes.clientEvent("SetHousePreference"):FireServer(key, value)
				end
				task.wait(0.3)
			end
		end
	end)
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
