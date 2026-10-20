# Cap. 1 v3 — crítico (20/10/2026)

Play no Studio pelo MCP, sem edições. Nota 8 aprova.

**Nota geral: 6,0** (reprovado). Tempo: 387 s (6,4 min) no 2º Play; o 1º travou na caixinha (bug C1). Estimativa para um
jogador real: ~4 min.

| Cômodo | Nota | | Item | Nota |
| --- | --- | --- | --- | --- |
| Hall | 7 | | Cadeira da Cida (tarefa nova) | 6 |
| Sala | 7,5 | | Caixinha da Lia | 4 (trava) |
| Cozinha | 6 | | Tábua Oca | 7 |
| Sala de jantar | 6,5 | | Banquinho que Foge | 8 |
| Corredor | 6,5 | | Porta que Troca | 3 |
| Biblioteca | 5,5 | | Luz | 6,5 |
| | | | Tung | 2 |
| | | | Medo | 3 |

## Corrigido (ok)
Cena de abertura; fita da TV (3 falas no hall e na sala); "Isso não dá para fazer agora" sumiu; prompt da pilha de
banquinhos travado; dica "ele não gosta de luz"; Olhos no Veio aparecem; tábuas tortas; teto sem estourar;
lençóis no sofá e na poltrona; foto, lampião, cesto e tapete na sala.

## Bugs restantes
1. **C1 — Caixinha dentro do sofá (trava o capítulo).** Às vezes a caixinha cai no `search_task_4_1` (-41,5; 0,9; -4),
   que fica dentro do `Sofa.FurnitureCollider` + `SheetSofa_Sheet`. Sem linha de visão: sem "[E]", e o servidor
   responde `too_far`. Passos: cap. 1 → cadeira da Cida → a música toca nesse baú → impossível abrir. Print 08.
2. **Porta que Troca não dispara.** A porta house_door_5 fecha na 3ª chave, mas a 4,9 st do centro (-12,9; 3,6; -36) não
   bateu nada; aos 9 s, "SwapUndo"; ao abrir, foi para o hall com "Passagem aberta!". Print 19.
3. **Prompt sobre a legenda** na tábua ("[E] LEVANTAR A TÁBUA" em cima de "Toc, toc…"/"Craaac!"). Prints 13, 14.
4. **Placa branca flutuando** na biblioteca (-31; 4,2; -71,4), com o texto da carta. Prints 21, 22.
5. **Tarefa da cadeira da Cida aponta para uma caixa preta** em (-31; 2,4; -6,5); a cadeira real está em
   (-17,4; 0; 6,5). Print 07.
6. **Canto que prende** entre a lareira, a porta house_door_3 aberta e a poltrona/cesto (-12,9; 3,6; 2,9). Print 09.
7. **Olho do Tung no menu** ainda salta para fora do rosto de lado. Print 02.
8. "Está escuro demais. Procure uma vela…" aparece na sala com a lanterna desligada, mas ela está na mão.
9. Legenda antiga da chave da cozinha ("A mesa está posta…"); caixinha de música não aparece no baú.
10. O Tung ficou `Dormant` o tempo todo. Não vi batidas na 1ª chave nem silhueta na 2ª; os sons ao redor foram só
    CreakWood/Whisper/DoorBang de cenário.

## O que falta para 8
- **Desenvolvedor:** C1 (tirar o baú de dentro do sofá ou ignorar o collider no `hasSight`); gatilho da Porta que Troca;
  confirmar presença do Tung (batidas/silhueta/quase); prompt nunca sobre legenda; dica de vela só sem lanterna na mochila.
- **Level designer:** a tarefa da cadeira deve ser a cadeira real; tirar o canto lareira/porta; um susto que se veja
  em cada cômodo (não ouvi nenhum além de rangidos).
- **Luz:** lanterna menos azul; cozinha e sala de jantar escuras demais mesmo com ela; lampiões não aparecem no hall/cozinha.
- **Artista 3D:** caixinha de música visível; carta como papel (a placa ainda flutua); caixas de tarefa em malha.
- **Animador:** olho do Tung dentro da órbita.
- **UI:** prompt e legenda separados.

Prints: 01–22 nesta pasta.
