# Cap. 1 v4 — crítico, rodada 2 (20/10/2026)

**Nota geral: 8,0 — APROVADO.** Tempo: 347,6 s (5,8 min), sem travar; para um jogador real, estimo ~4,5 min.
O sorteio da caixinha rodou 3 vezes: 6 móveis fixos, todos com linha de visão; nenhum dentro do sofá.

| Cômodo | Nota | | Item | Nota |
| --- | --- | --- | --- | --- |
| Hall | 8 | | Caixinha | 8 |
| Sala | 8,5 | | Cadeira da Cida | 7,5 |
| Cozinha | 8 | | Tábua | 8 |
| Sala de jantar | 7,5 | | Banquinho | 8 |
| Corredor | 7,5 | | Porta que Troca | 7 |
| Biblioteca | 8 | | Luz | 8 |
| | | | Tung | 7 |
| | | | Medo | 7 |

## Bugs da v3
Corrigidos: caixinha no sofá; Porta que Troca (bate a <7 st, tranca, 3 batidas, leva à sala, fala sem erro);
placa flutuante (agora papel no livro); marcador da cadeira na cadeira real; canto da lareira; "Está escuro demais"
(agora "Ligue a lanterna"); legenda da cozinha; presença do Tung (batidas DoorBang, passos CreatureStep, rosnado);
sustos com legenda em todos os cômodos (hall, cozinha, corredor, sala de jantar, biblioteca); olho do menu bem mais rente.
Continuam: "[E] LEVANTAR A TÁBUA" colado em cima da legenda (07).

## Bugs novos / restantes
1. Porta que Troca: na chegada à sala, a câmera continua olhando para o hall, e a troca quase não se percebe; a cadeira
   da Cida não vira para a porta (fica em -22,5; 0; 4,5) (11).
2. Cadeira da Cida: se você entra com a lanterna acesa, ela foge sem aviso visível; depois, no escuro, a dica "Está
   escuro demais. Ligue a lanterna" contradiz a tarefa "no escuro" (03).
3. Olho do Tung no menu: de lado, o brilho ainda fica um pouco para fora (01). Aceitável.
4. Não vi a silhueta (só sons); o Tung segue Dormant.

## Para subir além de 8
- Desenvolvedor: virar a câmera para o cômodo de destino na troca; não mostrar a dica de escuro durante a tarefa da cadeira.
- Level designer: aviso curto quando a cadeira foge ("A cadeira recuou da luz").
- UI: espaço entre o prompt e a legenda.
- Animador: silhueta visível pelo menos uma vez no cap. 1.

Prints: 01–13 nesta pasta.
