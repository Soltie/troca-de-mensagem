--!strict
-- A mesma transmissão acompanha pistas, televisão e cartelas; não contém soluções de puzzles.
local TableUtil = require("../Util/TableUtil")
local Broadcast = {
	{
		"A fita estava rodando antes de vocês chegarem.",
		"Ela mostra a porta da frente. Pelo lado de dentro.",
		"Três chaves. Uma pergunta: quem está gravando?",
	},
	{
		"Na gravação, ele bate à porta de cada quarto.",
		"Uma família respondia. Agora, só a casa responde.",
		"Se ouvirem três pancadas, apaguem a luz e escutem.",
	},
	{
		"O relógio parou na noite em que a família sumiu.",
		"Máscara, livro, retrato: cada lembrança guarda uma parte dela.",
		"Ele não protege a casa. A casa mantém ele aqui.",
	},
	{
		"O cofre foi fechado por alguém que tentou sair.",
		"O coração alimenta as paredes. O altar pode quebrar o ciclo.",
		"Devolvam o que foi levado. Não respondam às pancadas.",
	},
	{
		"A fita finalmente está mostrando o presente.",
		"Quando o coração parar, a casa perderá sua forma.",
		"Memorizem o retorno: escada, hall, varanda, floresta.",
	},
}
return TableUtil.deepFreeze(Broadcast)
