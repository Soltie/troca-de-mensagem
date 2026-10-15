--!strict
--[[
	Tema da interface: fonte pixel (Arcade), poucos tons, contorno escuro para leitura sobre a cena.
	Tamanhos de fonte em múltiplos do corpo base para manter o pixel nítido.
]]

local rgb = Color3.fromRGB

local Theme = {
	Font = Font.fromEnum(Enum.Font.Arcade),
	FontNote = Font.fromEnum(Enum.Font.SpecialElite),

	SizeSmall = 12,
	SizeBody = 14,
	SizeLarge = 22,
	SizeTitle = 40,

	Text = rgb(226, 220, 198),
	TextDim = rgb(150, 144, 126),
	Accent = rgb(196, 54, 42),
	Hazard = rgb(200, 164, 52),
	Good = rgb(96, 206, 128),
	Black = rgb(0, 0, 0),
	Panel = rgb(8, 8, 10),
	Paper = rgb(214, 206, 178),
	Ink = rgb(30, 26, 22),
	Skin = rgb(146, 146, 136),
}

return table.freeze(Theme)
