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
	for _ = 1, 4 do
		local hit = workspace:Raycast(origin, part.Position - origin, params)
		if hit == nil or hit.Instance == part or (hit.Position - part.Position).Magnitude <= 1.5 then
			return true
		end
		-- Colisor invisível de móvel e lençol não escondem o alvo.
		if hit.Instance.Name ~= "FurnitureCollider" and not string.find(hit.Instance.Name, "Sheet", 1, true) then
			return false
		end
		exclude[#exclude + 1] = hit.Instance
		params.FilterDescendantsInstances = exclude
	end
	return false
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
	-- Enigmas de verdade (PuzzleStyles): cada botão tem seu som (a nota do piano toca mesmo errando).
	local press = if part then part:GetAttribute("PressSound") else nil
	if part and typeof(press) == "string" and part.Parent then
		local pitch = part:GetAttribute("PressPitch")
		AudioController.playAt(press, part, 1, if typeof(pitch) == "number" then pitch else nil)
	end
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
		if
			data.kind == "BreakerWrong"
			or (campaign and (data.message == "wrong_sequence" or data.message == "puzzle_alarm"))
		then
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

function InteractionController.requestBreath(value: boolean)
	if not value or allowed() then
		holdBreath(value)
	end
end
-- Espiar pela fresta (só escondido). A câmera abre as portas um pouco; o servidor conta o tempo da queda.
local peekRequested = false
function InteractionController.requestPeek(value: boolean)
	local want = value and hiddenId() ~= nil and allowed()
	if want == peekRequested then
		return
	end
	peekRequested = want
	CameraController.setPeek(want)
	task.spawn(function()
		local ok, remote = pcall(Remotes.clientEvent, "SetPeek", 5)
		if ok then
			remote:FireServer(want)
		end
	end)
end
function InteractionController.useSupply(item: string)
	if allowed() then
		task.spawn(function()
			Remotes.clientFunction("UseHouseItem", 5):InvokeServer(item)
		end)
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
			InteractionController.requestPeek(false)
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		holdBreath(false)
	end)

	local function breathAction(_: string, state: Enum.UserInputState, _input: InputObject)
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			holdBreath(false)
			return Enum.ContextActionResult.Sink
		end
		if state == Enum.UserInputState.Begin and allowed() and not UserInputService:GetFocusedTextBox() then
			holdBreath(true)
		end
		return Enum.ContextActionResult.Sink
	end
	ContextActionService:BindAction(
		"HouseBreath",
		breathAction,
		false,
		(Enum.KeyCode :: any)[Config.House.BreathKey],
		Enum.KeyCode.ButtonL1
	)
	-- Espaço escondido = espiar pela fresta (fora do armário continua sendo o pulo).
	local function peekAction(_: string, state: Enum.UserInputState, input: InputObject)
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			InteractionController.requestPeek(false)
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.Space and not hiddenId() then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then
			InteractionController.requestPeek(true)
		end
		return Enum.ContextActionResult.Sink
	end
	-- Prioridade acima de tudo que usa Espaço (pulo do Roblox, pulo de obstáculo da mansão = 3500): dentro do
	-- armário a fresta fica com a tecla; fora dele o peekAction devolve (Pass) e o resto funciona igual.
	ContextActionService:BindActionAtPriority(
		"HousePeek",
		peekAction,
		false,
		Enum.ContextActionPriority.High.Value + 2000,
		Enum.KeyCode.Space,
		Enum.KeyCode.ButtonR1
	)
	-- Celular: botão ESPIAR só enquanto está escondido (o pulo do celular não é a tecla Espaço).
	if UserInputService.TouchEnabled then
		player:GetAttributeChangedSignal("Hidden"):Connect(function()
			if hiddenId() then
				ContextActionService:BindAction("HousePeekTouch", function(_, state)
					if state == Enum.UserInputState.Begin then
						InteractionController.requestPeek(true)
					elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
						InteractionController.requestPeek(false)
					end
					return Enum.ContextActionResult.Sink
				end, true)
				ContextActionService:SetTitle("HousePeekTouch", "ESPIAR")
				ContextActionService:SetPosition("HousePeekTouch", UDim2.new(1, -170, 1, -150))
			else
				InteractionController.requestPeek(false)
				ContextActionService:UnbindAction("HousePeekTouch")
			end
		end)
	end
	ContextActionService:BindAction("HouseInteract", function(_, state)
		if state == Enum.UserInputState.Begin then
			InteractionController.activate()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.ButtonX)
	ContextActionService:BindAction("HouseLightTouch", function(_, state)
		if state == Enum.UserInputState.Begin and allowed() then
			FlashlightController.set(not FlashlightController.isWanted())
		end
		return Enum.ContextActionResult.Sink
	end, false)
	local function cancelBreath()
		holdBreath(false)
		InteractionController.requestPeek(false)
	end
	GuiService.MenuOpened:Connect(cancelBreath)
	for _, attr in { "CampaignStatus", "CinematicActive", "FieldGuideOpen", "ComfortMenuOpen", "Hidden" } do
		player:GetAttributeChangedSignal(attr):Connect(cancelBreath)
	end
	player.CharacterAdded:Connect(cancelBreath)

	ContextActionService:BindAction("HouseBattery", function(_, state)
		if state == Enum.UserInputState.Begin then
			InteractionController.useSupply("battery")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.One, Enum.KeyCode.DPadLeft)
	ContextActionService:BindAction("HouseOxygen", function(_, state)
		if state == Enum.UserInputState.Begin then
			InteractionController.useSupply("oxygen")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Two, Enum.KeyCode.DPadUp)
	ContextActionService:BindAction("HouseDecoy", function(_, state)
		if state == Enum.UserInputState.Begin then
			InteractionController.useSupply("decoy")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Three, Enum.KeyCode.DPadRight)
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
			-- A dica do armário fica só no rodapé (NoirHud, CampaignController); aqui nada no meio da tela.
			clearTarget()
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

-- QA usa a mesma mira, visibilidade, estado e envio do botão E. Não ativa um alvo bloqueado.
function InteractionController.testInteract(expectedId: string): boolean
	assert(RunService:IsStudio(), "Studio-only interaction QA")
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local camera = workspace.CurrentCamera
	if not head or not head:IsA("BasePart") or not camera or not allowed() then
		return false
	end
	if hiddenId() == expectedId then
		interact(expectedId, nil)
		return true
	end
	local focus: BasePart? = nil
	for _, candidate in CollectionService:GetTagged(Tags.Interactable) do
		if candidate:IsA("BasePart") and candidate:GetAttribute(Tags.Attr.InteractId) == expectedId then
			focus = candidate
			break
		end
	end
	if not focus then
		return false
	end
	local previous = camera.CFrame
	camera.CFrame = CFrame.lookAt(head.Position, focus.Position)
	local selected = findTarget(camera)
	camera.CFrame = previous
	if selected ~= focus then
		return false
	end
	current = selected
	interact(expectedId, selected)
	return true
end
return InteractionController
