# Claude — testes de mecânicas em cópia local (PC Gabriel) — 19/10/2026

## Identidade e origem

- Agente: Claude (Claude Code), PC do humano em `C:/Users/Gabriel` (mesmo PC da frente `codex-dinamica`).
- **Sem branch Git nesta frente**: não há `git` instalado neste PC. O trabalho fica numa cópia local do place.
- Base: cópia baixada do `tungtung` (82955516040017) pelo menu "Baixar uma cópia" em 19/10/2026 ~21:23 (BRT).
  Dois arquivos em `RobloxProjetos/tungtung-testes/`:
  - `tungtung_ESTAVEL.rbxl` — backup intocado, somente leitura.
  - `tungtung_TESTES.rbxl` — onde os testes são aplicados.
- A cópia corresponde ao place atual: `Tests.Run` 412/412 (mesma contagem de `f4a112c`, mensagem 024), 328 scripts.
- Pacote `Tungtung_PROJETO_INTEGRADO_2026-10-18.zip` conferido no disco: SHA-256 `328dbd49…0dcb`, igual ao README.
  O place já passou bastante desse pacote (História, floresta, dinâmica, ambiente); a comparação é contra o place.

## Regras desta frente

- **Não escrevo no place 82955516040017.** No place, só leitura via MCP (estado, contagem de instâncias).
- **Sem Script Sync.** Nenhuma raiz conectada. Nada publicado no Roblox. Sem push no repositório do jogo.
- Qualquer mudança aprovada aqui só vai para o place depois de combinar neste canal com quem tem a reserva do arquivo.

## Alterações (só em `tungtung_TESTES.rbxl`, pedido do humano)

| Arquivo | Mudança | Motivo |
| --- | --- | --- |
| `Shared/Config` | `Battery.DrainPerSecond` 1/170 → 1/204 (+20% de duração) | humano: lanterna descarrega rápido |
| `Shared/Game/LightingProfile` | `Profile.TestBrightBoost = 0.26` somado em `Profile.exposure` (≈ +20% de luz, log2(1,2)) | humano: jogo escuro demais |

Testes na cópia: Play local, exposição 0,08 → 0,34, bateria 204 s; `Tests.Run` 412/412; console sem erro do jogo
(só avisos UIBlox do Roblox).

**Conflito a combinar antes de levar ao place:** `LightingProfile` é da frente `claude-ambiente3d` (item 1, luz escura
aprovada pelo humano em 19/10). `Config` está na reserva do integrador. Por isso as duas mudanças ficam só na cópia
até o humano aprovar e os donos concordarem.

## Próxima frente: animações do Tung Tung (proposta, não iniciada)

Seguir a seleção aprovada pelo humano na mensagem 022: Zombie Idle (Upright Twitching), Mutant Walking (Brutal Walk),
Running (Male Weighted Run), Looking Around (Idle Stand Looking Around, com pescoço menos esticado). Ataque atual mantido.
Converter com `tools/tungtung/bake.js` (bind pose conferida contra `bones.json`).

- **Não mexo** em `JumpscareController` nem no fluxo de captura da História (pedido da mensagem 023).
- Arquivos que eu tocaria, **só na cópia de TESTES**: `Client/Creature/TungTungClips`, `Client/Creature/TungTungRig`,
  `Client/Controllers/CreatureVisualController`.
- Bloqueio: nenhum FBX novo neste PC. Precisa download no Mixamo com o personagem certo (não a skin futura "tung tung
  sahur archive", mensagem 022).

## Reservas atuais

Nenhuma no place. Na cópia local de testes, os três arquivos de animação acima (ainda sem edição).

## Pendências

- Avaliação do humano jogando a cópia de TESTES (luz e bateria).
- FBX do Mixamo para as animações aprovadas.
- Envio deste registro ao GitHub: sem `git` neste PC.
