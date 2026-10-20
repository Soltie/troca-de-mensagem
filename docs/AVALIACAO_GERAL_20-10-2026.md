# Avaliação geral do jogo (20/10/2026, depois dos itens 1 a 5)

Nota geral: **6,5/10** (era 6/10 no veredito da manhã). Comparação só com os melhores do gênero (DOORS, The Mimic,
Piggy, Apeirophobia).

## Como foi testado
- Bot novo jogando como criança de teclado: anda com o direcional (14 studs/s, sem correr), procura nos móveis, caça
  o móvel fujão, tenta notas e números até acertar (erro zera o enigma), Tung **solto** (não congelado).
- Jogados: cap. 1, 2, 3 e 4 (casa) e 6 (floresta). Cap. 5, 7 e 8 vêm da jogada completa da manhã e de testes pontuais
  de hoje (lago, túnel, momentos).
- Studio `Tests.Run` 424/424 com o Play limpo; console sem erros.

## Tempo por capítulo (andando, sem correr, sem se esconder)
| Cap. | Tempo | Observação |
| --- | --- | --- |
| 1 | ~1,5–2 min | apagão disparou na 3ª chave; móvel fujão escapou uma vez |
| 2 | ~2 min | fusíveis em cômodos sorteados; vulto ao religar a energia |
| 3 | ~2,5 min | túnel ao pegar a máscara; Tung perseguiu 2x e perdeu o bot; derrubou no relógio |
| 4 | não fechou | bot travou ~90 s na escada do porão; Tung derrubou 2x no piano |
| 6 | **69 s** | floresta curta demais |

## Notas por área
| Área | Antes | Agora | Por quê |
| --- | --- | --- | --- |
| Estabilidade | 8 | 8 | Sem erro no console; testes verdes. |
| Atmosfera | 7 | 7,5 | Apagão e vulto no corredor funcionam muito bem. |
| Monstro e susto | 5 | 6,5 | "Quase" funciona; túnel aparece de verdade (cava o chão); ele perde quem corre. |
| Variedade de tarefas | 4 | 5 | Busca em móveis, móvel fujão e enigmas; o resto ainda é "ir e apertar E". |
| Enigmas | 3 | 6 | Relógio 03:12, piano com notas e cofre com código espalhado exigem pensar. |
| Duração | 4 | 4 | **Não mudou**: 1–2,5 min por capítulo; ~15–20 min a campanha sem morrer. |
| Visual | 6 | 6 | Bonito na casa; peças de bloco nas áreas novas; floresta e porão escuros. |
| Rejogar | 6 | 6,5 | Cômodos sorteados e voto nos modificadores ajudam. |

## Problemas encontrados hoje (do mais grave ao menos)
1. **Curto demais** (continua o maior problema). A floresta é a pior: 69 s no cap. 6.
2. (corrigido) **Porta aberta com parede invisível:** a colisão era o painel invisível de 9 studs de uma folha só;
   aberta, ela passava 4 studs da folha visível (parede invisível dentro do cômodo) e o lado da outra folha não
   colidia. Agora a colisão é das duas folhas (`HouseFinish.doubleDoor`), cada uma com o marcador de porta do
   pathfinding. Testado: passa pelo vão, bloqueia na folha e na porta fechada; o bot fez o cap. 1 em 45 s sem emperrar.
3. **Escada do porão:** o bot ficou ~90 s preso em (-22, 4, 13) tentando descer. Pode ser só o pathfinding do bot, mas
   vale um jogador de verdade conferir.
4. **Folga do Tung longa demais:** na fase "Relax" (35 s) ele ignorou o jogador a 4 studs por 50 s seguidos.
5. **Sistema Mansão do Codex no cap. 1:** aviso "REBOCO CAINDO — OUTRO LADO LIVRE" e travas aparecem antes de o Tung
   acordar; confunde e bloqueia caminho sem explicar.
6. **Captura rápida quando parado:** do "quase" à derrubada, 1,7 s. Justo para quem foge, duro para criança distraída.
7. (corrigido hoje) Tela de derrota com a câmera no chão: parede verde e tapete gigantes ("quadrado verde na cintura").
8. (corrigido hoje) Tela de derrota com três textos sobrepostos.
9. Coop (2+ pessoas) e tarefas de dupla continuam sem teste; ninguém jogou com teclado de verdade.

## Recomendações (ordem de impacto)
1. **Capítulos de 5–8 min:** mais 4–6 tarefas por capítulo usando as alas que já existem (Jardim de Inverno, Estufa,
   Pavilhão, Oficina, Pátio do Relógio, Fonte), tarefas de várias etapas (juntar 3 peças antes do enigma) e voltar a
   cômodos que mudaram. Na floresta, espaçar as tarefas e pôr perigo no caminho. Medir com o bot até passar de 5 min.
2. ~~Consertar a porta aberta~~ (feito em 20/10).
3. **Folga do Tung:** encurtar a fase Relax para ~20 s e deixar ele atacar quem está a menos de 6 studs e à vista.
4. **Mansão no cap. 1:** ligar as travas só depois de o Tung acordar (cap. 2), ou explicar na primeira vez.
5. **Conferir a escada do porão** com jogador de verdade; se prender, alargar degraus/colisão.
6. **Teste com gente:** uma jogada com teclado e uma em dupla antes de publicar para o público.
7. **Item 6 do plano:** trocar as peças de bloco (relógio, piano, cofre, catacumba, torre, van, jangada) por modelos.
