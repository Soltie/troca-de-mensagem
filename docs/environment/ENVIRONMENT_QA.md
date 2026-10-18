# QA do ambiente

Método: build Rojo nova por lote (`build/TungTung_ENV_*.rbxlx`), Play no Studio, voto "Story" pelo remote
real, capítulo 1, criatura congelada pelo `DebugBridge`, câmera de QA no cliente (HUD escondido, overlays de
cor mantidos), suíte `Tests.Run` no servidor e leitura do `LogService` (servidor e cliente).

## Lote 1 — Hall e corredores (17/10/2026, build `TungTung_ENV_L1c.rbxlx`)

| Verificação | Resultado |
| --- | --- |
| `lune run scripts/check` | ALL GREEN, 297 testes puros |
| `Tests.Run` no Studio | 309 aprovados, 0 falhas |
| Peças novas com colisão ou raycast | 0 de 402 (+120 soldadas nas portas) |
| Decoração acompanha a porta ao girar | sim (desvio 0,0000 entre antes e depois) |
| Erros/avisos do jogo no console | 0 no servidor, 0 no cliente (só avisos internos do Roblox/UIBlox) |
| Tempo de montagem do mundo | 278 ms (build L1) |
| Capturas antes/depois | `docs/evidence/environment/before/` e `after-lote1/` |

Observações:
- `after-lote1/04` e `05` são da build L1b (antes de trocar o material das telas e pôr passadeira nos
  patamares de cima); as demais são da build final L1c.
- Áreas pretas corrigidas no lote: canto leste do hall (atrás da escada). A cozinha continua escura (lote 3).

NÃO TESTADO neste lote:
- celular físico (desempenho e legibilidade em tela pequena);
- partida humana com a criatura ativa (perseguição passando pelo hall);
- campanha completa em dupla/seis jogadores (os testes de navegação cobrem rotas, não o ritmo).

## Lote 2 — Materiais PBR e móveis 3D (18/10/2026, build `TungTung_ENV_L2c/L2d.rbxlx`)

| Verificação | Resultado |
| --- | --- |
| `lune run scripts/check` | ALL GREEN, 297 testes puros |
| `Tests.Run` no Studio (L2c) | 309 aprovados, 0 falhas |
| Erros/avisos do jogo no `LogService` do servidor (L2c) | 0 |
| Modelos criados no capítulo 1 | 45 (pasta `CursedHouse.Props`) |
| Texturas carregadas (`ContentProvider`) | Success para wallpaper/walnut/runner |
| MaterialVariant por script em jogo | **impossível** (capability Plugin): vão no place via `src/MaterialService` |
| Bug encontrado e corrigido | telas dos quadros escondidas pelo revestimento: peças de parede agora ficam 0,1 stud à frente |
| Capturas | `docs/evidence/environment/after-lote2/` |

NÃO TESTADO: celular físico; partida humana com a criatura ativa; place compartilhado `tungtung` (a integração
é feita pelo Codex, integrador único).

## Lote 3 — Cômodos e portas (18/10/2026, build `TungTung_ENV_L3c.rbxlx`)

| Verificação | Resultado |
| --- | --- |
| `lune run scripts/check` | ALL GREEN, 297 testes puros |
| `Tests.Run` no Studio | 309 aprovados, 0 falhas |
| Erros/avisos do jogo (servidor e cliente) | 0 / 0 |
| Portas 3D soldadas | 20 de 20, alinhadas ao painel (bug de pivô corrigido) |
| Peças novas com colisão ou raycast | 0 |
| Modo ruína simulado (pasta `Ruins`) | 46/46 forros e revestimentos ficaram transparentes; voltaram ao remover |
| Peças no Workspace (capítulo 1) | ~3.080 |
| Capturas | `docs/evidence/environment/after-lote3/` |

NÃO TESTADO: celular físico; partida humana com criatura ativa; final em ruínas real (só simulado); place compartilhado.
## Lote 4 — Arquitetura dos cômodos e assets restantes (18/10/2026, build `TungTung_ENV_L4c.rbxlx`)

| Verificação | Resultado |
| --- | --- |
| `lune run scripts/check` | ALL GREEN, 297 testes puros |
| `Tests.Run` no Studio | 309 aprovados, 0 falhas |
| Erros/avisos do jogo (servidor) | 0 |
| Peças novas com colisão/raycast | 0 de 389 modelos |
| Peças no Workspace (cap. 1) | ~3.320 |
| Capturas | `docs/evidence/environment/after-lote4/` (08 e 09 são anteriores às tábuas do sótão e à pedra do porão) |

Pendências conhecidas: cômodos ainda escuros com a energia desligada (lote de iluminação); banheiro/cozinha sem piso de ladrilho;
fachada, jardim e floresta ainda não reformados. NÃO TESTADO: celular físico, partida humana, esconder-se no guarda-roupa novo
com a câmera real (a geometria foi alinhada à fresta, mas a vista não foi conferida em jogo).
## Lote 5 — Iluminação, fachada e jardim (18/10/2026, build `TungTung_ENV_L5d.rbxlx`)

| Verificação | Resultado |
| --- | --- |
| `lune run scripts/check` | ALL GREEN, 298 testes puros (novo: luz ambiente interna) |
| `Tests.Run` no Studio | 310 aprovados, 0 falhas (inclui navegação da casa, do jardim e EstateGround) |
| Erros/avisos do jogo no `LogService` | 0 |
| Peças novas com colisão, raycast ou toque | 0 de ~1.590 (casca, jardim e telhado) |
| Troca de capítulo (GeneratedEstate refeito) | telhado, cerca e terreno vestidos de novo, uma única vez |
| Ruínas simuladas (pasta `Ruins`) | 1.061/1.061 peças da casca somem; voltam ao remover |
| Árvores do jardim | 88 árvores presentes no lobby e depois de iniciar o capítulo |
| Peças no Workspace (cap. 1) | ~4.830 (antes ~3.320; +1.000 da casca, +600 das árvores que antes sumiam) |
| Ambiente num cômodo sem energia | (44, 37, 34) → cômodo legível; fora da casa continua (19, 22, 32) |
| Capturas | `docs/evidence/environment/after-lote5/` |

Observação de método: com três Studios abertos a placa de vídeo derrubou a qualidade e as PointLights pararam de
renderizar (falso "fachada escura"); as capturas finais foram feitas com um Studio só.

Pendências: telhado com Slate do próprio Roblox (falta textura de telhas), sem lucarnas; ladrilho no banheiro/cozinha;
floresta dos capítulos 6–8. NÃO TESTADO: celular físico (atenção ao total de peças), partida humana, final em ruínas real.

## Lote 6 — Grama, chão e chuva (18/10/2026, build `TungTung_ENV_L6b/L6c.rbxlx`)

| Verificação | Resultado |
| --- | --- |
| `lune run scripts/check` | ALL GREEN, 302 testes puros (novos: `Weather`) |
| `Tests.Run` no Studio (L6b) | 314 aprovados, 0 falhas |
| Erros/avisos do jogo | 0 (fora avisos temporários "content being generated" de imagens recém-enviadas) |
| Grama do Terrain | aparece e balança (Decoration ligada pelo `places/world/Workspace/Terrain.model.json`) |
| Chuva | visível, para sob telhado/varanda; 60 fps no Studio com 6 células ativas |
| Memória do cliente (Studio) | ~1,9 GB |
| Capturas | `docs/evidence/environment/after-lote6/` |

Ajuste: com `GrassLength` 0,9 o capim escondia as lápides (e poderia esconder itens no chão); reduzido para 0,55.
Observação: com várias janelas do Studio abertas, a captura de tela derrubou o Studio duas vezes; com uma só, não.

**Integração (Codex):** a grama do Terrain depende de `Workspace.Terrain.Decoration = true` (e `GrassLength = 0.55`) no place.
No build Rojo isso vem do `Terrain.model.json`; no place compartilhado é uma propriedade a marcar no Studio (não dá por script).

NÃO TESTADO: floresta dos capítulos 6–8 com o Terrain (só por código), celular físico, partida humana com a chuva
(conferir se o som não cobre os avisos da criatura), relâmpago visto em jogo (só a curva testada no Lune).
