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