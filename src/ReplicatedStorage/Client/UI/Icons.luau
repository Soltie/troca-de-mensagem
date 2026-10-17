--!strict
-- Pictogramas próprios em primitivas; sem imagens externas nem dependência de emoji.
--   draw   ícones finos do HUD (bateria, fôlego, oxigênio) em offsets de 24 px.
--   pixel  ícones pixel-art 12×12 dos menus (remaster); escalam pelo tamanho do contêiner.
local Create = require("./Create")
local Icons = {}
function Icons.draw(parent: Instance, kind: string, color: Color3)
	local function box(x: number, y: number, w: number, h: number, rotation: number?): Frame
		return Create("Frame", {
			Parent = parent,
			Name = "IconShape",
			Position = UDim2.fromOffset(x, y),
			Size = UDim2.fromOffset(w, h),
			Rotation = rotation or 0,
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}) :: Frame
	end
	if kind == "Battery" then
		local body = box(3, 6, 17, 12)
		body.BackgroundTransparency = 1
		Create("UIStroke", { Parent = body, Color = color, Thickness = 1.5 })
		box(21, 9, 2, 6)
		box(6, 9, 8, 6)
	elseif kind == "Stamina" then
		box(11, 3, 4, 10, 28)
		box(8, 11, 9, 3)
		box(10, 12, 4, 10, 28)
	else
		for _, x in { 4, 14 } do
			local lung = box(x, 8, 7, 12)
			Create("UICorner", { Parent = lung, CornerRadius = UDim.new(1, 0) })
		end
		box(11, 4, 3, 9)
	end
end

-- Bitmaps 12×12 ("#" = pixel aceso). Mesmo grid, peso e leitura em todos os ícones do menu.
local GRID = 12
local BITMAPS: { [string]: { string } } = {
	Play = {
		"............",
		"..##........",
		"..####......",
		"..######....",
		"..########..",
		"..#########.",
		"..#########.",
		"..########..",
		"..######....",
		"..####......",
		"..##........",
		"............",
	},
	Perks = {
		"......####..",
		".....####...",
		"....####....",
		"...####.....",
		"..#########.",
		".#########..",
		".....####...",
		"....####....",
		"...####.....",
		"..###.......",
		"..##........",
		"............",
	},
	Store = {
		"....####....",
		"...#....#...",
		"...#....#...",
		".##########.",
		".##########.",
		".####..####.",
		".##########.",
		".##########.",
		".##########.",
		".##########.",
		"..########..",
		"............",
	},
	Season = {
		"............",
		"............",
		".##########.",
		".###.##.###.",
		".##########.",
		"..########..",
		"..########..",
		".##########.",
		".###.##.###.",
		".##########.",
		"............",
		"............",
	},
	Daily = {
		"..##....##..",
		"...##..##...",
		"....####....",
		".##########.",
		".##########.",
		"..###..###..",
		"..###..###..",
		"..###..###..",
		"..###..###..",
		"..###..###..",
		"..########..",
		"............",
	},
	Servers = {
		"....####....",
		"..##.##.##..",
		".#...##...#.",
		".##########.",
		"#....##....#",
		"#....##....#",
		"#....##....#",
		".##########.",
		".#...##...#.",
		"..##.##.##..",
		"....####....",
		"............",
	},
	Friends = {
		"............",
		"..##....##..",
		".####..####.",
		".####..####.",
		"..##....##..",
		"............",
		".####..####.",
		"#####..#####",
		"#####..#####",
		"#####..#####",
		"............",
		"............",
	},
	Settings = {
		"............",
		".....##.....",
		"..#.####.#..",
		"..########..",
		"...##..##...",
		".###....###.",
		".###....###.",
		"...##..##...",
		"..########..",
		"..#.####.#..",
		".....##.....",
		"............",
	},
	More = {
		"............",
		"............",
		"............",
		"............",
		"............",
		".##..##..##.",
		".##..##..##.",
		"............",
		"............",
		"............",
		"............",
		"............",
	},
	Coin = {
		"............",
		"....####....",
		"..########..",
		".####..####.",
		".###.##.###.",
		"###.####.###",
		"###.####.###",
		".###.##.###.",
		".####..####.",
		"..########..",
		"....####....",
		"............",
	},
	Gem = {
		"............",
		"............",
		"...######...",
		"..##.##.##..",
		".##########.",
		"..########..",
		"...######...",
		"....####....",
		".....##.....",
		"............",
		"............",
		"............",
	},
	Backpack = {
		"....####....",
		"...#....#...",
		"..########..",
		".##########.",
		".##########.",
		".###....###.",
		".###.##.###.",
		".###....###.",
		".##########.",
		".##########.",
		"..########..",
		"............",
	},
	House = {
		".....##.....",
		"....####....",
		"...######...",
		"..########..",
		".##########.",
		"############",
		"..########..",
		"..##.##.##..",
		"..########..",
		"..###..###..",
		"..###..###..",
		"............",
	},
	Tree = {
		".....##.....",
		"....####....",
		"...######...",
		"....####....",
		"...######...",
		"..########..",
		"...######...",
		"..########..",
		".##########.",
		".....##.....",
		".....##.....",
		"............",
	},
	Lock = {
		"............",
		"....####....",
		"...#....#...",
		"...#....#...",
		"..########..",
		"..########..",
		"..###..###..",
		"..###..###..",
		"..########..",
		"..########..",
		"............",
		"............",
	},
	Check = {
		"............",
		"............",
		"..........##",
		".........##.",
		"........##..",
		".##....##...",
		"..##..##....",
		"...####.....",
		"....##......",
		"............",
		"............",
		"............",
	},
	Star = {
		"............",
		".....##.....",
		".....##.....",
		"....####....",
		"############",
		".##########.",
		"...######...",
		"...######...",
		"..###..###..",
		".##......##.",
		"............",
		"............",
	},
	Plus = {
		"............",
		"............",
		".....##.....",
		".....##.....",
		".....##.....",
		"..########..",
		"..########..",
		".....##.....",
		".....##.....",
		".....##.....",
		"............",
		"............",
	},
	Close = {
		"............",
		"............",
		"..##....##..",
		"...##..##...",
		"....####....",
		".....##.....",
		"....####....",
		"...##..##...",
		"..##....##..",
		"............",
		"............",
		"............",
	},
	Drum = {
		"..#......#..",
		"...#....#...",
		"....#..#....",
		".##########.",
		"#..........#",
		"#.########.#",
		"#.#.#..#.#.#",
		"#.#.#..#.#.#",
		"#.########.#",
		"#..........#",
		".##########.",
		"............",
	},
}

-- Lista de ícones disponíveis (testes e auditoria de assets).
function Icons.kinds(): { string }
	local list = {}
	for kind in BITMAPS do
		table.insert(list, kind)
	end
	table.sort(list)
	return list
end

-- Trechos horizontais contínuos de cada linha: { x, y, comprimento }. Puro (testável no Lune).
function Icons.runs(kind: string): { { number } }
	local rows = BITMAPS[kind]
	assert(rows, `[Icons] ícone desconhecido "{kind}"`)
	local runs = {}
	for y, row in rows do
		local start: number? = nil
		for x = 1, GRID + 1 do
			local on = x <= GRID and row:sub(x, x) == "#"
			if on and not start then
				start = x
			elseif not on and start then
				table.insert(runs, { start - 1, y - 1, x - start })
				start = nil
			end
		end
	end
	return runs
end

-- Desenha o ícone ocupando todo o `parent` (use tamanhos múltiplos de 12 para pixels nítidos).
function Icons.pixel(parent: Instance, kind: string, color: Color3): Frame
	local holder = Create("Frame", {
		Name = `Icon_{kind}`,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
	}) :: Frame
	for _, run in Icons.runs(kind) do
		Create("Frame", {
			Name = "Px",
			Position = UDim2.fromScale(run[1] / GRID, run[2] / GRID),
			Size = UDim2.fromScale(run[3] / GRID, 1 / GRID),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Parent = holder,
		})
	end
	holder.Parent = parent
	return holder
end

-- Troca a cor de um ícone já desenhado (estado selecionado/desabilitado).
function Icons.tint(icon: Instance, color: Color3)
	for _, px in icon:GetChildren() do
		if px:IsA("Frame") then
			px.BackgroundColor3 = color
		end
	end
end

return Icons
