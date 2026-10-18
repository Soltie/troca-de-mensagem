# Substituições e acabamentos por lote

Cada lote lista o que mudou, onde está o código e o que ficou intocado.
Toda peça nova é `CanCollide=false`, `CanQuery=false`, `CanTouch=false`; detalhes pequenos têm
`VisualDetail=true` (somem além de `detailDistance` na qualidade Baixa/Média).

## Lote 1 — Hall de entrada e corredores (17/10/2026)

Código: `src/ServerScriptService/Server/World/HouseFinish.luau` (novo), chamado no fim de `HouseScenery.build`.
Pasta no jogo: `Workspace.CursedHouse.Finish` (402 peças) + 6 peças soldadas em cada porta `house_door_N` (120).
Nenhum asset externo neste lote: tudo é geometria por código com materiais nativos do Roblox.

| Antes | Depois | Onde |
| --- | --- | --- |
| Teto do corredor = face de baixo do piso de cima (tábua) | Forro de gesso + sanca de madeira nos 4 andares | `corridor()` |
| Corredor sem piso decorado | Passadeira vinho com borda escura (térreo, 1º andar e sótão) | `corridor()` |
| Paredes do corredor vazias entre portas | Um quadro com moldura por cômodo, no trecho sem placa | `corridor()` |
| Portas lisas (placa de madeira) | Almofadas superior/inferior e maçaneta de latão nas duas faces | `dressDoor()` |
| Hall com teto de tábua e vão escuro | Forro de gesso em volta dos vãos das escadas, nos 4 níveis | `foyerCeiling()` |
| Hall sem acabamento de parede | Lambri com almofadas (térreo), rodapé e moldura de cadeira (todos os níveis) | `foyerWalls()` |
| Hall sem luz própria | Lustre de 6 velas com medalhão; pendentes nos patamares; lâmpada nua no porão | `chandelier()` |
| Entrada vazia | Capacho, passadeira até o corredor, arandelas na porta, aparador com espelho e vela | `entranceHall()` |
| Canto leste preto e vazio | Relógio de pêndulo parado às 03:12, banco estofado, 3 quadros, 2 arandelas, abajur, vasos, cabideiro | `entranceHall()` |
| Guarda-corpo maciço dos vãos | Almofadas nas duas faces e pilares com capitel nas pontas | `dressGuard()` |

Intocado: planta, peças de colisão (rampas, `StairGuard`, `LandingGuard`, paredes, pisos), portas
(painel, dobradiça, CFrames, prompts, som, `PathfindingModifier`), gates, barreiras de progressão,
esconderijos, objetivos, moedas, IA, UI.

Luzes novas: todas `LightKind = "Street"` (sempre acesas, não dependem da energia), registradas com
`Build.light` para o `WorldFxController` controlar sombra/visibilidade. Lustre e vela piscam raramente
(`Flicker`), respeitando a opção de flashes.

Pendências deste lote (ficam para lotes seguintes):
- `ProgressionBarriers.upstairs` (caixa de tábuas 11×16×34 que bloqueia a escada no capítulo 1) é a peça
  mais feia do hall; é gameplay, então só a aparência pode mudar, com cuidado (lote de portas/barreiras).
- Telas dos quadros são cor lisa; trocar por pinturas reais em domínio público quando houver envio de imagens.
- Escada principal e corrimões ainda são os originais.

## Lote 2 — Materiais PBR e móveis 3D no hall e corredores (18/10/2026)

O lote 1 usava só peças básicas com materiais nativos e ficou abaixo do padrão pedido. O lote 2 substitui:

| Antes (lote 1, procedural) | Depois | Código |
| --- | --- | --- |
| Paredes lisas de reboco | Papel de parede vitoriano ogival envelhecido (MaterialVariant PBR), em todas as paredes internas acima do porão | `HouseMaterials` |
| Paredes externas lisas por dentro | Revestimento interno fino com o mesmo papel (fora fica a fachada) | `HouseMaterials.skins` |
| Piso de tábua nativo | Tábuas escuras PBR (corredores, cômodos, patamares, escadas) | `HouseMaterials` |
| Forros cor sólida | Gesso PBR (forros, tetos dos cômodos) | `HouseMaterials` |
| Madeira cor sólida (lambri, portas, batentes, guarda-corpos) | Nogueira PBR | `HouseMaterials` |
| Passadeira vinho lisa | Jacquard quadrifólio vinho PBR | `HouseMaterials` |
| Lustre de caixas e cilindros | Lustre de velas 3D (Chandelier_03) + medalhão de gesso | `HouseProps` |
| Relógio de blocos | Relógio de pêndulo 3D parado às 03:12 | `HouseProps` |
| Aparador, espelho e vela de blocos | Console gótico, espelho em arco e lamparina 3D | `HouseProps` |
| Banco de blocos, abajur, vasos-esfera, cabideiro | Sofá vitoriano, criado-mudo com lamparina, poltrona 3D (vasos e cabideiro removidos) | `HouseProps` |
| Quadros de cor lisa | Molduras rococó/landscape/oval 3D com pinturas (hall e 18 no corredor) | `HouseProps` |
| Arandelas de blocos | Arandelas 3D de latão | `HouseProps` |

Luzes: as PointLights ficam em peças invisíveis (`HallChandelier`, `HallSconce`, `Candle`, `HallLampShade`) criadas com
`Build.light`, para o `WorldFxController` continuar controlando sombra, visibilidade e piscadas.
`ConnectedRoomWall`/`PassageLintel` do `HouseLevelBuilder` herdam o `MaterialVariant` da parede original.
Sem `Assets/MansionProps` (place de Script Sync sem o `.rbxm`), `HouseProps` não cria nada (fallback seguro).

Pendências: portas ainda são placas com almofadas simples (próximo: porta 3D modelada no Blender, só visual,
soldada ao painel); barreira de progressão da escada com aparência de caixote; cômodos, porão, fachada, floresta e luz.

## Lote 3 — Cômodos, portas 3D, forros e luz (18/10/2026)

| Antes | Depois | Código |
| --- | --- | --- |
| Portas = placa com almofadas de bloco | Porta vitoriana 3D (4 almofadas, latão) soldada ao painel; painel continua colisão/prompt/som | `HouseFinish.doorModel` |
| Teto dos cômodos piscando (piso de cima coincidente) | Forro de gesso em todos os cômodos (menos onde a escada de serviço abre o teto) | `HouseFinish` |
| Esferas neon de luz noturna | Lamparinas 3D penduradas com luz própria | `HouseProps.nightLights` |
| Quadros lisos dos cômodos | Molduras 3D com pinturas | `HouseProps.nightLights` |
| Sala: sofá de blocos, abajur, vaso-esfera | Sofá vitoriano, poltrona, criado-mudo com lamparina, relógio e castiçais na lareira | `ROOMS.Living` |
| Jantar: mesa e cadeiras de blocos, velas neon | Mesa redonda, 4 cadeiras góticas, castiçais, cristaleira | `ROOMS.Dining` |
| Biblioteca/sótãos: estantes de caixas coloridas | Estantes 3D com volumes (as caixas de colisão continuam, invisíveis) | `bookshelves` |
| Quartos: cama de bloco, guarda-roupa liso | Cama gótica / cama de ferro (infantil), criado-mudo com lamparina, cristaleira | `bedroom` |
| Escritório: escrivaninha de blocos | Console gótico, cadeira gótica, relógio, castiçal, estante | `ROOMS.Office` |
| Cozinha/sótãos | Armários pintados, divã, relógios | `ROOMS.Kitchen`, `attic` |
| Mesa antiga e armários-esconderijo em cor sólida | Nogueira PBR (só material; prompt/porta/tags iguais) | `HouseMaterials` |

Final em ruínas: forros, medalhões e revestimentos ficam transparentes junto com os tetos/fachadas.
Pendências: lareira e rack da TV ainda procedurais; banheiro, sala de máquinas, porão, fachada, floresta e iluminação global.
## Lote 4 — Revisão de arquitetura e troca dos assets restantes (18/10/2026)

Pedido do humano: sofá maior, armário-esconderijo e itens que continuavam primitivos, e cômodos "apertados e mal distribuídos".

Regras de planta adotadas (zonas livres por cômodo): porta, centro das tarefas, esconderijo e a frente dele, e o meio das
divisórias que a campanha pode abrir (`HouseLevelPlan`, passagens de até 24 studs em z = −20/−52). Móveis só nas paredes
da fachada, da porta, da frente (fileira 1, abaixo da janela do hall) e do fundo (fileira 3).
Escala: móveis de chão +25% (`FURNITURE`), porque a casa é maior que o real (portas de 11 studs, cômodos de 36 × 32).

| Antes (primitivo) | Depois |
| --- | --- |
| Lareira de tijolo-bloco com fogo neon | Lareira vitoriana (Hyper3D) na parede interna, com relógio e candelabros |
| Sofá pequeno junto da parede | Sofá 1,8× na fachada, de frente para a lareira; poltronas viradas para o fogo |
| Armários-esconderijo (caixas lisas) | Guarda-roupa de nogueira com cornija (modelado no Blender), face da porta no plano da fresta da câmera |
| Balcão branco, fogão cinza, geladeira verde | Bancada de nogueira com tampo de mármore, fogão a lenha de ferro (Hyper3D), geladeira-baú de madeira (Hyper3D), panela esmaltada |
| Banheira e pia de blocos, pato-cubo | Banheira de pé (Hyper3D), pia de coluna (Hyper3D), espelho, patinho 3D |
| Máquinas e manômetros de blocos | Caldeiras a vapor (Hyper3D), tubulações industriais, luminária de cano; sala com reboco e piso de pedra |
| Caixas, baú e barris de blocos | Caixas de madeira, baú marítimo, baú do tesouro, barris e barril quebrado (Poly Haven) |
| Brinquedos de blocos | Cadeira de balanço, patinho, baú de brinquedos |
| Velas do ritual (neon) | Castiçais de latão e candelabros nos cantos |
| Tapetes de cor lisa | Tapete persa com estampa própria |
| Mesa antiga (bloco que colide) | Mesa baixa de pés torneados no mesmo lugar (a colisão antiga continua) |
| Quadros lisos na fachada | Janela com caixilho de nogueira e cortinas de veludo (atrás) e moldura 3D (frente) |
| Esferas neon de luz noturna | Lamparinas penduradas com luz mais forte |
| Sótão com papel de parede | Tábuas cruas; porão com piso de pedra e sem quadros |
| Cama-esconderijo de caixote | Colcha de jacquard sobre a mesma estrutura |

Hyper3D: 8 gerações (chave de teste); 6 aproveitadas, 2 descartadas (ursinho e cavalinho saíram deformados).
Limitação: a porta do guarda-roupa é parte do mesmo modelo, então não acompanha visualmente o balanço da porta do esconderijo.
## Lote 5 — Iluminação, fachada e jardim (18/10/2026)

Sem downloads novos: tudo com modelos já aprovados (`WindowSet`, `Lantern`, `RockingChair`), texturas já enviadas
(`MansionPlaster`, `MansionDarkWood`, `MansionFloorPlanks`) e peças procedurais. Código em `World/HouseExterior.luau`.

| Antes | Depois |
| --- | --- |
| Paredes externas lisas; papel de parede aparecendo por fora da ala oeste | Casca externa fina sem colisão: reboco PBR claro, soco de tijolo com capa de pedra, faixas de nogueira entre andares, cornija em dois degraus |
| Quinas retas | Cunhais de pedra alternados nas 5 quinas externas |
| 40 janelas neon chapadas em 4 fileiras desalinhadas dos andares | 55 janelas com caixilho 3D, vidro, venezianas verde-escuras, peitoril de pedra, verga e frontão; luz quente com cortinas ou quarto escuro (≈60% acesas) |
| Telhado liso, chaminé de madeira | Testeira e cumeeira com pináculos de ferro; chaminés de tijolo com faixa e potes de barro |
| Letreiro grande sobre as janelas | Letreiro no frontão, com óculo aceso acima |
| Varanda dupla (telhadinho + marquise sobrepostos), postes de madeira | Marquise com capa de ardósia, testeiras, colunas torneadas com base de pedra e capitel; lanterna pendurada; deck de tábuas, degrau, capacho, cadeira de balanço |
| Luzes neon em caixa ao lado da porta | Lanternas de parede em braço de ferro |
| Postes de cilindro com cubo neon (um deles dentro do pilar da varanda) | Postes vitorianos de ferro com lanterna 3D, reposicionados |
| Abóboras de 3 esferas | Abóboras de 8 gomos com talo; rosto aceso nas do caminho |
| 6 lápides iguais dentro do pavilhão "Jardim de Inverno" | Cemitério em lugar livre: lápides em arco, cruzes e obelisco, tortas, com musgo e epitáfios |
| Cerca de pickets branca (301 peças) atrás do muro | Removida; muro do perímetro vira tijolo com coping e pilares; cerca da frente vira grade de ferro (a colisão original fica) |
| Chão do jardim lateral com material de madeira, caminhos de madeira | Grama; caminhos e pátio de paralelepípedo; mirante, pavilhões e bancos em nogueira |
| Árvores do jardim: nunca apareciam (pasta "Forest" apagada pelo ForestBuilder); algumas cairiam dentro dos pavilhões | Pasta `GardenTrees`; árvores secas retorcidas e copas escuras, sem nenhuma dentro de pavilhão, mirante, cerca ou cemitério |
| Portão: pilares de pedra lilás com esfera neon | Pilares de tijolo com capitel de pedra e lanterna 3D |
| Cômodos pretos com a energia desligada | Preenchimento ambiente quente só sob o telhado (`LightingProfile.ambient`); noite e floresta inalteradas |
