# Claude â€” reforma visual 3D da mansÃ£o (18/10/2026)

## Identidade e origem

- Agente: Claude (Claude Code), PC do humano dono da conta Roblox `fashionultraaura` (mesma conta do experimento `tungtung`).
- RepositÃ³rio local: `tung-tung-sahur`, branch `design/environment`, criada de `design/ui-remaster` (cde09de).
- HEAD: `a53dc13` (lote 2: materiais PBR + 12 modelos 3D). Patches e build em `entregas/claude-ambiente3d/`.
- NÃ£o conectei Script Sync e **nÃ£o escrevi no place 82955516040017**. O Codex integra (decisÃ£o do humano).

## Escopo

Somente acabamento visual do mundo 3D: materiais, mÃ³veis, decoraÃ§Ã£o, luminÃ¡rias e luz. Sem mexer em UI, gameplay,
IA, rede, dados, economia, Midnight Hunt, capÃ­tulos ou objetivos. Toda peÃ§a nova Ã© `CanCollide/CanQuery/CanTouch = false`.

## Reserva de arquivos (visuais)

Novos:
- `src/ServerScriptService/Server/World/HouseFinish.luau` (forros, sancas, lambris, passadeiras, almofadas de porta)
- `src/ServerScriptService/Server/World/HouseMaterials.luau` (MaterialVariant nas paredes/pisos/tetos)
- `src/ServerScriptService/Server/World/HouseProps.luau` (mÃ³veis 3D clonados de `Assets/MansionProps`)
- `src/MaterialService/*.model.json` (6 MaterialVariant PBR) + entrada `MaterialService` no `default.project.json`
- `src/ReplicatedStorage/Assets/MansionProps.rbxm` (12 modelos, MeshParts com SurfaceAppearance)

EdiÃ§Ãµes pequenas em compartilhados (2â€“3 linhas cada):
- `World/HouseScenery.luau`: chama `Finish.build`, `Props.build`, `Materials.build` no fim de `Scenery.build`.
- `World/HouseLevelBuilder.luau`: `ConnectedRoomWall`/`PassageLintel` copiam `MaterialVariant` da parede original.

PrÃ³ximos (vou avisar antes): `HouseFurniture`, `HouseScenery` (interior/fachada), `ForestBuilder` (sÃ³ visual),
`Shared/Game/LightingProfile` e `Client/Controllers/LightingController` (iluminaÃ§Ã£o por Ã¡rea).

## Assets (todos CC0, Poly Haven; IDs na conta do humano)

Texturas/MaterialVariant e modelos listados em `docs/environment/ASSET_SOURCES.md` da branch. AtenÃ§Ã£o: `MaterialVariant` e
`SurfaceAppearance` nÃ£o podem ser criados por script em jogo (capability Plugin); precisam vir no place/rbxm.
Script Sync **nÃ£o** transporta `MaterialService` nem `.rbxm` â€” o integrador precisa incluÃ­-los no place.

## Testes

Lote 1: check ALL GREEN (297 puros), Studio 309 aprovados, console sem erros. Lote 2 em validaÃ§Ã£o.

## PendÃªncias

Entregar patch + build do lote 2 em `entregas/`; seguir cÃ´modos, porÃ£o, fachada, floresta e luz.