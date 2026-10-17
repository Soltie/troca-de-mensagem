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

	-- Remaster "Cursed Mansion" (docs/ui-remaster): tokens das telas novas. Dourado só para foco,
	-- progresso e ação principal; verde = sucesso/equipado; vermelho = perigo (nunca pressão de compra).
	Bg = rgb(16, 25, 35),
	BgPanel = rgb(37, 51, 68),
	BgElevated = rgb(48, 65, 85),
	BgSunken = rgb(11, 17, 24),
	Gold = rgb(229, 182, 107),
	GoldLight = rgb(241, 211, 151),
	GoldDeep = rgb(120, 86, 40),
	Danger = rgb(141, 52, 59),
	Success = rgb(112, 190, 145),
	TextPrimary = rgb(237, 228, 213),
	TextSecondary = rgb(182, 193, 204),
	TextMuted = rgb(128, 140, 152),
	Border = rgb(86, 96, 107),
	Overlay = rgb(9, 14, 20),
	Wood = rgb(92, 62, 40),

	-- Alvo mínimo de toque (px de tela) e espaçamentos.
	TouchMin = 48,
	Gap = 8,
	GapLarge = 16,
	CornerLarge = UDim.new(0, 14),
	CornerPill = UDim.new(1, 0),
}

return table.freeze(Theme)
