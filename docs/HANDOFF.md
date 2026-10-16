# HANDOFF — SUBESTAÇÃO 9 (protótipo de terror)

**Polish visual — 16/10/2026:** texturas autorais, materiais, props/cenário e acabamento do Vigia,
CRTs/indicadores/poeira/faíscas. Check 151 testes, Studio 162 aprovados. Capturas comparáveis e
limites de desempenho em [VISUAL_POLISH.md](VISUAL_POLISH.md). Nenhuma colisão/rota nova.
Integração com a frente do Claude (`9e3931e`): 163 aprovados / 1 falha no teste novo do duto;
NOT READY para declarar essa integração totalmente verde. Arte isolada validada; recibos no relatório.

**Continuação vigente — interações/espectador (15–16/10/2026):** destaque e feedback de itens/puzzles,
armário solo, espectador coop e correção de O implementados. 148 testes locais/156 Studio aprovados;
QA dirigido validou eliminação, setas, entrada tardia, desconexão e retorno após respawn.
Leia [INTERACTION_SPECTATOR_PROGRESS.md](INTERACTION_SPECTATOR_PROGRESS.md) para recibos,
limites visuais e resultado da regressão com oito clientes (Won, estágio 3, 125 verificações).
Código `a09113a`; campanha ativada, Studio em Edit e sem reservas.

**Última entrega — terror:** commits `ca18f17`/`fab121c`: diretor de tensão, efeitos de medo,
captura individual e conforto. 142 testes Lune/150 Studio; QA pessoal com três clientes e
regressão da campanha com oito aprovados. Leia [TERROR_POLISH_PROGRESS.md](TERROR_POLISH_PROGRESS.md)
para evidências e pendências. Studio em Edit, sem reservas/push/publicação.

**Atualização vigente — Codex, 15/10/2026:** campanha cooperativa para 3–8 ativada em
`Config.Campaign.Enabled`, com três estágios na subestação, atividades/atalhos por seed,
quatro especialidades, resgate e extração coletiva. Integração sobre Claude `c6b247a`;
commits `68f3768`, `31f6b59`, `ca66ead`. Check: 136 testes; Studio: 144 testes;
simulações com 3 e 8 clientes aprovadas. Ainda falta playtest humano de equilíbrio/diversão.
Leia [COOP_CAMPAIGN.md](COOP_CAMPAIGN.md), [COOP_QA.md](COOP_QA.md) e
[NEXT_STEPS.md](NEXT_STEPS.md). O restante desta página descreve o protótipo solo histórico.

Atualizado: 2026-10-15. Estado: **protótipo jogável, testado de ponta a ponta no Studio**.
Atualização do mapa pelo Codex: [MAP_EXPANSION.md](MAP_EXPANSION.md), cinco áreas novas, 84 testes
Studio passando; coordenação e ressalva de integração paralela em [LEIA_CLAUDE.md](../LEIA_CLAUDE.md).
Leia também: `CLAUDE.md` (regras), `docs/GAME_SPEC.md` (design), `docs/ARCHITECTURE.md` (como funciona),
`docs/DECISIONS.md` (D19–D31 são do jogo), `docs/ASSETS.md` (origem dos assets).

## O que foi implementado

Terror atmosférico em primeira pessoa, estética PS1, rodada de ~3–10 min, um jogador, PC.
Você é o técnico do turno da noite numa subestação sem energia: encontre 3 fusíveis, encaixe-os no
quadro da Sala do Gerador e fuja pelo portão elétrico, enquanto **O Vigia** (Ademir) te caça.

- **Mapa** gerado por código (~840 peças): pátio com van, guarita, postes, cerca e portão; prédio com
  recepção, escritório, sala de bombas, corredor, sala do gerador e depósito. Placas, bilhetes e pichação.
- **Jogador:** 1ª pessoa travada, corrida com fôlego, lanterna e interação "mire + E".
- **Objetivo:** fusíveis (2 posições sorteadas por sala) → quadro → energia → portão → saída.
  Progresso visível na UI.
- **O Vigia:** patrulha → investiga barulho → procura → persegue → captura.
  - Lanterna ligada aumenta o alcance de visão dele; correr faz barulho.
  - Fica mais rápido a cada fusível, "fareja" a partir do 2º e caça quando a energia volta.
  - Arromba portas fechadas.
  - Visual em stop-motion: posição a 12 Hz, poses a 3–12 poses/s.
- **Rodada:** intro (cartela), escalada (despertar, faro, caça), vitória ou derrota (jumpscare em sprite
  de 2 quadros) e reinício completo com R ou botão.
- **Arte e áudio:**
  - Luz e cor: névoa que recorta silhuetas, luz chapada sem sombras, emergência vermelha, gradação de cor.
  - Efeitos: sobreposição retrô e luzes piscando em passos.
  - Áudio: 16 áudios licenciados (PSE/APM) + 2 do cliente Roblox, com filtro "lo-fi".
- **Conforto:** V liga/desliga o filtro retrô; B liga/desliga o balanço e o tremor de câmera
  (e os flashes do susto).

Principais arquivos: `src/ServerScriptService/Server/{World,Game,Services}`,
`src/ReplicatedStorage/{Shared/Game,Client/Controllers,Client/Creature}` (mapa completo no `CLAUDE.md`).

## Como abrir, jogar e reiniciar

1. Studio → abrir `places/Dev.rbxlx` (o Script Sync retoma sozinho; se houver conflito: **Keep Disk**).
2. **Play** (F5). A intro dura 9 s.
3. Controles:

   | Tecla | Ação |
   | --- | --- |
   | WASD + mouse | andar e olhar |
   | Shift | correr (fôlego) |
   | F | lanterna |
   | E | interagir (mire no objeto); escondido: sair do armário |
   | Q | entreabrir/fechar porta |
   | C / Ctrl | agachar (alterna / segura) |
   | Espaço | escondido: prender a respiração |
   | Tab | inventário (segurar) |
   | L | **loja** (fora da ação: intro, intervalo, telas finais, esperando) |
   | O | opções de conforto (1–8) |
   | C / R | telas finais: continuar do checkpoint / reiniciar tudo |
   | V | filtro retrô |
   | B | movimento de câmera |
   | H | ajuda |
   | F3 | debug (FPS, estado) |

   Loja, progressão e compras: `docs/MONETIZATION.md`.

4. Reiniciar: R ou o botão "[R] JOGAR DE NOVO" nas telas finais (sem parar o Play).
5. Recriar a place do zero, se precisar: `lune run scripts/build dev --force`, abrir e refazer o Script Sync
   (ver `docs/MANUAL_STEPS.md`). O mundo do jogo vem do código, então a place só precisa estar vazia.

## Decisões técnicas e de arte (resumo)

- Repositório = fonte da verdade: mundo, luz, UI e criatura são construídos por código; áudio por ID.
- O servidor é autoritativo para fase, itens, portas, portão, energia, captura e vitória. Cada
  interação é revalidada (fase, existência, distância, linha de visão, possibilidade).
- Vigia: corpo invisível cinemático no servidor (pathfinding) e corpo visível em stop-motion no cliente.
- O "retrô" sai do que o Roblox oferece de verdade (sem shader nem pixelização): paleta curta, névoa
  clássica, `GlobalShadows` desligado, fonte pixel, sobreposição 2D e animação em passos.
- Detalhes e alternativas: `docs/DECISIONS.md` D19–D31.

## Assets

Sem modelos de terceiros nem `generate_*`. Áudio: Pro Sound Effects e APM Music (licenciados pela
Roblox, gratuitos), mais sons do cliente Roblox. Rosto do Vigia: foto fornecida pelo humano (integrada por
outra sessão), textura local via EditableImage. Lista completa com IDs e uso: `docs/ASSETS.md`.

## Testes realizados e resultados (2026-10-15)

- `lune run scripts/check`: **ALL GREEN**. Testes puros: **73 passed** (objetivos, regras, cérebro,
  layout, paredes, texto pixel, utilitários).
- Studio `Tests.Run`: **79 passed, 0 failed**. Inclui `Navigation`: rotas reais para o jogador e o Vigia
  até todas as salas, pontos dos fusíveis, bilhetes, quadro e portão, e rota de patrulha completa.
- **Rodada pelo caminho normal** (MCP: `character_navigation` + câmera apontada + tecla E):
  - portão sem energia recusado ("SEM ENERGIA");
  - 3 fusíveis pegos com E, com a porta do escritório aberta com E no caminho;
  - porta do gerador aberta e quadro → energia (17 luzes, zumbido, status verde, quadro desabilitado);
  - portão aberto → saída → **Won** em 01:54; tela de vitória com tempo e 3/3;
  - **R** restaurou fusíveis, portas, quadro, portão, luzes, criatura e fase.
- Validação no servidor: o mesmo fusível pedido 2× → `not_available`; objetos distantes → `too_far`;
  argumentos inválidos e flood → `invalid_arguments`/`rate_limited`.
- **Vigia ativo:**
  - investigou o barulho do 1º fusível, achou o jogador parado e capturou (uma vez só);
  - em teste dirigido: Patrol → Chase (0,2 s) → Capture (0,4 s) → Lost, com 1 captura no log;
  - de costas a 10 studs, não percebeu (correto).
- **Console:** 0 warnings/erros do projeto no servidor e no cliente. O único ruído é
  `FoundationProvider` dos CorePackages da Roblox.
- **Uma rodada completa também foi vencida em sessão compartilhada** (log `power restored` →
  `Playing -> Won`) por outra pessoa ou agente jogando no mesmo Studio.

### Desempenho

Medido no Studio (janela 1193×793, qualidade gráfica Automatic, 836 primitivas, 7 luzes acesas sem
energia / 17 com energia):

- Custo por quadro: **render CPU 7,4 ms, GPU 0,3 ms, scripts (Heartbeat) 0,15 ms**, dentro dos 16,7 ms
  de 60 FPS.
- `Stats.FrameTime` ficou em **66,7 ms constantes (15 FPS)** durante a automação. Esse valor fixo é o
  limite do Studio para janela em segundo plano, não custo do jogo. Uma leitura pontual com a janela
  ativa deu 17,7 ms (~56 FPS).
- **Não medido:** FPS com a janela do Studio em foco por um período longo nem num cliente publicado.

## Problemas conhecidos e partes não verificadas

- A rodada completa pelo caminho normal foi feita com o Vigia **congelado** (a automação via MCP é lenta
  demais para fugir). Perseguição e captura foram validadas separadamente. Fugir de verdade do Vigia é
  teste humano: o equilíbrio de velocidades e distâncias (`Config.Creature`) não foi afinado com jogadores.
- O mouse simulado do MCP não gira a câmera travada; a mira automatizada aponta a câmera por código.
  Com o mouse real isso não se aplica.
- Teclado/mouse apenas. Mobile e gamepad não foram testados (a interação é por tecla E).
- `EditableImage` (rosto) funciona no Studio. Numa experiência publicada exige habilitação específica,
  e a foto é de uma pessoa real: confirmar consentimento antes de publicar.
- O balanço de áudio foi verificado por estado (`IsPlaying`, volumes), não ouvido por um humano.
- Durante o desenvolvimento, outra sessão de agente trabalhou no mesmo Studio e nos mesmos arquivos
  (rosto do Ademir, docs de equipe). As mudanças foram preservadas e versionadas separadamente.

## Próximos passos recomendados

1. Playtest humano focado em equilíbrio: velocidade do Vigia, fôlego, alcance com e sem lanterna.
   Ajustar só em `Config`.
2. Esconderijos (armários) ou quebra de linha de visão mais legível, se as fugas estiverem difíceis.
3. Feedback de "fui visto" mais claro: ruído na tela ou stinger curto no evento `spotted`, que o cérebro
   já emite.
4. Áudio posicional de passos do jogador por material e reverb por sala.
5. Mais variação: posições extras de fusíveis e rota de patrulha alternativa por rodada.
6. Suporte a gamepad (E → ButtonX, F → ButtonY) e checagem em resoluções menores.

## Duas frentes recuperadas — 16/10/2026
Animações/transições e analytics/temporada concluídos nos commits be50b06 e 1602f3d. Relatório e critérios verificados: docs/TWO_CHATS_RESUME.md. Sem push/publicação. QA de compras reais, mobile/FPS e integração visual com menu de história continua separado.
