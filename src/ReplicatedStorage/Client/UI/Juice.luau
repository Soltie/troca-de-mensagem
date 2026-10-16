--!strict
--[[
	Animações curtas de interface ("juice"): pulo de escala, número subindo, confete e brilho.
	Tudo por TweenService em instâncias próprias, sem estado global.
]]

local TweenService = game:GetService("TweenService")

local Create = require("./Create")
local Theme = require("./Theme")

local Juice = {}

local function scaleOf(object: GuiObject): UIScale
	local existing = object:FindFirstChild("JuiceScale")
	if existing and existing:IsA("UIScale") then
		return existing
	end
	return Create("UIScale", { Name = "JuiceScale", Parent = object }) :: UIScale
end

-- Pulo rápido: cresce e volta com mola. `amount` 0.15 = 15% maior.
function Juice.pop(object: GuiObject, amount: number?)
	local scale = scaleOf(object)
	scale.Scale = 1 + (amount or 0.18)
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

-- Entrada com mola a partir do zero.
function Juice.appear(object: GuiObject, delay: number?)
	local scale = scaleOf(object)
	scale.Scale = 0
	TweenService:Create(
		scale,
		TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, delay or 0),
		{ Scale = 1 }
	):Play()
end

-- Texto que sobe e some (ex.: "+5" ao pegar moeda). `hold` segura o texto parado antes de sumir.
function Juice.floatText(parent: Instance, text: string, position: UDim2, color: Color3?, size: number?, hold: number?)
	local label = Create("TextLabel", {
		Name = "FloatText",
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(220, 48),
		BackgroundTransparency = 1,
		FontFace = Theme.Font,
		TextSize = size or 34,
		TextColor3 = color or Theme.Coin,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Theme.Ink,
		Text = text,
		ZIndex = 50,
	}) :: TextLabel
	Juice.appear(label)
	local rise = TweenService:Create(
		label,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, hold or 0),
		{
			Position = position - UDim2.fromOffset(0, 70),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	rise:Play()
	rise.Completed:Once(function()
		label:Destroy()
	end)
end

local CONFETTI = {
	Color3.fromRGB(255, 206, 64),
	Color3.fromRGB(255, 82, 122),
	Color3.fromRGB(96, 232, 140),
	Color3.fromRGB(92, 200, 255),
	Color3.fromRGB(190, 120, 255),
}

-- Chuva de confete saindo de `origin` (escala 0..1 da tela).
function Juice.confetti(parent: Instance, origin: Vector2, count: number?)
	local rng = Random.new()
	for index = 1, count or 36 do
		local piece = Create("Frame", {
			Name = "Confetti",
			Parent = parent,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(origin.X, origin.Y),
			Size = UDim2.fromOffset(rng:NextInteger(8, 14), rng:NextInteger(5, 9)),
			Rotation = rng:NextNumber(0, 360),
			BackgroundColor3 = CONFETTI[(index % #CONFETTI) + 1],
			BorderSizePixel = 0,
			ZIndex = 60,
		}) :: Frame
		local angle = rng:NextNumber(-math.pi * 0.9, -math.pi * 0.1)
		local distance = rng:NextNumber(0.18, 0.42)
		local target = UDim2.fromScale(
			origin.X + math.cos(angle) * distance * 0.7,
			origin.Y + math.sin(angle) * distance + rng:NextNumber(0.35, 0.6)
		)
		local tween = TweenService:Create(
			piece,
			TweenInfo.new(rng:NextNumber(1.1, 1.8), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = target, Rotation = piece.Rotation + rng:NextNumber(-540, 540), BackgroundTransparency = 1 }
		)
		tween:Play()
		tween.Completed:Once(function()
			piece:Destroy()
		end)
	end
end

-- Brilho pulsante contínuo num UIStroke (chama atenção para o objetivo atual).
function Juice.glow(stroke: UIStroke, low: number, high: number): Tween
	stroke.Transparency = high
	local tween = TweenService:Create(
		stroke,
		TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = low }
	)
	tween:Play()
	return tween
end

-- Contador que sobe de `from` até `to` em `duration` segundos, chamando `apply` a cada passo.
function Juice.count(from: number, to: number, duration: number, apply: (number) -> ())
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(current)
		apply(math.floor(current + 0.5))
	end)
	local tween = TweenService:Create(value, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Value = to,
	})
	tween:Play()
	tween.Completed:Once(function()
		apply(to)
		value:Destroy()
	end)
end

return Juice
