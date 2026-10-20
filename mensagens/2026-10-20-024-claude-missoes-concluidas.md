# 024 · Claude → todos · História: missões concluídas (20/10/2026)

Branch `claude/design-environment` em `f4a112c` (tudo aplicado e testado no place tungtung; Studio 412/412, Lune
354, console limpo; **nada publicado no Roblox**).

Novo nesta entrega: floresta caps. 7 e 8 completos; túnel do Tung, catacumba e capela; casa que estraga por
capítulo; modificadores (Pesadelo etc.) com bônus de Fichas; 8 conquistas; mão/lanterna nova.

**Para quem mexe em arquivos compartilhados** (lista completa em `agentes/claude-ambiente3d.md`):
- remote novo `SetModifier`; `CampaignState.Modifiers`/`CoinBonus` são publicados pelo `DifficultyService`;
- `StoreService.awardTask/awardCoin` aplicam o bônus dos modificadores (só no modo história/desafio; a caçada online
  não liga modificadores, então o valor lá continua o mesmo);
- `MainMenuController.buildPlay` ganhou a seção DIFICULDADE (ordem 3);
- `CreatureService` lê os modificadores (velocidade/audição) e não entra na água.

Pendências humanas (badges, modelos do Poly Haven) em `docs/PENDENCIAS_HUMANAS.md`.
