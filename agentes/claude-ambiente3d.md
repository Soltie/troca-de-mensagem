# Claude — reforma visual 3D da mansão (18/10/2026)

## Identidade e origem

- Agente: Claude (Claude Code), PC do humano dono da conta Roblox `fashionultraaura` (mesma conta do experimento `tungtung`).
- Repositório local: `tung-tung-sahur`, branch `design/environment`, criada de `design/ui-remaster` (cde09de).
- HEAD publicado: `ff88474` (lote 1). Trabalho seguinte (materiais PBR + modelos 3D) ainda local, sem commit.
- Não conectei Script Sync e **não escrevi no place 82955516040017**. O Codex integra (decisão do humano).

## Escopo

Somente acabamento visual do mundo 3D: materiais, móveis, decoração, luminárias e luz. Sem mexer em UI, gameplay,
IA, rede, dados, economia, Midnight Hunt, capítulos ou objetivos. Toda peça nova é `CanCollide/CanQuery/CanTouch = false`.

## Reserva de arquivos (visuais)

Novos:
- `src/ServerScriptService/Server/World/HouseFinish.luau` (forros, sancas, lambris, passadeiras, almofadas de porta)
- `src/ServerScriptService/Server/World/HouseMaterials.luau` (MaterialVariant nas paredes/pisos/tetos)
- `src/ServerScriptService/Server/World/HouseProps.luau` (móveis 3D clonados de `Assets/MansionProps`)
- `src/MaterialService/*.model.json` (6 MaterialVariant PBR) + entrada `MaterialService` no `default.project.json`
- `src/ReplicatedStorage/Assets/MansionProps.rbxm` (12 modelos, MeshParts com SurfaceAppearance)

Edições pequenas em compartilhados (2–3 linhas cada):
- `World/HouseScenery.luau`: chama `Finish.build`, `Props.build`, `Materials.build` no fim de `Scenery.build`.
- `World/HouseLevelBuilder.luau`: `ConnectedRoomWall`/`PassageLintel` copiam `MaterialVariant` da parede original.

Próximos (vou avisar antes): `HouseFurniture`, `HouseScenery` (interior/fachada), `ForestBuilder` (só visual),
`Shared/Game/LightingProfile` e `Client/Controllers/LightingController` (iluminação por área).

## Assets (todos CC0, Poly Haven; IDs na conta do humano)

Texturas/MaterialVariant e modelos listados em `docs/environment/ASSET_SOURCES.md` da branch. Atenção: `MaterialVariant` e
`SurfaceAppearance` não podem ser criados por script em jogo (capability Plugin); precisam vir no place/rbxm.
Script Sync **não** transporta `MaterialService` nem `.rbxm` — o integrador precisa incluí-los no place.

## Testes

Lote 1: check ALL GREEN (297 puros), Studio 309 aprovados, console sem erros. Lote 2 em validação.

## Pendências

Entregar patch + build do lote 2 em `entregas/`; seguir cômodos, porão, fachada, floresta e luz.