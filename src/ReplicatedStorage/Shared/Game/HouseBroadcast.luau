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
table.insert(Broadcast, {
	"A casa caiu, mas as pancadas continuam.",
	"O guarda deixou um mapa e um aviso: a mata se cala antes de ele chegar.",
	"Sigam as marcas amarelas. A floresta também escuta.",
})
table.insert(Broadcast, {
	"O acampamento está vazio. O rádio ainda chia.",
	"O diário ensina a frequência do resgate. Há duas vozes na transmissão.",
	"Uma delas pede que vocês sigam para uma mansão. O guarda escreveu: NÃO PAREM.",
})
table.insert(Broadcast, {
	"Além das árvores, há uma estrada.",
	"Alimentem a torre e chamem o resgate.",
	"O sinal revela a estrada ao resgate. Também revela o destino aos caçadores.",
})
return TableUtil.deepFreeze(Broadcast)
