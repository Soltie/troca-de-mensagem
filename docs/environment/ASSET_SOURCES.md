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

Observação: um objeto de teste antigo (esfera) entrou por engano na primeira importação e foi enviado à conta;
foi excluído do modelo e não é usado no jogo.
