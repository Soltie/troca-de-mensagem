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
local AudioController = require("./AudioController")
local GameUiController = require("./GameUiController")

local player = Players.LocalPlayer
local CONE_DEGREES = 24
local CONE_CLOSE_DEGREES = 40

local current: BasePart? = nil
local busy = false
local phase: GameState.Phase = "Loading"

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

local function interact(part: BasePart)
	local id = part:GetAttribute(Tags.Attr.InteractId)
	if type(id) ~= "string" or busy then
		return
	end
	busy = true
	local ok, response = pcall(function()
		return Remotes.clientFunction("Interact", 5):InvokeServer(id)
	end)
	busy = false
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
			AudioController.play("UiBlip", 1, 0.8)
			GameUiController.showNote(data.note)
		elseif data.message == "fuse_taken" then
			AudioController.play("Switch", 0.7, 1.7)
		end
	else
		AudioController.play("UiBlip", 1, 0.55)
	end
	local text = messageFor(data.message)
	if text ~= "" then
		GameUiController.caption(text)
	end
end

local InteractionController = {
	Name = "InteractionController",
}

function InteractionController.Start()
	GameState.observe(function(snapshot)
		phase = snapshot.phase
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or input.KeyCode ~= Enum.KeyCode.E then
			return
		end
		if GameUiController.isNoteOpen() then
			GameUiController.closeNote()
			return
		end
		local part = current
		if part and phase == "Playing" then
			task.spawn(interact, part)
		end
	end)

	local accumulator = 0
	RunService.RenderStepped:Connect(function(dt: number)
		accumulator += dt
		if accumulator < 1 / 20 then
			return
		end
		accumulator = 0
		local camera = workspace.CurrentCamera
		if not camera or phase ~= "Playing" or GameUiController.isNoteOpen() then
			current = nil
			GameUiController.setPrompt(nil)
			return
		end
		current = findTarget(camera)
		if current then
			local prompt = current:GetAttribute(Tags.Attr.InteractPrompt)
			GameUiController.setPrompt(`[E] {if type(prompt) == "string" then prompt else ""}`)
		else
			GameUiController.setPrompt(nil)
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
