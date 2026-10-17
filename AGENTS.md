> **IA de outro computador:** comece por [LEIA_IA_COLEGA.md](LEIA_IA_COLEGA.md) e [docs/IA/README.md](docs/IA/README.md).

# Projeto independente: Tung Tung Sahur

Raiz atual: `C:/Users/xpg/Documents/tung-tung-sahur`.
Leia primeiro [INICIAR_AQUI.md](INICIAR_AQUI.md). Edite somente o src desta pasta.
Os caminhos, worktrees e reservas anteriores nos documentos abaixo são históricos.
Use Studio e Script Sync próprios deste jogo; não conecte à árvore do outro jogo.
A conexão da nova places/Dev.rbxlx ainda precisa ser configurada e verificada.

---

# AGENTS.md — como trabalhar neste repositório

Template de jogo Roblox feito para agentes. **O repositório é a fonte da verdade**: código vive em
`src/` e chega ao Studio pelo **Script Sync**; o agente testa no Studio pelo **MCP oficial** (`Roblox_Studio`).
Responda ao humano em **português do Brasil**, curto e direto.

O jogo em si está descrito (quando existir) em `docs/GAME_SPEC.md`. Decisões em `docs/DECISIONS.md`,
arquitetura em `docs/ARCHITECTURE.md`, estado do ambiente em `docs/SETUP_REPORT.md`.

## Onde fica cada coisa

```
src/ServerScriptService/            -> ServerScriptService (Script Sync)
  Server/Main.server.luau           bootstrap ÚNICO do servidor (lista ordenada de Services)
  Server/Services/*.luau            Services: { Name, Init?, Start? } + API própria
  Server/Net/ServerNet.luau         handlers de remote: rate limit + validação + pcall
  Server/Data/                      PlayerDataSchema (formato/migração), MockDataStore
  Tests/TestKit.luau, Run.luau      framework + runner no Studio; Tests/Specs/*.luau = specs
src/ReplicatedStorage/              -> ReplicatedStorage (Script Sync)
  Client/Main.client.luau           bootstrap ÚNICO do cliente (Script RunContext=Client)
  Client/Controllers/*.luau         Controllers: { Name, Init?, Start? }
  Client/UI/Create.luau             helper de UI por código
  Shared/                           Config, Types, Logger, Loader, Net/{Remotes,Guard,RateLimiter}, Util/
places/Dev.project.json             mundo base (sem scripts) -> places/Dev.rbxlx (place de trabalho, não versionada)
places/world/                       definição versionada do mundo base (.model.json)
default.project.json                layout Rojo SÓ para `rojo sourcemap` e `rojo build` (nunca `rojo serve`)
scripts/*.luau                      tarefas em Lune (check, test, build, format, sourcemap)
```

## Loop de desenvolvimento

1. Editar o arquivo em `src/` (nunca no Studio).
2. `lune run scripts/check` — format, lint, sourcemap, tipos (strict), testes Lune. Tem que dar `ALL GREEN`.
   (`lune run scripts/format` corrige formatação.)
3. Confirmar o sync no Studio (skill `script-sync`, ou ler o `Source` via `execute_luau` Edit).
4. Playtest via MCP (skill `roblox-playtest`): `start_stop_play` -> `get_console_output`
   -> testes via `execute_luau` (Server) -> `screen_capture` se houver UI -> parar o play.
5. Ler o console: zero erros e zero warnings inesperados.
6. Corrigir e repetir.
7. Commit pequeno e descritivo (`git add` + `git commit`). Não faça push.

## Regras

- **Nunca edite no Studio um script sincronizado** (nem via `multi_edit`). Edite o arquivo.
- **Servidor autoritativo**: o cliente só pede; todo remote passa por `ServerNet` com `Guard` em
  todos os argumentos e rate limit. Remotes só existem em `Shared/Net/Remotes.luau` (DEFINITIONS).
- **Nada de segredos** no código/repo (chaves, tokens, cookies). Use Secrets do Roblox (servidor).
- **Sempre passe `studio_id`** nas ferramentas do MCP (pegue com `list_roblox_studios`).
- **Economize contexto**: filtre `search_game_tree` por caminho e profundidade; ignore CoreGui e CoreScripts.
  Se as ferramentas de busca voltarem só um resumo de uma linha, use `execute_luau` retornando JSON
  (receita na skill `roblox-playtest`).
- `execute_luau` em `Edit` altera a place: use para leitura. Testes rodam em `Server` durante o Play.
- Não rode `rojo serve` (conflita com o Script Sync). Não use `generate_*`/`insert_asset`/`upload_image`
  sem pedido explícito. Não publique nada, não mexa no Creator Hub nem em monetização.
- Um bootstrap por lado. Novo código = novo Service/Controller registrado na lista do `Main`.
- Nunca `.client.luau` em `StarterPlayerScripts`/`StarterCharacterScripts` (roda duas vezes).
- UI é construída por código (Controllers + `UI/Create`), nunca montada à mão no Studio.
- Mudou o formato de `PlayerData`? Suba `Config.Data.SchemaVersion` e migre em `PlayerDataSchema`.

## Convenções de código (resumo; detalhes na skill `luau-conventions`)

`--!strict` em todo arquivo; StyLua (tabs, 120 col); identificadores em inglês, comentários em PT-BR,
logs em inglês via `Logger`; requires por string (`./`, `../` na mesma árvore; `@game/...` entre serviços);
módulos puros (sem `game`/`task`) com testes em `Tests/Specs`.

## Comandos úteis

| Comando | O que faz |
| --- | --- |
| `lune run scripts/check` | tudo que precisa estar verde antes do commit |
| `lune run scripts/test` | só os testes puros (Lune) |
| `lune run scripts/format` | aplica StyLua |
| `lune run scripts/sourcemap` | regenera `sourcemap.json` |
| `lune run scripts/build` | `build/Test.rbxlx` (mundo + código), descartável |
| `lune run scripts/build dev` | `places/Dev.rbxlx` (só mundo); não sobrescreve sem `--force` |
| `rokit install` | instala a toolchain fixada em `rokit.toml` |

Testes no Studio (MCP, `execute_luau`, `datamodel_type = "Server"`, com Play rodando):
`return require(game:GetService("ServerScriptService").Tests.Run)()`
