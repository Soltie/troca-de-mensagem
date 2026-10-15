--!strict
--[[
	Paleta curta (estética PS1): poucos tons por família, saturação baixa, acentos raros
	(amarelo de perigo, vermelho de emergência, verde de saída). Mude aqui para reestilizar o mapa.
]]

local rgb = Color3.fromRGB

local Palette = {
	-- Paredes internas (faixa de cima / faixa de baixo)
	WallUpper = rgb(104, 100, 88),
	WallLower = rgb(60, 68, 62),
	WallUpperCold = rgb(86, 94, 98), -- gerador / depósito
	WallLowerCold = rgb(48, 54, 58),
	-- Fachada
	Facade = rgb(112, 106, 94),
	FacadeLower = rgb(66, 64, 58),
	Ceiling = rgb(42, 42, 40),
	Trim = rgb(34, 34, 32),

	-- Pisos
	TileA = rgb(80, 78, 68),
	TileB = rgb(56, 56, 50),
	CorridorA = rgb(86, 78, 60),
	CorridorB = rgb(62, 58, 46),
	Concrete = rgb(70, 70, 66),
	MetalFloor = rgb(64, 68, 70),

	-- Materiais de props
	Metal = rgb(62, 68, 72),
	MetalDark = rgb(36, 40, 44),
	Rust = rgb(96, 60, 40),
	Wood = rgb(88, 64, 44),
	WoodDark = rgb(56, 40, 30),
	Paper = rgb(212, 204, 178),
	Fabric = rgb(52, 58, 68),
	Ceramic = rgb(222, 216, 198),
	Screen = rgb(18, 26, 22),

	-- Acentos
	Hazard = rgb(186, 150, 40),
	Black = rgb(16, 16, 16),
	Red = rgb(140, 32, 28),
	ExitGreen = rgb(40, 160, 80),
	FuseGlow = rgb(255, 150, 60),
	Brass = rgb(176, 140, 64),
	Uniform = rgb(40, 46, 58), -- farda do vigia
	UniformDark = rgb(26, 30, 38),
	Skin = rgb(150, 118, 96),
	Hair = rgb(54, 50, 46),

	-- Exterior
	Asphalt = rgb(34, 36, 38),
	Grass = rgb(28, 36, 26),
	Gravel = rgb(52, 50, 46),
	Foliage = rgb(22, 34, 24),
	FoliageDark = rgb(16, 26, 18),
	Trunk = rgb(42, 32, 24),
	Fence = rgb(70, 74, 72),
	VanBody = rgb(168, 162, 146),

	-- Luzes
	LampOff = rgb(70, 72, 70),
	LampOn = rgb(214, 236, 226),
	Fluorescent = rgb(205, 232, 222),
	Emergency = rgb(255, 64, 52),
	Sodium = rgb(255, 172, 104),
	ExitLight = rgb(90, 255, 140),
	PanelOff = rgb(120, 24, 20),
	PanelOn = rgb(70, 255, 120),

	-- Atmosfera
	-- Névoa um pouco mais clara que os objetos: recorta silhuetas (truque clássico de PS1).
	Fog = rgb(30, 34, 44),
	FogPower = rgb(36, 32, 34),
	Ambient = rgb(16, 16, 20),
	AmbientPower = rgb(34, 32, 32),
	-- Luar: o pátio fica escuro, mas cerca/árvores/fachada leem como silhuetas (orientação).
	OutdoorAmbient = rgb(64, 72, 92),
}

return table.freeze(Palette)
