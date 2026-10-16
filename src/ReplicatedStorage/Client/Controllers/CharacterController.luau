--!strict
--[[
	Corpo do jogador em primeira pessoa (cliente). A câmera em si fica no CameraController.
	- Corrida com fôlego (Shift) e aceleração/frenagem com peso (WalkSpeed em rampa).
	- Exaustão: fôlego zerado = passos lentos e ofegantes por ExhaustedTime.
	- Agachar: C alterna, Ctrl segura (controle: B). O pedido vai ao servidor (SetStance), que
	  valida o teto e muda o corpo (HipHeight). Levantar sem espaço é recusado aqui e lá.
	- Detecta pousos (para o tranco de câmera e o som).
	O servidor valida a velocidade e decide o resultado mecânico (ver PlayerStateService).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require("@game/ReplicatedStorage/Shared/Config")
local Perks = require("@game/ReplicatedStorage/Shared/Game/Perks")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Remotes = require("@game/ReplicatedStorage/Shared/Net/Remotes")

export type Stance = "Stand" | "Crouch"

export type Motion = {
	-- Velocidade horizontal real (studs/s) e componente lateral no espaço da câmera.
	speed: number,
	lateral: number,
	sprinting: boolean,
	stance: Stance,
	-- 0..1: quão "sem fôlego" (exaustão recente).
	exhaustion: number,
	grounded: boolean,
	floorY: number?,
	floorMaterial: Enum.Material?,
	floorPart: BasePart?,
	standHipHeight: number,
	hidden: boolean,
}

local P = Config.Player
local player = Players.LocalPlayer

local stamina = P.StaminaMax
local exhaustedUntil = 0
local exhaustion = 0
local sprinting = false
local phase: GameState.Phase = "Loading"
local currentSpeed = P.WalkSpeed
local requested: Stance = "Stand"
local requestedAt = 0
local crouchHeld = false
local toggledCrouch = false
local lastStandTry = 0
local standHipHeight = 2
local peakFall = 0
local landedCallbacks: { (number) -> () } = {}
local blockedCallbacks: { () -> () } = {}
local lastBlockedAt = 0
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local motion: Motion = {
	speed = 0,
	lateral = 0,
	sprinting = false,
	stance = "Stand",
	exhaustion = 0,
	grounded = true,
	floorY = nil,
	floorMaterial = nil,
	floorPart = nil,
	standHipHeight = 2,
	hidden = false,
}

local function humanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function disableCoreUi()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	task.spawn(function()
		for _ = 1, 20 do
			local ok = pcall(function()
				StarterGui:SetCore("ResetButtonCallback", false)
			end)
			if ok then
				return
			end
			task.wait(0.5)
		end
	end)
end

-- Postura confirmada pelo servidor (atributo no Player).
local function serverStance(): Stance
	if player:GetAttribute("Stance") == "Crouch" then
		return "Crouch"
	end
	return "Stand"
end

local function isHidden(): boolean
	local hidden = player:GetAttribute("Hidden")
	return type(hidden) == "string" and hidden ~= ""
end

local function active(): boolean
	local status = player:GetAttribute("CampaignStatus")
	return status == nil or status == "Active"
end

-- Há espaço acima da cabeça para levantar? (o servidor faz a mesma checagem)
local function canStand(): boolean
	local root = rootPart()
	local character = player.Character
	if not root or not character then
		return true
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	params.CollisionGroup = root.CollisionGroup
	local height = P.CrouchDrop + P.StandClearance
	-- Topo da cabeça agachado ~ centro da raiz + 2.3.
	local center = root.Position + Vector3.new(0, 2.3 + height / 2, 0)
	local parts = workspace:GetPartBoundsInBox(CFrame.new(center), Vector3.new(1.6, height, 1.2), params)
	return #parts == 0
end

local function sendStance(stance: Stance)
	requested = stance
	requestedAt = os.clock()
	task.spawn(function()
		local ok, remote = pcall(Remotes.clientEvent, "SetStance", 5)
		if ok then
			remote:FireServer(stance)
		end
	end)
end

local function desiredStance(): Stance
	if crouchHeld or toggledCrouch then
		return "Crouch"
	end
	return "Stand"
end

-- Leva a postura pedida ao servidor. Levantar só com espaço (avisa a UI se faltar).
local function syncStance(now: number)
	if phase ~= "Playing" or isHidden() or not active() then
		return
	end
	local desired = desiredStance()
	local confirmed = serverStance()
	if desired == requested and (desired == confirmed or now - requestedAt < 0.6) then
		return
	end
	if desired == "Crouch" then
		sendStance("Crouch")
		return
	end
	if now - lastStandTry < 0.25 then
		return
	end
	lastStandTry = now
	if not canStand() then
		if now - lastBlockedAt > 2.5 then
			lastBlockedAt = now
			for _, callback in blockedCallbacks do
				task.spawn(callback)
			end
		end
		return
	end
	sendStance("Stand")
end

local function currentStance(): Stance
	-- O pedido vale por um instante (resposta do servidor a caminho); depois manda o servidor.
	if os.clock() - requestedAt < 0.6 then
		return requested
	end
	return serverStance()
end

local function probeFloor(root: BasePart, character: Model)
	rayParams.FilterDescendantsInstances = { character }
	local hit =
		workspace:Raycast(root.Position, Vector3.new(0, -(root.Size.Y / 2 + standHipHeight + 1.5), 0), rayParams)
	if hit then
		motion.floorY = hit.Position.Y
		motion.floorMaterial = hit.Material
		motion.floorPart = if hit.Instance:IsA("BasePart") then hit.Instance else nil
	else
		motion.floorY = nil
		motion.floorMaterial = nil
		motion.floorPart = nil
	end
end

local function update(dt: number)
	local h = humanoid()
	local root = rootPart()
	local character = player.Character
	if not h or not root or not character then
		return
	end
	local now = os.clock()
	local hidden = isHidden()
	motion.hidden = hidden

	-- C alterna, Ctrl segura. Sem teto para levantar, continua agachado e tenta de novo.
	syncStance(now)
	local stance: Stance = currentStance()

	local moving = h.MoveDirection.Magnitude > 0.1
	local wantsSprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.ButtonL3)
	if stamina <= 0 and exhaustedUntil < now then
		exhaustedUntil = now + P.ExhaustedTime
	end
	local exhausted = now < exhaustedUntil or (stamina < P.StaminaMinToSprint and exhaustedUntil > now - 2)
	sprinting = phase == "Playing"
		and active()
		and wantsSprint
		and moving
		and not exhausted
		and stance == "Stand"
		and not hidden

	-- Melhoria "Fôlego de Maratona" (nível publicado pelo StoreService): mais fôlego e recarga.
	local lungs = Perks.factor("folego", tonumber(player:GetAttribute("PerkFolego")) or 0)
	local staminaMax = P.StaminaMax * lungs
	if sprinting then
		stamina = math.max(0, stamina - dt)
	else
		stamina = math.min(staminaMax, stamina + dt * P.StaminaRegen * lungs * (if moving then 0.7 else 1))
	end
	local exhaustionTarget = if now < exhaustedUntil then 1 else math.clamp(1 - stamina / staminaMax, 0, 1) * 0.5
	exhaustion += (exhaustionTarget - exhaustion) * math.min(1, dt * (if exhaustionTarget > exhaustion then 4 else 0.5))

	-- Velocidade em rampa (peso).
	local target = if stance == "Crouch"
		then P.CrouchSpeed
		elseif sprinting then P.SprintSpeed
		elseif now < exhaustedUntil then P.ExhaustedSpeed
		else P.WalkSpeed
	if not moving then
		target = math.min(target, P.WalkSpeed * 0.45)
	end
	local rate = if target > currentSpeed then P.Acceleration else P.Deceleration
	currentSpeed += math.clamp(target - currentSpeed, -rate * dt, rate * dt)
	if phase == "Playing" and active() and not hidden then
		h.WalkSpeed = math.max(currentSpeed, P.WalkSpeed * 0.45)
		h.JumpHeight = if stance == "Crouch" then 0 else P.JumpHeight
	end

	-- Medidas para câmera e sons.
	local velocity = root.AssemblyLinearVelocity
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z)
	local camera = workspace.CurrentCamera
	motion.speed = horizontal.Magnitude
	motion.lateral = if camera then camera.CFrame.RightVector:Dot(horizontal) else 0
	motion.sprinting = sprinting
	motion.stance = stance :: Stance
	motion.exhaustion = exhaustion
	motion.grounded = h.FloorMaterial ~= Enum.Material.Air
	motion.standHipHeight = standHipHeight
	probeFloor(root, character)

	-- Queda: guarda a maior velocidade de descida até pousar.
	if not motion.grounded then
		peakFall = math.max(peakFall, -velocity.Y)
	elseif peakFall > 0 then
		local fall = peakFall
		peakFall = 0
		if fall >= Config.Camera.LandingMinSpeed then
			local intensity = math.clamp(
				(fall - Config.Camera.LandingMinSpeed) / (Config.Camera.LandingMaxSpeed - Config.Camera.LandingMinSpeed),
				0.15,
				1
			)
			for _, callback in landedCallbacks do
				task.spawn(callback, intensity)
			end
		end
	end
end

local CharacterController = {
	Name = "CharacterController",
}

function CharacterController.Init()
	-- Primeira pessoa travada (definido no cliente: no servidor não replica de forma confiável).
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
	player.CameraMinZoomDistance = 0.5
	disableCoreUi()
	UserInputService.MouseIconEnabled = false
end

function CharacterController.Start()
	GameState.observe(function(snapshot)
		if snapshot.phase ~= phase and snapshot.phase == "Intro" then
			stamina = P.StaminaMax
			exhaustedUntil = 0
			exhaustion = 0
			requested = "Stand"
			toggledCrouch = false
			crouchHeld = false
		end
		phase = snapshot.phase
	end)

	player.CharacterAdded:Connect(function(character: Model)
		local h = character:WaitForChild("Humanoid", 10)
		if h and h:IsA("Humanoid") then
			-- Altura de pé de referência (o servidor muda o HipHeight ao agachar).
			standHipHeight = (character:GetAttribute("StandHipHeight") :: number?) or h.HipHeight
		end
		requested = "Stand"
		toggledCrouch = false
		peakFall = 0
	end)

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or not active() then
			return
		end
		if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonB then
			if not crouchHeld then
				toggledCrouch = not toggledCrouch
			end
		elseif input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			crouchHeld = true
			toggledCrouch = false
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl then
			crouchHeld = false
		end
	end)

	RunService.RenderStepped:Connect(update)
end

function CharacterController.getStamina(): (number, number)
	return stamina, P.StaminaMax * Perks.factor("folego", tonumber(player:GetAttribute("PerkFolego")) or 0)
end

function CharacterController.isSprinting(): boolean
	return sprinting
end

function CharacterController.getMotion(): Motion
	return motion
end

function CharacterController.onLanded(callback: (intensity: number) -> ())
	table.insert(landedCallbacks, callback)
end

-- Chamado quando o jogador tenta levantar sem espaço (a UI mostra um aviso).
function CharacterController.onStandBlocked(callback: () -> ())
	table.insert(blockedCallbacks, callback)
end

-- Força uma postura (ex.: sair do esconderijo de pé). Respeita o teto.
function CharacterController.requestStance(stance: Stance)
	toggledCrouch = stance == "Crouch"
	crouchHeld = false
end

return CharacterController
