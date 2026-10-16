# Arquitetura

## Apresentação de terror por jogador (15/10/2026)

`ThreatTargetUserId` no Root do Vigia é publicado pelo CreatureService. `ThreatPresentation`
filtra modo/status e calcula intensidades de efeitos, com testes puros. TensionController executa
o diretor e eventos locais canceláveis; ScreenFxController cria UI/blur/fog respeitando conforto;
ThreatFeedbackController reage à captura individual e restaura a câmera. Não há remotes novos.
Os três controllers estão no bootstrap único; efeitos de props usam clones sem colisão e máscaras
locais restauradas, sem mover geometria autoritativa. Detalhes/QA: `TERROR_POLISH_PROGRESS.md`.

## Campanha cooperativa (15/10/2026)

O slot `RoundService` do bootstrap é uma fachada de modo: seleciona o runtime solo ou
`Server/Campaign/CampaignRuntime`, nunca ambos. Campanha publica seu estado limitado em
`ReplicatedStorage.CampaignState` e os atributos `CampaignStatus`, `CampaignRole` e proteção
temporária no Player; GameState mantém a fase compatível para câmera, áudio e serviços existentes.

Catálogo → RNG puro → plano validado → CoopSession → ActivityBuilder → runtime autoritativo.
O cliente só pede Interact/RequestRestart pelo ServerNet; distâncias, visão, cooldowns, estado
de membro, relés, resgate e votos são decididos no servidor. Nenhum dado persistente foi alterado.

O bootstrap injeta PlayerStateService no runtime quando presente, preservando bateria/postura
por jogador. CampaignController usa o mesmo helper UI/Create; os HUDs não disputam a tela.
Detalhes, limites e roadmap: [COOP_CAMPAIGN.md](COOP_CAMPAIGN.md).

## Visão geral

```
            disco (git)                                   Roblox Studio (place Dev)
  src/ServerScriptService/  <--- Script Sync --->  ServerScriptService
  src/ReplicatedStorage/    <--- Script Sync --->  ReplicatedStorage
  places/world/ (.model.json) -- rojo build dev -->  Workspace (mundo base, 1x)
                                                        ^
  Claude Code  ---------------- MCP (Roblox_Studio) ----+  lê árvore, executa Luau, playtest, console, screenshot
  scripts/*.luau (Lune) -- stylua / selene / rojo sourcemap / luau-lsp analyze / testes puros
```

- **Fonte da verdade**: `src/` (código) e `places/` (mundo base). A place `places/Dev.rbxlx` é local,
  não versionada; se for perdida, `lune run scripts/build dev` recria o mundo e o Script Sync repõe o código.
- **Script Sync** sincroniza só Script/LocalScript/ModuleScript/Folder. UI, Parts e Models não viram
  arquivo — por isso a UI é construída por código e o mundo base é gerado pelo Rojo.
- **Rojo** é usado só para `rojo sourcemap` (luau-lsp) e `rojo build` (places). `rojo serve` não é usado.

## Boot (servidor e cliente)

Um único ponto de entrada por lado:

- `ServerScriptService.Server.Main` (Script, RunContext Server)
  1. `Remotes.setupServer()` cria `ReplicatedStorage.Remotes` com todos os remotes declarados.
  2. `Loader.boot(services)` chama `Init()` de todos, depois `Start()` de todos, na ordem da lista.
  3. Loga `[Server] boot OK (N services)`.
- `ReplicatedStorage.Client.Main` (Script, RunContext Client — recomendação oficial; ver DECISIONS)
  1. Espera `game.Loaded`.
  2. `Loader.boot(controllers)`; loga `[Client] boot OK (N controllers)`.

Falha em qualquer `Init`/`Start` interrompe o boot com `[Server] Init failed in <Nome>: <erro + traceback>`.
`Init` prepara estado; `Start` começa a trabalhar (loops longos via `task.spawn`).

## Requires

Require por string (suportado nativamente pelo Roblox e pelo Luau):

- `./X` e `../X`: relativos à pasta do arquivo (no Roblox, `script.Parent` / `script.Parent.Parent`).
- `@game/Serviço/...`: absoluto a partir de `game`. No Roblox e no luau-lsp é nativo (via sourcemap);
  no Lune funciona pelo alias `"game": "./src"` do `.luaurc`. É isso que permite rodar os mesmos
  módulos e specs no Studio e no Lune.

## Rede (servidor autoritativo)

- `Shared/Net/Remotes.luau`: registro central (`DEFINITIONS`). Servidor cria; cliente espera com timeout.
  Nome desconhecido = erro imediato.
- `Server/Net/ServerNet.luau`: `onInvoke`/`onEvent` aplicam, nesta ordem, rate limit por jogador
  (token bucket, `Shared/Net/RateLimiter`), validação de todos os argumentos (`Shared/Net/Guard`,
  rejeita NaN/inf, strings inválidas/longas, tabelas com buracos/metatable, argumentos a mais) e `pcall`
  no handler. RemoteFunction sempre responde `Types.Result` (`{ok=true,data}` ou `{ok=false,error}`).

## PlayerData

`Server/Services/PlayerDataService.luau`:

- Modo: servidor ao vivo = sempre DataStore real. Studio = `Config.Data.StudioMode` (`auto` testa o acesso
  e cai para **mock** se não houver; place não publicada = mock). Studio em modo real usa store `<nome>_Studio`.
- Load com retry/backoff; falha no ao vivo = kick (não sobrescreve dados reais com o template).
- Save com `UpdateAsync` (+ `userIds` para pedidos de remoção de dados), autosave periódico,
  save no `PlayerRemoving` e no `BindToClose` (espera os saves pendentes até `ShutdownTimeout`).
- Formato e migração: `Server/Data/PlayerDataSchema.luau` (puro, testado).
- **TODO session locking**: hoje o último save vence se o jogador estiver em dois servidores ao mesmo tempo
  (teleporte/reconexão rápida). Antes de lançar com dados valiosos: lock de sessão no `UpdateAsync`
  (campo `lockedBy`/`lockedAt` com expiração) ou adotar ProfileStore (exige decidir sobre pacotes/Wally).

## UI

Construída por código dentro de Controllers, com `Client/UI/Create.luau` (Luau puro, sem lib declarativa).
Exemplo: `HudController` cria `PlayerGui.DebugHud` (ping, modo de dados). Desligue com `Config.Debug.ShowHud`.

## Testes

- `Tests/TestKit.luau`: mini framework (`describe`/`it`/`expect`), sem dependências.
- `Tests/Specs/*.luau`: um spec por módulo. Specs com `robloxOnly = true` só rodam no Studio.
- Studio (MCP): `return require(game:GetService("ServerScriptService").Tests.Run)()` em `execute_luau` (Server).
- Fora do Studio: `lune run scripts/test` (também roda dentro de `scripts/check`).

## Smoke test

`PingService` (servidor) + `PingController` (cliente): o cliente chama `Ping("hello")`, o servidor valida,
aplica rate limit, consulta o PlayerData e responde; o cliente loga e mostra latência/modo no HUD.
É exemplo técnico; remova os dois quando o jogo tiver remotes reais.

---

# Jogo: SUBESTAÇÃO 9

```
SERVIDOR (autoritativo)                                   CLIENTE (efeitos e UI)
WorldService  ── constrói o mapa (World/MapBuilder)       CharacterController  1ª pessoa, corrida, balanço
   luz/energia, portas e portão em passos                 FlashlightController lanterna -> SetFlashlight
RoundService  ── fases, objetivos (Game/Objectives),       InteractionController mira + E -> Interact
   remotes Interact/SetFlashlight/RequestRestart          CreatureVisualController corpo do Vigia em stop-motion
   valida interação (Game/RoundRules)                     AudioController      camadas, stingers, lo-fi
CreatureService ── Root invisível + pathfinding            WorldFxController    luzes piscando em passos
   cérebro puro (Game/CreatureBrain)                      RetroFxController    gradação + sobreposição (V)
DebugService  ── ServerStorage.DebugBridge (só Studio)    GameUiController     objetivo, intro, bilhete, finais
        │                                                 HudController        debug (F3): FPS, estado
        └── ReplicatedStorage.GameState (atributos) ──► todos os controllers observam
```

## Fluxo da rodada

`Loading → Intro (9 s, jogador ancorado) → Playing → Won | Lost → [R] → Intro ...`

1. `RoundService.restart()` sorteia os fusíveis (2 pontos por sala) e restaura portas, portão, quadro,
   luzes, criatura e atributos. Depois spawna o jogador (`CharacterAutoLoads = false`).
2. Entrar no prédio → objetivo "fusíveis". O 1º fusível (ou 120 s) acorda o Vigia no ponto mais
   distante do jogador.
3. Cada interação passa por `ServerNet` → `RoundRules.validateInteraction` → regra do objeto
   (`Objectives`). O resultado volta como chave de mensagem (`Text.Messages`).
4. Com os 3 fusíveis no quadro: `PowerOnDelay` → energia (luzes, zumbido, névoa mais longa), o Vigia
   passa a caçar e o portão pode abrir.
5. Vitória: portão aberto + jogador na `ExitZone`. Derrota: o `CreatureBrain` devolve `capture`
   (perto + linha de visão). As duas saem de `Playing` só uma vez (`endRound`).

## O Vigia

- **Servidor:** `Workspace.Vigia.Root` (invisível, ancorada, sem colisão), atributos `Mode`/`Active`.
  - Cérebro a cada 0,2 s, com os modos Dormant, Patrol, Investigate, Search, Chase e Capture.
  - Movimento cinemático no Heartbeat; repath a cada 0,5 s na perseguição.
  - Arromba portas fechadas no caminho.
- **Percepção:**
  - Visão: raycast olho → cabeça, campo de 120°, alcance 30 (55 com a lanterna) e 7 studs mesmo de costas.
  - Barulho: corrida (velocidade > 13), fusíveis, quadro, portas e portão.
  - "Faro" a partir do 2º fusível; caça com a energia ligada.
- **Cliente:** `Client/Creature/Rig.luau` (21 peças, cinemática direta) + `Poses.luau` (poses-chave).
  - A posição visual acompanha a Root a 12 Hz.
  - Poses: Walk/Chase/Search/Idle/Capture a 3–12 poses/s.
  - A cabeça "estala" para olhar o jogador.
  - Passos com som e tremor.

## Mapa

`Server/World/Layout.luau` (dados puros, testados) define:

- salas, paredes com aberturas, portas e portão;
- zona de saída e spawn;
- pontos dos fusíveis e onde ficar de pé para pegá-los;
- rota de patrulha, luminárias e luzes de emergência.

`MapBuilder` monta tudo com `Build`/`Props`/`Palette`. As regiões de porta ficam no grupo de colisão
`NavOnly` (ver DECISIONS D26).

## Testes do jogo

- Lune (`lune run scripts/test`): `Objectives`, `RoundRules`, `CreatureBrain`, `Layout`/`WallMath` e
  `PixelText`, além dos do template.
- Studio (`Tests.Run`): os mesmos, mais `Remotes` e `Navigation`. O `Navigation` calcula rotas reais com o
  agente do jogador e do Vigia: spawn → todos os pontos de apoio, salas, quadro e portão, mais a rota de
  patrulha completa.
