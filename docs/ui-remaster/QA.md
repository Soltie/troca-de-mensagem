# QA da remaster de UI — Tung Tung Sahur

Status: `PASSOU`, `FALHOU`, `NÃO TESTADO`. Atualizado a cada fase.

## Fase 1 — Fundação visual + menu principal (17/10/2026)

**Arquivos:** `Client/UI/Theme.luau` (tokens novos, nomes antigos preservados), `Client/UI/Icons.luau`
(20 ícones pixel-art 12×12, sem emoji nem asset externo), `Client/UI/Components.luau` (novo),
`Client/UI/MenuLayout.luau` (novo, puro), `Client/Controllers/MainMenuController.luau`,
`Tests/Specs/MenuUi.luau` (novo).

**Não alterado:** StoreService, StoreCatalog, Perks, Economy, Season, DataStore/schema, remotes, preços, XP,
chances, recompensas, capítulos, mapa, criatura, HUD de partida.

| Caso | Status | Evidência |
|---|---|---|
| `lune run scripts/check` (format, lint, sourcemap, tipos strict, testes) | PASSOU | ALL GREEN, 289 testes (283 + 6 novos de `MenuUi`) |
| Todos os ícones do menu existem e cabem no grid 12×12 | PASSOU | spec `MenuUi` |
| Classe de layout: 1920×1080 PC escala 1,5; 1366×768 PC; celular 844×390 compacto baixo; tablet 1024×768 compacto | PASSOU | spec `MenuUi` |
| Trilho compacto com 4 destinos + MAIS | PASSOU | spec `MenuUi` |
| Estados dos capítulos (sem quedas / vencido / próximo / aberto), exatamente um "próximo" | PASSOU | spec `MenuUi` |
| `lune run scripts/build` | PASSOU | `build/Test.rbxlx` e cópia `build/TungTung_UI_REMASTER_F1.rbxlx` |
| Runner do Studio (specs puras + motor) sobre a build final | PASSOU | 301 aprovados, 0 falhas, 0 pulados |
| Console do cliente no menu e após o voto | PASSOU | nenhum aviso/erro do projeto |
| Votar História: `GameModeVote`, contagem e botão "SEU VOTO" (verde) | PASSOU | clique real via MCP; `StoryVotes = 1`; `f1-voto-inicia-capitulo1.jpg` |
| Voto leva à partida e o menu fecha | PASSOU | contagem iniciou e entrou no Capítulo 01 |
| Equipe 1–6 com avatar e espaços vazios | PASSOU (1 jogador) | capturas; 2–6 jogadores ainda NÃO TESTADO |
| Mochila mostra estoque real e estado (sem estoque) | PASSOU | capturas; ligar/desligar com estoque NÃO TESTADO (conta sem itens) |
| Moedas, nível e XP na barra superior | PASSOU (leitura) | 100 Fichas, 0 Créditos, Nível 1 0/300 XP iguais aos atributos |
| Selo de notificação com prêmio diário disponível | PASSOU | `DailyClaimable` real; selo no PRÊMIO DIÁRIO e no MAIS |
| MAIS (celular) abre os 4 destinos e fecha ao tocar fora | PASSOU | `f1-celular-menu-mais.jpg`; `More.Visible = false` após toque fora |
| PC 1094×674 (escala desktop) | PASSOU | `f1-pc-final.jpg` |
| Celular 19,5:9 (844×390) | PASSOU | `f1-celular-844x390.jpg` |
| Celular pequeno 16:9 (667×375), uma coluna | PASSOU | `f1-celular-667x375.jpg` |
| Tablet 4:3 (853×640) | PASSOU | `f1-tablet-853x640.jpg` |
| PC 1920×1080 e 1366×768 | NÃO TESTADO | janela do Studio menor; escala coberta pela spec `MenuUi` |
| Botão + Créditos abre a aba CRÉDITOS | NÃO TESTADO | fase 3 (loja) |
| Smartphone físico | NÃO TESTADO | depende do dono |
| Instâncias do MainMenu (PC, aba JOGAR) | MEDIDO | 790 descendentes; sem baseline antigo para comparar |

Celular e tablet foram simulados no Studio com o atributo `MenuViewportQA` ("844x390" etc.), que só existe
no Studio: força a classe de layout de toque e o tamanho da área do menu. Não substitui o aparelho físico.

**Correções feitas após as capturas:** removido o ponto REC duplicado (a câmera de segurança já mostra REC);
faixa da arte do cartão maior no celular (o selo encostava no título); nomes da mochila em duas linhas legíveis;
espaço vazio do cartão História mostra o progresso real (vencidos e sem quedas).

**Decisões de comportamento desta fase:**
- Produtos Robux com `id = 0` (todos hoje) não aparecem como botão nos cartões de campanha. Antes apareciam
  "PASSE INDISPONÍVEL"/"BÔNUS INDISPONÍVEL" como botões mortos. A aba MELHORIAS ainda mostra "INDISPONÍVEL"
  (fase 4).
- Abas MELHORIAS, SERVIDORES e AMIGOS herdaram só o novo estilo de botão/cartão; o redesenho delas é da fase 4/6.
