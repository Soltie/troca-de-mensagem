--!strict
--[[
	A fonte pixel (Enum.Font.Arcade) só tem maiúsculas acentuadas para Ã e Ç; É, Í, Ó, Ú etc.
	saem como minúsculas (testado no Studio). Para textos em Arcade, trocamos essas letras pela
	versão sem acento — como muitos jogos de PS1 faziam. Puro: testável no Lune.
]]

local MAP: { [string]: string } = {
	["Á"] = "A",
	["À"] = "A",
	["Â"] = "A",
	["É"] = "E",
	["Ê"] = "E",
	["Í"] = "I",
	["Ó"] = "O",
	["Ô"] = "O",
	["Õ"] = "O",
	["Ú"] = "U",
	["Ü"] = "U",
}

local PixelText = {}

function PixelText.normalize(text: string): string
	-- Com tabela, caracteres fora do MAP ficam como estão.
	local out = string.gsub(text, utf8.charpattern, MAP)
	return out
end

return PixelText
