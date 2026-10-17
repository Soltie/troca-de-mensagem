# Auditoria técnica da UI — Tung Tung Sahur

17/10/2026. Branch `design/ui-remaster`, a partir de `codex/tung-tung-sahur` @ `7a7f4ca`.
Fonte da verdade: o código em `src/`. Os números das capturas de `REFERENCIAS/` não foram copiados.

## 1. Como o projeto é construído

- Rojo 7.7.1 via `default.project.json`; toda a UI é **criada por código** (nenhum `StarterGui` editado no Studio).
- Um único bootstrap do cliente: `ReplicatedStorage/Client/Main.client.luau` registra 34 controllers, em ordem, pelo `Shared/Loader`.
- Helpers de UI: `Client/UI/Create.luau` (fábrica), `Theme.luau` (tokens), `Icons.luau` (pictogramas por primitivas), `Juice.luau` (animações), `FieldHud.luau` (HUD da campanha).
- Checks: `lune run scripts/check` (StyLua, selene, sourcemap, luau-lsp strict, 283 testes). Build: `lune run scripts/build`.
- Backup: o branch original `codex/tung-tung-sahur` fica intacto; o bundle em `C:\Projetos\pacote\historico` também.

## 2. ScreenGuis existentes

| ScreenGui | DisplayOrder | Dono | Função |
|---|---:|---|---|
| `GameUi` | 10 | GameUiController | mira, prompt, objetivo, inventário, ajuda, notas, intro, susto, telas finais |
| `RetroFx` | 50 | RetroFxController | overlay VHS/scanlines |
| `FearOverlay` | 55 | ScreenFxController | vinheta/VHS de perigo |
| `CampaignUi` | 60 | FieldHud (CampaignController) | HUD da campanha: bateria, fôlego, oxigênio, objetivo, guia |
| `SpectatorUi`, `StoryUi` | 65 | SpectatorController, StoryController | espectador; gravações/legendas |
| `ContinueOffer`, `InteractionUi` | 70 | ContinueController, GameUiController | oferta de continuar; interação compartilhada |
| `HouseTouchControls` | 85 | TouchControlsController | botões de toque |
| `Hud` (debug) | 100 | HudController | painel F3 |
| `TransitionUi` | 120 | TransitionController | fades, cartelas, pálpebras |
| `CinematicControls` | 121 | CinematicController | pular cena, cartela "próximo jogo" |
| **`MainMenu`** | 200 | **MainMenuController** | lobby: Jogar/votos, Melhorias, Servidores, Amigos |
| **`StoreUi`** | 220 | **StoreController** | Loja, Temporada, Baús, Diário (+roleta), Coleção, Créditos |
| `ComfortOptions` | 250 | SettingsController | Ajustes (qualidade, conforto, volumes) |
| `TrailerUi` | 500 | TrailerController | só Studio |

## 3. Remotes usados pela UI

Todos declarados em `Shared/Net/Remotes.luau` e validados no servidor por `ServerNet` + `Guard` + rate limit.

| Remote | Tipo | Quem chama | Handler | Observação |
|---|---|---|---|---|
| `SelectGameMode` | Function | MainMenu (Votar) | CampaignRuntime | voto por maioria; retorna `{accepted}` |
| `Store` | Function | MainMenu, StoreController | StoreService | ações abaixo; envelope `{ok, data|error}` |
| `StoreNotice` | Event S→C | — | StoreService | recompensas concedidas (toasts) |
| `StoreTrack` | Event | StoreController | TelemetryService | só funil; não altera o jogo |
| `Lobby` | Function | MainMenu | LobbyService | `servers`, `join`, `friend` |
| `SetHousePreference` | Event | SettingsController | StoreService/Preferences | qualidade/shaders/conforto |
| `RequestRestart` | Function | GameUiController | RoundService | telas finais |

Ações do remote `Store` (StoreService): `claim_daily`, `spin`, `open_chest`, `buy_fichas`, `buy_creditos`, `equip`,
`upgrade_fichas`, `upgrade_creditos`, `consumable_fichas`, `consumable_creditos`, `loadout_on`, `loadout_off`,
`use_continue`, `buy_product`.

## 4. Fonte de cada dado exibido (atributos do Player, publicados pelo StoreService)

`Fichas`, `Creditos`, `Xp`, `Level`, `Vip`, `Owned` (JSON), `Tapes`, `DailyStreak`, `DailyClaimable`, `SpinsLeft`,
`PaidRandomRestricted`, `StarterBought`, `KitBought`, `EquipFlashlight`, `EquipUniform`, `EquipFilter`, `Title`,
`SeasonId`, `SeasonXp`, `SeasonPremium`, `Perks`, `Consumables`, `Loadout`, `BoostFichasUntil`, `BoostXpUntil`,
`HousePreferences`, `StoryProgress` (`{cleared, flawless}`), `StoryPass`, `StoreReady`.

`ReplicatedStorage.CampaignState`: `Phase`, `StoryVotes`, `StandardVotes`, `NextStageAt` e o resumo da campanha.
Player: `GameModeVote`, `OpeningActive`, `CampaignStatus`, `ModeMenuOpen`.

Catálogos compartilhados (somente leitura na UI): `StoreCatalog` (itens, preços, produtos Robux), `Perks`
(4 melhorias × 5 níveis, 3 consumíveis), `StoryRewards` (8 capítulos), `Season`/`SeasonCatalog`, `Economy` (`levelInfo`).

## 5. Matriz de dependências (tela → evento → servidor → dado → resultado)

| Tela / ação | Evento cliente | Servidor | Dado lido | Resultado esperado |
|---|---|---|---|---|
| Votar modo | `SelectGameMode(id)` | CampaignRuntime | `StoryVotes`/`StandardVotes`, `GameModeVote` | voto registrado; contagem começa com ≥ minPlayers |
| Equipe | — | CampaignRuntime | `Players`, `GameModeVote`, `NextStageAt` | slots 1–6 com avatar e cor do voto |
| Mochila (kit) | `Store("loadout_on/off", id)` | StoreService/Perks | `Consumables`, `Loadout` | item liga/desliga no kit; estoque não muda |
| Melhorias | `Store("upgrade_fichas/creditos", id)` | StoreService/Perks | `Perks`, `Fichas`, `Creditos` | nível +1, débito único; erro com saldo insuficiente |
| Consumíveis | `Store("consumable_fichas/creditos", id)` | StoreService/Perks | `Consumables` | estoque + pacote |
| Produto Robux | `Store("buy_product", key)` → prompt nativo | StoreService + `ProcessReceipt` | `StoreCatalog.Products[].id` | concessão só no recibo |
| Loja item | `Store("buy_fichas/buy_creditos", id)` | StoreService | `Owned` | posse; sem cobrança dupla |
| Equipar | `Store("equip", id)` | StoreService | `Equip*`, `Title` | cosmético aplicado (CosmeticService) |
| Diário | `Store("claim_daily")` | StoreService/Economy | `DailyClaimable`, `DailyStreak` | prêmio do dia |
| Roleta | `Store("spin")` | StoreService/Economy (sorteio no servidor) | `SpinsLeft` | prêmio decidido no servidor |
| Baú | `Store("open_chest", id)` | StoreService | `PaidRandomRestricted` | chances exibidas antes; baú pago some se restrito |
| Temporada | `Store("buy_product", passe)` | StoreService | `SeasonXp`, `SeasonPremium` | trilha grátis/premium |
| Servidores/Amigos | `Lobby(...)` | LobbyService | resposta da chamada | lista / teleporte validado |
| Ajustes | `SetHousePreference` | StoreService | `HousePreferences` | perfil aplicado e salvo |

## 6. Achados importantes

1. **Todos os 16 produtos Robux têm `id = 0`** em `StoreCatalog` (passe da história, bônus duplo, créditos, kits, passe
   de temporada…). Por isso a tela atual mostra "PASSE INDISPONÍVEL" / "BÔNUS INDISPONÍVEL": os Developer Products
   ainda não foram criados no Creator Hub. **Não é bug de UI.** A remaster não deve exibir botões de compra mortos:
   produto sem ID aparece como "indisponível no momento", sem preço clicável. Criar os produtos é ação do dono.
2. Ícones de navegação usam **emoji** (▶️⚡🛒🎫🎁🌐👫⚙️): renderização varia por plataforma e fica fora da paleta.
   Substituir por pictogramas próprios (`Icons.luau`), sem asset externo.
3. `MainMenuController` (1.842 linhas) posiciona quase tudo com offsets absolutos e reescreve layout por frame no
   `RenderStepped` para o modo compacto; o painel JOGAR usa `CanvasSize` fixo. Funciona, mas é frágil em 19,5:9 e 4:3.
4. A tela JOGAR concentra: modos, 8 capítulos, oferta de passe, bônus pago, equipe, mochila e vitrine — densidade alta
   e duas ofertas pagas dentro dos cartões de modo.
5. Estado reativo é bom: o menu marca `dirty` em mudanças de atributos e redesenha no máximo uma vez por quadro.
   Mantido.
6. Vitrine 3D do Tung Tung: um `ViewportFrame` com `WorldModel` e `RenderStepped`, que se desconecta quando a aba é
   destruída. Mantido (custo único, somente na aba JOGAR).
7. `ScreenInsets = CoreUISafeInsets` já está no `MainMenu`: respeita notch e barra do Roblox.
8. Não há framework de UI externo; o padrão é `Create` + funções locais. A remaster segue esse padrão (componentes
   em `Client/UI/Components.luau`), sem introduzir biblioteca nova.

## 7. Riscos e como foram tratados

| Risco | Tratamento |
|---|---|
| Conceder item/saldo pelo cliente | UI só chama `Store`/`SelectGameMode`; nenhuma lógica de preço/posse no cliente |
| Compra duplicada por clique duplo | `invoke` mantém o lock `busy` existente |
| `ProcessReceipt` | intocado (StoreService) |
| DataStore / schema | intocado (schema 6) |
| Mudança de economia | nenhuma constante de preço, XP, chance ou recompensa alterada |
| Duplicar conexões ao redesenhar | listeners por aba ficam na tabela `live`, limpa a cada `clearBody` |
| Botões sob controles de toque | menu só existe no Lobby (sem joystick); `CoreUISafeInsets` |

## 8. Baseline e limites desta auditoria

- Check ALL GREEN (283 testes) no commit de partida.
- Capturas "antes": as 6 imagens de `REFERENCIAS/` fornecidas pelo dono (estado atual real).
- **NÃO MEDIDO:** tempo de abertura, contagem de instâncias e FPS no Studio — o MCP `Roblox_Studio` não estava ativo
  neste PC durante a auditoria. Medir quando o Studio estiver com "Enable Studio as MCP server" ligado.
- **Figma / Hyper3D:** nenhum conector disponível nesta sessão. A remaster segue com UI nativa e pictogramas por código;
  nenhum asset novo precisa de upload nesta fase.
