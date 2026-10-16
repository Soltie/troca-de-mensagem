# Decisões

## Ala norte modular por rodada — 16/10/2026

- **Escolha:** acrescentar nove salas de 28×28, duas entradas pelo núcleo, funções permutadas,
  equipamentos por cantos e paredes/passagens sorteadas por seed + estágio. O núcleo, pátio e
  saída são referências estáveis; a maioria dos objetivos explora a ala nova.
- **Por quê:** variar o espaço físico sem invalidar as interações solo, o spawn e a extração.
  Kruskal garante conectividade; 1–3 arestas adicionais dão circuitos. Sinalização de retorno
  segue busca em largura real, nunca uma direção que cruza parede fechada.
- **Limites:** geração reconstruída entre estágios, com jogadores congelados e Vigia reiniciado;
  sem mover salas durante uma perseguição. Checkpoint solo conserva o sorteio. Arte continua
  limitada a 160 superfícies/360 texturas por cliente. Ver `MAP_RANDOMIZATION.md`.

## Tensão e captura por jogador — 15/10/2026

- Chase/Capture globais não representam ataque a toda a equipe: publicar alvo no servidor e
  filtrar pelo UserId/status local; derrubados/evacuados/aguardando não recebem eventos de jogo ativo.
- Captura de apresentação tem duração limitada e restaura câmera, sem impedir resgate/continuação.
- Eventos locais têm geração de cancelamento. Props usam clones sem colisão; deslocamento retorna
  após 1,2 s, em vez de acumular até Intro. Isso evita divergência visual prolongada do collider real.
- Faixas coloridas são aproximação de glitch/chroma; Roblox não fornece shader de tela próprio aqui.
  Não há dessaturação de ferimento, porque não existe esse estado. Opções desativam os efeitos respectivos.
- Expor sete opções já executáveis; haptics não é apresentado como funcional antes de ter executor.
- Separar testes puros, simulação de clientes e playtest humano. Limites em `TERROR_POLISH_PROGRESS.md`.

## Campanha cooperativa — 15/10/2026

- **Um runtime por modo:** RoundService delega para CampaignRuntime ou executa o solo; impede
  registros duplicados de remotes e dois sistemas controlando fase/captura/spawn.
- **Cooperação 3–8:** captura individual com resgate; eliminação aguarda o próximo estágio;
  extração coletiva; reinício por maioria; entrada tardia não altera puzzles em andamento.
- **Randomização determinística:** mesma seed/estágio/grupo reproduz atividades, sequências e
  atalhos fechados. A espinha de circulação nunca é removida. Não é geração de prédios arbitrários.
- **Três estágios no mapa existente:** Reconexão, Sincronização e Evacuação. Novos cenários completos
  ficam no roadmap. Vigia é o único NPC; Eco/Apagão são eventos ambientais nesta versão.
- **Especialidades sem dependência obrigatória:** Técnico, Socorrista, Batedor e Operador são bônus;
  o último sobrevivente consegue completar relés, evitando softlock após desconexão/captura.
- **Separar missão solo da campanha:** trancas e prompts de itens legados não podem bloquear o
  grafo da campanha; conservados no modo solo. Os estágios usam estações próprias.
- **Spawn estável:** vagas fixas, espera separada, contagem reiniciada em nova entrada e barreira
  de personagens prontos. Corrige a sobreposição descoberta com oito clientes reais no Studio.
- **Sem persistência nova:** seed, progresso, votos e membros duram somente a sessão.

Evidências e limites: [COOP_CAMPAIGN.md](COOP_CAMPAIGN.md), [COOP_QA.md](COOP_QA.md).

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

---

# Decisões do protótipo SUBESTAÇÃO 9 (2026-10-15)

## D19. Mundo gerado por código no boot do servidor
- **Alternativas:** construir o mapa na place (Studio) e salvar o `.rbxlx`; modelos `.model.json` via `rojo build`.
- **Por quê:** a place não é versionada e o Script Sync só leva scripts. Gerar o mapa por código
  (`Server/World/Layout.luau` → `MapBuilder.luau`) deixa o repositório como fonte da verdade: apagar
  `Workspace.Substation9` e rodar de novo recria tudo (838 peças em ~10 ms). O `Baseplate`/`SpawnLocation`
  do template são removidos em runtime (`WorldService`).

## D20. Vigia: corpo invisível cinemático no servidor + visual em stop-motion no cliente
- **Alternativas:** NPC com Humanoid e animações; visual animado no servidor.
- **Por quê:** a peça `Root` ancorada e movida por CFrame ao longo dos waypoints do PathfindingService
  é previsível (sem física, sem travar em quinas) e autoritativa para captura. O cliente monta o corpo
  low poly e só o atualiza **em passos**: posição a 12 Hz e poses-chave a 3–12 poses/s, sem interpolação.
  Assim a animação é "travada" de propósito, mas a simulação, a colisão e os controles continuam a 60 Hz.
  O cérebro (`Server/Game/CreatureBrain.luau`) é puro e testado no Lune.

## D21. Interação "mirar + E" com validação completa no servidor
- **Alternativas:** `ProximityPrompt`.
- **Por quê:** fica coerente com o survival horror de PS1 e passa pelo registro central de remotes
  (`Interact`) + `ServerNet` (Guard + rate limit). O servidor revalida a fase, a existência, o estado
  habilitado, a distância (com folga de latência), a linha de visão e se a ação é possível
  (`RoundRules.validateInteraction`, testado).

## D22. Primeira pessoa travada definida no cliente
- **Alternativas:** só `Player.CameraMode` no servidor.
- **Por quê:** testado: o valor definido no servidor não chegou ao cliente (continuou Classic/zoom 400).
  Agora o cliente define `CameraMode`/zoom, e o servidor também ajusta `StarterPlayer`.

## D23. Mecânica central: a lanterna é faca de dois gumes
- **Por quê:** dá escolhas sem ampliar o escopo. A lanterna ligada aumenta o alcance de visão do Vigia
  (30 → 55 studs); correr faz barulho (o servidor mede pela velocidade, sem confiar no cliente);
  pegar e encaixar fusíveis também faz barulho. A partir do 2º fusível ele "fareja" a posição aproximada
  do jogador; com a energia de volta, caça.

## D24. "Retrô" com o que o Roblox realmente oferece
- **Validado:** não existe shader nem pixelização da render. `Lighting.Technology` e
  `MaterialService.Use2022Materials` não são acessíveis por script (testado via MCP).
- **Escolha:**
  - Névoa clássica (`Fog*`, sem `Atmosphere`) um pouco **mais clara que os objetos**, para recortar silhuetas.
  - `GlobalShadows = false` (luz chapada, sem sombras).
  - Cores sólidas com paleta curta e pisos em xadrez.
  - Gradação de cor + bloom.
  - Sobreposição 2D com scanlines, vinheta, granulação a 12 quadros/s e linha de tracking (liga/desliga com V).
  - Fonte pixel `Arcade`.
  - Animações em passos: Vigia, portas (4 quadros), portão (6 quadros), luzes piscando a 12 Hz,
    texto da intro e sprite de 2 quadros no susto.

## D25. Acentos na fonte pixel
- **Validado:** `Arcade` desenha só Ã e Ç maiúsculos; É/Í/Ó/Ú saem minúsculos.
- **Escolha:** `PixelText.normalize` remove esses acentos em textos de UI/placas (como em muitos jogos
  de PS1). Os bilhetes usam `SpecialElite` e mantêm a acentuação completa.

## D26. Regiões de porta "atravessáveis" no grupo de colisão NavOnly
- **Validado:** `PathfindingModifier.PassThrough` só funciona se a peça da região tiver `CanQuery = true`.
- **Escolha:** região com `CanQuery = true`, no grupo `NavOnly`, que não colide com `Default`. Assim os
  raycasts de visão e interação continuam ignorando a peça invisível. O Vigia planeja passar pela porta
  fechada e a arromba ao chegar.

## D27. Corredor sem obstáculos e agente do Vigia com raio 1,3
- **Validado pelo teste `Navigation`:** banco, cadeira caída e armários estreitavam o corredor para
  ~5 studs; com voxels de 4 studs, a rota do agente maior fechava. O corredor (artéria principal) ficou
  só com decoração sem colisão, e o agente usa raio 1,3 / altura 7,6 (`Config.Creature`).

## D28. Ponte de debug só no Studio (`ServerStorage.DebugBridge`)
- **Validado:** o `execute_luau` do MCP roda em outra VM; `require` lá cria uma cópia nova dos módulos e
  não enxerga o estado do jogo. Uma `BindableFunction` (criada só se `RunService:IsStudio()`) dá acesso a
  `state`, `awaken`, `freezeCreature`, `placeCreature`, `teleport` e `restart`.

## D29. Estado da rodada por atributos (`ReplicatedStorage.GameState`)
- **Alternativas:** RemoteEvents servidor → cliente.
- **Por quê:** atributos são sempre o estado atual (sem corrida ao entrar) e a UI só observa. Remotes
  ficam só para pedidos do cliente (`Interact`, `SetFlashlight`, `RequestRestart`).

## D30. Áudio: bibliotecas licenciadas + filtro "lo-fi"
- **Por quê:** Pro Sound Effects / APM Music (parceiras da Roblox) evitam uploads de origem incerta.
  Todos os sons do cliente e do mundo passam por um `SoundGroup` com EQ cortando agudos e reverb de
  corredor de pedra, para soar como hardware antigo. Detalhes em `docs/ASSETS.md`.

## D32. Interações compartilhadas e espectador sem câmera livre (15/10/2026)
- **Escolha:** apresentação das interações em InteractionUi; somente membros Active interagem.
  Waiting/Escaped acompanham colegas Active pelo CameraController, com seleção determinística;
  Downed mantém a própria visão enquanto pode ser resgatado. Nenhum novo remote.
- **Alternativas:** câmera livre, permitir interações ao espectador ou reativar armários solo no coop.
- **Por quê:** reduzir espera sem permitir ações após eliminação nem mudar as regras da campanha.
  Armários/portas solo recebem polish, mas a adaptação de ocupação ao coop continua separada.
  Menu O usa ContextActionService com prioridade alta porque a câmera padrão consome a tecla.

## D33. Arte industrial por código com texturas locais limitadas (16/10/2026)
- **Escolha:** cinco máscaras autorais RGBA 32×32 em EditableImage/Texture, 160 peças/360 faces
  como teto; fallback de materiais nativos. Props e detalhes de uniforme são primitivas versionadas.
- **Alternativas:** importar modelos do Creator Store, gerar/publicar assets ou usar apenas cor sólida.
- **Por quê:** manter proveniência, estilo retrô e reconstrução pelo repositório sem uploads; dar
  textura e identidade ao cenário com custo previsível. Decoração não participa de colisão/raycast.
  CRT/poeira usam distância; faíscas respeitam conforto. Renderer e QA humano são evidências separadas.

## D31. Rosto do Ademir (outra sessão)
- **Contexto:** o humano pediu, em outra sessão de agente, para usar uma foto como rosto do Vigia.
  A integração (`AdemirPortrait.luau`, `EditableImage` local com fallback) foi preservada sem mudanças
  e versionada separadamente. Antes de publicar, confirmar o consentimento da pessoa e as permissões
  de `EditableImage`.

## D34. Monetização só cosmética, com duas moedas (16/10/2026)
- **Escolha:**
  - **Fichas** (ganhas jogando, nunca vendidas) e **Créditos** (Robux).
  - Lojas de lanternas, fardas, filtros e títulos.
  - Baú grátis (Fichas) e baú pago (Créditos).
  - Roleta e calendário diários, níveis, fitas colecionáveis, Passe VIP e Pacote Inicial.
- **Alternativas:** vender revives, baterias ou velocidade (vantagem contra o Vigia); moeda única
  comprável que alimentasse todos os sorteios.
- **Por quê:**
  - Pagar por poder num coop de terror quebra o medo e a justiça entre colegas.
  - Separar a moeda ganha da paga deixa só UM sorteio pago (o Baú Lacrado) sob as regras de itens
    aleatórios pagos: chances em % antes da compra, PolicyService e alternativa de compra direta.
  - O resto é sorteio grátis, mas mostra as chances do mesmo jeito.
  - Detalhes em `docs/MONETIZATION.md`.

## D35. Trava de sessão nos dados do jogador (16/10/2026)
- **Escolha:**
  - `sessionLock = { job, at }` gravado no load por UpdateAsync.
  - O save não sobrescreve trava válida de outro servidor.
  - O autosave renova a trava; a saída a libera; TTL de 300 s.
  - Depois de 4 tentativas, o load assume a trava (servidor antigo caiu).
- **Alternativas:** ProfileStore (dependência externa/Wally) ou "último save vence" (TODO anterior).
- **Por quê:** com compras em Robux, uma reconexão rápida não pode apagar Créditos já entregues.
  O ProcessReceipt grava o recibo e a concessão no mesmo registro e salva antes de confirmar.

## D36. Recompensa e coleção sem mexer nos runtimes (16/10/2026)
- **Escolha:**
  - `RewardService` paga o fim de partida observando o estado replicado: `GameState` no solo e
    `CampaignState` na campanha (Roster, estágio).
  - As fitas VHS entram nos runtimes só por um gancho de 3 linhas (id `"tape"`).
- **Alternativas:** chamar a economia de dentro de `RoundService`/`CampaignRuntime`.
- **Por quê:**
  - Os dois runtimes têm donos diferentes (Claude e Codex) e mudam em paralelo.
  - Observar estado público evita acoplamento e funciona nos dois modos.
  - A fita dá a recompensa à equipe toda: cooperação, não disputa.

## D-SEASON. Temporada e telemetria autoritativas (16/10/2026)
- Escolha: XP separado, 30 níveis, recompensas automáticas marcadas por trilha e temporada; Game Pass por temporada.
- Alternativas: resgate manual, XP comprado ou reaproveitar VIP como passe.
- Motivo: entrega retroativa idempotente, sem vantagem de gameplay e sem confundir os dois passes.
- Analytics registra gasto bruto e reembolso separadamente, inclusive níveis da conta e recompensas da temporada.
  Eventos em Studio ficam em memória; falha de envio não bloqueia o jogo. Compras reais/painel aguardam QA próprio.

## D-ANIMATION. Um compositor de câmera e animações locais (16/10/2026)
- Escolha: câmera cinema no CameraController, cenas canceláveis no CinematicController, overlay com tokens por camada.
  Poses de jogadores/Vigia são locais; LookPitch validado pelo servidor só comunica aparência.
- Alternativas: segundo compositor, assets de animação publicados ou cinematografia longa no início de cada combate.
- Motivo: preservar autoridade/física e evitar perda de controle durante a ação. Abertura só no lobby/intro, fuga na vitória;
  início de etapa ativa usa piscada curta. Espaço/A/botão pula a cena; movimento reduzido usa planos estáticos.
- Focus acompanha o plano e CFrame anterior é restaurado; câmera de captura/esconderijo/espectador tem prioridade.
