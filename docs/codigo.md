# Código (agente CODE) — cap. 1

Estado: feito no **repo**; **NÃO aplicado ao place** (Studio estava aberto sem place: "Place is not open").

## Presença do Tung (cap. 1)
Três momentos novos (`Shared/Game/ChapterMoments`, visual em `MomentController`, disparo em `ChapterMomentService`):
- `knocks`: 5 pancadas na parede (som `DoorBang` grave, tremor leve), de um lado do jogador ou de `at`.
- `silhouette`: silhueta com bastão a ~20 studs à frente do jogador, cruza 7 studs de lado em 1,1 s e some (sem piscar).
- `nearmiss`: pancada forte colada nas costas, poeira, tremor 0,75, luz pisca.

Gatilhos padrão (só modo História, cap. 1): 1ª chave = `knocks`; 2ª chave = `silhouette`; 4ª tarefa = `nearmiss`.

**API para o level design**
- Servidor: `ChapterMomentService.presence("knocks" | "silhouette" | "nearmiss", at: Vector3?)`.
- Sem código: peça no mapa com a tag `TungPresenceZone` e atributo `Presence` (texto). Dispara quando um jogador entra no volume da peça
  (uma vez por capítulo; atributo `Once = false` repete a cada 30 s). A peça deve ficar invisível, sem colisão. O `at` das
  batidas é a posição da peça.

## Bugs
- "Isso não dá para fazer agora." na porta trocada: `door_swapped` agora é ignorado em `CampaignController` (e `""` em `Text.Messages`).
- `moveChair` só move a cadeira da Dona Cida (`CidaChair`, marcada em `HouseProps`); fallback por região da sala de estar.
- Fita da TV: conta a posição do corpo (≤ 20 studs na horizontal, ±8 em Y) e só 4 s depois do spawn; não dispara com a câmera de carregamento.
- Banquinhos: marcados/pilha pronta travam o `[E] LEVAR O BANQUINHO...` (via `target.locked`); se o banquinho fugir, tudo destrava.
- Olhos no Veio: agora na parede mais próxima (raycast 4 direções), neon maior com luz, fade-in e piscada; fallback no ar.
- Cutscene de abertura do cap. 1: já existe no repo (`StoryCatalog` cena 1, 8 s, `StoryController`); depende do código do place estar atualizado — verificar ao aplicar.

## Pendente (precisa do Studio com o place aberto)
Luz v4, dedos da lanterna, tranco de porta (`WorldService.animateDoor`), `FurnitureMotionController`, correções de menu/UI do cap. 1;
lâmpada fraca no corredor e na cozinha (precisa das posições no mapa).

## Como testar
`lune run scripts/check` (ALL GREEN). No Studio: iniciar História cap. 1; pegar 1ª e 2ª chave; criar peça com tag `TungPresenceZone` e `Presence`.
