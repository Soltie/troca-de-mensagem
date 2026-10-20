--!strict
--[[
	Enigmas de verdade (veredito 20/10/2026, item 3; refeitos pelo crítico no mesmo dia). Quatro botões numa ordem,
	e cada enigma vira um objeto que faz sentido na história:
	- Cap. 3, escritório: o RELÓGIO. Acertar 03:12, a hora em que o Tum Tum entrou na máquina. Ninguém escreve a
	  hora: o videocassete da sala lembra "03:__" e o rádio-relógio do quarto infantil lembra "__:12", e os dois só
	  acendem no escuro (lanterna apagada, World/HouseClocks + Client/DarkClueController).
	- Cap. 4, porão dos símbolos: o DUETO DA LIA (banco de puzzles v2). As teclas têm desenhos fixos (LUA, SOL,
	  BASTÃO, ESTRELA, da esquerda para a direita). No escuro a Lia toca a primeira frase da música do sahur e o
	  jogador responde com a segunda frase, a da caixinha do cap. 1 (Shared/Game/SahurMelody, sorteada pela semente).
	  O painel do porão tem os mesmos desenhos e cada um toca a nota baixinho (lugar seguro para testar).
	- Cap. 4, cofre: o código ESPALHADO. Os dois primeiros dígitos estão na catacumba, os dois últimos riscados no
	  painel do porão. O teclado do cofre tem quatro dígitos sorteados.
	- Floresta (cap. 6 a 8): o RÁDIO. Sintonizar as frequências do diário/código do guarda.
	Erro: no relógio e no piano (`forgiving`) o chute errado não apaga o que já foi feito; ele badala/desafina alto e
	chama o Tum Tum. Nos outros, o chute errado zera a sequência.
	Puro: sem `game`; testado no Lune.
]]

export type Style = {
	id: string,
	labels: { string },
	prompt: string,
	-- Ordem fixa (o relógio sempre marca 03:12); nil = sorteada pelo plano.
	fixed: { number }?,
	-- Chute errado não zera o progresso (o castigo é o barulho que chama o Tum Tum).
	forgiving: boolean?,
}

local SahurMelody = require("./SahurMelody")

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
	forgiving = true,
}) :: Style
-- Desenhos das teclas do piano, da esquerda para a direita (lua no painel = lua no piano).
PuzzleStyles.PIANO = table.freeze({
	id = "piano",
	labels = table.freeze({ "LUA", "SOL", "BASTÃO", "ESTRELA" }),
	prompt = "TOCAR A TECLA DA",
	forgiving = true,
}) :: Style
PuzzleStyles.RADIO = table.freeze({
	id = "radio",
	labels = table.freeze({ "88.1", "93.5", "101.7", "107.9" }),
	prompt = "SINTONIZAR",
}) :: Style

-- Cor de cada desenho (RGB). Cor e nome juntos: quem não distingue vermelho e verde ainda lê o desenho.
PuzzleStyles.MARK_COLORS = table.freeze({
	["LUA"] = table.freeze({ 70, 130, 235 }),
	["SOL"] = table.freeze({ 245, 200, 50 }),
	["BASTÃO"] = table.freeze({ 215, 70, 50 }),
	["ESTRELA"] = table.freeze({ 235, 235, 240 }),
} :: { [string]: { number } })

-- Velocidade de reprodução de cada tecla, da esquerda para a direita (escala maior a partir do DÓ).
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
		-- A resposta é a segunda frase da música do sahur (a mesma variação da caixinha do cap. 1).
		return {
			id = "piano",
			labels = PuzzleStyles.PIANO.labels,
			prompt = PuzzleStyles.PIANO.prompt,
			forgiving = true,
			fixed = SahurMelody.second(seed),
		}
	elseif stage == 4 and index == 4 then
		-- Cofre também perdoa (banco v2: erro chama o Tum Tum e não zera).
		return { id = "safe", labels = PuzzleStyles.safeDigits(seed), prompt = "DIGITAR", forgiving = true }
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
		return "O RELÓGIO PAROU QUANDO ELE ENTROU NA MÁQUINA.\nNO ESCURO, A CASA AINDA LEMBRA A HORA."
	elseif style.id == "piano" then
		-- O painel não diz a ordem: cada desenho canta a nota baixinho, e a música vem da caixinha do cap. 1.
		local text = "A MÚSICA DO SAHUR: TOQUE NOS DESENHOS\nNO ESCURO, A LIA COMEÇA. RESPONDA COM A CAIXINHA."
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
		return `{shown[1]}{shown[2]}:{shown[3]}{shown[4]} · QUE HORAS A CASA LEMBRA NO ESCURO?`
	elseif style.id == "safe" then
		return `{table.concat(shown, " ")} · JUNTE AS DUAS METADES DO CÓDIGO`
	elseif style.id == "piano" then
		return `{progress}/4 NOTAS · RESPONDA À LIA COM A MÚSICA DA CAIXINHA`
	elseif style.id == "radio" then
		return `{progress}/4 CANAIS · SIGA O PAPEL DO GUARDA`
	end
	return `{progress}/4 · CONSULTE A PISTA RECUPERADA`
end

return table.freeze(PuzzleStyles)
