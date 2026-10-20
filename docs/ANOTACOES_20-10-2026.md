# Anotações de 20/10/2026 (nada disto foi mexido ainda)

## Problemas vistos jogando
1. **Tábua Oca (cozinha, chave do Juca) sem sentido** — `Campaign/HouseMiniPuzzles.luau`.
   Nada no jogo diz para bater nas tábuas nem que o som importa (a pista só existe no roteiro); as tábuas tortas
   parecem bagunça, não pista; sem som não há como achar.
   Conserto proposto: pista antes (bilhete do Juca ou fita: "escondi embaixo da tábua que soa oca"), sinal visual na
   certa (pregos soltos, serragem, fresta) e legenda ao bater ("toc… cheio" / "toc… OCO!").
2. **Bicho preto de olho vermelho** — é o vulto dos momentos (`Client/Controllers/MomentController.shadowFigure`),
   um boneco de blocos que não parece o Tung. Aparece no cap. 1 depois da 2ª chave (e a cada 35–60 s, "silhouette"
   do level design) e no cap. 2 quando a energia volta.
   Conserto proposto: usar o modelo de verdade do Tung (o mesmo do susto 3D), todo escuro, sem olhos inventados.
3. **Carta da biblioteca mal montada** (último objetivo do cap. 1) — `World/HouseTaskProps` ("message").
   A folha atravessa o livro na diagonal, o texto sai cortado e grande ("ELE NÃ O", acento quebrado na fonte pixel),
   a faixa verde do marcador passa por cima e o "Objetivo concluído!" tapa a leitura.
   Conserto proposto: carta reta ao lado do livro, frase inteira pequena em duas linhas ("ELE NÃO É O DONO. / O CORAÇÃO
   ESTÁ SOB A CASA.") numa fonte com acento, e abrir a carta grande na tela antes do "Objetivo concluído!".

## Ideia: corredor infinito (aprovada como ideia, não feita)
Depois da "Porta que Troca" (3ª chave, cap. 1): um corredor que leva de volta ao começo dele mesmo. A cada volta algo
muda (quadro torto → luz do fundo apaga → caixinha tocando atrás da parede → vulto do Tung longe e depois mais perto).
Sai quem descobre a regra (andar de costas, apagar a lanterna ou seguir a caixinha; dica discreta na 3ª volta).
Cuidados: 3–4 voltas (60–90 s), Tung não persegue lá dentro, a dupla entra e sai junto, só uma vez no jogo.

## Ideias de enigmas
Lista completa em [IDEIAS_PUZZLES.md](IDEIAS_PUZZLES.md) (14 ideias; começar por retratos, batidas e duas alavancas).

## Da avaliação geral (nota 6,5) ainda em aberto
Detalhes em [AVALIACAO_GERAL_20-10-2026.md](AVALIACAO_GERAL_20-10-2026.md).
- Capítulos curtos (1–2,5 min na casa, ~1 min na floresta) — o que mais derruba a nota.
- Folga do Tung (Relax 35 s) longa demais: ignorou o jogador a 4 studs por 50 s.
- Sistema Mansão do Codex no cap. 1 ("REBOCO CAINDO") confunde antes de o Tung acordar.
- Escada do porão: o bot ficou preso ~90 s; conferir com jogador de verdade.
- Captura de quem está parado em 1,7 s (duro para criança distraída).
- Floresta: tarefas perto demais, pouco perigo no caminho, torre/van/jangada/cabana de blocos, trechos escuros.
- Peças de bloco (relógio, piano, cofre, catacumba, torre, van, jangada) a trocar por modelos.
- Coop e tarefas de dupla sem teste; ninguém jogou com teclado de verdade.

## Já resolvido hoje
Porta com parede invisível (13b6f55); câmera da derrota e textos sobrepostos (12cd0d8).
