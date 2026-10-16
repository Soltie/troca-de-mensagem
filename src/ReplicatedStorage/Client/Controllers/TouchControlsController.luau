--!strict
-- Controles touch próprios: ContextActionService limita a quantidade de botões automáticos.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Create = require("../UI/Create")
local Interaction = require("./InteractionController")
local Character = require("./CharacterController")
local Flashlight = require("./FlashlightController")
local Campaign = require("./CampaignController")
local Settings = require("./SettingsController")
local Controller = { Name = "TouchControlsController" }
local player = Players.LocalPlayer

function Controller.Start()
	local gui = Create("ScreenGui", {
		Name = "HouseTouchControls",
		Parent = player:WaitForChild("PlayerGui"),
		ResetOnSpawn = false,
		DisplayOrder = 85,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ClipToDeviceSafeArea = true,
	}) :: ScreenGui
	local controls = Create("Frame", {
		Name = "Actions",
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -94, 1, -12),
		Size = UDim2.fromOffset(240, 96),
		BackgroundTransparency = 1,
	}) :: Frame
	local inventory = Create("Frame", {
		Name = "Inventory",
		Parent = gui,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -94, 1, -116),
		Size = UDim2.fromOffset(240, 48),
		BackgroundTransparency = 1,
		Visible = false,
	}) :: Frame
	local navigation = Create("Frame", {
		Name = "Navigation",
		Parent = gui,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(152, 44),
		BackgroundTransparency = 1,
	}) :: Frame
	local function button(
		parent: Instance,
		name: string,
		title: string,
		column: number,
		row: number,
		columns: number
	): TextButton
		return Create("TextButton", {
			Name = name,
			Modal = true,
			Parent = parent,
			Position = UDim2.new(column / columns, 3, 0, row * 52),
			Size = UDim2.new(1 / columns, -6, 0, 44),
			Text = title,
			TextSize = 12,
			TextWrapped = true,
			Font = Enum.Font.Code,
			TextColor3 = Color3.fromRGB(238, 223, 190),
			BackgroundColor3 = Color3.fromRGB(32, 29, 24),
			BackgroundTransparency = 0.12,
			BorderSizePixel = 1,
			BorderColor3 = Color3.fromRGB(156, 128, 64),
		}) :: TextButton
	end
	local action = button(controls, "Interact", "AÇÃO / SAIR", 0, 0, 3)
	local breath = button(controls, "Breath", "SEGURE\nRESPIRAÇÃO", 1, 0, 3)
	local sprint = button(controls, "Sprint", "SEGURE\nCORRER", 2, 0, 3)
	local light = button(controls, "Light", "LANTERNA", 0, 1, 3)
	local crouch = button(controls, "Crouch", "AGACHAR", 1, 1, 3)
	local pack = button(controls, "Backpack", "MOCHILA", 2, 1, 3)
	local guide = button(navigation, "Guide", "GUIA", 0, 0, 2)
	local options = button(navigation, "Options", "OPÇÕES", 1, 0, 2)
	local open = false
	local heldBreath: InputObject? = nil
	local heldSprint: InputObject? = nil
	local function releaseBreath()
		heldBreath = nil
		Interaction.requestBreath(false)
	end
	local function releaseSprint()
		heldSprint = nil
		player:SetAttribute("TouchSprint", false)
	end
	local function hold(buttonObject: TextButton, begin: (InputObject) -> (), finish: () -> ())
		buttonObject.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				begin(input)
				local connection: RBXScriptConnection? = nil
				connection = input:GetPropertyChangedSignal("UserInputState"):Connect(function()
					if
						input.UserInputState == Enum.UserInputState.End
						or input.UserInputState == Enum.UserInputState.Cancel
					then
						finish()
						if connection then
							connection:Disconnect()
						end
					end
				end)
			end
		end)
		buttonObject.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.Touch
				or input.UserInputType == Enum.UserInputType.MouseButton1
			then
				finish()
			end
		end)
	end
	hold(breath, function(input)
		heldBreath = input
		Interaction.requestBreath(true)
	end, releaseBreath)
	hold(sprint, function(input)
		heldSprint = input
		player:SetAttribute("TouchSprint", true)
	end, releaseSprint)
	Input.InputEnded:Connect(function(input)
		if input == heldBreath then
			releaseBreath()
		end
		if input == heldSprint then
			releaseSprint()
		end
	end)
	local function cancel()
		releaseBreath()
		releaseSprint()
	end
	Input.WindowFocusReleased:Connect(cancel)
	GuiService.MenuOpened:Connect(cancel)
	for _, name in { "CampaignStatus", "CinematicActive", "ComfortMenuOpen", "FieldGuideOpen" } do
		player:GetAttributeChangedSignal(name):Connect(cancel)
	end
	player.CharacterAdded:Connect(cancel)
	action.Activated:Connect(function()
		Interaction.activate()
	end)
	light.Activated:Connect(function()
		Flashlight.set(not Flashlight.isWanted())
	end)
	crouch.Activated:Connect(function()
		Character.requestStance(if Character.getMotion().stance == "Stand" then "Crouch" else "Stand")
	end)
	pack.Activated:Connect(function()
		open = not open
	end)
	guide.Activated:Connect(Campaign.toggleGuide)
	options.Activated:Connect(Settings.toggleMenu)
	local stockButtons: { [string]: TextButton } = {}
	for index, item in { "battery", "oxygen", "decoy" } do
		local itemButton = button(inventory, item, item, index - 1, 0, 3)
		stockButtons[item] = itemButton
		itemButton.Activated:Connect(function()
			Interaction.useSupply(item)
		end)
	end
	local labels = { battery = "PILHA", oxygen = "O₂ +25", decoy = "ISCA" }
	local function stock()
		local raw = player:GetAttribute("HouseSupplies")
		local values = if type(raw) == "string" then HttpService:JSONDecode(raw) else {}
		for item, itemButton in stockButtons do
			itemButton.Text = `{labels[item]} ×{values[item] or 0}`
		end
	end
	player:GetAttributeChangedSignal("HouseSupplies"):Connect(stock)
	stock()
	local elapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.1 then
			return
		end
		elapsed = 0
		gui.Enabled = Input.TouchEnabled
		local camera = workspace.CurrentCamera
		if camera then
			local width = math.clamp(camera.ViewportSize.X * 0.32, 192, 246)
			controls.Size, inventory.Size = UDim2.fromOffset(width, 96), UDim2.fromOffset(width, 48)
		end
		local active = GameState.get("Phase") == "Playing" and player:GetAttribute("CampaignStatus") == "Active"
		local menu = player:GetAttribute("ComfortMenuOpen") == true or player:GetAttribute("FieldGuideOpen") == true
		controls.Visible = active and not menu and player:GetAttribute("CinematicActive") ~= true
		inventory.Visible = controls.Visible and open
		navigation.Visible = player:GetAttribute("CinematicActive") ~= true
		if not controls.Visible and (heldBreath or heldSprint) then
			cancel()
		end
	end)
end
return Controller
