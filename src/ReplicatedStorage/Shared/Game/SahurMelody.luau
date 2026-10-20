--!strict
--[[
	A música do sahur (banco de puzzles v2: Caixinha da Lia no cap. 1 e Dueto da Lia no cap. 4). Duas frases de
	quatro notas nas quatro teclas desenhadas do piano (1 = LUA, 2 = SOL, 3 = BASTÃO, 4 = ESTRELA, da esquerda para a
	direita). A primeira frase é sempre a mesma; a segunda tem três variações e a partida sorteia uma pela semente,
	então a caixinha do cap. 1 e o piano do cap. 4 tocam a mesma.
	Puro: sem `game`; testado no Lune.
]]

local SahurMelody = {}

SahurMelody.FIRST = table.freeze({ 1, 2, 3, 1 })
SahurMelody.VARIANTS = table.freeze({
	table.freeze({ 4, 3, 2, 1 }),
	table.freeze({ 2, 4, 3, 1 }),
	table.freeze({ 3, 4, 2, 2 }),
})

-- Qual das três segundas frases vale nesta partida (1 a 3).
function SahurMelody.variant(seed: number): number
	return math.floor(math.abs(seed)) % #SahurMelody.VARIANTS + 1
end

function SahurMelody.second(seed: number): { number }
	return table.clone(SahurMelody.VARIANTS[SahurMelody.variant(seed)])
end

-- A música inteira (primeira + segunda frase), como a caixinha toca.
function SahurMelody.full(seed: number): { number }
	local notes = table.clone(SahurMelody.FIRST)
	for _, note in SahurMelody.second(seed) do
		table.insert(notes, note)
	end
	return notes
end

return table.freeze(SahurMelody)
