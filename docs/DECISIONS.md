# Decisões

Formato: **decisão** · alternativas · por quê. Fontes conferidas em 2026-10-14 (docs oficiais da Roblox,
READMEs/releases oficiais das ferramentas e docs do Claude Code).

## D1. Script Sync para o código; Rojo só para sourcemap e build
- **Alternativas:** `rojo serve` + plugin do Rojo no Studio; editar direto no Studio.
- **Por quê:** Script Sync é oficial, não precisa de plugin, retoma sozinho ao abrir a place e é o
  caminho do guia oficial "Build with a coding harness". `rojo serve` exigiria instalar plugin de terceiros
  e conectar manualmente a cada sessão; rodar os dois nas mesmas pastas causaria conflito (dois escritores).
  O Rojo continua útil para `rojo sourcemap` (luau-lsp) e `rojo build` (places).

## D2. Cliente: Script RunContext=Client em `ReplicatedStorage/Client`, não em `StarterPlayerScripts`
- **Alternativas:** `.client.luau` em StarterPlayerScripts; LocalScript (`.local.luau`) em StarterPlayerScripts.
- **Por quê:** a doc oficial "Script types and locations" recomenda um único Script Client em
  ReplicatedStorage e avisa que um Script Client em StarterPlayerScripts roda **duas vezes** (original + cópia).
  LocalScript funcionaria, mas o Rojo 7.7.1 não mapeia `.local.luau` (o sourcemap ficaria errado).
  Consequência: só **dois** serviços sincronizados (ServerScriptService e ReplicatedStorage) — um passo humano a menos.

## D3. Require por string (`./`, `../`, `@game/`) + alias `game` no `.luaurc`
- **Alternativas:** requires por instância (`require(ReplicatedStorage.Shared.X)`); aliases próprios (`@Shared`).
- **Por quê:** o Roblox suporta require por string, inclusive `@game/` (doc de `require`). O luau-lsp resolve
  `@game/` sozinho pelo sourcemap e o Lune resolve pelo alias `"game": "./src"`. Testado nos três.
  Resultado: os mesmos módulos e specs rodam no Studio e no Lune. Aliases próprios não funcionam no Roblox.

## D4. Toolchain via Rokit, instalado pelo winget; versões fixadas
- **Alternativas:** Aftman/Foreman (antecessores do Rokit); binários soltos; script de instalação remoto.
- **Por quê:** Rokit é o gerenciador atual mantido pela org rojo-rbx; `Rojo.Rokit` existe no winget (fonte oficial).
- **Política de versão:** última estável com pelo menos ~1 semana de lançamento.
  rojo 7.7.1 · selene 0.32.0 · luau-lsp 1.70.1 · **stylua 2.5.2** (2.6.0 tinha 4 dias) · **lune 0.10.5** (0.11.0 tinha 3 dias).
  Atualizar: editar `rokit.toml` (ou `rokit update`), rodar `rokit install` e `lune run scripts/check`.

## D5. Scripts de tarefa em Lune
- **Alternativas:** PowerShell/Bash; npm scripts.
- **Por quê:** Luau em todo lugar, multiplataforma (Windows/macOS), sem Node. O próprio Lune roda os testes puros.

## D6. Wally: não adotado (por enquanto)
- **Alternativas:** Wally com ProfileStore, Fusion/React-lua, TestEZ etc.
- **Por quê:** nenhum pacote é necessário para a fundação; zero dependências = menos superfície e menos
  sincronização. Wally está sem release desde 2023. Se o jogo precisar: `wally.toml`, pacotes em
  `src/ReplicatedStorage/Packages` (gitignored, entram pelo Script Sync), validar sourcemap e sync antes.

## D7. UI em Luau puro (`Client/UI/Create.luau`)
- **Alternativas:** Fusion, React-lua (via Wally).
- **Por quê:** prova o padrão "UI vive no repositório" sem dependências. Trocar por lib declarativa
  quando a UI do jogo justificar (decisão a registrar aqui).

## D8. Testes com TestKit próprio
- **Alternativas:** TestEZ (arquivado), Jest-Lua (via Wally, mais pesado).
- **Por quê:** ~150 linhas, roda igual no Studio (via MCP `execute_luau`) e no Lune, sem dependências.

## D9. MCP oficial adicionado no escopo de **usuário** (`claude mcp add --scope user`)
- **Alternativas:** `.mcp.json` no projeto; escopo local (só esta pasta); Quick Connect do Studio.
- **Por quê:** o caminho do servidor muda entre Windows e macOS, então não fica no repositório; o template
  vai ser copiado para outras pastas (escopo local se perderia); `.mcp.json` exige aprovação por projeto.
  Comandos (doc oficial): Windows `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat`;
  macOS `/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`. Ver MANUAL_STEPS.
  Quick Connect não é necessário (evita entrada duplicada).

## D10. PlayerData: wrapper próprio, mock automático, session locking como TODO
- **Alternativas:** ProfileStore (session locking pronto, via Wally); DataStore cru.
- **Por quê:** sem dependências e fácil de ler; retry + autosave + BindToClose cobrem o básico.
  Mock: só no Studio (`Config.Data.StudioMode = "auto"` testa o acesso). Ao vivo nunca usa mock e
  falha de load = kick. Studio em modo real usa store `_Studio` para não sujar dados de produção.
  Session locking documentado como TODO em ARCHITECTURE.md (implementar ou adotar ProfileStore antes de lançar).

## D11. Place de trabalho gerada pelo Rojo, não versionada
- **Alternativas:** versionar `.rbxlx`; criar a place à mão no Studio ("New Experience").
- **Por quê:** `places/Dev.rbxlx` sai de `places/Dev.project.json` só com o mundo base (sem scripts);
  o código entra pelo Script Sync ("Keep Disk"). Arquivos de place são grandes/ruidosos no git e
  duplicariam o código. O mundo base fica versionado em `places/world/*.model.json`.
  `scripts/build dev` se recusa a sobrescrever a place existente (sem `--force`).
  Quando o jogo tiver mapa feito à mão, decidir: exportar modelos para o repo ou versionar a place.

## D12. Checagem de tipos com definições Roblox fixadas
- **Alternativas:** usar sempre a definição mais nova (`main`); só VS Code.
- **Por quê:** `scripts/check` baixa `globalTypes.None.d.luau` do repositório oficial do luau-lsp **na mesma
  tag** fixada no `rokit.toml` (reprodutível) e guarda em `.cache/`. Nível de segurança `None` = o que
  scripts de jogo podem usar.

## D13. Rede: envelope `Result` e ServerNet obrigatório
- **Alternativas:** handlers diretos em `OnServerInvoke`; erros lançados para o cliente.
- **Por quê:** cliente sempre recebe `{ok, data | error}` previsível; validação, rate limit e `pcall`
  ficam num lugar só, impossível esquecer.

## D14. CI no GitHub Actions: não criado agora
- **Por quê:** não há repositório remoto (push é decisão do humano) e não daria para testar o workflow.
  Quando houver: job com `rokit install` + `lune run scripts/check` (sem Roblox).

## D15. Allowlist do Claude Code (`.claude/settings.json`)
- **Liberado:** ferramentas de leitura/execução/playtest do MCP (listadas uma a uma), `lune run scripts/*`,
  rojo sourcemap/build, selene, stylua, luau-lsp analyze, git status/diff/log/show/add/commit.
- **Sempre pergunta (`ask`):** `generate_*`, `insert_asset`, `upload_image`, `store_image`, `rojo serve`,
  `git push/reset/clean/checkout --`, `rm -rf`, `Remove-Item -Recurse`.

## D16. Idioma
- Identificadores em inglês; comentários e docs em PT-BR; mensagens de log/erro em inglês (estáveis para
  o agente procurar no console, ex.: `[Server] boot OK`).

## D17. Logger com closures (`log.info(...)`) em vez de métodos (`log:info(...)`)
- **Por quê:** tipagem strict mais simples e sem armadilha de `.` vs `:`.

## D18. Roblox Studio instalado pelo humano
- **Contexto:** `winget install Roblox.RobloxStudio` falhou (hash do instalador no manifesto do winget
  desatualizado em relação ao instalador atual da Roblox). Não contornamos a verificação de hash.
