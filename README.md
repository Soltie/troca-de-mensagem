# Roblox + Claude Code — template

Repositório-template para desenvolver jogos Roblox com agentes de IA. Ainda **não tem jogo**:
tem a fundação testada (bootstrap servidor/cliente, rede segura, dados do jogador com modo mock,
UI por código, testes, checks e documentação para agentes).

- Código em `src/`, sincronizado com o Studio pelo **Script Sync** (oficial, sem plugin).
- O agente controla o Studio pelo **MCP oficial** do Roblox Studio.
- Toolchain fixada via **Rokit**: Rojo (só sourcemap/build), selene, StyLua, luau-lsp, Lune.

## Começar

1. `rokit install` (instala as ferramentas de `rokit.toml`).
2. `lune run scripts/check` (deve terminar em `ALL GREEN`).
3. Primeira vez no Studio: siga [docs/MANUAL_STEPS.md](docs/MANUAL_STEPS.md).
4. Descreva o jogo em [docs/GAME_SPEC.md](docs/GAME_SPEC.md) e peça ao agente para implementar fase por fase.

## Documentação

| Arquivo | Para quê |
| --- | --- |
| [CLAUDE.md](CLAUDE.md) | regras e loop de trabalho para agentes |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | como o template funciona |
| [docs/DECISIONS.md](docs/DECISIONS.md) | o que foi decidido, alternativas e porquês |
| [docs/MANUAL_STEPS.md](docs/MANUAL_STEPS.md) | checklist do que só um humano faz |
| [docs/SETUP_REPORT.md](docs/SETUP_REPORT.md) | estado do ambiente, evidências e próximo passo |
| [docs/GAME_SPEC.md](docs/GAME_SPEC.md) | especificação do jogo (em branco) |

## Editor (opcional)

VS Code com as extensões recomendadas em `.vscode/extensions.json` (luau-lsp, selene, StyLua, Claude Code).
O luau-lsp gera o `sourcemap.json` sozinho a partir de `default.project.json`.
