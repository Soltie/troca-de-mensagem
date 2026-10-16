--!strict
--[[
	Cenas locais; a fase e o relógio da partida continuam sendo decididos pelo servidor.

	  Opening  primeira vez no lobby (antes do menu de modo) e cartela da missão solo (briefing nas legendas);
	  Attract  câmeras de segurança em laço atrás do menu de modo, enquanto a equipe vota;
	  Escape   vitória, da estrada;
	  Story*   capítulos do modo história (o StoryController chama play()).

	Sem tirar a câmera, durante o congelamento do servidor: cartela de etapa do modo padrão com o olho
	abrindo, despertar no início da missão solo e ao ser resgatado.
	Planos de câmera de segurança (CinematicShots.isCctv) andam a 12 quadros/s com cor de CFTV; planos
	na mão são lisos. O próprio personagem aparece nas câmeras. Espaço/A/botão pula (o laço do lobby só
	some com o menu). Movimento reduzido: planos estáticos e olhos abrindo sem tremida.

	Atributos locais do jogador: CinematicActive (cena no ar: HUDs e mão somem), CinematicHold (cena de
	verdade: avisos da loja esperam) e OpeningActive (abertura do lobby: o menu de modo espera).
]]
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Config = require("@game/ReplicatedStorage/Shared/Config")
local CampaignCatalog = require("@game/ReplicatedStorage/Shared/Game/CampaignCatalog")
local GameState = require("@game/ReplicatedStorage/Shared/Game/GameState")
local Shots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Camera = require("./CameraController")
local Settings = require("./SettingsController")
local Transition = require("./TransitionController")
local Store = require("./StoreController")
local Animator = require("./CharacterAnimatorController")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")

local CCTV_FPS = 12

export type PlayOptions = {
	-- Repete a sequência até stop() (laço do lobby).
	loop: boolean?,
	-- Sem faixas de cinema nem botão de pular (fica atrás do menu).
	quiet: boolean?,
	-- Troca as legendas da sequência (ex.: briefing da missão solo).
	captions: { string }?,
}

local player = Players.LocalPlayer
local sequence: Shots.Sequence? = nil
local options: PlayOptions = {}
local elapsed = 0
local lastShot = 0
local lastKey = ""
local lastCaption: string? = nil
local ownsTitle = false
local openingSeen = false
local skipButton: TextButton? = nil
local cctvTint: ColorCorrectionEffect? = nil
-- LocalTransparencyModifier original das peças do próprio corpo (aparece nas câmeras).
local revealed: { [BasePart]: number } = {}
local cardToken = 0
local Controller = { Name = "CinematicController" }

local function vec(v: Shots.Vec): Vector3
	return Vector3.new(v.x, v.y, v.z)
end

local function sink(): Enum.ContextActionResult
	return Enum.ContextActionResult.Sink
end

local function campaignState(): Instance?
	return if Config.Campaign.Enabled then ReplicatedStorage:FindFirstChild("CampaignState") else nil
end

local function hideSelf()
	for part, value in revealed do
		if part.Parent then
			part.LocalTransparencyModifier = value
		end
	end
	revealed = {}
end

local function showSelf()
	local character = player.Character
	if not character then
		return
	end
	for _, inst in character:GetDescendants() do
		if inst:IsA("BasePart") then
			if revealed[inst] == nil then
				revealed[inst] = inst.LocalTransparencyModifier
			end
			inst.LocalTransparencyModifier = 0
		end
	end
end

local function setCctv(on: boolean)
	if cctvTint then
		cctvTint.Enabled = on
	end
end

function Controller.stop()
	local wasActive = sequence ~= nil
	sequence = nil
	options = {}
	lastCaption = nil
	ownsTitle = false
	player:SetAttribute("CinematicActive", false)
	player:SetAttribute("CinematicHold", false)
	player:SetAttribute("OpeningActive", false)
	if skipButton then
		skipButton.Visible = false
	end
	ContextActionService:UnbindAction("S9CinemaMovement")
	Camera.endCinema()
	setCctv(false)
	hideSelf()
	-- Sem cena no ar, não apaga a cartela de etapa nem o despertar (renascer chama stop()).
	if wasActive then
		Transition.reset()
	end
end

function Controller.play(value: Shots.Sequence, playOptions: PlayOptions?)
	Controller.stop()
	if Store.isOpen() then
		return
	end
	-- Uma cena nova cancela a cartela/despertar em curso: começa com a tela limpa (olhos abertos).
	cardToken += 1
	Transition.reset()
	sequence = value
	options = playOptions or {}
	elapsed = 0
	lastShot = 0
	player:SetAttribute("CinematicActive", true)
	-- Avisos da loja esperam cenas de verdade (o laço do lobby não segura nada).
	player:SetAttribute("CinematicHold", not options.loop)
	if skipButton then
		skipButton.Visible = not options.loop
	end
	ContextActionService:BindActionAtPriority(
		"S9CinemaMovement",
		sink,
		false,
		3000,
		Enum.PlayerActions.CharacterForward,
		Enum.PlayerActions.CharacterBackward,
		Enum.PlayerActions.CharacterLeft,
		Enum.PlayerActions.CharacterRight,
		Enum.PlayerActions.CharacterJump
	)
	if not options.quiet then
		task.spawn(Transition.setLetterbox, true, 0.35)
	end
	-- Laço do lobby é "ao vivo" (REC, hora atual da noite); o resto é fita reproduzida.
	local live = options.loop == true
	Transition.stamp(
		value.shots[1].label,
		if live then "REC" else "PLAY",
		Shots.TAPE_START + (if live then os.time() % 1800 else 0)
	)
	if value.title then
		Transition.title(value.title, value.subtitle)
		ownsTitle = true
	end
end

function Controller.debugState(): { [string]: any }
	return {
		sequence = if sequence then sequence.name else "",
		elapsed = elapsed,
		shot = lastShot,
		loop = options.loop == true,
		caption = lastCaption,
		cctv = cctvTint ~= nil and cctvTint.Enabled,
		revealed = next(revealed) ~= nil,
		openingSeen = openingSeen,
	}
end

local function phaseKey(): (string, string)
	local campaign = campaignState()
	if campaign then
		local phase = tostring(campaign:GetAttribute("Phase"))
		return phase, `{phase}:{campaign:GetAttribute("CampaignId")}:{campaign:GetAttribute("Stage")}`
	end
	local state = GameState.snapshot()
	return state.phase, `{state.phase}:{state.roundId}`
end

local function roleTitle(): string
	local id = player:GetAttribute("CampaignRole")
	for _, role in CampaignCatalog.Roles do
		if role.id == id then
			return role.title
		end
	end
	return "EQUIPE"
end

-- Olhos fecham rápido e abrem pesados (acordar, voltar do resgate).
function Controller.wake(delay: number?)
	cardToken += 1
	local token = cardToken
	task.spawn(function()
		Transition.closeEyes(0.1)
		task.wait(delay or 0.15)
		if token == cardToken then
			Transition.openEyes(1, Settings.motionEnabled())
		end
	end)
end

--[[
	Cartela de etapa (modo padrão): tela escura com "ETAPA N/3", o servidor recria e congela os
	personagens; o olho abre na equipe e a cartela sai. Não mexe na câmera nem nos controles.
]]
function Controller.stageCard()
	local campaign = campaignState()
	if not campaign then
		return
	end
	cardToken += 1
	local token = cardToken
	local stage = tonumber(campaign:GetAttribute("Stage")) or 1
	local title = tostring(campaign:GetAttribute("Title") or "")
	local threat = tostring(campaign:GetAttribute("Threat") or "")
	local character = player.Character
	task.spawn(function()
		local started = os.clock()
		Transition.closeEyes(0.12)
		task.spawn(Transition.setLetterbox, true, 0.3)
		Transition.title(
			`ETAPA {stage}/{#CampaignCatalog.Stages} · {title}`,
			if threat ~= "" then `AMEAÇA: {threat}  ·  VOCÊ: {roleTitle()}` else `VOCÊ: {roleTitle()}`
		)
		-- Espera o renascimento da etapa (ou o fim do congelamento), no máximo ~3 s no escuro.
		while token == cardToken and os.clock() - started < 3.2 do
			local current = player.Character
			local root = current and current:FindFirstChild("HumanoidRootPart")
			local respawned = current ~= character and root ~= nil
			local released = root ~= nil and root:IsA("BasePart") and not root.Anchored
			if respawned or (released and os.clock() - started > 1.2) then
				break
			end
			task.wait(0.1)
		end
		local rest = 1.1 - (os.clock() - started)
		if rest > 0 then
			task.wait(rest)
		end
		if token ~= cardToken then
			return
		end
		Transition.openEyes(1.1, Settings.motionEnabled())
		task.wait(1.3)
		if token ~= cardToken then
			return
		end
		Transition.title(nil)
		Transition.setLetterbox(false, 0.35)
	end)
end

local function onKeyChanged(phase: string, previous: string)
	Controller.stop()
	local campaign = campaignState()
	if phase == "Lobby" then
		-- Primeira vez no servidor: a abertura passa antes do menu (o menu espera OpeningActive).
		if not openingSeen then
			openingSeen = true
			Controller.play(Shots.Opening)
			player:SetAttribute("OpeningActive", true)
		end
	elseif phase == "Intro" then
		if not GameState.snapshot().fromCheckpoint then
			Controller.play(Shots.Opening, { captions = Text.Intro })
			player:SetAttribute("OpeningActive", true)
		end
	elseif phase == "Won" then
		Controller.play(Shots.Escape)
	elseif phase == "Playing" and previous ~= "" then
		if campaign and campaign:GetAttribute("GameMode") ~= "Story" then
			Controller.stageCard()
		elseif campaign then
			-- História: a cena do capítulo vem do servidor; só um piscar para marcar o corte.
			task.spawn(Transition.blink, 0.02)
		else
			Controller.wake()
		end
	end
end

local function updateSequence(current: Shots.Sequence, dt: number)
	elapsed += dt
	local total = Shots.duration(current)
	local time = if options.loop then Shots.wrap(current, elapsed) else elapsed
	local index, alpha, done = Shots.locate(current, time)
	if done then
		Controller.stop()
		return
	end
	local shot = current.shots[index]
	local cctv = Shots.isCctv(shot)
	if lastShot ~= index then
		local first = lastShot == 0
		lastShot = index
		Transition.stamp(shot.label, if options.loop then "REC" else "PLAY")
		if shot.cut == "static" and not first then
			Transition.static(0.22, 0.5)
		end
		setCctv(cctv)
		-- A cartela de abertura fica só no primeiro plano.
		if ownsTitle and not first then
			Transition.title(nil)
			ownsTitle = false
		end
	end
	if ownsTitle and #current.shots == 1 and alpha > 0.55 then
		Transition.title(nil)
		ownsTitle = false
	end
	if not options.loop then
		local line = Shots.caption(options.captions or current.captions, elapsed, total)
		if line ~= lastCaption then
			lastCaption = line
			Transition.caption(line)
		end
	end

	local motion = Settings.motionEnabled()
	local progress = if not motion then 0.5 elseif cctv then Shots.quantize(alpha, shot.duration, CCTV_FPS) else alpha
	local position, look = Shots.sample(shot, progress)
	local frame = CFrame.lookAt(vec(position), vec(look))
	if motion and Settings.get("shake") and shot.handheld > 0 then
		local amount = shot.handheld
		frame *= CFrame.Angles(
			math.noise(elapsed * 0.7, 1.3) * amount * 0.02,
			math.noise(elapsed * 0.6, 7.1) * amount * 0.025,
			math.noise(elapsed * 0.5, 3.7) * amount * 0.015
		)
	end
	if not Camera.setCinema(frame, shot.fov, vec(look)) then
		Controller.stop()
	end
end

function Controller.Init()
	local gui = Create("ScreenGui", {
		Name = "CinematicControls",
		ResetOnSpawn = false,
		DisplayOrder = 121,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local button = Create("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -20),
		Size = UDim2.fromOffset(220, 32),
		BackgroundColor3 = Theme.Panel,
		TextColor3 = Theme.Text,
		FontFace = Theme.Font,
		TextSize = 16,
		Text = "PULAR CENA [ESPAÇO / A]",
		Modal = true,
		Visible = false,
		Parent = gui,
	}) :: TextButton
	skipButton = button
	button.Activated:Connect(Controller.stop)
	-- Imagem de CFTV com visão noturna: dessaturada, clareada e esverdeada (só nos planos fixos).
	local tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "S9CctvFeed"
	tint.Saturation = -0.8
	tint.Contrast = 0.12
	tint.Brightness = 0.14
	tint.TintColor = Color3.fromRGB(200, 236, 210)
	tint.Enabled = false
	tint.Parent = Lighting
	cctvTint = tint
	-- A ponte usa a VM real dos controllers (execute_luau roda em outra VM).
	if RunService:IsStudio() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "AnimationDebugBridge"
		bridge.OnInvoke = function(command: string, value: any): any
			if command == "scene" then
				local selected = if value == "Escape"
					then Shots.Escape
					elseif value == "Attract" then Shots.Attract
					else Shots.Opening
				Controller.play(selected, if value == "Attract" then { loop = true, quiet = true } else nil)
			elseif command == "skip" then
				Controller.stop()
			elseif command == "stage" then
				Controller.stageCard()
			elseif command == "wake" then
				Controller.wake()
			elseif command == "motion" then
				for _, key in { "bob", "tilt", "shake", "fov", "flashes" } do
					Settings.set(key :: Settings.Key, value == true)
				end
			end
			return {
				cinematic = Controller.debugState(),
				camera = Camera.debugState(),
				transition = Transition.debugState(),
				characters = Animator.debugState(),
			}
		end
		bridge.Parent = gui
	end
end

function Controller.Start()
	UserInputService.InputBegan:Connect(function(input, _processed)
		if
			UserInputService:GetFocusedTextBox() == nil
			and sequence
			and not options.loop
			and (input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA)
		then
			Controller.stop()
		end
	end)
	player.CharacterRemoving:Connect(Controller.stop)
	-- Resgatado: os olhos abrem de novo.
	local lastStatus = player:GetAttribute("CampaignStatus")
	player:GetAttributeChangedSignal("CampaignStatus"):Connect(function()
		local status = player:GetAttribute("CampaignStatus")
		if lastStatus == "Downed" and status == "Active" then
			Controller.wake(0.2)
		end
		lastStatus = status
	end)
	RunService:BindToRenderStep("S9Cinematic", Enum.RenderPriority.Camera.Value - 2, function(dt)
		local phase, key = phaseKey()
		if key ~= lastKey then
			local previous = lastKey
			lastKey = key
			onKeyChanged(phase, previous)
		end
		local current = sequence
		if not current then
			-- Lobby com o menu de modo aberto: câmeras de segurança ao fundo.
			if phase == "Lobby" and player:GetAttribute("ModeMenuOpen") == true and not Store.isOpen() then
				Controller.play(Shots.Attract, { loop = true, quiet = true })
			end
			return
		end
		if Store.isOpen() or player:GetAttribute("CampaignStatus") == "Downed" then
			Controller.stop()
			return
		end
		if options.loop and phase ~= "Lobby" then
			Controller.stop()
			return
		end
		updateSequence(current, dt)
	end)
	-- Depois do módulo de câmera do Roblox (que esconde o corpo em primeira pessoa).
	RunService:BindToRenderStep("S9CinematicSelf", Enum.RenderPriority.Camera.Value + 3, function()
		if sequence then
			showSelf()
		end
	end)
end
return Controller
