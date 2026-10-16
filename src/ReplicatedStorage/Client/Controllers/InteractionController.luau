--!strict
--[[
	Interação "mire e aperte E" (estilo survival horror):
	- Procura o interagível habilitado mais alinhado com o centro da tela, dentro da distância,
	  com linha de visão. Mostra "[E] AÇÃO" na UI.
	- E envia o pedido ao servidor (remote Interact). O servidor valida TUDO de novo e responde
	  com uma chave de mensagem; o cliente só mostra o resultado.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")
local Tags = require("@game/ReplicatedStorage/Shared/Game/Tags")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Types = require("@game/ReplicatedStorage/Shared/Types")
local Rules = require("@game/ReplicatedStorage/Shared/Game/InteractionPresentation")
local AudioController = require("./AudioController")
local CameraController = require("./CameraController")
local CharacterController = require("./CharacterController")
local FearController = require("./FearController")
local FlashlightController = require("./FlashlightController")
local ScreenFxController = require("./ScreenFxController")
local GameUiController = require("./GameUiController")

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local player = Players.LocalPlayer
local breathRequested = false
local CONE_DEGREES = 24
local CONE_CLOSE_DEGREES = 40

local current: BasePart? = nil
local busy = false
local phase: GameState.Phase = "Loading"
local roundId = -1
local generation = 0
local hasKey = false
local campaign = false
local highlight: Highlight? = nil

local function hiddenId(): string?
	local id = player:GetAttribute("Hidden")
	return if type(id) == "string" and id ~= "" then id else nil
end

local function allowed(): boolean
	return player:GetAttribute("FieldGuideOpen") ~= true
		and player:GetAttribute("ComfortMenuOpen") ~= true
		and player:GetAttribute("CinematicActive") ~= true
		and Rules.allowed(phase, player:GetAttribute("CampaignStatus") :: string?)
end

local function clearTarget()
	current = nil
	if highlight then
		-- Sem alvo, Adornee=nil usa o Parent (Workspace) e contorna o cenário inteiro.
		highlight.Enabled = false
		highlight.Adornee = nil
	end
	GameUiController.setPrompt(nil)
end

local function holdBreath(value: boolean)
	if value == breathRequested then
		return
	end
	breathRequested = value
	task.spawn(function()
		local ok, remote = pcall(Remotes.clientEvent, "SetHoldBreath", 5)
		if ok then
			remote:FireServer(value)
		end
	end)
end

local function visible(camera: Camera, part: BasePart): boolean
	local origin = camera.CFrame.Position
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(origin, part.Position - origin, params)
	if hit == nil or hit.Instance == part then
		return true
	end
	return (hit.Position - part.Position).Magnitude <= 1.5
end

local function findTarget(camera: Camera): BasePart?
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local best: BasePart? = nil
	local bestAngle = math.huge
	for _, instance in CollectionService:GetTagged(Tags.Interactable) do
		if instance:IsA("BasePart") and instance:GetAttribute(Tags.Attr.InteractEnabled) == true then
			local offset = instance.Position - origin
			local distance = offset.Magnitude
			local maxDistance = (instance:GetAttribute(Tags.Attr.InteractDistance) :: number?) or 8
			if distance <= maxDistance and distance > 0.01 then
				local angle = math.deg(math.acos(math.clamp(look:Dot(offset.Unit), -1, 1)))
				local limit = if distance < 3.5 then CONE_CLOSE_DEGREES else CONE_DEGREES
				if angle <= limit and angle < bestAngle and visible(camera, instance) then
					best = instance
					bestAngle = angle
				end
			end
		end
	end
	return best
end

local function messageFor(key: string): string
	return (Text.Messages :: any)[key] or ""
end

local function interact(id: string, part: BasePart?, action: string?)
	if busy or not allowed() then
		return
	end
	busy = true
	local token = generation
	-- A coleta remove a peça no servidor; guardar a origem antes do pedido.
	local origin = if part then part.Position else Vector3.zero
	local ok, response = pcall(function()
		return Remotes.clientFunction("Interact", 5):InvokeServer(id, action)
	end)
	busy = false
	if token ~= generation or not allowed() then
		return
	end
	if not ok then
		GameUiController.caption(messageFor("unknown"))
		return
	end
	local result = response :: Types.Result<Types.InteractResponse>
	if not result.ok then
		return -- rate limit / argumentos: silencioso
	end
	local data = result.data
	if data.accepted then
		if data.note then
			AudioController.play("Paper", 1, 0.8)
			GameUiController.showNote(data.note)
		elseif Rules.pickup(data.kind) then
			FlashlightController.showPickup(data.kind :: string, origin)
		elseif data.kind == "Unlock" then
			FlashlightController.playKeyUnlock()
		elseif data.kind == "BreakerSolved" or (campaign and data.message == "solved") then
			ScreenFxController.pulse(Color3.fromRGB(70, 170, 95))
			AudioController.play("Switch", 0.6, 1.3)
		elseif campaign and data.message == "progress" then
			AudioController.play("Switch", 0.5, 1.2)
		end
	else
		AudioController.play("UiBlip", 1, 0.55)
		if data.kind == "BreakerWrong" or (campaign and data.message == "wrong_sequence") then
			CameraController.addTrauma(0.5)
			FearController.spike(0.15)
			ScreenFxController.pulse(Color3.fromRGB(165, 25, 25))
		elseif data.kind == "DoorLocked" then
			CameraController.addTrauma(0.1)
		end
	end
	local text = messageFor(data.message)
	if text ~= "" then
		GameUiController.caption(text)
	end
end

local InteractionController = {
	Name = "InteractionController",
}

-- Entrada única para teclado e outras interfaces; nunca aceita um ID arbitrário do chamador.
function InteractionController.activate(action: string?)
	if not allowed() then
		return
	end
	local alt = action == "alt"
	if GameUiController.isNoteOpen() then
		if not alt then
			GameUiController.closeNote()
		end
		return
	end
	local hidden = hiddenId()
	if hidden then
		if not alt then
			task.spawn(interact, hidden, nil, nil)
		end
		return
	end
	local part = current
	if part then
		local id = part:GetAttribute(Tags.Attr.InteractId)
		if
			type(id) == "string" and (not alt or (not campaign and type(part:GetAttribute("InteractAlt")) == "string"))
		then
			task.spawn(interact, id, part, if alt then "alt" else nil)
		end
	end
end

function InteractionController.Start()
	campaign = GameState.wait():GetAttribute("CampaignActive") == true
	local focus = Instance.new("Highlight")
	highlight = focus
	focus.Name = "InteractionFocus"
	focus.Enabled = false
	focus.FillTransparency = 1
	focus.OutlineTransparency = 0.55
	focus.OutlineColor = Color3.fromRGB(205, 188, 144)
	focus.DepthMode = Enum.HighlightDepthMode.Occluded
	focus.Parent = workspace
	GameState.observe(function(snapshot)
		if roundId ~= snapshot.roundId or phase ~= snapshot.phase then
			generation += 1
			clearTarget()
		end
		roundId = snapshot.roundId
		hasKey = snapshot.hasKey
		phase = snapshot.phase
	end)
	player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
		generation += 1
		clearTarget()
	end)
	local function syncHidden()
		local eye = player:GetAttribute("HideEye")
		if hiddenId() and typeof(eye) == "CFrame" and allowed() then
			CameraController.setHidden(eye :: CFrame)
		else
			CameraController.setHidden(nil)
		end
	end
	player:GetAttributeChangedSignal("Hidden"):Connect(syncHidden)
	player:GetAttributeChangedSignal("HideEye"):Connect(syncHidden)
	player.CharacterAdded:Connect(function()
		generation += 1
		CameraController.setHidden(nil)
		clearTarget()
	end)
	syncHidden()
	CharacterController.onStandBlocked(function()
		GameUiController.caption(Text.Hints.no_room)
	end)
	FlashlightController.onHint(function(key)
		local text = (Text.Hints :: any)[key]
		if text and allowed() then
			GameUiController.caption(text)
		end
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not allowed() then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.E and input.KeyCode ~= Enum.KeyCode.Q then
			return
		end
		InteractionController.activate(if input.KeyCode == Enum.KeyCode.Q then "alt" else nil)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space then
			holdBreath(false)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		holdBreath(false)
	end)

	local function breathAction(_: string, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			holdBreath(false)
			return Enum.ContextActionResult.Sink
		end
		if input.KeyCode == Enum.KeyCode.Space and not hiddenId() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and allowed() and not UserInputService:GetFocusedTextBox() then
			holdBreath(true)
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction(
		"HouseBreath",
		breathAction,
		true,
		(Enum.KeyCode :: any)[Config.House.BreathKey],
		Enum.KeyCode.ButtonL1,
		Enum.KeyCode.Space
	)
	ContextActionService:SetTitle("HouseBreath", "RESPIRAR")
	ContextActionService:SetPosition("HouseBreath", UDim2.new(1, -180, 1, -200))
	ContextActionService:BindAction("HouseInteract", function(_, state)
		if state == Enum.UserInputState.Begin then
			InteractionController.activate()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("HouseInteract", "AÇÃO / SAIR")
	ContextActionService:SetPosition("HouseInteract", UDim2.new(1, -90, 1, -210))
	ContextActionService:BindAction("HouseLightTouch", function(_, state)
		if state == Enum.UserInputState.Begin and allowed() then
			FlashlightController.set(not FlashlightController.isWanted())
		end
		return Enum.ContextActionResult.Sink
	end, true)
	ContextActionService:SetTitle("HouseLightTouch", "LUZ")
	ContextActionService:SetPosition("HouseLightTouch", UDim2.new(1, -180, 1, -110))
	local function cancelBreath()
		holdBreath(false)
	end
	GuiService.MenuOpened:Connect(cancelBreath)
	for _, attr in { "CampaignStatus", "CinematicActive", "FieldGuideOpen", "ComfortMenuOpen", "Hidden" } do
		player:GetAttributeChangedSignal(attr):Connect(cancelBreath)
	end
	player.CharacterAdded:Connect(cancelBreath)
	local function useItem(item: string)
		if allowed() and player:GetAttribute("ComfortMenuOpen") ~= true then
			task.spawn(function()
				Remotes.clientFunction("UseHouseItem", 5):InvokeServer(item)
			end)
		end
	end
	ContextActionService:BindAction("HouseBattery", function(_, state)
		if state == Enum.UserInputState.Begin then
			useItem("battery")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.One, Enum.KeyCode.DPadLeft)
	ContextActionService:SetTitle("HouseBattery", "PILHA")
	ContextActionService:SetPosition("HouseBattery", UDim2.new(0, 30, 1, -250))
	ContextActionService:BindAction("HouseOxygen", function(_, state)
		if state == Enum.UserInputState.Begin then
			useItem("oxygen")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Two, Enum.KeyCode.DPadUp)
	ContextActionService:SetTitle("HouseOxygen", "O₂ +25")
	ContextActionService:SetPosition("HouseOxygen", UDim2.new(0, 120, 1, -250))
	ContextActionService:BindAction("HouseDecoy", function(_, state)
		if state == Enum.UserInputState.Begin then
			useItem("decoy")
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.Three, Enum.KeyCode.DPadRight)
	ContextActionService:SetTitle("HouseDecoy", "ISCA")
	ContextActionService:SetPosition("HouseDecoy", UDim2.new(0, 210, 1, -250))
	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 / 20 then
			return
		end
		accumulator = 0
		local camera = workspace.CurrentCamera
		if not camera or not allowed() or GameUiController.isNoteOpen() then
			clearTarget()
			return
		end
		if hiddenId() then
			clearTarget()
			GameUiController.setPrompt(
				Text.HiddenHint .. (if player:GetAttribute("HoldBreath") then "\n" .. Text.HoldingBreath else "")
			)
			return
		end
		current = findTarget(camera)
		if current then
			local prompt = current:GetAttribute(Tags.Attr.InteractPrompt)
			GameUiController.setPrompt(
				Rules.prompt(
					if type(prompt) == "string" then prompt else "",
					current:GetAttribute("InteractAlt") :: string?,
					current:GetAttribute("Locked") == true,
					hasKey,
					campaign
				)
			)
			local parent = current.Parent
			if highlight then
				highlight.Adornee = if parent and parent:IsA("Model") then parent else current
				highlight.Enabled = true
			end
		else
			clearTarget()
		end
	end)
end

-- Para testes/depuração: o que está sob a mira agora.
function InteractionController.currentTarget(): string?
	local part = current
	if part then
		local id = part:GetAttribute(Tags.Attr.InteractId)
		return if type(id) == "string" then id else nil
	end
	return nil
end

return InteractionController
