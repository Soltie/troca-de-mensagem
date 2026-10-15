# SETUP_REPORT — estado do ambiente

Atualizado: 2026-10-15. Máquina: Windows 11, PowerShell 5.1 / Git Bash. Projeto: `C:\Users\xpg\Documents\roblox-teste`.

## Estado atual / próximo passo

**Estado:** ambiente **pronto e verificado de ponta a ponta**. Toolchain fixada, template funcionando,
`scripts/check` verde, MCP e Script Sync verificados no Studio, playtest automatizado verde (43 testes no Studio).
Nenhuma mecânica de jogo implementada.

**Próximo passo:** receber a ideia do jogo — preencher `docs/GAME_SPEC.md` (ou descrever ao agente) e
implementar fase por fase seguindo o loop do `CLAUDE.md`.

Para retomar numa sessão nova: *"Leia docs/SETUP_REPORT.md e continue a partir de 'Estado atual / próximo passo'."*

Pendências opcionais (decisão do humano): repositório remoto + push; publicar a experiência e ligar acesso às APIs
para testar DataStore real; decidir sobre `AGENTS.md`/`.agents/` (ver "Problemas encontrados").

## Toolchain (fixada em `rokit.toml`)

| Ferramenta | Versão | Origem |
| --- | --- | --- |
| Rokit | 1.2.0 | winget `Rojo.Rokit` (GitHub Releases oficial) |
| Rojo | 7.7.1 | Rokit |
| selene | 0.32.0 | Rokit |
| StyLua | 2.5.2 | Rokit |
| luau-lsp (CLI) | 1.70.1 | Rokit |
| Lune | 0.10.5 | Rokit |
| Git | 2.55.0 | já instalado |
| Claude Code (CLI) | 2.1.295 | app Claude (desktop) |
| Roblox Studio | `version-4f087c32742644ab` (instalado pelo humano) | roblox.com |

MCP: `Roblox_Studio` → `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` (em `~/.claude.json`, escopo usuário).
O `mcp.bat` é criado pelo Studio quando se liga "Enable Studio as MCP server" e aponta para o `StudioMCP.exe`
da versão instalada (com fallback pelo registro).

## Evidências

### Checks locais (`lune run scripts/check`)
```
[check 1/5] format (stylua --check)          -> ok
[check 2/5] lint (selene)  0 errors 0 warnings -> ok
[check 3/5] sourcemap (rojo)                 -> ok
[check 4/5] types (luau-lsp analyze, strict) -> ok
[check 5/5] tests  [Tests] 40 passed, 0 failed, 1 skipped specs -> ok
[check] ALL GREEN
```
O spec pulado no Lune é `Remotes` (`robloxOnly`), que roda no Studio.
Teste negativo: um spec com `expect(1).toBe(2)` sai como `FAIL ... expected 2, got 1` (o runner não engole falhas).

### Builds (`rojo build`)
```
lune run scripts/build      -> build/Test.rbxlx (mundo + código; Main cliente RunContext=2, servidor RunContext=1)
lune run scripts/build dev  -> places/Dev.rbxlx (0 scripts; Baseplate + SpawnLocation)
lune run scripts/build dev  -> recusa sobrescrever (exit 1), como esperado
```

### MCP
```
list_roblox_studios -> {"id":"cac08fd1-...","name":"Dev.rbxlx"}
get_studio_state    -> Mode: Edit / (no play) Mode: Play, DataModels: Client, Server
search_game_tree(Edit, path=Workspace, depth 1) -> Baseplate (Part), SpawnLocation, Terrain, Camera
```
`search_game_tree` devolveu JSON completo: o bug do "resumo de uma linha" não aconteceu nesta versão.
O contorno com `execute_luau` continua documentado na skill `roblox-playtest`.

### Script Sync
```
GetStatus: ServerScriptService = SyncedAsRoot (22 descendants) | ReplicatedStorage = SyncedAsRoot (19 descendants)
GetSyncedInstance(src\ReplicatedStorage\Client\Main.client.luau) -> ReplicatedStorage.Client.Main (Script, RunContext=Client)
criar  src/ServerScriptService/SyncProbe.luau -> ModuleScript, SyncedAsDescendant, Source = "probe-v1"
editar (v1 -> v2)                               -> has v2=true | has v1=false
apagar                                          -> SyncProbe presente=false | filhos=Server,Tests
editar HudController.luau (ReplicatedStorage)   -> sync da edição chegou=true
```
Nada do runtime vazou para o disco durante o play (a pasta `Remotes`, criada em runtime, não virou arquivo).

### Playtest (via MCP)
Console do servidor e do cliente (filtrado por `LogService`, sem CoreScripts):
```
server: [PlayerDataService] mode=mock (place not published (GameId = 0))
server: [Server] boot OK (2 services)
server: [PlayerDataService] loaded XISPEGE (mode=mock, sessions=1)
server: [PingService] ping from XISPEGE: "hello"
client: [Client] boot OK (2 controllers)
client: [PingController] ping OK: "hello" in 582 ms (dataMode=mock, sessions=1)
```
Nenhum `MessageWarning`/`MessageError` do nosso código. Só aparece ruído da própria Roblox:
`[Roblox][CorePackages...UIBlox] FoundationProvider not found` (CoreScripts; ignorar).

Testes no Studio (`execute_luau`, Server): `[Tests] 43 passed, 0 failed, 0 skipped specs`.

HUD (`screen_capture` + leitura no Client): `PlayerGui.DebugHud.Info` = `"DEBUG HUD\nping: 582 ms\ndata: mock (sessions: 1)"`.
Na 1ª captura ele cobria a dica do chat (canto superior esquerdo). Movi para o topo central e repeti o ciclo
editar → check → sync → play: posição (504, 8), sem sobreposição.

Segurança de rede (cliente malicioso via `execute_luau` Client):
```
number arg  -> invalid_arguments    | extra args -> invalid_arguments | string 65 chars -> invalid_arguments
flood x8    -> ok,ok,rate_limited,rate_limited,rate_limited,rate_limited,rate_limited,rate_limited
```
O desligamento (BindToClose) não deixou save pendente. O play foi parado no fim.

## Problemas encontrados e contornos

- `winget install Roblox.RobloxStudio` falhou: hash do instalador diferente do manifesto. A instalação ficou com o humano.
- `claude mcp add` via Git Bash converte `/c` em `C:/`: use `MSYS_NO_PATHCONV=1`. A config final é igual ao JSON da doc oficial.
- O luau-lsp (solver novo) exige anotações em alguns pontos: listas de módulos em `Main` tipadas como `{ any }`
  (o Loader valida em runtime), casts em `pcall` de funções sem retorno e literais mistos anotados.
- O primeiro "Sync to" do ReplicatedStorage apontou para `src\ReplicatedStorage`, e o Studio criou
  `src\ReplicatedStorage\ReplicatedStorage\` vazio. Foi refeito apontando para `src`; a pasta vazia foi removida.
  `MANUAL_STEPS.md` agora explica isso.
- Apareceram `AGENTS.md` e `.agents/skills/` (14/10 23:55), cópias **únicas** e idênticas do `CLAUDE.md` e das skills
  (não são espelho: não acompanham edições). A origem provável é a integração de agentes do Assistant do Studio;
  não foi o agente desta sessão. Não versionei nem apaguei: ficaram em `.git/info/exclude` (exclusão só local).
  Recomendação: apagar, ou trocar o `AGENTS.md` por um ponteiro para o `CLAUDE.md`.
- Ruído de CoreScripts no console (UIBlox FoundationProvider): não é do projeto. A skill `roblox-playtest` mostra
  como filtrar via `LogService`.

## Histórico

- 2026-10-14: ambiente e template criados (sessão inicial); checkpoint humano.
- 2026-10-15: MCP, Script Sync e playtest verificados no Studio; HUD movido para o topo central.
