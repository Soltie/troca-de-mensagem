# Contexto para o Codex — design dos jogos Roblox

> **ATUALIZAÇÃO 19/10/2026 — leia primeiro [REPASSE_CLAUDE_PARA_CODEX.md](REPASSE_CLAUDE_PARA_CODEX.md):**
> estado atual da reforma 3D no place `tungtung`, a lista de problemas do humano em ordem de prioridade e como continuar.

Preparado em 17/10/2026 para ajudar no **design** (visual, interface, mapa, atmosfera e experiência do jogador) de dois jogos Roblox.
Leia este arquivo inteiro antes de propor ou editar qualquer coisa. Responda em **português do Brasil**.

---

## 1. Situação neste computador (já verificada)

| Item | Estado |
|---|---|
| Pasta raiz | `C:\Projetos` |
| Subestação 9 | `C:\Projetos\subestacao-9` — branch `codex/subestacao-9`, commit `8e61ad0` |
| Tung Tung Sahur | `C:\Projetos\tung-tung-sahur` — branch `codex/tung-tung-sahur`, commit `7a7f4ca` |
| Pacote original | `C:\Projetos\pacote` (o `origin` dos dois clones aponta para os `.bundle` daqui; **não apagar**) |
| Git | 2.55.0 instalado |
| Rokit | 1.2.0; ferramentas fixadas instaladas: Rojo 7.7.1, Lune 0.10.5, selene 0.32.0, StyLua 2.5.2, luau-lsp 1.70.1 |
| Checks | `lune run scripts/check` → **ALL GREEN** nos dois (248 e 283 testes) |
| Builds | `lune run scripts/build` → `build/Test.rbxlx` gerado nos dois |
| Roblox Studio | instalado; MCP `Roblox_Studio` e Script Sync **ainda não configurados/verificados** neste PC |
| GitHub | sem remoto real ainda; **não fazer push** |

Ignore caminhos `C:/Users/xpg/...` e Studio IDs que aparecem nos relatórios antigos: são do computador do colega que criou os jogos.

---

## 2. Regras obrigatórias

1. Cada jogo é um repositório independente. Abra **um projeto por vez** como raiz. Não copie código, mapa, schema de dados ou modelos de um para o outro sem pedido explícito.
2. Antes de editar: leia `AGENTS.md`, `CLAUDE.md`/`LEIA_CLAUDE.md` e `docs/IA/README.md` do projeto, e rode `git status`.
3. Crie um branch por tarefa (ex.: `design/hud-menu`). Commits locais pequenos, só dos seus arquivos.
4. Edite somente `src/` no disco. Todo arquivo Luau é `--!strict`, indentação com tabs, 120 colunas, identificadores em inglês, comentários em PT-BR (ver `.agents/skills/luau-conventions/SKILL.md`).
5. O mundo, a luz, a UI e as criaturas são **gerados por código** — não edite manualmente no Studio esperando que fique salvo.
6. Depois de cada mudança: `lune run scripts/check` precisa ficar ALL GREEN; depois `lune run scripts/build` e testar `build/Test.rbxlx` no Studio.
7. **Nunca:** publicar no Roblox, fazer push/merge, rodar `rojo serve`, enviar/gerar assets para o Creator Store, mudar compras/monetização ou trocar versões das ferramentas para esconder falha de check.
8. Não altere regras de gameplay (IA da criatura, objetivos, recompensas, rede) numa tarefa de design. Decoração nova não pode colidir nem entrar em raycasts (`CanCollide=false`, `CanQuery=false`, `CanTouch=false`) e não pode mover/redimensionar objetos interativos.
9. Não crie um segundo HUD, um segundo bootstrap de cliente ou um controller que force câmera/mouse por frame.
10. Ao relatar, separe: **comprovado**, **não verificado** e **pendente de teste humano**.

---

## 3. Jogo A — SUBESTAÇÃO 9

**Gênero:** terror cooperativo em primeira pessoa, estética PS1 / início do PS2. PC (teclado e mouse). 13+ (tensão e susto, sem sangue).

**Pitch:** 03:12, a energia de uma subestação elétrica no meio do mato caiu. A equipe do turno da noite precisa restaurar a instalação e sair pelo portão. Algo ficou lá dentro: **O Vigia**.

**Jogadores:** 2–8 (cooperativo). No lobby a equipe vota o modo:
- **História — O Último Turno:** mapa autoral fixo, 3 capítulos, 9 objetivos em ordem, gravações legendadas e cenas cinematográficas.
- **Padrão:** 3 etapas com seed; mapa (ala norte modular com 9 módulos) e tarefas sorteados; tarefas podem ser divididas.

**Mecânica central de design:** *a luz é faca de dois gumes* — a lanterna é necessária para enxergar, mas torna o jogador visível de mais longe. Fôlego limitado, resgate de colegas caídos, extração física obrigatória.

**O Vigia:** figura alta (~7,5 studs), magra e curvada, braços até os joelhos, casaco de vigia escuro e rasgado, rosto liso cinzento com dois olhos pálidos que brilham. Move-se em *stop-motion* (~10 poses/s) enquanto o jogo roda a 60 FPS. Silhueta reconhecível no fim de um corredor.

**Referências de arte:** Silent Hill (névoa, rádio), Signalis / Haunted PS1 (low poly, paleta curta), Fatal Frame (escuridão com intenção). Direção atual: **instalação industrial brasileira envelhecida**, paleta curta, baixa resolução, leitura de silhuetas.

**Estado visual atual (polish de 16/10):**
- 5 texturas autorais 32×32 geradas por código (tinta gasta, concreto, oxidação, madeira, rejunte), com fallback para materiais nativos.
- Setores numerados, conduítes, caixas de junção, painéis com ponteiro, manchas de umidade/óleo, mesas com teclado/arquivos, 6 monitores CRT com scanlines, poeira por distância, faíscas.
- Vigia com 22 peças de detalhe (bolsos, distintivo, rádio, cinto…).
- HUD: "ordem de serviço" compacta (objetivo, setor, progresso), marcador do próximo setor, guia na tecla H, TAB enquanto pressionado, lanterna/fôlego/postura no rodapé.
- Retrô sem shader: paleta, `Lighting.Fog*`, sombras globais desligadas, fonte pixel (`Enum.Font.Arcade`), overlay 2D (scanlines, vinheta, granulação; tecla V liga/desliga).

**Controles:** WASD+mouse, Shift correr, F lanterna, E interagir, H ajuda, TAB guia, V filtro retrô, B balanço de câmera, F3 debug.

**Pendências de design registradas:** QA humano de leitura no escuro e da arte no fluxo normal; desempenho em hardware alvo/mobile; menus de início/fim/checkpoint; identidade visual das 4 especialidades; novos biomas (bombeamento, retransmissora) estão no backlog, não implementados.

---

## 4. Jogo B — TUNG TUNG SAHUR: THE CURSED HOUSE

**Gênero:** terror **leve** e cooperativo para crianças, primeira pessoa. PC e mobile (controles de toque existem, mas precisam de QA em aparelho real).

**Jogadores:** 1–6. (Não aumentar sem revisar planos, spawns, HUD e testes.)

**Estrutura:** 8 capítulos — 5 numa **casa amaldiçoada** de quatro níveis (com porão, jardim, estufa, mirante, pátio) e 3 na **floresta** (26 objetivos: 8 + 9 + 9).
- **História:** objetivos guiados e progressão narrativa, gravações exclusivas.
- **Desafio:** variações por seed, até 16 passagens opcionais, alterna interiores/exteriores; tarefas paralelas na casa.

**O Tung Tung Sahur:** modelo 3D com esqueleto e animações (`ReplicatedStorage/Assets/TungTung.rbxm`, aparência de madeira, SurfaceAppearance PBR). Patrulha, persegue a luz e bate "TUM TUM TUM" com o bastão. Na floresta fica **sem luz própria** — aparece só pela lanterna do jogador e fontes do cenário.

**Capítulos da floresta:** *A Mata Escuta*, *Ninguém no Rádio*, *Eles Ouviram o Sinal*. Apagões das lanternas da trilha (6 s), drone de tensão, pancadas laterais.

**Epílogo:** extração na van; revelação do Tung Tung e do **Crocodilo Armadilho** (modelo geométrico autoral: mandíbula, dentes, patas, cauda, placas de armadura) e a cartela **"PRÓXIMO JOGO — A MANSÃO DO ARMADILHO"**. A continuação não está implementada.

**Recompensas:** moedas e uma gema por capítulo → Fichas e XP; comemoração em capítulo e vitória; derrota repete o capítulo de graça. Existe passe de temporada (trilha gratuita/premium) — não mexer em IDs, XP ou concessões.

**Estado visual atual (remaster de 17/10):**
- Iluminação `Future`, preset Realistic, sem `Atmosphere` (névoa clássica mantida). Bloom suave; DOF só em cinemáticas.
- Materiais coerentes: portas e móveis em madeira/tecido/metal, ardósia, tijolo, abajures sem neon.
- Floresta com perfil próprio: ambiente frio, silhuetas azuladas nas sombras (não preto puro), pontos quentes guiando o percurso; 500+ árvores próximas por seed.
- Interface: paleta **azul escura / âmbar**, contornos leves, ícones próprios de fôlego/bateria/oxigênio, painéis roláveis, fonte estilizada.
- Perfis de qualidade (Automática / Baixa / Média / Alta / Shaders OFF) controlam sombras, partículas, detalhes e bloom. Pistas, objetivos e feedback de perigo **nunca** são desligados pelos perfis.

**Pendências de design registradas:** sessão humana com perseguição ativa e sustos; legibilidade e toque em celular/tablet físicos; benchmark em aparelho de entrada; a "Mansão do Armadilho" é só um gancho.

---

## 5. Onde fica cada parte do design no código

Caminhos relativos a `src/`. A maioria existe nos dois jogos; os marcados **(Sahur)** só existem no Tung Tung Sahur.

### Mundo e cenário (servidor)
| Arquivo | Papel |
|---|---|
| `ServerScriptService/Server/World/Palette.luau` | cores e materiais do mundo |
| `.../World/ArtBuilder.luau` | texturas, desgaste e detalhes de arte |
| `.../World/Build.luau` | helpers de criação de peças |
| `.../World/Props.luau`, `FeatureBuilder.luau`, `Features.luau` | objetos e elementos de cenário |
| `.../World/MapBuilder.luau`, `Layout.luau` | planta fixa (História) |
| `.../World/ProceduralLayout.luau`, `SectorBuilder.luau`, `SectorExterior.luau`, `Expansion.luau` | mapa procedural/setores/exteriores |
| `.../World/WallMath.luau` | geometria de paredes e vãos |
| `.../World/HouseBuilder.luau`, `HouseArchitecture.luau`, `HouseLevelBuilder.luau` **(Sahur)** | construção da casa e andares |
| `.../World/HouseFurniture.luau`, `HouseScenery.luau`, `HouseTaskProps.luau` **(Sahur)** | mobília, decoração e props das tarefas |
| `.../World/HouseAccess.luau` **(Sahur)** | fundação/solo/porão (cuidado: evita buracos) |
| `.../World/HouseTelevision.luau` **(Sahur)** | televisão/transmissão |
| `.../World/ForestLayout.luau`, `ForestBuilder.luau` **(Sahur)** | trilhas, árvores, abrigos, torre, resgate |

### Luz, efeitos e atmosfera (cliente)
| Arquivo | Papel |
|---|---|
| `ReplicatedStorage/Shared/Game/LightingProfile.luau` | perfis de luz (ambiente, névoa, exposição) |
| `ReplicatedStorage/Client/Controllers/LightingController.luau` | compositor artístico de luz/cor/bloom/névoa |
| `.../Controllers/WorldFxController.luau` | luminárias, sombras por proximidade, partículas |
| `.../Controllers/ArtController.luau` | materiais/detalhes/efeitos locais |
| `.../Controllers/RetroFxController.luau` | filtro retrô 2D (scanlines, vinheta, granulação) |
| `.../Controllers/ScreenFxController.luau` | blur/overlays de perigo, respeitando conforto |
| `ReplicatedStorage/Shared/Game/VisualQuality.luau`, `Presentation.luau` **(Sahur)** | perfis de qualidade e diretrizes de apresentação |
| `ReplicatedStorage/Shared/Game/ThreatPresentation.luau` | apresentação de ameaça/medo |

### Interface
| Arquivo | Papel |
|---|---|
| `ReplicatedStorage/Client/UI/Theme.luau` | **cores, fontes e estilos da UI** — ponto de partida para redesign |
| `.../UI/Create.luau` | fábrica de elementos de UI |
| `.../UI/FieldHud.luau` | HUD principal (recursos, ação, guia) — não criar outro |
| `.../UI/Icons.luau`, `Juice.luau` **(Sahur)** | ícones próprios e animações de feedback |
| `.../Controllers/MainMenuController.luau` | menu inicial e votação de modo |
| `.../Controllers/CampaignController.luau` | HUD da campanha/equipe/tarefas |
| `.../Controllers/GameUiController.luau` | objetivo/guia/feedback/telas |
| `.../Controllers/StoreController.luau` | loja e temporada (só visual; não concede saldo) |
| `ReplicatedStorage/Shared/Game/InteractionPresentation.luau` | textos/apresentação dos prompts de interação |

### Criaturas e cinemáticas
| Arquivo | Papel |
|---|---|
| `ReplicatedStorage/Client/Creature/Rig.luau`, `Poses.luau`, `UniformDetails.luau` | corpo/poses/detalhes do Vigia |
| `.../Creature/TungTungRig.luau`, `TungTungClips.luau`, `ClipCodec.luau` **(Sahur)** | rig e animação do Tung Tung (não alterar o `.rbxm`) |
| `.../Creature/ArmadilhoRig.luau` **(Sahur)** | Crocodilo Armadilho do epílogo |
| `.../Controllers/CreatureVisualController.luau` | render da criatura (posição vem do servidor) |
| `.../Controllers/CinematicController.luau` + `Shared/Game/CinematicShots.luau` | abertura, cenas de capítulo e finais |

### Testes relacionados ao visual
`ServerScriptService/Tests/Specs/` — `LightingProfile`, `ThreatPresentation`, `InteractionPresentation`, `CinematicShots`, `VisualArt` (Subestação), `Presentation` e `VisualQuality` (Sahur). Mudou o visual → atualize/adicione specs.

Para localizar qualquer função: `docs/IA/07_INVENTARIO.md` e `docs/IA/CODE_MAP.json` (consultar sob demanda, são grandes).

---

## 6. Documentos de referência dentro de cada projeto

- `docs/IA/README.md` — índice de leitura para IA
- `docs/IA/02_ARQUITETURA.md` — services, controllers, fluxo de estado
- `docs/IA/03_PROJETO_ATUAL.md` — direção e implementação atual (prevalece sobre docs antigos)
- `docs/GAME_SPEC.md` — conceito (o topo é o atual; o resto é histórico)
- `docs/VISUAL_POLISH.md`, `docs/LIGHTING_POLISH.md`, `docs/HUD_PLAYER_GUIDE.md`
- Sahur: `docs/VISUAL_REMASTER.md`, `docs/HORROR_ATMOSPHERE.md`, `docs/HOUSE_MAP_POLISH.md`, `docs/FLORESTA_TERROR_FINAL.md`, `docs/FINAL_POLISH.md`
- Capturas de antes/depois: `docs/evidence/`

Atenção: o Tung Tung Sahur herdou docs da Subestação (falam de Vigia, fusíveis, 2–8 jogadores). Para o Sahur valem `Config`, os catálogos/planos da casa e da floresta e o `03_PROJETO_ATUAL.md`. O nome técnico do modelo da criatura no Sahur continua `Vigia` — é só nome interno.

---

## 7. Limites técnicos do Roblox já confirmados

- Não há shader de tela/pixelização: o retrô vem de paleta, névoa clássica, poucas sombras, fonte pixel, overlay 2D e animação em passos.
- `Lighting.Technology` e `MaterialService.Use2022Materials` não são alteráveis por script (a tecnologia fica no `default.project.json`).
- IDs de mesh/textura/áudio precisam de permissão na experiência de destino; ter o `.rbxm` local não dá permissão. Não adicionar IDs externos sem pedido.
- Script Sync não transporta modelos binários (`TungTung.rbxm`); por isso teste pela build completa.

---

## 8. Fluxo de trabalho para uma tarefa de design

```powershell
Set-Location C:\Projetos\<jogo>
git status
git switch -c design/<nome-da-tarefa>
# editar src/...
lune run scripts/check
lune run scripts/build
# abrir build/Test.rbxlx no Studio, testar (Subestação: Test > Clients and Servers com 2 jogadores)
git add <arquivos>
git commit -m "design: <descrição>"
```

Se o MCP `Roblox_Studio` estiver conectado, use-o para capturas de tela antes/depois e para conferir console sem erros do projeto. Encerre só o Play que você iniciou.

---

## 9. Como me ajudar (pedido do usuário)

Quero ajuda com o **design** desses jogos. Antes de mudar código:

1. Pergunte em qual jogo vamos trabalhar e qual área (menu, HUD, mapa/cenário, iluminação/atmosfera, criatura, cinemáticas, loja).
2. Leia os arquivos da área e os docs indicados; descreva como está hoje.
3. Proponha 2–3 direções de design com prós/contras, respeitando o público (Subestação 13+ terror retrô; Sahur terror leve para crianças) e o desempenho em mobile.
4. Só implemente a direção escolhida, em branch próprio, com check verde, build e lista do que foi testado.
