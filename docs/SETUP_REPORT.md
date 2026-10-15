# SETUP_REPORT — estado do ambiente

Atualizado: 2026-10-14. Máquina: Windows 11, PowerShell 5.1 / Git Bash. Projeto: `C:\Users\xpg\Documents\roblox-teste`.

## Estado atual / próximo passo

**Estado:** repositório, toolchain, template, testes Lune, docs e allowlist prontos e commitados.
MCP oficial registrado no Claude Code (escopo usuário). Roblox Studio instalado e logado pelo humano.
**Falta:** passos humanos 1–6 de `docs/MANUAL_STEPS.md` e, depois, a verificação no Studio (seção 7 da missão).

**Próximo passo (agente):** quando o humano disser "feito":
1. Conferir `Test-Path "$env:LOCALAPPDATA\Roblox\mcp.bat"` e se as ferramentas `mcp__Roblox_Studio__*` existem.
2. `list_roblox_studios` → `studio_id`; ler o Workspace (Baseplate, SpawnLocation).
3. Script Sync: `GetStatus` dos dois serviços; criar `src/ServerScriptService/SyncProbe.server.luau`,
   editar, conferir no Studio, apagar e conferir que sumiu.
4. Playtest: boot OK servidor/cliente, ping, PlayerData mock, HUD (`screen_capture`), testes via `execute_luau`
   (Server), console limpo, parar o play.
5. Registrar evidências abaixo, remover temporários, commit, working tree limpa.

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
| Roblox Studio | versão atual (instalado pelo humano) | roblox.com |

MCP: `Roblox_Studio` → `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` (em `~/.claude.json`, escopo usuário).
Observação: antes de ligar o toggle do MCP no Studio, `mcp.bat` ainda não existe (o binário `StudioMCP.exe`
já está na pasta de versão do Studio).

## Evidências

### Checks locais (`lune run scripts/check`)
```
[check 1/5] format (stylua --check)        -> ok
[check 2/5] lint (selene)  0 errors 0 warnings -> ok
[check 3/5] sourcemap (rojo)               -> ok
[check 4/5] types (luau-lsp analyze, strict) -> ok
[check 5/5] tests  [Tests] 40 passed, 0 failed, 1 skipped specs -> ok
[check] ALL GREEN
```
(O spec pulado é `Remotes`, `robloxOnly`, que roda no Studio.)
Teste negativo: um spec com `expect(1).toBe(2)` é reportado como `FAIL ... expected 2, got 1` (o runner não engole falhas).

### Builds (`rojo build`)
```
lune run scripts/build      -> build/Test.rbxlx (mundo + código; Main cliente RunContext=2, servidor RunContext=1)
lune run scripts/build dev  -> places/Dev.rbxlx (0 scripts; Baseplate + SpawnLocation)
lune run scripts/build dev  -> recusa sobrescrever (exit 1), como esperado
```

### Studio / MCP / Script Sync / Playtest
Pendente (depende dos passos humanos).

## Problemas encontrados e contornos

- `winget install Roblox.RobloxStudio` falhou: hash do instalador diferente do manifesto. Instalação ficou com o humano.
- `claude mcp add` via Git Bash converte `/c` em `C:/` → usar `MSYS_NO_PATHCONV=1` (já corrigido; config final igual ao JSON da doc oficial).
- luau-lsp (solver novo) exige anotações em alguns pontos: listas de módulos em `Main` tipadas como `{ any }`
  (o Loader valida em runtime), casts em `pcall` de funções sem retorno, literais mistos anotados.

## Histórico

- 2026-10-14: ambiente e template criados (sessão inicial).
