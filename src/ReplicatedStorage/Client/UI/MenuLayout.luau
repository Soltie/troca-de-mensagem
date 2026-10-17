--!strict
--[[
	Decisões de layout do menu (remaster), puras e testáveis no Lune.

	  mode      classifica a viewport segura: PC (escala 1280×720) ou compacto (toque/telas pequenas),
	            e se a altura é curta (celular na horizontal).
	  columns   1 ou 2 colunas para cartões, conforme a largura útil do conteúdo.
	  split     no compacto, até 5 destinos ficam no trilho e o resto vai para "MAIS".
	  chapters  estado visual de cada capítulo da História a partir do StoryProgress publicado.
]]

local MenuLayout = {}

export type Mode = {
	compact: boolean,
	short: boolean,
	scale: number,
	key: string,
}

export type ChapterState = "flawless" | "cleared" | "next" | "open"

-- Referência de desenho do PC; o compacto usa pixels reais (alvos de toque >= 48 px).
MenuLayout.BASE_WIDTH = 1280
MenuLayout.BASE_HEIGHT = 720
MenuLayout.RAIL_SLOTS = 5
MenuLayout.TWO_COLUMNS_MIN = 620

function MenuLayout.mode(width: number, height: number, touch: boolean): Mode
	local compact = touch or width < 1000 or height < 600
	local short = compact and height < 430
	local scale = 1
	if not compact then
		scale = math.clamp(math.min(width / MenuLayout.BASE_WIDTH, height / MenuLayout.BASE_HEIGHT), 0.7, 1.6)
	end
	return {
		compact = compact,
		short = short,
		scale = scale,
		key = if compact then (if short then "compact-short" else "compact") else "desktop",
	}
end

function MenuLayout.columns(contentWidth: number): number
	return if contentWidth >= MenuLayout.TWO_COLUMNS_MIN then 2 else 1
end

-- Separa os destinos do trilho compacto: os primeiros ficam visíveis, o resto vai para "MAIS".
function MenuLayout.split<T>(items: { T }, compact: boolean): ({ T }, { T })
	if not compact or #items <= MenuLayout.RAIL_SLOTS then
		return table.clone(items), {}
	end
	local visible, overflow = {}, {}
	for index, item in items do
		table.insert(if index < MenuLayout.RAIL_SLOTS then visible else overflow, item)
	end
	return visible, overflow
end

-- "next" = primeiro capítulo ainda não vencido (a próxima recompensa de primeira vitória).
function MenuLayout.chapters(
	cleared: { [number]: boolean },
	flawless: { [number]: boolean },
	total: number
): { ChapterState }
	local states: { ChapterState } = {}
	local nextFound = false
	for chapter = 1, total do
		if flawless[chapter] then
			states[chapter] = "flawless"
		elseif cleared[chapter] then
			states[chapter] = "cleared"
		elseif not nextFound then
			states[chapter] = "next"
			nextFound = true
		else
			states[chapter] = "open"
		end
	end
	return states
end

return MenuLayout
