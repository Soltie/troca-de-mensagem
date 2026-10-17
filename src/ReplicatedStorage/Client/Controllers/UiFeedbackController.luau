--!strict
-- Resposta local a mouse, toque e foco do controle; não altera nenhuma ação do botão.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Settings = require("./SettingsController")

type Feedback = {
	button: GuiButton,
	overlay: Frame,
	scale: UIScale?,
	hovered: boolean,
	focused: boolean,
	pressed: boolean,
	tweens: { Tween },
	connections: { RBXScriptConnection },
}

local tracked: { [GuiButton]: Feedback } = {}
local Controller = { Name = "UiFeedbackController" }

local function update(state: Feedback)
	for _, tween in state.tweens do
		tween:Cancel()
	end
	table.clear(state.tweens)
	local enabled = state.button.Active and state.button.Interactable and state.button.Visible
	local pressed = enabled and state.pressed
	local highlighted = enabled and (state.hovered or state.focused)
	local transparency = if pressed then 0.88 elseif highlighted then 0.94 else 1
	local duration = if Settings.motionEnabled() then (if pressed then 0.07 else 0.16) else 0
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	table.insert(state.tweens, TweenService:Create(state.overlay, info, { BackgroundTransparency = transparency }))
	if state.scale then
		table.insert(
			state.tweens,
			TweenService:Create(state.scale, info, {
				Scale = if pressed and Settings.motionEnabled() then 0.985 else 1,
			})
		)
	end
	for _, tween in state.tweens do
		tween:Play()
	end
end

local function attach(instance: Instance)
	if not instance:IsA("GuiButton") or tracked[instance] or instance:GetAttribute("PresentationFeedback") == false then
		return
	end
	local gui = instance:FindFirstAncestorWhichIsA("ScreenGui")
	-- Controles de movimento já têm resposta própria; esta frente cuida da apresentação.
	if not gui or gui.Name == "TouchControls" or gui.Name == "HouseTouchControls" then
		return
	end
	-- Um botão clonado não herda o estado pressionado nem ganha dois overlays.
	local copiedOverlay = instance:FindFirstChild("PresentationFeedback")
	if copiedOverlay then
		copiedOverlay:Destroy()
	end
	local overlay = Instance.new("Frame")
	overlay.Name = "PresentationFeedback"
	overlay.BackgroundColor3 = Color3.fromRGB(236, 223, 188)
	overlay.BackgroundTransparency = 1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = instance.ZIndex + 1
	overlay.Active, overlay.Selectable = false, false
	local corner = instance:FindFirstChildWhichIsA("UICorner")
	if corner then
		corner:Clone().Parent = overlay
	end
	overlay.Parent = instance
	local scale: UIScale? = nil
	local existingScale = instance:FindFirstChildWhichIsA("UIScale")
	if existingScale and existingScale.Name == "PresentationScale" then
		existingScale.Scale = 1
		scale = existingScale
	elseif not existingScale then
		local created = Instance.new("UIScale")
		created.Name = "PresentationScale"
		created.Parent = instance
		scale = created
	end
	local state: Feedback = {
		button = instance,
		overlay = overlay,
		scale = scale,
		hovered = false,
		focused = false,
		pressed = false,
		tweens = {},
		connections = {},
	}
	tracked[instance] = state
	local function connect(signal: RBXScriptSignal, callback: (...any) -> ())
		table.insert(state.connections, signal:Connect(callback))
	end
	connect(instance.MouseEnter, function()
		state.hovered = true
		update(state)
	end)
	connect(instance.MouseLeave, function()
		state.hovered = false
		state.pressed = false
		update(state)
	end)
	connect(instance.SelectionGained, function()
		state.focused = true
		update(state)
	end)
	connect(instance.SelectionLost, function()
		state.focused = false
		state.pressed = false
		update(state)
	end)
	connect(instance.InputBegan, function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			state.pressed = true
			update(state)
		end
	end)
	for _, property in { "Visible", "Active", "Interactable" } do
		connect(instance:GetPropertyChangedSignal(property), function()
			state.pressed, state.hovered, state.focused = false, false, false
			update(state)
		end)
	end
	connect(instance.Destroying, function()
		tracked[instance] = nil
		for _, tween in state.tweens do
			tween:Cancel()
		end
		for _, connection in state.connections do
			connection:Disconnect()
		end
	end)
end

function Controller.debugState(): { [string]: any }
	local buttons, pressed = 0, 0
	for _, state in tracked do
		buttons += 1
		if state.pressed then
			pressed += 1
		end
	end
	return { buttons = buttons, pressed = pressed }
end

function Controller.Start()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	gui.DescendantAdded:Connect(attach)
	for _, descendant in gui:GetDescendants() do
		attach(descendant)
	end
	UserInputService.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
			or input.KeyCode == Enum.KeyCode.ButtonA
		then
			for _, state in tracked do
				if state.pressed then
					state.pressed = false
					update(state)
				end
			end
		end
	end)
	Settings.onChanged(function()
		for _, state in tracked do
			update(state)
		end
	end)
end

return Controller
