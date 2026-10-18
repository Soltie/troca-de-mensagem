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
