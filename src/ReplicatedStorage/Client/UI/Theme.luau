--!strict
--[[
	Tema da interface: fonte arredondada e cores vivas (roxo da noite, amarelo de destaque, rosa de alerta).
	Pensado para crianças: letras grandes, contraste alto e cantos arredondados.
	Os nomes antigos (Hazard, Paper, Ink...) continuam válidos para as telas existentes.
]]

local rgb = Color3.fromRGB

local Theme = {
	Font = Font.fromEnum(Enum.Font.FredokaOne),
	FontNote = Font.fromEnum(Enum.Font.GothamMedium),
	FontBody = Font.fromEnum(Enum.Font.GothamBold),

	SizeSmall = 13,
	SizeBody = 16,
	SizeLarge = 24,
	SizeTitle = 44,

	Text = rgb(255, 250, 240),
	TextDim = rgb(190, 199, 211),
	Accent = rgb(183, 72, 91),
	Hazard = rgb(233, 193, 122),
	Good = rgb(96, 232, 140),
	Info = rgb(92, 200, 255),
	Black = rgb(0, 0, 0),
	Panel = rgb(18, 24, 34),
	PanelLight = rgb(34, 44, 58),
	Stroke = rgb(151, 130, 98),
	Paper = rgb(255, 242, 210),
	Ink = rgb(44, 30, 66),
	Skin = rgb(176, 112, 64),
	Coin = rgb(255, 196, 40),

	Corner = UDim.new(0, 10),
	CornerSmall = UDim.new(0, 6),
}

return table.freeze(Theme)
