--!strict
-- Ações nas bordas; movimento, pulo e arraste da câmera continuam com o Roblox.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")
local Interaction = require("./InteractionController")
local GameUi = require("./GameUiController")
local Character = require("./CharacterController")
local Flashlight = require("./FlashlightController")
local Campaign = require("./CampaignController")
local Settings = require("./SettingsController")
local Spectator = require("./SpectatorController")
local Controller = { Name = "TouchControlsController" }
local player = Players.LocalPlayer

function Controller.Start()
	local gui = Create("ScreenGui", {
		Name = "HouseTouchControls",
		Parent = player:WaitForChild("PlayerGui"),
		ResetOnSpawn = false,
		DisplayOrder = 85,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ClipToDeviceSafeArea = true,
	}) :: ScreenGui
	local root = Create(
		"Frame",
		{ Name = "SafeArea", Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }
	) :: Frame
	local controls = Create("Frame", {
		Name = "Actions",
		Parent = root,
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
	}) :: Frame
	local navigation = Create("Frame", {
		Name = "Navigation",
		Parent = root,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 8),
		Size = UDim2.fromOffset(156, 44),
		BackgroundTransparency = 1,
	}) :: Frame
	local function button(parent: Instance, name: string, title: string): TextButton
		return Create("TextButton", {
			Name = name,
			Parent = parent,
			Text = title,
			TextSize = 14,
			TextWrapped = true,
			FontFace = Theme.Font,
			TextColor3 = Theme.Text,
			BackgroundColor3 = Theme.Panel,
			BackgroundTransparency = 0.12,
			AutoButtonColor = true,
			BorderSizePixel = 0,
		}, {
			Create("UICorner", { CornerRadius = UDim.new(0, 12) }),
			Create("UIStroke", { Color = Theme.Hazard, Thickness = 1, Transparency = 0.4 }),
		}) :: TextButton
	end
	local action = button(controls, "Interact", "AÇÃO")
	local sprint = button(controls, "Sprint", "CORRER")
	local crouch = button(controls, "Crouch", "AGACHAR")
	local light = button(controls, "Light", "LANTERNA")
	local pack = button(controls, "Backpack", "MOCHILA")
	local breath = button(controls, "Breath", "SEGURE\nO AR")
	local guide = button(navigation, "Guide", "GUIA")
	local options = button(navigation, "Options", "AJUSTES")
	guide.Size, options.Size = UDim2.fromOffset(74, 44), UDim2.fromOffset(74, 44)
	options.Position = UDim2.fromOffset(82, 0)

	local inventory = Create("Frame", {
		Name = "Inventory",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Theme.Panel,
		Visible = false,
		BorderSizePixel = 0,
	}, { Create("UICorner", { CornerRadius = Theme.Corner }), Create("UIStroke", { Color = Theme.Hazard }) }) :: Frame
	local inventoryTitle = Create("TextLabel", {
		Name = "TeamItems",
		Parent = inventory,
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -112, 0, 54),
		Text = "MOCHILA",
		TextSize = 14,
		TextWrapped = true,
		FontFace = Theme.Font,
		TextColor3 = Theme.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	}) :: TextLabel
	local close = button(inventory, "Close", "FECHAR")
	close.Position, close.Size = UDim2.new(1, -94, 0, 10), UDim2.fromOffset(82, 44)
	close.Modal = true
	local open = false
	local function closePack()
		open = false
		player:SetAttribute("TouchBackpackOpen", false)
	end
	close.Activated:Connect(closePack)
	local heldBreath: InputObject? = nil
	local breathConnection: RBXScriptConnection? = nil
	local function releaseBreath()
		if breathConnection then
			breathConnection:Disconnect()
			breathConnection = nil
		end
		heldBreath = nil
		Interaction.requestBreath(false)
	end
	local function cancel()
		releaseBreath()
		player:SetAttribute("TouchSprint", false)
	end
	breath.InputBegan:Connect(function(input)
		if
			input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.MouseButton1
		then
			return
		end
		releaseBreath()
		heldBreath = input
		Interaction.requestBreath(true)
		breathConnection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
			if
				input.UserInputState == Enum.UserInputState.End
				or input.UserInputState == Enum.UserInputState.Cancel
			then
				releaseBreath()
			end
		end)
	end)
	Input.InputEnded:Connect(function(input)
		if input == heldBreath then
			releaseBreath()
		end
	end)
	Input.WindowFocusReleased:Connect(cancel)
	GuiService.MenuOpened:Connect(cancel)
	for _, name in
		{
			"CampaignStatus",
			"CinematicActive",
			"ComfortMenuOpen",
			"FieldGuideOpen",
			"TouchBackpackOpen",
			"NoteOpen",
			"Hidden",
		}
	do
		player:GetAttributeChangedSignal(name):Connect(cancel)
	end
	player.CharacterAdded:Connect(function()
		cancel()
		closePack()
	end)
	action.Activated:Connect(function()
		if
			not GameUi.isNoteOpen()
			and (player:GetAttribute("Hidden") or "") == ""
			and Interaction.currentTarget() == nil
		then
			GameUi.caption("Chegue perto e mire no objeto para usar AÇÃO.", 2)
		else
			Interaction.activate()
		end
	end)
	sprint.Activated:Connect(function()
		player:SetAttribute("TouchSprint", player:GetAttribute("TouchSprint") ~= true)
	end)
	light.Activated:Connect(function()
		Flashlight.set(not Flashlight.isWanted())
	end)
	crouch.Activated:Connect(function()
		Character.requestStance(if Character.getMotion().stance == "Stand" then "Crouch" else "Stand")
	end)
	pack.Activated:Connect(function()
		open = not open
		player:SetAttribute("TouchBackpackOpen", open)
	end)
	guide.Activated:Connect(function()
		closePack()
		Campaign.toggleGuide()
	end)
	options.Activated:Connect(function()
		closePack()
		Settings.toggleMenu()
	end)
	local stockButtons: { [string]: TextButton } = {}
	local stockLabels = {
		battery = "PILHA — recarregar lanterna",
		oxygen = "AR EXTRA — recuperar oxigênio",
		decoy = "ISCA — distrair o Tung Tung",
	}
	local stockValues: { [string]: number } = {}
	for index, item in { "battery", "oxygen", "decoy" } do
		local b = button(inventory, item, item)
		b.Position, b.Size = UDim2.fromOffset(12, 68 + (index - 1) * 52), UDim2.new(1, -24, 0, 44)
		b.Modal = true
		stockButtons[item] = b
		b.Activated:Connect(function()
			if (stockValues[item] or 0) > 0 then
				Interaction.useSupply(item)
				closePack()
			end
		end)
	end
	local function stock()
		local raw = player:GetAttribute("HouseSupplies")
		stockValues = if type(raw) == "string" then HttpService:JSONDecode(raw) else {}
		for item, b in stockButtons do
			local count = stockValues[item] or 0
			b.Text = `{stockLabels[item]} ×{count}`
			b.TextTransparency = if count > 0 then 0 else 0.55
			b.Active, b.AutoButtonColor = count > 0, count > 0
		end
	end
	player:GetAttributeChangedSignal("HouseSupplies"):Connect(stock)
	stock()
	local watching = Create("Frame", {
		Name = "Spectate",
		Parent = root,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -96),
		Size = UDim2.fromOffset(224, 44),
		BackgroundTransparency = 1,
	}) :: Frame
	local previous, nextPlayer = button(watching, "Previous", "◀ COLEGA"), button(watching, "Next", "COLEGA ▶")
	previous.Size, nextPlayer.Size = UDim2.fromOffset(108, 44), UDim2.fromOffset(108, 44)
	nextPlayer.Position = UDim2.fromOffset(116, 0)
	previous.Activated:Connect(function()
		Spectator.cycle(-1)
	end)
	nextPlayer.Activated:Connect(function()
		Spectator.cycle(1)
	end)

	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		gui.Enabled = Input.TouchEnabled
		local w, h = root.AbsoluteSize.X, root.AbsoluteSize.Y
		local width = math.clamp(w * 0.29, 210, 252)
		local cell, height = (width - 12) / 3, 52
		local bottom = if w >= 900 then 148 else 112
		local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
		local jump = touchGui and touchGui:FindFirstChild("JumpButton", true)
		if jump and jump:IsA("GuiObject") and jump.Visible then
			bottom = math.max(bottom, h - (jump.AbsolutePosition.Y - root.AbsolutePosition.Y) + 12)
		end
		controls.Size, controls.Position = UDim2.fromOffset(width, height * 2 + 8), UDim2.new(1, -8, 1, -bottom)
		for index, b in { crouch, sprint, action, light, pack, breath } do
			b.Size = UDim2.fromOffset(cell, height)
			b.Position = UDim2.fromOffset(((index - 1) % 3) * (cell + 6), math.floor((index - 1) / 3) * (height + 8))
		end
		inventory.Size = UDim2.fromOffset(math.min(400, w - 24), 228)
		local state = ReplicatedStorage:FindFirstChild("CampaignState")
		local phase = if state then state:GetAttribute("Phase") else GameState.get("Phase")
		local status = player:GetAttribute("CampaignStatus")
		local cinema = player:GetAttribute("CinematicActive") == true
		local active = (phase == "Playing" or phase == "Extracting") and status == "Active"
		local menu = player:GetAttribute("ComfortMenuOpen") == true or player:GetAttribute("FieldGuideOpen") == true
		local hidden = type(player:GetAttribute("Hidden")) == "string" and player:GetAttribute("Hidden") ~= ""
		local note = GameUi.isNoteOpen()
		controls.Visible = active and not menu and not cinema and not open
		inventory.Visible = active and not menu and not cinema and open
		navigation.Visible = not cinema
			and not menu
			and (phase == "Playing" or phase == "Extracting" or phase == "Intermission")
		watching.Visible = not cinema
			and not menu
			and not open
			and (phase == "Playing" or phase == "Extracting")
			and (status == "Waiting" or status == "Downed" or status == "Escaped")
		breath.Visible = hidden and not note
		sprint.Visible, crouch.Visible = not hidden and not note, not hidden and not note
		light.Visible = not hidden and not note and player:GetAttribute("HasFlashlight") == true
		pack.Visible = not hidden and not note
		action.Text = if note
			then "FECHAR"
			elseif hidden then "SAIR"
			elseif (Interaction.currentTarget() or ""):find("rescue", 1, true) then "AJUDAR"
			else "AÇÃO"
		action.BackgroundColor3 = if hidden
				or note
				or Interaction.currentTarget() ~= nil
			then Theme.Accent
			else Theme.Panel
		sprint.Text = if player:GetAttribute("TouchSprint") == true then "CORRER\nLIGADO" else "CORRER"
		sprint.BackgroundColor3 = if player:GetAttribute("TouchSprint") == true then Theme.Accent else Theme.Panel
		crouch.Text = if Character.getMotion().stance == "Crouch" then "LEVANTAR" else "AGACHAR"
		light.Text = if Flashlight.isWanted() then "LUZ\nLIGADA" else "LANTERNA"
		breath.BackgroundColor3 = if heldBreath then Theme.Accent else Theme.Panel
		if not active or menu or cinema then
			closePack()
		end
		if not controls.Visible and (heldBreath or player:GetAttribute("TouchSprint") == true) then
			cancel()
		end
		if open and state then
			local items = HttpService:JSONDecode((state:GetAttribute("Inventory") or "{}") :: string)
			inventoryTitle.Text =
				`MOCHILA DO TIME\nCHAVES {(items.key_living or 0) + (items.key_kitchen or 0) + (items.key_dining or 0)}/3 · FUSÍVEIS {(items.fuse_1 or 0) + (items.fuse_2 or 0) + (items.fuse_3 or 0)}/3 · ARTEFATO {items.artifact or 0}`
		end
	end)
end
return Controller
