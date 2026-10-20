# Claude — História do Tung Tung (casa, floresta, sustos) — atualizado 20/10/2026 (fim das missões)

## Identidade e origem

- Agente: Claude (Claude Code), PC do humano dono da conta Roblox `fashionultraaura`.
- Repositório local: `tung-tung-sahur`, branch `design/environment`.
- **Código publicado aqui como branch `claude/design-environment`** (deste repositório de coordenação). Puxe por ela.
- Aplico no place `tungtung` (82955516040017) pelo MCP, **sem Script Sync** (ScriptEditorService, arquivo por arquivo,
  com inserções pontuais nos scripts que têm código só do place: CampaignRuntime, CampaignController, WorldService,
  AudioController, Main do cliente/servidor). Não publico o jogo.

## Escopo (frente "história")

Modo História (casa caps. 1–5 e floresta caps. 6–8): sustos, mecânicas de terror, mapas, jumpscare, loading.
Não mexo em Midnight Hunt, caçada online/PvP, filas, salas, loja/economia, dados nem nas animações do Codex.

## Entregue (todas testadas no Studio do tungtung; Tests.Run 412/412; console sem erros) — commit f4a112c

Coração e passos que informam, contorno guia e dica ao cair, sanidade no escuro, armário com surpresa, sopro no
corredor, revista do armário, corrida roteirizada da fuga do incêndio, diretor de tensão, móvel da chave que foge,
**jumpscare 3D do Tung**, tela de loading, encaixe/polimento.
Floresta v2 completa: cap. 6 (neblina, ponte que desaba), cap. 7 (lago, jangada, A Voz), cap. 8 (morro, torre, farol,
árvores que caem, Tung no capô da van na cena final).
Opção A: túnel de minhoca do Tung (caps. 2–5), catacumba (cap. 4) e capela (cap. 5) embaixo do jardim leste, casa que
estraga a cada capítulo. Opção E: modificadores no lobby (Pesadelo etc.) e 8 conquistas. Opção G: mão/lanterna nova,
móveis de busca com acabamento. Detalhes: `docs/AVALIACAO_20-10-2026.md`, `docs/FLORESTA_V2.md`,
`docs/MODELOS_SUBSTITUIVEIS.md`, `docs/PENDENCIAS_HUMANAS.md` da branch.

## Arquivos compartilhados que toquei (pontual, por âncora no place)

- `Shared/Net/Remotes.luau`: remote novo `SetModifier` (RemoteFunction).
- `MainMenuController`: uma linha em `buildPlay` chama `UI/DifficultyPanel.build(scroll, 3, columns)`; o showcase
  passou para a ordem 4.
- `StoreService`: `awardTask`/`awardCoin` multiplicam as Fichas por `Difficulty.boost` (modificadores).
- `PlayerStateService`: gasto da bateria × modificador. `CreatureService`: velocidade e audição × modificador;
  pathfinding com custo infinito na água.
- `CollectibleService`: nos caps. 6–8 a fita nasce na floresta (a versão do place é diferente do repo; mudei só
  `spawnTape` e um require).
- `CampaignRuntime.interact`: ids `tunnel_*` vão para `TunnelService.board`. `WorldService.setHouseStage`: chama
  `Catacomb.setStage` e `HouseDecay.setStage`.

## Reservas atuais

Nenhuma frente nova reservada. Fico disponível para ajustes pedidos pelo humano na história.

## Decisão do humano sobre o jumpscare

O humano pediu para **não mudar o que eu já fiz** (20/10/2026). O jumpscare atual (JumpscareController: silêncio,
duas batidas, Tung de corpo inteiro avançando com o bastão, luz de baixo, pancada e câmera tombando, só na vítima)
fica como está. A troca de clipes pelo Zombie Headbutt (mensagem 022) não foi feita por mim.
