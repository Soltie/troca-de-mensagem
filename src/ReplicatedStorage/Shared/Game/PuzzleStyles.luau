--!strict
--[[
	Enigmas de verdade (veredito 20/10/2026, item 3). A regra continua a mesma no servidor (quatro botões numa ordem,
	chute errado zera), mas cada enigma vira um objeto que faz sentido na história:
	- Cap. 3, escritório: o RELÓGIO. Acertar 03:12 (a hora de todas as fitas). O livro do sótão traz "03:1_" com o
	  último número rasgado; o relógio recuperado no sótão diz a hora inteira.
	- Cap. 4, porão dos símbolos: o PIANO velho. O painel do porão traz a melodia (DÓ RÉ MI SOL, sorteada); cada tecla
	  toca a nota.
	- Cap. 4, cofre: o código ESPALHADO. Os dois primeiros dígitos estão na catacumba, os dois últimos riscados no
	  painel do porão. O teclado do cofre tem quatro dígitos sorteados.
	- Floresta (cap. 6 a 8): o RÁDIO. Sintonizar as frequências do diário/código do guarda.
	Puro: sem `game`; testado no Lune.
]]

export type Style = {
	id: string,
	labels: { string },
	prompt: string,
	-- Ordem fixa (o relógio sempre marca 03:12); nil = sorteada pelo plano.
	fixed: { number }?,
}

local PuzzleStyles = {}

PuzzleStyles.SYMBOLS = table.freeze({
	id = "symbols",
	labels = table.freeze({ "LUA", "OLHO", "CHAMA", "PORTA" }),
	prompt = "PRESSIONAR",
}) :: Style
PuzzleStyles.CLOCK = table.freeze({
	id = "clock",
	labels = table.freeze({ "0", "1", "2", "3" }),
	prompt = "GIRAR O PONTEIRO PARA",
	fixed = table.freeze({ 1, 4, 2, 3 }),
}) :: Style
PuzzleStyles.PIANO = table.freeze({
	id = "piano",
	labels = table.freeze({ "DÓ", "RÉ", "MI", "SOL" }),
	prompt = "TOCAR",
}) :: Style
PuzzleStyles.RADIO = table.freeze({
	id = "radio",
	labels = table.freeze({ "88.1", "93.5", "101.7", "107.9" }),
	prompt = "SINTONIZAR",
}) :: Style

-- Velocidade de reprodução de cada tecla (escala maior a partir do DÓ).
PuzzleStyles.PIANO_PITCH = table.freeze({ 1, 2 ^ (2 / 12), 2 ^ (4 / 12), 2 ^ (7 / 12) })

-- Quatro dígitos diferentes (1 a 9) para o teclado do cofre, reproduzíveis pela semente.
function PuzzleStyles.safeDigits(seed: number): { string }
	local pool = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
	local state = math.floor(math.abs(seed)) % 2147483647 + 1
	local out = {}
	for i = 1, 4 do
		state = (state * 48271) % 2147483647
		local pick = state % (#pool - i + 1) + i
		pool[i], pool[pick] = pool[pick], pool[i]
		table.insert(out, tostring(pool[i]))
	end
	return out
end

function PuzzleStyles.forTask(stage: number, index: number, seed: number): Style
	if stage == 3 and index == 5 then
		return PuzzleStyles.CLOCK
	elseif stage == 4 and index == 2 then
		return PuzzleStyles.PIANO
	elseif stage == 4 and index == 4 then
		return { id = "safe", labels = PuzzleStyles.safeDigits(seed), prompt = "DIGITAR" }
	elseif stage >= 6 then
		return PuzzleStyles.RADIO
	end
	return PuzzleStyles.SYMBOLS
end

-- A resposta escrita com os nomes do enigma (DÓ - MI - ..., 7 1 9 3).
function PuzzleStyles.answer(style: Style, order: { number }): { string }
	local out = {}
	for _, button in order do
		table.insert(out, style.labels[button] or "?")
	end
	return out
end

-- Texto da pista. `extra` = segunda metade de outra resposta riscada no mesmo papel (o código do cofre no painel).
function PuzzleStyles.clue(style: Style, order: { number }, extra: { string }?): string
	local answer = PuzzleStyles.answer(style, order)
	if style.id == "clock" then
		return "ACERTE O RELÓGIO DO ESCRITÓRIO\nNA HORA DAS FITAS: 03:1_ (RASGADO)"
	elseif style.id == "piano" then
		local text = `MELODIA DO PIANO DO PORÃO\n{table.concat(answer, " - ")}`
		if extra then
			text ..= `\nRISCADO EMBAIXO: _ _ {extra[3]} {extra[4]}`
		end
		return text
	elseif style.id == "safe" then
		return `CÓDIGO DO COFRE: {answer[1]} {answer[2]} _ _\nO RESTO ESTÁ NO PAINEL DO PORÃO`
	elseif style.id == "radio" then
		return `CANAIS DO GUARDA\n{table.concat(answer, " · ")}`
	end
	return `LUA=1 OLHO=2 CHAMA=3 PORTA=4\nORDEM: {table.concat(order, " - ")}`
end

-- Placa de progresso em cima do enigma.
function PuzzleStyles.progress(style: Style, order: { number }, progress: number): string
	local answer = PuzzleStyles.answer(style, order)
	local shown = {}
	for i = 1, 4 do
		shown[i] = if i <= progress then answer[i] else "_"
	end
	if style.id == "clock" then
		return `{shown[1]}{shown[2]}:{shown[3]}{shown[4]} · QUE HORAS AS FITAS MARCAM?`
	elseif style.id == "safe" then
		return `{table.concat(shown, " ")} · JUNTE AS DUAS METADES DO CÓDIGO`
	elseif style.id == "piano" then
		return `{progress}/4 NOTAS · TOQUE A MELODIA DO PAINEL`
	elseif style.id == "radio" then
		return `{progress}/4 CANAIS · SIGA O PAPEL DO GUARDA`
	end
	return `{progress}/4 · CONSULTE A PISTA RECUPERADA`
end

return table.freeze(PuzzleStyles)
