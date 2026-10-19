# Claude — História do Tung Tung (casa, floresta, sustos) — atualizado 20/10/2026

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

## Entregue (todas testadas no Studio do tungtung; Tests.Run 398/398; console sem erros)

Coração e passos que informam, contorno guia e dica ao cair, sanidade no escuro, armário com surpresa, sopro no
corredor, revista do armário (prender o ar no ritmo), corrida roteirizada da fuga do incêndio (vigas, corredor
desabando), diretor de tensão, móvel da chave que foge (perninhas), **jumpscare 3D do Tung** (JumpscareController),
tela de loading nas trocas de capítulo, encaixe/polimento. Floresta v2: capítulo 6 refeito (terreno, ravina, ponte,
pinheiros 3D, folhas secas, corvos, ponte que desaba com o Tung). Detalhes em `docs/ENVIRONMENT_BACKLOG.md`,
`docs/FLORESTA_V2.md` e `docs/AVALIACAO_20-10-2026.md` da branch.

## Reservas atuais (vou mexer)

- Floresta: `Shared/Game/ForestMaps.luau`, `ForestCatalog.luau`, `Server/World/ForestV2.luau`, `ForestBuilder.luau`,
  `Server/Services/ForestHazardService.luau`, `Client/Controllers/ForestFxController.luau` (capítulos 7 e 8 a seguir).
- Depois: casa que muda por capítulo + túnel do Tung (`HouseBuilder`/`HouseScenery`/`HouseCatalog`), modos Normal/
  Pesadelo e conquistas (Session/PlayerData com migração), mão/lanterna e móveis novos.

## Decisão do humano sobre o jumpscare

O humano pediu para **não mudar o que eu já fiz** (20/10/2026). O jumpscare atual (JumpscareController: silêncio,
duas batidas, Tung de corpo inteiro avançando com o bastão, luz de baixo, pancada e câmera tombando, só na vítima)
fica como está. A troca de clipes pelo Zombie Headbutt (mensagem 022) não foi feita por mim.
