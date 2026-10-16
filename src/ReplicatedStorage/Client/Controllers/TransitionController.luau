--!strict
--[[
	Transições de tela (só cliente), no ritmo stop-motion do jogo (passos de 1/12 s):

	  letterbox  faixas de cinema (entram e saem em passos);
	  eyes       pálpebras com borda suave: fechar, abrir com tremida (acordar, voltar do resgate);
	  fade       tela preta (0 = some, 1 = preto);
	  static     estática de fita VHS entre planos; com "flashes" desligado vira só um escurecer;
	  stamp      carimbo da fita: ▶ PLAY / ● REC, nome da câmera e relógio correndo;
	  title      cartela central (título + subtítulo) com tremida de projeção;
	  caption    legenda datilografada na faixa de baixo.

	Funções que animam (setLetterbox, closeEyes, openEyes, blink, setFade) BLOQUEIAM até terminar:
	chame dentro de task.spawn quando não quiser esperar. Cada camada tem um token: um pedido novo
	cancela a animação anterior da mesma camada. reset() limpa tudo na hora.
	A tela fica acima de toda a interface (DisplayOrder 120).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CinematicShots = require("@game/ReplicatedStorage/Shared/Game/CinematicShots")
local PixelText = require("@game/ReplicatedStorage/Shared/Game/PixelText")
local SettingsController = require("./SettingsController")
local Create = require("../UI/Create")
local Theme = require("../UI/Theme")

local STEP = 1 / 12
local BAR = 0.11
local NOISE_BARS = 22
local LID = 0.62

export type StampMode = "PLAY" | "REC"

type Refs = {
	gui: ScreenGui,
	top: Frame,
	bottom: Frame,
	lidTop: Frame,
	lidBottom: Frame,
	fade: Frame,
	noise: Frame,
	bars: { Frame },
	tracking: Frame,
	stamp: Frame,
	stampMode: TextLabel,
	stampDot: Frame,
	stampCamera: TextLabel,
	stampClock: TextLabel,
	title: TextLabel,
	subtitle: TextLabel,
	caption: TextLabel,
}

local refs: Refs? = nil
local tokens: { [string]: number } = {}
local letterboxAlpha = 0
local eyesAlpha = 0
local fadeAlpha = 0
local staticUntil = 0
local staticStrength = 0
local stampClock = 0
local stampMode: StampMode = "PLAY"
local rng = Random.new()

local function r(): Refs
	assert(refs, "[TransitionController] used before Init")
	return refs
end

local function bump(layer: string): number
	tokens[layer] = (tokens[layer] or 0) + 1
	return tokens[layer]
end

local function alive(layer: string, token: number): boolean
	return tokens[layer] == token
end

-- Anima apply(t) de 0 a 1 em passos de STEP; false se outro pedido da camada cancelou.
local function stepped(layer: string, duration: number, apply: (number) -> ()): boolean
	local token = bump(layer)
	local steps = math.max(1, math.floor(duration / STEP + 0.5))
	for i = 1, steps do
		if not alive(layer, token) then
			return false
		end
		apply(i / steps)
		if i < steps then
			task.wait(STEP)
		end
	end
	return alive(layer, token)
end

local function text(props: { [string]: any }): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextSize = Theme.SizeBody,
		TextColor3 = Theme.Text,
		TextStrokeColor3 = Theme.Black,
		TextStrokeTransparency = 0.3,
		ZIndex = 6,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Create("TextLabel", defaults) :: TextLabel
end

local function black(props: { [string]: any }, children: { any }?): Frame
	local defaults: { [string]: any } = {
		BackgroundColor3 = Theme.Black,
		BorderSizePixel = 0,
	}
	for key, value in props do
		defaults[key] = value
	end
	return Create("Frame", defaults, children) :: Frame
end

-- Borda suave das pálpebras (transparente só na beira que fecha).
local function lidGradient(rotation: number): Instance
	return Create("UIGradient", {
		Rotation = rotation,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.82, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})
end

local function build(): Refs
	local gui = Create("ScreenGui", {
		Name = "TransitionUi",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 120,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	local top = black({ Name = "BarTop", Size = UDim2.fromScale(1, 0), ZIndex = 2, Parent = gui })
	local bottom = black({
		Name = "BarBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		ZIndex = 2,
		Parent = gui,
	})

	-- Estática: barras horizontais sorteadas a cada passo + faixa de tracking.
	local noise = Create("Frame", {
		Name = "Static",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(120, 120, 116),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 3,
		Parent = gui,
	}) :: Frame
	local bars: { Frame } = {}
	for i = 1, NOISE_BARS do
		table.insert(
			bars,
			Create("Frame", {
				Name = `Bar{i}`,
				BorderSizePixel = 0,
				ZIndex = 3,
				Parent = noise,
			}) :: Frame
		)
	end
	local tracking = Create("Frame", {
		Name = "Tracking",
		Size = UDim2.fromScale(1, 0.07),
		BackgroundColor3 = Color3.fromRGB(230, 230, 222),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = noise,
	}) :: Frame

	-- Carimbo da fita (canto superior, dentro da faixa quando ela existe).
	local stamp = Create("Frame", {
		Name = "Stamp",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 6,
		Parent = gui,
	}) :: Frame
	-- Ponto vermelho do REC (a fonte pixel não tem "●").
	local stampDot = Create("Frame", {
		Name = "Dot",
		Position = UDim2.new(0, 28, 0.03, 4),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
		Parent = stamp,
	}, {
		Create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	}) :: Frame
	local stampModeLabel = text({
		Name = "Mode",
		Position = UDim2.new(0, 52, 0.03, 0),
		Size = UDim2.fromOffset(240, 24),
		TextSize = Theme.SizeLarge,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stamp,
	})
	local stampCamera = text({
		Name = "Camera",
		Position = UDim2.new(0, 28, 0.03, 28),
		Size = UDim2.fromOffset(520, 18),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = stamp,
	})
	local stampClockLabel = text({
		Name = "Clock",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -28, 0.03, 0),
		Size = UDim2.fromOffset(300, 24),
		TextSize = Theme.SizeLarge,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = stamp,
	})

	local title = text({
		Name = "Title",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.new(0.9, 0, 0, 60),
		TextSize = 56,
		TextColor3 = Theme.Text,
		TextStrokeTransparency = 0,
		Visible = false,
		ZIndex = 7,
		Parent = gui,
	})
	local subtitle = text({
		Name = "Subtitle",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.44, 40),
		Size = UDim2.new(0.9, 0, 0, 22),
		TextSize = Theme.SizeLarge,
		TextColor3 = Theme.Hazard,
		TextStrokeTransparency = 0,
		Visible = false,
		ZIndex = 7,
		Parent = gui,
	})
	local caption = text({
		Name = "Caption",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1 - BAR / 2),
		Size = UDim2.new(0.92, 0, 0, 24),
		TextSize = Theme.SizeLarge,
		TextWrapped = true,
		Visible = false,
		ZIndex = 7,
		Parent = gui,
	})

	-- Pálpebras e fade ficam por cima de tudo (o título some com o olho fechado).
	local lidTop = black({
		Name = "LidTop",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1.2, LID),
		ZIndex = 9,
		Parent = gui,
	}, { lidGradient(90) })
	local lidBottom = black({
		Name = "LidBottom",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromScale(1.2, LID),
		ZIndex = 9,
		Parent = gui,
	}, { lidGradient(-90) })
	local fade = black({
		Name = "Fade",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return {
		gui = gui,
		top = top,
		bottom = bottom,
		lidTop = lidTop,
		lidBottom = lidBottom,
		fade = fade,
		noise = noise,
		bars = bars,
		tracking = tracking,
		stamp = stamp,
		stampMode = stampModeLabel,
		stampDot = stampDot,
		stampCamera = stampCamera,
		stampClock = stampClockLabel,
		title = title,
		subtitle = subtitle,
		caption = caption,
	}
end

local function applyLetterbox(alpha: number)
	letterboxAlpha = alpha
	local ui = r()
	ui.top.Size = UDim2.fromScale(1, BAR * alpha)
	ui.bottom.Size = UDim2.fromScale(1, BAR * alpha)
end

-- 0 = olhos abertos, 1 = fechados. A borda suave passa um pouco do meio para fechar de vez.
local function applyEyes(alpha: number)
	eyesAlpha = alpha
	local ui = r()
	local reach = (0.5 + LID * 0.18) * alpha
	ui.lidTop.Position = UDim2.fromScale(0.5, reach)
	ui.lidBottom.Position = UDim2.fromScale(0.5, 1 - reach)
end

local function applyFade(alpha: number)
	fadeAlpha = alpha
	r().fade.BackgroundTransparency = 1 - alpha
end

local function updateStatic(now: number)
	local ui = r()
	local active = now < staticUntil
	ui.noise.Visible = active
	if not active then
		return
	end
	local flashes = SettingsController.get("flashes")
	if not flashes then
		-- Conforto: sem cintilação, só um véu escuro estável.
		ui.noise.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
		ui.noise.BackgroundTransparency = 1 - 0.7 * staticStrength
		for _, bar in ui.bars do
			bar.Visible = false
		end
		ui.tracking.Visible = false
		return
	end
	ui.noise.BackgroundColor3 = Color3.fromRGB(110, 110, 106)
	ui.noise.BackgroundTransparency = 1 - (0.45 + rng:NextNumber(0, 0.35)) * staticStrength
	for _, bar in ui.bars do
		bar.Visible = rng:NextNumber() < 0.8
		local gray = rng:NextInteger(20, 245)
		bar.BackgroundColor3 = Color3.fromRGB(gray, gray, gray - rng:NextInteger(0, 12))
		bar.BackgroundTransparency = rng:NextNumber(0.05, 0.6)
		bar.Position = UDim2.fromScale(rng:NextNumber(-0.3, 0.2), rng:NextNumber(0, 1))
		bar.Size = UDim2.new(rng:NextNumber(0.4, 1.3), 0, 0, rng:NextInteger(2, 26))
	end
	ui.tracking.Visible = true
	ui.tracking.Position = UDim2.fromScale(0, (now * 1.7) % 1.1 - 0.05)
end

local TransitionController = {
	Name = "TransitionController",
}

function TransitionController.Init()
	refs = build()
	applyEyes(0)
	applyLetterbox(0)
	applyFade(0)
end

function TransitionController.Start()
	local stepClock = 0
	RunService.RenderStepped:Connect(function(dt: number)
		stepClock += dt
		local ui = r()
		if ui.stamp.Visible then
			stampClock += dt
		end
		-- Estática e carimbo atualizam a ~20 Hz (fita, não vídeo liso).
		if stepClock < 0.05 then
			return
		end
		stepClock = 0
		local now = os.clock()
		updateStatic(now)
		if ui.stamp.Visible then
			local blinkOn = (now * 1.6) % 1 < 0.6
			if stampMode == "REC" then
				ui.stampMode.Text = "REC"
				ui.stampMode.TextColor3 = Theme.Accent
				ui.stampDot.Visible = blinkOn
			else
				ui.stampMode.Text = "PLAY >"
				ui.stampMode.TextColor3 = Theme.Text
				ui.stampDot.Visible = false
			end
			ui.stampClock.Text = CinematicShots.clock(stampClock)
			-- Tremida de tracking no carimbo (desliga com "vhs").
			local jitter = if SettingsController.get("vhs") and rng:NextNumber() < 0.15
				then rng:NextInteger(-2, 2)
				else 0
			ui.stamp.Position = UDim2.fromOffset(jitter, 0)
		end
	end)
end

-- Faixas de cinema (bloqueia durante `duration`).
function TransitionController.setLetterbox(on: boolean, duration: number?)
	local from = letterboxAlpha
	local target = if on then 1 else 0
	stepped("letterbox", duration or 0.5, function(t)
		applyLetterbox(from + (target - from) * t)
	end)
end

function TransitionController.closeEyes(duration: number?)
	local from = eyesAlpha
	stepped("eyes", duration or 0.25, function(t)
		applyEyes(from + (1 - from) * t * t)
	end)
end

-- Abre os olhos; `flutter` faz a tremida de quem acorda (abre um pouco, pesa, abre de vez).
function TransitionController.openEyes(duration: number?, flutter: boolean?)
	local total = duration or 0.6
	local token = bump("eyes")
	local function hold(alpha: number, time: number): boolean
		if not alive("eyes", token) then
			return false
		end
		applyEyes(alpha)
		task.wait(time)
		return alive("eyes", token)
	end
	if flutter then
		local sequence = { 0.72, 0.55, 0.62, 0.86, 0.9, 0.5, 0.3, 0.15, 0.05, 0 }
		for _, alpha in sequence do
			if not hold(alpha, total / #sequence) then
				return
			end
		end
	else
		local steps = math.max(2, math.floor(total / STEP + 0.5))
		local from = eyesAlpha
		for i = 1, steps do
			local t = i / steps
			if not hold(from * (1 - t) * (1 - t), STEP) then
				return
			end
		end
	end
	applyEyes(0)
end

-- Piscar rápido (fecha, segura, abre).
function TransitionController.blink(hold: number?)
	local token = bump("blink")
	TransitionController.closeEyes(0.16)
	if not alive("blink", token) then
		return
	end
	task.wait(hold or 0.08)
	if not alive("blink", token) then
		return
	end
	TransitionController.openEyes(0.25, false)
end

function TransitionController.setFade(alpha: number, duration: number?)
	local from = fadeAlpha
	local target = math.clamp(alpha, 0, 1)
	stepped("fade", duration or 0.4, function(t)
		applyFade(from + (target - from) * t)
	end)
end

-- Estática de fita por `duration` segundos (não bloqueia).
function TransitionController.static(duration: number, strength: number?)
	staticUntil = os.clock() + duration
	staticStrength = math.clamp(strength or 1, 0, 1)
	updateStatic(os.clock())
end

-- Carimbo da fita. label = nil esconde. clock = segundos desde a meia-noite (continua se omitido).
function TransitionController.stamp(label: string?, mode: StampMode?, clock: number?)
	local ui = r()
	if not label then
		ui.stamp.Visible = false
		return
	end
	stampMode = mode or "PLAY"
	if clock then
		stampClock = clock
	end
	ui.stampCamera.Text = PixelText.normalize(label)
	ui.stamp.Visible = true
end

-- Cartela central. title = nil apaga. Entra com 3 quadros de tremida de projeção.
function TransitionController.title(title: string?, subtitle: string?)
	local ui = r()
	local token = bump("title")
	if not title then
		ui.title.Visible = false
		ui.subtitle.Visible = false
		return
	end
	ui.title.Text = PixelText.normalize(title)
	ui.subtitle.Text = if subtitle then PixelText.normalize(subtitle) else ""
	task.spawn(function()
		local offsets: { number } = { 6, -3, 1, 0 }
		if not SettingsController.motionEnabled() then
			offsets = { 0, 0, 0, 0 }
		end
		local fades = { 0.7, 0.35, 0.15, 0 }
		for i, offset in offsets do
			if not alive("title", token) then
				return
			end
			ui.title.Visible = true
			ui.title.Position = UDim2.new(0.5, offset, 0.44, 0)
			ui.title.TextTransparency = fades[i]
			ui.title.TextStrokeTransparency = fades[i]
			task.wait(STEP)
		end
		task.wait(0.3)
		if alive("title", token) and subtitle then
			ui.subtitle.Visible = true
		end
	end)
end

-- Legenda datilografada na faixa de baixo. text = nil apaga.
function TransitionController.caption(value: string?)
	local ui = r()
	local token = bump("caption")
	if not value or value == "" then
		ui.caption.Visible = false
		return
	end
	local normalized = PixelText.normalize(value)
	ui.caption.Visible = true
	task.spawn(function()
		local length = utf8.len(normalized) or #normalized
		local shown = 0
		while shown < length do
			if not alive("caption", token) then
				return
			end
			shown = math.min(length, shown + 2)
			local cut = utf8.offset(normalized, shown + 1)
			ui.caption.Text = if cut then string.sub(normalized, 1, cut - 1) else normalized
			task.wait(1 / 30)
		end
	end)
end

-- Limpa tudo na hora (troca de rodada, cena cancelada).
function TransitionController.reset()
	for layer in tokens do
		bump(layer)
	end
	staticUntil = 0
	applyLetterbox(0)
	applyEyes(0)
	applyFade(0)
	local ui = r()
	ui.stamp.Visible = false
	ui.title.Visible = false
	ui.subtitle.Visible = false
	ui.caption.Visible = false
	updateStatic(os.clock())
end

function TransitionController.debugState(): { [string]: any }
	return {
		letterbox = letterboxAlpha,
		eyes = eyesAlpha,
		fade = fadeAlpha,
		static = os.clock() < staticUntil,
		stamp = r().stamp.Visible,
		title = if r().title.Visible then r().title.Text else nil,
	}
end

return TransitionController
