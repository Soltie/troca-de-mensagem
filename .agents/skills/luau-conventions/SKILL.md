---
name: luau-conventions
description: Convenções de código Luau deste repositório e receitas para adicionar Service, Controller, Remote, Config, teste ou UI. Use antes de criar ou alterar arquivos em src/.
---

# Convenções Luau do projeto

## Regras de arquivo

- Todo arquivo começa com `--!strict`. Tabs, 120 colunas, aspas duplas (StyLua decide; rode `lune run scripts/format`).
- Nomes de arquivo = nomes de instância: `PascalCase.luau` (ModuleScript), `Main.server.luau`,
  `Main.client.luau`. Sem nomes duplicados no mesmo diretório, sem pontos extras no nome.
- **Nunca** `.client.luau` em Starter* (roda duas vezes). Código de cliente fica em `src/ReplicatedStorage/Client`.
- Requires por string:
  - mesma árvore: relativo (`require("./Foo")`, `require("../Net/Guard")`);
  - outra árvore/serviço: `require("@game/ReplicatedStorage/Shared/Logger")`.
  - `./` = pasta do arquivo (no Roblox: `script.Parent`).
- Identificadores em inglês; comentários em PT-BR; mensagens de log/erro em inglês (estáveis para grep).
- Logs só via `Logger.new("Escopo")` -> `log.info("x=%d", x)`. Nada de `print` solto.
- Módulos puros (sem `game`, sem `task`) ficam testáveis no Lune. Injete relógio/espera como parâmetro.

## Receitas

**Novo Service (servidor)**: `src/ServerScriptService/Server/Services/XService.luau`
```lua
--!strict
local XService = { Name = "XService" }
function XService.Init() end   -- preparar estado (opcional)
function XService.Start() end  -- começar a trabalhar (opcional; loops via task.spawn)
return XService
```
Registre na lista de `Server/Main.server.luau` (a ordem é a ordem de Init/Start).

**Novo Controller (cliente)**: igual, em `src/ReplicatedStorage/Client/Controllers/`, registrado em `Client/Main.client.luau`.

**Novo Remote**:
1. Declare em `DEFINITIONS` de `Shared/Net/Remotes.luau` (`Nome = "RemoteEvent" | "RemoteFunction" | "UnreliableRemoteEvent"`).
2. Servidor: `ServerNet.onInvoke/onEvent(nome, { args = { Guard... }, rateLimit = {...} }, handler)`.
   Valide TODOS os argumentos; o servidor decide tudo (autoritativo).
3. Cliente: `Remotes.clientFunction(nome)` / `Remotes.clientEvent(nome)`.
Nunca `Instance.new("RemoteEvent")` fora de `Remotes.setupServer`.

**Constante nova**: `Shared/Config.luau` (congelado). Tipo compartilhado: `Shared/Types.luau`.

**Dados persistentes**: altere `Types.PlayerData` + template em `Server/Data/PlayerDataSchema.luau`,
suba `Config.Data.SchemaVersion` e trate a migração. Use `PlayerDataService.update(player, fn)`.

**Teste**: `src/ServerScriptService/Tests/Specs/Nome.luau` retornando `TestKit.Spec`
(`robloxOnly = true` se usar APIs do Roblox; requires do Roblox dentro de `run`).

**UI**: construída por código com `Client/UI/Create.luau`, dentro de um Controller. Nada de UI feita à mão no Studio.

## Antes de commitar

`lune run scripts/check` verde -> playtest (skill `roblox-playtest`) -> commit pequeno e descritivo.
