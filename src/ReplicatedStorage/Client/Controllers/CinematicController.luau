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
local Presentation = require("@game/ReplicatedStorage/Shared/Game/Presentation")
local HouseCatalog = require("@game/ReplicatedStorage/Shared/Game/HouseCatalog")
local Text = require("@game/ReplicatedStorage/Shared/Game/Text")
local Camera = require("./CameraController")
local Settings = require("./SettingsController")
local Transition = require("./TransitionController")
local Store = require("./StoreController")
local Animator = require("./CharacterAnimatorController")
local TungTungRig = require("../Creature/TungTungRig")
local ArmadilhoRig = require("../Creature/ArmadilhoRig")
local AudioController = require("./AudioController")
local Rain = require("./RainController")
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

-- Participação do Tung Tung nas cenas (só visual, só neste cliente).
-- Abertura: surge na porta na última tomada e bate o bastão. Laço do lobby: anda pela varanda.
local cameo: TungTungRig.TungRig? = nil
local cameoClock = 0
local armadilho: Model? = nil
local epilogueLight: BasePart? = nil
local epilogueShot = 0
local teaser: Frame? = nil
local teaserCountdown: TextLabel? = nil
-- Sob a porta, de frente para o quintal (o modelo olha para -Z): silhueta com recorte de luz fria.
local PORCH = CFrame.lookAt(Vector3.new(0.2, -0.5, 66), Vector3.new(1.2, -0.5, 90))
local porchLights: { Instance } = {}
local porchFlash = false
local porchDimmed: { Light } = {}

local function dropCameo()
	if armadilho then
		armadilho:Destroy()
		armadilho = nil
	end
	if epilogueLight then
		epilogueLight:Destroy()
		epilogueLight = nil
	end
	epilogueShot = 0
	for _, light in porchLights do
		light:Destroy()
	end
	table.clear(porchLights)
	for _, light in porchDimmed do
		if light.Parent then
			light.Enabled = true
		end
	end
	table.clear(porchDimmed)
	porchFlash = false
	if cameo then
		cameo.model:Destroy()
		cameo = nil
	end
end

local function ensureCameo(): TungTungRig.TungRig?
	if not cameo then
		cameo = TungTungRig.build(nil)
		if cameo then
			cameo.model.Name = "TungTungCameo"
			cameo.model.Parent = workspace
			cameoClock = 0
		end
	end
	return cameo
end

local function updateCameo(current: Shots.Sequence, index: number, dt: number)
	if current.name == "Opening" and not options.loop then
		if index < #current.shots then
			dropCameo()
			return
		end
		local rig = ensureCameo()
		if not rig then
			return
		end
		cameoClock += dt
		TungTungRig.place(rig, PORCH)
		if #porchLights == 0 then
			-- Recorte frio por trás/acima (contorno) e um fio de luz quente de frente: lê como vulto, não boneco.
			local function lamp(name: string, cframe: CFrame, light: Light): Part
				local holder = Instance.new("Part")
				holder.Name, holder.Anchored, holder.Transparency = name, true, 1
				holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
				holder.CFrame = cframe
				light.Parent = holder
				holder.Parent = workspace
				table.insert(porchLights, holder)
				return holder
			end
			-- Só neste plano (e só no cliente): as lâmpadas da varanda apagam e a luz dos olhos sai, senão o corpo
			-- fica laranja e chapado. Voltam ao normal no dropCameo.
			rig.eyeLight.Enabled = false
			for _, light in workspace:GetDescendants() do
				if light:IsA("Light") and light.Enabled and not light:IsDescendantOf(rig.model) then
					local holder = light.Parent
					local position = if holder and holder:IsA("BasePart")
						then holder.Position
						elseif holder and holder:IsA("Attachment") then holder.WorldPosition
						else nil
					if position and (position - PORCH.Position - Vector3.new(0, 6, 4)).Magnitude < 26 then
						light.Enabled = false
						table.insert(porchDimmed, light)
					end
				end
			end
			-- Contraluz frio no corredor (silhueta) e luz lateral quente e dura no rosto.
			local back = Instance.new("SpotLight")
			back.Color, back.Brightness, back.Range, back.Angle, back.Shadows =
				Color3.fromRGB(150, 175, 230), 12, 20, 60, true
			lamp("CameoBack", CFrame.lookAt(Vector3.new(0, 9, 55), Vector3.new(0.2, 5, 67)), back)
			local hall = Instance.new("PointLight")
			hall.Color, hall.Brightness, hall.Range, hall.Shadows = Color3.fromRGB(120, 140, 190), 1.2, 16, false
			lamp("CameoHall", CFrame.new(0, 7, 54), hall)
			local key = Instance.new("SpotLight")
			key.Color, key.Brightness, key.Range, key.Angle, key.Shadows = Color3.fromRGB(255, 150, 85), 8, 12, 30, true
			lamp("CameoKey", CFrame.lookAt(Vector3.new(6.5, 8, 67.5), Vector3.new(0.2, 7.4, 66.2)), key)
		end
		-- Relâmpago no meio do plano revela o rosto; no fim, o bastão bate.
		if not porchFlash and cameoClock > 1.4 then
			porchFlash = true
			Rain.strikeNow()
		end
		if cameoClock < 2.6 then
			TungTungRig.play(rig, "idle", 0)
		elseif TungTungRig.playing(rig) == "idle" then
			TungTungRig.play(rig, "slash", 0.2, 0.75)
		end
		TungTungRig.step(rig, dt)
	elseif current.name == "Attract" and options.loop then
		local rig = ensureCameo()
		if not rig then
			return
		end
		cameoClock += dt
		-- Trajeto oval: desacelera e vira pelo próprio arco, sem inverter 180 graus de uma vez.
		local angle = cameoClock * math.pi / 8
		local position = Vector3.new(2 + 7 * math.sin(angle), -0.5, 67 + math.cos(angle))
		local velocity = Vector3.new(7 * math.cos(angle), 0, -math.sin(angle)) * math.pi / 8
		TungTungRig.place(rig, CFrame.lookAt(position, position + velocity))
		TungTungRig.play(rig, "walk", 0.3, math.clamp(velocity.Magnitude / 3.5, 0.35, 1))
		TungTungRig.step(rig, dt)
	elseif current.name == "ForestRescue" and index == 1 then
		-- No último segundo ele pula no capô da van, bate no vidro e escorrega quando ela arranca.
		local actor = ensureCameo()
		if not actor then
			return
		end
		cameoClock += dt
		local hood = Vector3.new(0, 6.5, 876.5)
		local land, slide = 0.9, 2.8
		local position = hood
		if cameoClock < land then
			local k = cameoClock / land
			position = Vector3.new(-9, 0, 868):Lerp(hood, k) + Vector3.new(0, math.sin(k * math.pi) * 5, 0)
		elseif cameoClock >= slide then
			local k = math.min(1, (cameoClock - slide) / 0.7)
			position = hood + Vector3.new(7 * k, -6.5 * k * k, -3 * k)
		end
		TungTungRig.place(actor, CFrame.lookAt(position, Vector3.new(0, position.Y, 890)))
		TungTungRig.play(actor, if cameoClock >= land and cameoClock < slide then "slash" else "idle", 0.15)
		TungTungRig.step(actor, dt)
		if epilogueShot ~= index and cameoClock >= land then
			epilogueShot = index
			AudioController.play("DoorBang", 0.9, 0.8)
		end
	elseif current.name == "ForestRescue" and (index == 2 or index == 3) then
		local actor = ensureCameo()
		if actor then
			actor.eyeLight.Enabled = false
			TungTungRig.place(actor, CFrame.lookAt(Vector3.new(-7, 0, 830), Vector3.new(-7, 0, 850)))
			TungTungRig.play(actor, "idle", 0.2)
			TungTungRig.step(actor, dt)
		end
		if not armadilho then
			armadilho = ArmadilhoRig.build(workspace)
		end
		local crocodile = armadilho :: Model
		cameoClock += dt
		crocodile:PivotTo(
			CFrame.lookAt(
				Vector3.new(7, math.sin(cameoClock * 1.4) * 0.06, 828 + math.min(1.5, cameoClock * 0.15)),
				Vector3.new(7, 0, 850)
			)
		)
		if not epilogueLight then
			local lamp = Instance.new("Part")
			lamp.Name, lamp.Anchored, lamp.Transparency = "RescueHeadlights", true, 1
			lamp.CanCollide, lamp.CanQuery, lamp.CanTouch = false, false, false
			lamp.CFrame = CFrame.lookAt(Vector3.new(0, 8, 847), Vector3.new(0, 4, 830))
			local light = Instance.new("SpotLight")
			light.Angle, light.Range, light.Brightness, light.Shadows = 85, 52, 3.8, true
			light.Color, light.Parent = Color3.fromRGB(212, 194, 156), lamp
			lamp.Parent, epilogueLight = workspace, lamp
		end
		if epilogueShot ~= index then
			epilogueShot = index
			AudioController.play(if index == 2 then "DoorBang" else "Roar", 0.65, 0.65)
		end
	else
		dropCameo()
	end
end

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
	dropCameo()
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
		Transition.reveal(0.25)
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
		skipButton.Visible = false
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
		if token ~= cardToken then
			return
		end
		task.spawn(Transition.setLetterbox, true, 0.3)
		Transition.title(
			`ETAPA {stage}/{#HouseCatalog.Chapters}`,
			`{title}\n{if threat ~= "" then `AMEAÇA: {threat}  ·  ` else ""}VOCÊ: {roleTitle()}`
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
	-- Troca de fase invalida cartelas antigas; o respawn isolado continua preservando a cartela atual.
	cardToken += 1
	Transition.reset()
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
		Controller.play(
			if campaign and campaign:GetAttribute("ForestActive") == true
				then require("@game/ReplicatedStorage/Shared/Game/ForestCinema")
				else Shots.Escape
		)
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
	if skipButton then
		skipButton.Visible = not options.loop and elapsed >= 0.65
	end
	local nextShot = current.shots[index + 1]
	local cutShade = Presentation.cut(
		alpha,
		shot.duration,
		index > 1 and shot.cut == "blink",
		nextShot ~= nil and nextShot.cut == "blink"
	)
	Transition.sceneShade(if options.quiet then 0 else math.max(Presentation.shade(elapsed, total), cutShade))
	updateCameo(current, index, dt)
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
		-- Com cartela no primeiro plano, as legendas só começam depois dela (as duas dividem a faixa de baixo).
		local titleTime = if current.title then current.shots[1].duration else 0
		local line = if elapsed < titleTime
			then nil
			else Shots.caption(options.captions or current.captions, elapsed - titleTime, total - titleTime)
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
	if not Camera.setCinema(frame, Shots.lens(shot, progress), vec(look)) then
		Controller.stop()
	end
end

function Controller.Init()
	local gui = Create("ScreenGui", {
		Name = "CinematicControls",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 121,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local button = Create("TextButton", {
		Name = "Skip",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0.12, 8),
		Size = UDim2.fromOffset(220, 44),
		BackgroundColor3 = Theme.Panel,
		TextColor3 = Theme.Text,
		FontFace = Theme.Font,
		TextSize = 16,
		Text = if UserInputService.TouchEnabled then "PULAR CENA" else "PULAR CENA [ESPAÇO / A]",
		Modal = true,
		Visible = false,
		Parent = gui,
	}) :: TextButton
	skipButton = button
	local panel = Create("Frame", {
		Name = "NextGame",
		Parent = gui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(3, 5, 6),
		BorderSizePixel = 0,
		Visible = false,
	}) :: Frame
	local function cardLine(
		name: string,
		y: number,
		height: number,
		value: string,
		color: Color3,
		maximum: number
	): TextLabel
		local label = Create("TextLabel", {
			Name = name,
			Parent = panel,
			Position = UDim2.fromScale(0.1, y),
			Size = UDim2.fromScale(0.8, height),
			BackgroundTransparency = 1,
			Text = value,
			TextColor3 = color,
			FontFace = Theme.Font,
			TextWrapped = true,
			TextScaled = true,
		}) :: TextLabel
		Create("UITextSizeConstraint", { Parent = label, MinTextSize = 12, MaxTextSize = maximum })
		return label
	end
	cardLine("Kicker", 0.16, 0.07, "PRÓXIMO JOGO", Color3.fromRGB(162, 126, 75), 22)
	cardLine("Title", 0.27, 0.19, "A MANSÃO DO ARMADILHO", Color3.fromRGB(222, 208, 170), 46)
	cardLine(
		"Story",
		0.5,
		0.19,
		"Vocês fugiram da casa e da floresta.\nTung Tung Sahur e Crocodilo Armadilho estão procurando vocês.\nA caçada está só começando.",
		Color3.fromRGB(174, 184, 178),
		23
	)
	teaserCountdown = cardLine("Return", 0.8, 0.07, "CONTINUA...", Color3.fromRGB(147, 154, 150), 17)
	teaser = panel
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
			if command == "transition" then
				if value == "reset" then
					Transition.reset()
				elseif value == "caption" then
					Transition.caption("Uma fita. Três pancadas. Não responda.")
				elseif value == "title" then
					Transition.title("CAPÍTULO 08", "A FLORESTA · NINGUÉM FICA PARA TRÁS")
				elseif value == "replace" then
					Transition.title(nil)
					Transition.title("CAPÍTULO 09", "A NOVA FITA")
				end
			elseif command == "scene" then
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
				feedback = require("./UiFeedbackController").debugState(),
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
			and elapsed >= 0.65
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
		local state = campaignState()
		local showTeaser = phase == "Won"
			and state ~= nil
			and state:GetAttribute("ForestActive") == true
			and (current == nil or (current.name == "ForestRescue" and lastShot >= 4))
		if teaser then
			teaser.Visible = showTeaser
		end
		player:SetAttribute("ForestEpilogueVisible", showTeaser)
		if showTeaser and teaserCountdown and state then
			local remaining = math.max(
				0,
				math.ceil(
					(tonumber(state:GetAttribute("LobbyReturnAt")) or workspace:GetServerTimeNow())
						- workspace:GetServerTimeNow()
				)
			)
			teaserCountdown.Text = `CONTINUA...  ·  A equipe volta ao lobby em {remaining}s`
		end
		if not current then
			-- Lobby com o menu de modo aberto: câmeras de segurança ao fundo (só se o palco 3D do menu não existir).
			if
				phase == "Lobby"
				and player:GetAttribute("ModeMenuOpen") == true
				and player:GetAttribute("MenuStageActive") ~= true
				and not Store.isOpen()
			then
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
