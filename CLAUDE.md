# Tung Tung Sahur: The Cursed House (Roblox, terror leve)

Place `tungtung`, PlaceId 82955516040017. Responda em pt-BR, curto, só o que mudou.
Estado/decisões: [PROGRESSO.md](PROGRESSO.md). Referências e régua do crítico: [docs/referencias.md](docs/referencias.md).
CLAUDE.md antigo (histórico longo): `backup/CLAUDE.md`.

## Estrutura
```
src/ServerScriptService/Server/   Main.server.luau (bootstrap único), Services/, Campaign/, Game/ (regras puras), World/, Net/, Data/
src/ServerScriptService/Tests/    TestKit, Run, Specs/ (testes)
src/ReplicatedStorage/Client/     Main.client.luau (bootstrap único), Controllers/, Creature/, UI/
src/ReplicatedStorage/Shared/     Config, Net/Remotes, Game/ (catálogos, regras puras), Util
src/ReplicatedStorage/Assets/     .rbxm (TungTung etc.)
src/MaterialService/              materiais
places/world/                     mundo base (.model.json)
build/                            saídas geradas (não ler); build/arte3d = modelos Blender
docs/critica/                     prints do crítico (pode ler)
```

## Convenções
- `--!strict`; tabs, 120 col; identificadores em inglês, comentários em PT-BR, logs em inglês via `Logger`.
- Servidor autoritativo; remotes só em `Shared/Net/Remotes.luau`, via `ServerNet` com Guard + rate limit.
- Novo código = novo Service/Controller registrado no `Main`. UI por código (`UI/Create`), nunca à mão no Studio.
- Regras puras (sem `game`/`task`) em módulos com spec em `Tests/Specs`.
- Valores ajustáveis em `Shared/Config.luau`. Mudou `PlayerData`? Suba `Config.Data.SchemaVersion` e migre.
- Tung oficial = `Assets.TungTung` (`TungTung_Quebrado` está quebrado). Gasolina removida (lata = óleo do Valdemar).

## Comandos
| Comando | Uso |
| --- | --- |
| `lune run scripts/check` | format + lint + tipos + testes Lune (tem que dar ALL GREEN) |
| `lune run scripts/test` | só testes puros |
| `selene src` / `stylua --check src` | lint / formato (rodar antes de chamar o crítico) |
| `rojo sourcemap default.project.json -o sourcemap.json` | sourcemap |
| `rojo serve sync.project.json` | sincroniza scripts (ver "Rojo" abaixo) |
| `powershell scripts/upload.ps1 -Folder <pasta>` | sobe .fbx/.png para Roblox (Open Cloud), IDs em `assets_ids.md` |
| Studio (MCP, Server, com Play) | `return require(game.ServerScriptService.Tests.Run)()` |

Rojo: `default.project.json` serve só para sourcemap/build. `sync.project.json` mapeia só scripts
(`$ignoreUnknownInstances`, não apaga o resto do place). O place hoje está com Script Sync desligado e o
código foi aplicado à mão: o place tem código extra (PvP/Mansão do Codex) fora do `src`. Antes do 1º sync, comparar.

## Regras de trabalho
- Um Roblox Studio por vez. Sempre passar `studio_id` nas ferramentas do MCP.
- Nunca publicar no Roblox sem o usuário (ele clica Publish). Nunca mexer em Creator Hub/monetização.
- Assets do Toolbox: remover scripts antes de usar. SEM Mixamo: animações feitas à mão (Blender → TungTungClips).
- Nunca apagar: mover o que for substituído para `backup/` mantendo o caminho relativo. Sem git destrutivo.
- Apontar arquivo exato em vez de explorar. Juntar pedidos pequenos. Plano antes de tarefa grande.
- Testar só a cena/script alterado. Rodar selene + stylua antes de pedir o crítico.
- Agentes não conversam entre si: escrevem resultado em `.md` (`docs/roteiro.md`, `docs/puzzles_aprovados.md`...) e o próximo lê só o necessário.
- Modelos: Opus orquestra/planeja/revisa e assume se um subagente falhar 2x; Sonnet = subagente padrão;
  Haiku = tarefas simples (formatar, renomear, edições pequenas, resumos, atualizar PROGRESSO).
  Se Sonnet/Haiku insistir (~2 tentativas) e não conseguir, não esperar: o Opus faz na hora.
- No máximo 2 agentes ao mesmo tempo.
- Crítico só ao fim de cada etapa concluída; no máx. 2 rodadas por item; nota >= 8 aprova (substitui a regra antiga de 9).
- Capítulo N+1 só depois do crítico aprovar o N. Git (commit/push) é tarefa do coordenador ao fim da etapa.

## Ferramentas de economia de tokens
- **caveman** (plugin, ativo): respostas curtas; `/caveman`. Subagentes `caveman:cavecrew-*` para achar/editar/revisar.
- **graphify** (skill): `/graphify` gera `graphify-out/` (grafo do código). Consultar `/graphify query "..."` antes de explorar.
