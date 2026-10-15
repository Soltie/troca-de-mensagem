# Arquitetura

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
