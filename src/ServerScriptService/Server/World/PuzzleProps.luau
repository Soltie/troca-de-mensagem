--!strict
--[[
	Corpo dos enigmas de verdade (Shared/Game/PuzzleStyles): relógio de pêndulo, piano de armário e cofre, atrás do
	pedestal onde ficam os quatro botões. Só visual: colisão ligada no móvel (é um móvel de verdade), consultas
	desligadas para não roubar a mira dos botões. Os jogadores usam o lado +Z (de frente para as placas).
]]

local Debris = game:GetService("Debris")

local Audio = require("@game/ReplicatedStorage/Shared/Game/Audio")
local Build = require("./Build")
local HouseArt = require("./HouseArt")

local PuzzleProps = {}

local wood = Color3.fromRGB(92, 58, 36)
local darkWood = Color3.fromRGB(56, 36, 24)
local brass = Color3.fromRGB(176, 136, 64)
local ivory = Color3.fromRGB(232, 224, 204)

local function block(parent: Instance, name: string, at: Vector3, size: Vector3, color: Color3, material: Enum.Material)
	local p = Build.part(parent, name, size, CFrame.new(at), color, { material = material, query = false })
	return p
end

local function clock(parent: Instance, p: Vector3)
	local back = p + Vector3.new(0, 0, -2.4)
	block(parent, "ClockBase", back + Vector3.new(0, 1.1, 0), Vector3.new(3.4, 2.2, 1.8), darkWood, Enum.Material.Wood)
	block(parent, "ClockCase", back + Vector3.new(0, 4.4, 0), Vector3.new(2.8, 4.4, 1.5), wood, Enum.Material.Wood)
	block(parent, "ClockHood", back + Vector3.new(0, 7.6, 0), Vector3.new(3.4, 2.4, 1.8), darkWood, Enum.Material.Wood)
	block(parent, "ClockCrown", back + Vector3.new(0, 9, 0), Vector3.new(2.4, 0.5, 1.4), wood, Enum.Material.Wood)
	-- Vidro do pêndulo e o pêndulo parado.
	local glass = block(
		parent,
		"PendulumGlass",
		back + Vector3.new(0, 4.4, 0.78),
		Vector3.new(1.8, 3.4, 0.06),
		Color3.fromRGB(70, 80, 78),
		Enum.Material.Glass
	)
	glass.Transparency = 0.55
	block(
		parent,
		"PendulumRod",
		back + Vector3.new(0, 4.9, 0.55),
		Vector3.new(0.12, 2.6, 0.08),
		brass,
		Enum.Material.Metal
	)
	Build.cylinder(
		parent,
		"PendulumBob",
		back + Vector3.new(0, 3.5, 0.55),
		Vector3.zAxis,
		0.12,
		0.9,
		brass,
		{ material = Enum.Material.Metal, query = false }
	)
	-- Mostrador com os ponteiros caídos (o relógio parou; quem acerta a hora é vocês).
	local face = back + Vector3.new(0, 7.6, 0.92)
	Build.cylinder(
		parent,
		"ClockRim",
		face,
		Vector3.zAxis,
		0.08,
		2.5,
		brass,
		{ material = Enum.Material.Metal, query = false }
	)
	Build.cylinder(
		parent,
		"ClockFace",
		face + Vector3.new(0, 0, 0.05),
		Vector3.zAxis,
		0.06,
		2.2,
		ivory,
		{ material = Enum.Material.SmoothPlastic, query = false }
	)
	for hour = 1, 12 do
		local angle = hour / 12 * math.pi * 2
		block(
			parent,
			"HourMark",
			face + Vector3.new(math.sin(angle) * 0.92, math.cos(angle) * 0.92, 0.1),
			Vector3.new(0.08, 0.2, 0.02),
			darkWood,
			Enum.Material.SmoothPlastic
		).CFrame = CFrame.new(
			face + Vector3.new(math.sin(angle) * 0.92, math.cos(angle) * 0.92, 0.1)
		) * CFrame.Angles(0, 0, -angle)
	end
	type Hand = { name: string, length: number, width: number, tilt: number }
	local hands: { Hand } = {
		{ name = "HourHand", length = 0.55, width = 0.1, tilt = 0.2 },
		{ name = "MinuteHand", length = 0.85, width = 0.07, tilt = -0.25 },
	}
	for _, hand in hands do
		local length = hand.length
		local tilt = hand.tilt
		Build.part(
			parent,
			hand.name,
			Vector3.new(hand.width, length, 0.03),
			CFrame.new(face + Vector3.new(0, 0, 0.13))
				* CFrame.Angles(0, 0, math.pi + tilt)
				* CFrame.new(0, length / 2, 0),
			Color3.fromRGB(20, 16, 14),
			{ material = Enum.Material.Metal, query = false }
		)
	end
end

local function piano(parent: Instance, p: Vector3)
	local back = p + Vector3.new(0, 0, -2.1)
	block(parent, "PianoBody", back + Vector3.new(0, 2.6, -0.2), Vector3.new(8.6, 5.2, 2), darkWood, Enum.Material.Wood)
	block(parent, "PianoLid", back + Vector3.new(0, 5.3, -0.1), Vector3.new(8.9, 0.25, 2.3), wood, Enum.Material.Wood)
	block(parent, "PianoFront", back + Vector3.new(0, 3.6, 0.85), Vector3.new(8.2, 2.6, 0.12), wood, Enum.Material.Wood)
	-- Partitura velha no suporte (rasgada: a melodia certa está no painel do porão).
	local sheet = block(
		parent,
		"SheetMusic",
		back + Vector3.new(0.6, 3.9, 0.95),
		Vector3.new(2.2, 1.6, 0.04),
		Color3.fromRGB(196, 182, 150),
		Enum.Material.SmoothPlastic
	)
	sheet.CFrame *= CFrame.Angles(math.rad(-12), 0, math.rad(4))
	for side = -1, 1, 2 do
		block(
			parent,
			"PianoCheek",
			p + Vector3.new(side * 4.1, 1.3, -0.3),
			Vector3.new(0.4, 2.6, 2.8),
			darkWood,
			Enum.Material.Wood
		)
		Build.cylinder(
			parent,
			"Candle",
			back + Vector3.new(side * 3.6, 5.9, 0.4),
			Vector3.yAxis,
			1,
			0.3,
			ivory,
			{ query = false }
		)
		-- Chama acesa: o piano é o único ponto quente do porão (sem ela ele some no escuro).
		local flame = Build.part(
			parent,
			"Flame",
			Vector3.new(0.16, 0.32, 0.16),
			CFrame.new(back + Vector3.new(side * 3.6, 6.58, 0.4)),
			Color3.fromRGB(255, 176, 92),
			{ material = Enum.Material.Neon, collide = false, query = false }
		)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness, glow.Shadows = Color3.fromRGB(255, 170, 96), 11, 0.9, false
		glow.Parent = flame
	end
	-- Teclas pretas entre as quatro brancas (as brancas são os botões do enigma).
	for i = 1, 3 do
		block(
			parent,
			"BlackKey",
			p + Vector3.new((i - 2) * 1.8, 2.75, -0.15),
			Vector3.new(0.7, 0.45, 1.3),
			Color3.fromRGB(18, 16, 15),
			Enum.Material.SmoothPlastic
		)
	end
end

local function safe(parent: Instance, p: Vector3)
	local back = p + Vector3.new(0, 0, -2.8)
	local steel = Color3.fromRGB(58, 66, 62)
	block(
		parent,
		"SafeBody",
		back + Vector3.new(0, 2.6, 0),
		Vector3.new(5, 5.2, 3.2),
		steel,
		Enum.Material.DiamondPlate
	)
	block(
		parent,
		"SafeDoor",
		back + Vector3.new(0, 2.6, 1.65),
		Vector3.new(4.2, 4.4, 0.15),
		Color3.fromRGB(44, 50, 47),
		Enum.Material.Metal
	)
	Build.cylinder(
		parent,
		"SafeDial",
		back + Vector3.new(0, 3.2, 1.8),
		Vector3.zAxis,
		0.2,
		1.3,
		Color3.fromRGB(150, 148, 140),
		{ material = Enum.Material.Metal, query = false }
	)
	block(
		parent,
		"SafeHandle",
		back + Vector3.new(1.3, 2, 1.85),
		Vector3.new(0.25, 1.4, 0.25),
		brass,
		Enum.Material.Metal
	)
	for _, x in { -1.9, 1.9 } do
		for _, y in { 0.7, 4.5 } do
			Build.cylinder(
				parent,
				"SafeBolt",
				back + Vector3.new(x, y, 1.75),
				Vector3.zAxis,
				0.1,
				0.3,
				brass,
				{ material = Enum.Material.Metal, query = false }
			)
		end
	end
end

-- Monta o móvel do enigma `style` atrás do pedestal em `p` (o radio da floresta já existe no HouseTaskProps).
-- Pivô de um modelo de arte encostado atrás do pedestal, de frente para os jogadores (+Z).
local function facing(p: Vector3, back: number): CFrame
	local at = p + Vector3.new(0, 0, back)
	return CFrame.lookAt(at, at + Vector3.zAxis)
end

function PuzzleProps.build(parent: Instance, p: Vector3, style: string)
	if style == "clock" then
		clock(parent, p)
	elseif style == "piano" then
		-- Piano da Lia do artista (frente para +Z, onde ficam as teclas do enigma); sem ele, o piano em blocos.
		local art = HouseArt.swap(parent, "LiaPiano", facing(p, -2.3), function(folder)
			piano(folder, p)
		end)
		if art then
			-- A luz quente das velas continua: o piano é o único ponto quente do porão.
			local glow = Build.part(
				parent,
				"PianoGlow",
				Vector3.new(0.2, 0.2, 0.2),
				CFrame.new(p + Vector3.new(0, 6.5, -1.6)),
				Color3.fromRGB(255, 176, 92),
				{ collide = false, query = false, transparency = 1 }
			)
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Shadows = Color3.fromRGB(255, 170, 96), 14, 0.9, false
			light.Parent = glow
		end
	elseif style == "safe" then
		HouseArt.swap(parent, "BasementSafe", facing(p, -2.8), function(folder)
			safe(folder, p)
		end)
	end
end

-- Chute errado num enigma que não zera (relógio e piano): o relógio badala três vezes e o piano desafina alto.
-- O som é do servidor (todos ouvem, de longe); quem chama o Tum Tum é o CampaignRuntime.
function PuzzleProps.alarm(focus: BasePart)
	local model = focus.Parent
	local style = model and model:GetAttribute("PuzzleStyle")
	type Note = { speed: number, delay: number, volume: number }
	local notes: { Note } = if style == "clock"
		then {
			{ speed = 0.38, delay = 0, volume = 2.4 },
			{ speed = 0.38, delay = 0.8, volume = 2.4 },
			{ speed = 0.38, delay = 1.6, volume = 2.4 },
		}
		else {
			{ speed = 0.47, delay = 0, volume = 2.2 },
			{ speed = 0.5, delay = 0, volume = 2.2 },
			{ speed = 0.71, delay = 0.04, volume = 2 },
		}
	for _, note in notes do
		task.delay(note.delay, function()
			local sound = Build.sound(focus, "PuzzleAlarm", Audio.PianoKey.id, note.volume, note.speed)
			sound.RollOffMaxDistance = 140
			sound:Play()
			Debris:AddItem(sound, 4)
		end)
	end
end

-- Tecla do piano: o botão do enigma vira a tecla (mais larga, com a cor do desenho).
PuzzleProps.KEY_SIZE = Vector3.new(1.6, 0.45, 2.4)
PuzzleProps.IVORY = ivory

return PuzzleProps
