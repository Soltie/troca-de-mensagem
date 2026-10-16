# Revisão da frente de animações — Claude, 16/10/2026

Base: `1602f3d` (entregue pelo Codex a partir do plano do Claude) + menu de modo de `cfb2d08`.
Objetivo do humano: animações, transições e introdução que dêem mais imersão.

## Problemas encontrados e corrigidos

| Problema | Correção |
| --- | --- |
| No co-op (modo padrão do jogo) a abertura nunca aparecia: o menu de modo é opaco e chamava `Cinema.stop()` | Na primeira entrada a abertura passa **antes** do menu (`OpeningActive`); depois o menu fica sobre um laço de câmeras de segurança (`Attract`) com fundo semitransparente |
| Título e legenda ficavam fixos nos 3 planos da abertura, cobrindo a cena | Cartela só no 1º plano (ou até 55% de plano único); legendas divididas pelo tempo da cena |
| Solo: a cena escondia a cartela da intro e o jogador perdia o briefing | Legendas da abertura solo = `Text.Intro` (objetivos da missão) |
| Início de etapa do modo padrão só piscava | Cartela "ETAPA N/3 · TÍTULO", ameaça e papel do jogador no escuro; o olho abre quando o personagem renasce/é liberado. Não mexe na câmera nem nos controles |
| Lanterna dos colegas reposicionada só 12×/s (ficava até ~1,5 stud atrás da mão correndo) | Lanterna a cada quadro; poses a 30 Hz |
| Pose de resgate dependia do último aviso `rescuing` (podia ficar ajoelhado para sempre) e não descia o corpo | Vale só por `ReviveSeconds + 0,75 s`; ajoelhado de verdade (joelho no chão, coxa medida nas juntas) |
| Incapacitado ficava girado mas flutuando | Desce até o chão pela altura real do quadril; pernas e braços soltos |
| Agachado com comprimento de perna fixo (2,2): pés flutuavam ~0,35 stud em avatares de pé grande | Calibração pelo pé real: mede o pé mais baixo e corrige a altura até encostar (folga medida: −0,002 stud) |
| Avisos da loja ("+100 FICHAS", relatório do turno) entravam por cima da abertura e da fuga | Avisos esperam a cena (`CinematicHold`) e 0,35 s de margem para a fase chegar antes |
| Solo: painel de objetivo aparecia sob as faixas de cinema | GameUi some durante cenas no solo (no co-op o CampaignController já esconde) |
| Uma cena começando durante a cartela/despertar deixava os olhos fechados | `play()` cancela a cartela e limpa o overlay |

## Câmeras de segurança

Planos fixos (`handheld = 0`) são tratados como CFTV: imagem a 12 quadros/s (`CinematicShots.quantize`)
e `ColorCorrection` de visão noturna (dessaturada, clareada, esverdeada). Planos na mão continuam lisos.
O próprio personagem aparece nas câmeras (LocalTransparencyModifier restaurado ao sair).
Enquadramentos do laço testados ao vivo no Studio: portão visto da estrada, pátio da guarita, van com o
portão ao fundo e porta da recepção.

## Evidência (Studio Dev, 16/10/2026)

- `lune run scripts/check`: ALL GREEN; runner do Studio: **231 aprovados**, zero falhas; console sem erros do projeto.
- Capturas em `docs/evidence/animation-review/`: abertura solo com briefing (01), menu sobre o CFTV (02),
  câmera do portão (03), cartela de etapa (04), ajoelhado no resgate (05), incapacitado (06),
  fuga sem avisos (07) e relatório depois da cena (08).
- Poses conferidas no próprio personagem com atributos locais de teste e câmera de QA (cliente apenas).

## Não verificado

- Cartela de etapa num início de etapa real com 3+ clientes (tempo de renascimento do servidor).
- Lanterna por quadro vista por outro cliente; poses em R6 e avatares muito fora do padrão.
- Desempenho com 8 jogadores (cálculo do pé: 16 cantos por jogador agachado, a 30 Hz).
