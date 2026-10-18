# Fontes e licenças dos assets do ambiente

Regra: só entra asset com licença verificada arquivo por arquivo; nada extraído de outros jogos.
Todos os itens abaixo vêm do Poly Haven (https://polyhaven.com), licença **CC0** (domínio público, uso
comercial livre, atribuição não exigida; registramos os autores por cortesia). Downloads em 1K, autorizados
pelo humano em 18/10/2026. Arquivos brutos ficam em `.cache/env-assets/` (fora do Git).
IDs enviados para a conta Roblox do humano (mesma conta do experimento `tungtung`).

## Ferramentas

| Fonte | Estado | Observação |
| --- | --- | --- |
| Poly Haven (Blender MCP) | ligado | texturas, modelos |
| Hyper3D Rodin (Blender MCP) | ligado, chave de teste do add-on | ainda não usado |
| Sketchfab / Poly Pizza | desligados | dependem de chave de API do humano |

## Texturas (MaterialVariant em `src/MaterialService`)

IDs completos em `tools/environment/texture_ids.json`.

| Variant | Origem | Autor(es) | Tratamento |
| --- | --- | --- | --- |
| MansionWallpaper | estampa ogival própria (gerada por script) + `decrepit_wallpaper` | Rob Tuytel | envelhecimento, normal e rugosidade do decrepit |
| MansionDarkWood | `dark_wood` | Dario Barresi, Dimitrios Savva, Rico Cilliers | recolorida para nogueira |
| MansionPlaster | `plastered_wall_04` | Rob Tuytel | — |
| MansionFloorPlanks | `dark_wooden_planks` | Amal Kumar | — |
| MansionRunner | `quatrefoil_jacquard_fabric` | Rico Cilliers, colormass | recolorida para vinho, contraste do desenho |
| MansionLeather | `fabric_leather_02` | Rob Tuytel | — |

## Modelos (`src/ReplicatedStorage/Assets/MansionProps.rbxm`)

Processados no Blender 5.1: junção, separação por material (uma MeshPart por material), redução de
polígonos, origem na base, texturas 512–1024, exportação GLB, importação pelo importador 3D do Studio
(MeshParts + SurfaceAppearance PBR), escala 1 m = 3,6 studs, sem colisão.

| Modelo | Poly Haven | Autor(es) | Tris originais → finais |
| --- | --- | --- | --- |
| Chandelier | Chandelier_03 | Kirill Sannikov | 29.301 → 9.000 |
| GrandfatherClock | vintage_grandfather_clock_01 (ponteiros em 03:12) | James Ray Cock, Yann Kervran | 8.582 → 6.200 |
| Console | ClassicConsole_01 | Kirill Sannikov | 7.566 → 5.000 |
| Mirror | ornate_mirror_01 | James Ray Cock | 14.246 → 3.000 |
| Armchair | ArmChair_01 | Kirill Sannikov | 5.626 → 4.500 |
| Sofa | Sofa_01 | Kirill Sannikov | 4.101 |
| Nightstand | ClassicNightstand_01 | Kirill Sannikov | 2.002 |
| FrameLandscape | fancy_picture_frame_01 | Rico Cilliers, Rob Tuytel | 938 |
| FrameRococo | fancy_picture_frame_02 | Rico Cilliers, Rob Tuytel | 35.102 → 2.600 |
| FrameOval | hanging_picture_frame_03 (sem vidro) | James Ray Cock | 22.300 → 2.400 |
| Sconce | industrial_wall_sconce | Ulan Cabanilla | 9.826 → 2.000 |
| Lantern | Lantern_01 (sem vidro) | Rajil Jose Macatangay | 30.830 → 2.600 |

### Lote 3 (cômodos e porta), downloads aprovados em 18/10/2026

| Modelo | Poly Haven | Autor(es) | Tris originais → finais |
| --- | --- | --- | --- |
| Bookshelf (estante + volumes) | wooden_bookshelf_worn + book_encyclopedia_set_01 | Ulan Cabanilla; John Malcolm | 10.106 + 67.000 → 15.200 |
| GothicBed | GothicBed_01 | Kirill Sannikov | 18.741 → 7.000 |
| GothicChair | WoodenChair_01 | Jake Mobley | 19.992 → 3.500 |
| RoundTable | round_wooden_table_01 | Ulan Cabanilla | 8.640 → 3.500 |
| Cabinet | vintage_cabinet_01 | Rico Cilliers | 61.096 → 9.000 |
| PaintedCabinet | painted_wooden_cabinet | Kirill Sannikov | 2.227 |
| MantelClock | mantel_clock_01 (sem rig) | Rico Cilliers, Yann Kervran | 25.721 → 3.000 |
| Candlestick | wooden_candlestick | Josh Dean | 3.328 → 800 |
| IronBed | old_bed_frame | Luca B | 49.990 → 5.000 |
| DayBed | vintage_day_bed | Aron Łyczek | 2.715 |
| MansionDoor | **modelada no Blender por Claude** (folha de 4 almofadas, latão), textura nogueira acima | — | 5.200 |

`decorative_book_set_01` foi baixado e descartado (70 materiais, pesado demais para celular).
`vintage_wooden_drawer_01` falhou no download (arquivo do Poly Haven corrompido/Blender 5.2) e não foi usado.

Observação: um objeto de teste antigo (esfera) entrou por engano na primeira importação e foi enviado à conta;
foi excluído do modelo e não é usado no jogo.

### Lote 4 (downloads aprovados em 18/10/2026)

| Modelo | Fonte | Autor(es) | Licença |
| --- | --- | --- | --- |
| Crate, SeaChest | wooden_crate_01, wooden_crate_02 | James Ray Cock; Jurita Burger | CC0 |
| Barrel, BrokenBarrel | wooden_barrels_01 | James Ray Cock | CC0 |
| TreasureChest | treasure_chest | Rico Cilliers | CC0 |
| Suitcase | vintage_suitcase | Maximilian Schuster | CC0 |
| RockingChair | Rockingchair_01 | Jorge Camacho | CC0 |
| RubberDuck | rubber_duck_toy | Plat251 | CC0 |
| PipeRun | modular_industrial_pipes_01 | Jorge Camacho | CC0 |
| PipeLamp | industrial_pipe_lamp | Mateusz Sadek | CC0 |
| EnamelPot | pot_enamel_01 | Kuutti Siitonen | CC0 |
| Candelabra, BrassCandle | brass_candleholders | Tina | CC0 |
| WoodenLantern | wooden_lantern_01 | James Ray Cock | CC0 |
| Fireplace, Bathtub, PedestalSink, WoodStove, Icebox, Boiler | **gerados no Hyper3D Rodin** (chave de teste do add-on MCP for Blender) | — | conforme termos do Hyper3D |
| Wardrobe, LowTable, KitchenCounter, WindowSet, PersianRug | **modelados/gerados por Claude no Blender** (estampa do tapete gerada por script) | — | próprios |

O `.rbxm` agora é salvo pelo MCP (`SerializationService` + `tools/environment/serve.luau`, POST local), sem depender do menu do Studio.
### Lote 5 (fachada e jardim)

Nenhum download novo. Reutiliza `WindowSet`, `Lantern` e `RockingChair` (lotes 1–4) e as MaterialVariants já enviadas.
Candidatas para o próximo lote, ainda **não baixadas** (dependem do ok do humano): `roof_slates_03` (telhado),
`brick_wall_10` (muro/soco) e `street_lamp_01` (poste), todas Poly Haven CC0.

### Lote 6 — chão, mato e chuva (downloads aprovados em 18/10/2026)

| Uso | Fonte | Autor(es) | Licença |
| --- | --- | --- | --- |
| MaterialVariant GardenLawn | Poly Haven `leafy_grass` | Charlotte Baglioni | CC0 |
| MaterialVariant ForestFloor | Poly Haven `forrest_ground_01` | Rob Tuytel | CC0 |
| MaterialVariant DirtTrail | Poly Haven `forest_ground_06` | Charlotte Baglioni | CC0 |
| MaterialVariant SandPath | Poly Haven `sand_03` | Charlotte Baglioni | CC0 |
| MaterialVariant RoofSlate | Poly Haven `roof_slates_03` | Rob Tuytel | CC0 |
| MaterialVariant GardenBrick | Poly Haven `brick_wall_10` | Dimitrios Savva | CC0 |
| TallGrassA/B/Clump (mato alto 3D) | Poly Haven `grass_medium_02` (tufos reduzidos para 1.000–4.600 triângulos, cor + alfa num PNG) | Rico Cilliers | CC0 |
| Grama rasteira animada | grama decorativa do próprio Terrain do Roblox (`Terrain.Decoration`) | Roblox | motor |
| Gota e respingo de chuva | texturas geradas por script (próprias) | — | próprias |
| AmbRain | PSE "Rain On Window 3" (rbxassetid 9112856553) | Pro Sound Effects | licenciado pela Roblox, gratuito |
| AmbThunder | PSE "Thunder Distant Rumble 1" (rbxassetid 9120018692) | Pro Sound Effects | licenciado pela Roblox, gratuito |

IDs das imagens em `tools/environment/texture_ids.json`.

### Lote 7 — floresta, ladrilho, escada e guarda-roupa (18/10/2026)

| Uso | Fonte | Autor(es) | Licença |
| --- | --- | --- | --- |
| ForestFirA/B (pinheiros) | **montados por Claude no Blender** (tronco cônico + ~25 cartões de galho) com as texturas de casca e do atlas de galhos de Poly Haven `fir_tree_01` (o modelo original, com 0,5–4 milhões de triângulos, não foi usado) | Rico Cilliers, Rob Tuytel (texturas) | CC0 |
| MansionTiles (cozinha e banheiro) | Poly Haven `floor_tiles_06` | Rob Tuytel | CC0 |
