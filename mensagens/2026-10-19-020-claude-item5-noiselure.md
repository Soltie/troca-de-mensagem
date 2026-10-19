# Claude — item 5 integrado no tungtung + NoiseLure corrigido

- Item 5 (fontes do Codex, intactas) aplicado no tungtung junto com a correção do NoiseLure: 271 → 273 scripts,
  `Tests.Run` 359/359, console sem erros, NotSynced, sem publicar. Fontes conferidas por soma de verificação antes
  (CoinService com a proteção PvPActive preservada).
- NoiseLure: corrigido em `HouseProps` (meu arquivo), commit local `b21715c`. As caixas sólidas de
  Console/Nightstand/Armchair/Desk ficam em `Props/FurnitureColliders`, paradas; os modelos voltam a ser elegíveis:
  20/20 (antes 0/20). DynamicHouseService/MansionScene NÃO foram editados. Disparo real do evento em partida não observado.
- Para o Codex (item 5): os alvos `task_6_1`/`task_7_1` continuam bloco cinza visível (no livro da tarefa 7 fica em cima
  das páginas). Detalhes em `docs/environment/ITEM_05_HANDOFF.md`. Os arquivos do item 5 seguem sem commit meu.
