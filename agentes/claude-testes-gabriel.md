# Claude — testes de mecânicas em cópia local (PC Gabriel) — atualizado 19/10/2026 ~22:40 BRT

## Identidade e origem

- Agente: Claude (Claude Code), PC do humano em `C:/Users/Gabriel` (mesmo PC da frente `codex-dinamica`).
- **Sem branch Git do jogo nesta frente.** O trabalho fica em cópias locais do place, em `RobloxProjetos/tungtung-testes/`.
- **Cópia atual: `tungtung_TESTES_v2.rbxl`**, feita de `tungtung_ESTAVEL_v2.rbxl` ("Baixar uma cópia" do `tungtung`
  em 19/10 ~22:24 BRT, somente leitura). A v1 (`tungtung_ESTAVEL.rbxl`, ~21:23) fica como histórico.
- Receita das mudanças (trecho antes → depois): `tungtung-testes/MUDANCAS_TESTES.md`.

## Regras desta frente

- **Não escrevo no place 82955516040017.** No place, só leitura via MCP (contagens, somas de verificação).
- **Sem Script Sync.** Nada publicado no Roblox. Sem push no repositório do jogo.
- Mudança aprovada aqui só vai ao place depois de combinar neste canal com o dono do arquivo.

## Alterações na v2 (só na cópia local)

| Arquivo | Mudança |
| --- | --- |
| `Shared/Config` | `Battery.DrainPerSecond` 1/170 → 1/204 (+20% de lanterna) |
| `Client/Creature/TungTungRig` | tipo `Overlay` e 4º parâmetro opcional em `step` (sem ele, igual a antes) |
| `Client/Controllers/CreatureVisualController` | postura procedural do Tung Tung (só visual, cliente) |

Postura: espreita curvada com cabeça varrendo e tiques; quando vê o jogador (≤45 studs, ±110°, sem parede) vira a
cabeça devagar e encara; no início da perseguição a cabeça estala e os olhos acendem; na perseguição inclina 6–22°
com a cabeça travada na vítima. Captura/dormente zeram a postura. **Não toquei em `JumpscareController`,
captura, `CreatureService`/`CreatureBrain`, Root, velocidade ou visão do servidor.**

**Tipos de aproximação (v2, `CreatureService`, autorizado pelo humano):** camada por cima do `CreatureBrain`
(sem editá-lo), atributo `Approach` na Root. Encarar (para 0,9–1,4 s ao te ver a 8–24 studs), arrancada (2,4 s a
1,28×, teto `SprintSpeed - 0,5`) e espreita (de longe anda a 4,5 e congela quando você olha). Visual e sons de cada
fase no `CreatureVisualController`. Testado no Play: sequências completas, 0 erros, `Tests.Run` 413/413. Detalhes em
`tungtung-testes/MUDANCAS_TESTES.md` (seção 5). **Conflito potencial:** `CreatureService` é arquivo compartilhado
(História mexe nele; mensagem 023). Nada disso vai ao place sem combinar.

**Luz: NÃO reaplicada na v2.** O place já recebeu "20/10: levemente mais claro" (exposição 0,08 → 0,20, ambiente e lua
maiores, lanterna com degradê). Somar o +20% da v1 dobraria o efeito. Fica a luz do place.

## Testes na v2

- `Tests.Run` **413/413** (Play local), console sem erro do jogo.
- Bateria 204 s; `SchemaVersion` 8.
- Postura: corpo virado 85° → cabeça vira devagar até o jogador (97° → 64° em 2 s, convergindo); 0 erros.
- Na v1: cabeça encara com erro de 1–2°; perseguição parada com cabeça a 6–10° da câmera; perseguição real até a
  captura sem erro. **Não medido:** inclinação durante a corrida real.

## Achado para todos (ver mensagem 026)

A cópia baixada do place às ~22:24 veio com `Config.Data.SchemaVersion = 6`, enquanto a sessão ao vivo tem **8**.
Era a única diferença de script entre a cópia e o ao vivo (comparação por soma de verificação, 328 scripts). Na
v2 corrigi para 8 (alinhado ao ao vivo); com 6, `Specs.PvPMatch` "v6 data migrates" falha (esperado 8, veio 6).

## Reservas

Nenhuma no place. Na cópia local: `TungTungRig`, `CreatureVisualController`, `CreatureService`, `Config` (bateria).

## Pendências

- Avaliação do humano jogando a v2 (bateria, postura; e se a luz nova do place basta).
- Clipes do Mixamo aprovados na 022: falta baixar os FBX (login Adobe) para converter com `bake.js`.
- A sessão da v2 tem mudanças não salvas em disco; o humano pode salvar com Ctrl+S na janela da v2 (arquivo local).
