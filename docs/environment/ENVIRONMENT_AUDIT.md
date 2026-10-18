# Auditoria do ambiente 3D — antes da reforma

Data: 17/10/2026. Branch `design/environment` (base `design/ui-remaster`, cde09de).
Build de referência: `build/TungTung_ENV_REF.rbxlx` (não versionado). Check: ALL GREEN, 297 testes puros.
Capturas: `docs/evidence/environment/before/` (Play real, capítulo 1 da História e capítulo 6 da floresta,
câmera de QA no cliente, HUD escondido, overlays de cor do jogo mantidos, criatura congelada).

O mundo é gerado por código (`Server/World`). Contagem no capítulo 1: ~2.400 BaseParts no Workspace
(Architecture 239, Furnishings 663, Furniture 301, Yard 384, Facade 164, GeneratedEstate 201, Dressing 140).
Nenhum modelo 3D externo no cenário; tudo é Part/Wedge/Cylinder com materiais nativos.

## Notas (0 = ausente, 5 = nível DOORS/The Mimic)

| Área | Arquitetura/acabamento | Materiais | Móveis/decoração | Iluminação | Legibilidade (sem área preta) | Coerência | Média |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Hall de entrada / escadaria (z 12–64) | 1 | 2 | 0 | 1 | 1 | 2 | **1,2** |
| Corredor central (4 andares) | 3 | 2 | 1 | 3 | 4 | 3 | **2,7** |
| Sala de estar | 2 | 2 | 2 | 3 | 4 | 2 | **2,5** |
| Cozinha | 2 | 2 | 1 | 0 | 0 | 2 | **1,2** |
| Biblioteca | 2 | 2 | 2 | 2 | 3 | 2 | **2,2** |
| Quartos / escritório (1º andar) | 2 | 2 | 1 | 2 | 3 | 2 | **2,0** |
| Sótão | 2 | 2 | 1 | 2 | 2 | 2 | **1,8** |
| Porão / ritual / túnel | 2 | 2 | 1 | 3 | 4 | 1 | **2,2** |
| Fachada e jardim | 1 | 2 | 2 | 3 | 4 | 1 | **2,2** |
| Floresta (cap. 6–8) | 1 | 1 | 1 | 1* | 1* | 2 | **1,2** |

\* Na floresta a escuridão é proposital (lanterna obrigatória). A captura foi feita sem lanterna;
a nota de luz precisa ser revista com a lanterna acesa antes do lote da floresta.

## Problemas por área

**Hall / escadaria** (`HouseBuilder`, `HouseArchitecture`): é a primeira impressão e a pior área.
Piso e teto com o mesmo `WoodPlanks` liso, sem forro nem sanca; vão escuro sem luz de preenchimento;
nenhum móvel (sem aparador, espelho, quadros, tapete, lustre); guarda-corpo é uma placa maciça sem balaústres;
parede de fundo em madeira bruta. O texto de orientação está no fim do corredor, longe da entrada.

**Corredor**: melhor área (lambri, rodapé, batentes, luminárias). Faltam: forro (o teto é a face de baixo
do piso de cima, em tábuas), tapete-passadeira, quadros/arandelas nas paredes, portas com almofadas e maçaneta
(hoje são placas lisas `Wood` cor vinho), variação de cor/sujeira.

**Cômodos (geral)** (`HouseFurniture`, `HouseScenery`): móveis são caixas de cor chapada (sofá, estante,
cômodas, baús), livros em `SmoothPlastic` com cores saturadas, quadros vazios, mesmo pendente de globo branco
em todos os cômodos, tetos em tábua igual ao piso, nenhum rodapé interno, janelas sem cortina.
Cozinha está praticamente preta (luz não alcança a área do balcão).

**Porão / ritual**: tijolo em todas as paredes (bom), mas piso de tábua corrida em vez de pedra; círculo
ritual é um disco vermelho chapado; velas em neon amarelo forte.

**Fachada**: lê como prédio de apartamentos (muitas janelas iguais, telhado plano), não como mansão.
Muro de tábuas e pilares claros sem relação com a casa. Placa "TUNG TUNG SAHUR" sobre a fachada.

**Floresta**: árvores em colunas/blocos, silhuetas retangulares; sem vegetação baixa, raízes ou neblina com volume.

## O que não pode mudar (contratos usados pelos testes e pela IA)

- Planta: `HouseLayout` (níveis −16/0/16/32, escadas, recortes), `HouseCatalog.Rooms` (posições dos cômodos),
  aberturas de porta de 10 studs com lintel em 11,5, corredor de 16 studs, rampas de 10 studs.
- Peças com nome usado em teste/serviço: `CorridorFloor`, `RoomFloor`, `StairDeck`, `Facade`, `DoorWall`,
  `DoorLintel`, `RoomPartition`, `RoomCeiling`, `RearWall`, rampas com atributo `StairRoute`, `StairGuard`,
  `LandingGuard`, gates em `MissionGates`, portas `house_door_N` (painel, dobradiça, CFrames), armários/esconderijos
  `hide_*` (porta tagueada, `inside`/`eye`/`exit`), `ForestGate`, `ExitBeacon`, `PowerPanel`.
- Tags/atributos: `Interactable`, `InteractId`, `PowerLight`, `LightKind`, `Flicker`, `BaseBrightness`,
  `FloorLevel`, `VisualDetail`, `PathfindingModifier` das portas.
- Regra do projeto: decoração nova é `CanCollide=false`, `CanQuery=false`, `CanTouch=false` e fica fora de
  portas, rotas e aproximações dos objetivos.

## Prioridade dos lotes

1. **Hall de entrada + corredores** (maior impacto e primeira impressão).
2. Materiais globais: forros, pisos por área, portas com almofada/maçaneta (sem mudar o painel interativo).
3. Cômodos do térreo (sala, cozinha — corrigir área preta —, jantar, banheiro, biblioteca, máquinas).
4. 1º andar e sótão.
5. Porão, cofre, túnel, ritual, mecanismo.
6. Fachada, jardim e portão.
7. Floresta (com lanterna).
8. Iluminação global por área (`LightingProfile`, `LightingController`) e revisão final.
