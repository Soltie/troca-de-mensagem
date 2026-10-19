# Modelos substituíveis (20/10/2026)

Tudo o que eu escolhi ou fiz sozinho e que você pode pedir para trocar. "Por código" = feito com peças do Roblox
(sem malha importada); dá para trocar por um modelo do Poly Haven quando ele for importado (passo humano, ver
`docs/PENDENCIAS_HUMANAS.md`). Para pedir troca, diga o item e eu mostro 3–4 alternativas com foto.

## Malhas já no jogo (Assets/MansionProps, Poly Haven CC0, importadas antes)

| Onde aparece | Modelo | Fonte |
| --- | --- | --- |
| Floresta (caps. 6–8): pinheiros | ForestFirA, ForestFirB | Poly Haven (fir) |
| Floresta: capim alto | TallGrassA, TallGrassB, TallGrassClump | Poly Haven (grass) |
| Casa: quadros tortos/caídos (decadência) | FrameRococo, FrameLandscape, FrameOval | Poly Haven (picture frames) |
| Casa: móveis do cenário | Sofa, Armchair, Wardrobe, Nightstand, Cabinet, SeaChest, TreasureChest, Suitcase, etc. | Poly Haven |

## Feitos por código nesta rodada

| Onde aparece | O que é | Arquivo | Troca sugerida (Poly Haven) |
| --- | --- | --- | --- |
| Primeira pessoa | Mão + lanterna (cilindros, dedos curvados, LEDs) | Client/Controllers/FlashlightController | uma lanterna real (ex. "vintage flashlight") + mão low poly do Sketchfab (CC0/CC-BY) |
| Móveis de busca | Cômoda com gavetas e baú com tampa (frisos, latão) | Server/Campaign/HiddenStash | cômoda e baú com gaveta/tampa SEPARADAS da malha (as do MansionProps são uma peça só e não abrem) |
| Cap. 6 | Ponte de corda, guincho, corvos, folhas | Server/World/ForestV2 | ponte de madeira e corvo do Sketchfab |
| Cap. 7 | Jangada, cais, posto de rádio, lampião da Voz | ForestV2, ForestHazardService | jangada, cais e rádio antigo |
| Cap. 8 | Torre de vigia, farol, van, árvores que caem | ForestV2 | torre de madeira e van antiga |
| Casa caps. 2–5 | Buracos do túnel do Tung (arco de pedra, tábuas pregadas) | Server/Services/TunnelService | — |
| Caps. 4–5 | Túnel, catacumba (nichos, crânios, sarcófago), capela (bancos, altar) | Server/World/Catacomb | "stone sarcophagus", "wooden pew", "skull" |
| Casa caps. 2–5 | Cadeiras tombadas, papéis, garras, mãos, símbolos, poças, canos, velas, tábuas nas janelas | Server/World/HouseDecay | cadeira e vela do Poly Haven |
| Cena final | Tung no capô da van | Client/Controllers/CinematicController | — |

## Sons escolhidos (Pro Sound Effects, gratuitos)

Ver `docs/ASSETS.md`: WallScurry (arranhado na parede), HammerNail (pregar tábua), WallBurst (parede quebrando),
CrowCaw, BirdsTakeoff, LeavesCrunch, BigSplash.
