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

## Fase 3 — Loja, prévias e compra/equipar (17/10/2026)

**Arquivos:** `Shared/Game/StoreView.luau` (novo, puro), `Client/UI/ItemPreview.luau` (novo),
`Client/UI/ViewportQA.luau` (novo), `Client/Controllers/StoreController.luau` (moldura, aba LOJA, detalhe,
confirmação), `Client/UI/Icons.luau` (baú, fita), `Shared/Game/Text.luau` (acentos), `Tests/Specs/StoreView.luau`
(novo), `Tests/Specs/PixelText.luau`, `Tests/Specs/MenuUi.luau`.

**Não alterado:** StoreService, StoreCatalog (preços, itens, raridades), Economy, remotes, dados, chances.
As abas TEMPORADA, BAÚS, DIÁRIO, COLEÇÃO e CRÉDITOS ganharam só a moldura/estilo novos (fase 5).

| Caso | Status | Evidência |
|---|---|---|
| Check (format, lint, tipos strict, testes) | PASSOU | ALL GREEN, 295 testes puros |
| Runner do Studio na build final | PASSOU | 307 aprovados, 0 falhas, 0 pulados |
| Console do cliente com a loja aberta | PASSOU | nenhum aviso/erro do projeto; StoreUi com 741 descendentes |
| Todo item do catálogo explica como obter, com número real (nível, fitas, capítulo, nível do passe) | PASSOU | spec `StoreView` |
| Miniaturas reais por item (cores do catálogo): lanternas, fardas, filtros, títulos | PASSOU | `f3-loja-pc-acentos.jpg`, `f3-loja-fardas-hazmat.jpg`, `f3-filtros.jpg`, `f3-titulos.jpg` |
| Prévia 3D girável (lanterna e farda) só no detalhe; limpa ao trocar | PASSOU (visual) | capturas; arrastar com o mouse NÃO TESTADO por automação |
| Filtro: cena com a mesma correção de cor do jogo (brilho, contraste, saturação, tinta) | PASSOU | spec `StoreView` (grade) + `f3-filtros.jpg` |
| Saldo e nível na barra superior atualizam ao mudar o atributo | PASSOU | 100 → 1.500 Fichas após `storeGrant` |
| Compra com Fichas pede confirmação (item, preço, saldo depois) | PASSOU | `f3-confirmacao-compra.jpg` |
| Compra debita uma vez e concede | PASSOU | 1.500 → 500 Fichas; `lanterna_retro` em Owned; mensagem "COMPRADO!" |
| Segunda compra do mesmo item não cobra | PASSOU | servidor respondeu `store_owned`; saldo continuou 500 |
| Saldo insuficiente: botão desativado com "FALTAM N CRÉDITOS" | PASSOU | captura Hazmat / Neon |
| Equipar atualiza cartão e detalhe | PASSOU | `EquipFlashlight = lanterna_retro`; antigo virou ADQUIRIDO; `f3-equipado-apos-compra.jpg` |
| Item bloqueado explica a origem (sem empurrar compra) | PASSOU | "RECOMPENSA AO CHEGAR NO NÍVEL 3." |
| PC 1094×674: grade + detalhe lado a lado | PASSOU | capturas |
| Celular 844×390: 5 colunas, detalhe por cima com voltar de 48 px | PASSOU | `f3-celular-844x390.jpg`, `f3-celular-detalhe.jpg` |
| Compra com Créditos (com saldo) | NÃO TESTADO | conta de teste sem Créditos; mesmo caminho do servidor (`buy_creditos`) |
| Smartphone físico / toque real | NÃO TESTADO | depende do dono |

**Correções feitas durante o QA:** feixe da miniatura deixou de ser uma "bola"; modelo 3D maior e mais claro;
acentos restaurados em toda a interface (o `Text.luau` tirava É/Í/Ó/Ú de tudo por causa da antiga fonte Arcade,
que hoje só existe em placas do cenário — essas continuam normalizando no próprio builder); diálogos da loja
ficavam atrás do véu (ScreenGui agora usa `ZIndexBehavior.Sibling`); em tela baixa a loja usa uma coluna e
mais colunas de cartões; detalhe ajusta a altura da prévia para o texto não sumir atrás dos botões.

## Fase 4 — Melhorias e mochila (17/10/2026)

**Arquivos:** `Client/Controllers/MainMenuController.luau` (aba MELHORIAS, diálogo de confirmação, rolagem
preservada, `MenuQARequest`), `Client/Controllers/StoreController.luau` (rolagem preservada),
`Client/UI/Icons.luau` (bateria, pulmões, maleta, passos, coração, repetir). **Não alterado:** `Perks`
(preços, efeitos, estoque máximo), StoreService, remotes.

| Caso | Status | Evidência |
|---|---|---|
| Check / runner do Studio | PASSOU | ALL GREEN (295) · Studio 307 aprovados, 0 falhas |
| Console do cliente | PASSOU | nenhum aviso/erro do projeto |
| Cartão de melhoria: ícone, descrição, nível 5 etapas + "NÍVEL N/5", efeito atual e próximo | PASSOU | `f4-melhorias-pc.jpg` |
| Preço nas duas moedas; sem saldo: "FALTAM N CRÉDITOS" desativado | PASSOU | `f4-consumiveis-pc.jpg` |
| Confirmação antes de melhorar (efeito, preço, saldo depois) | PASSOU | `f4-confirmar-melhoria.jpg` (clique real) |
| Melhorar debita uma vez e sobe o nível | PASSOU | 1.000 → 700 Fichas; `Perks.bateria = 1`; "MELHORIA INSTALADA!" (cliques reais) |
| Comprar consumível com confirmação | PASSOU | 1.000 → 700 Fichas; `pilha_extra = 3` (pacote de 3) |
| Colocar na mochila separado da compra | PASSOU | `Loadout = ["pilha_extra"]` (clique real) |
| Rolagem mantida após compra (menu e loja) | PASSOU | `CanvasPosition.Y = 470` antes e depois |
| Continuação: só por Créditos e uso no botão CONTINUAR; sem toggle de mochila | PASSOU | captura |
| Pacotes em Robux só aparecem com produto publicado | PASSOU | todos com `id = 0` → seção oculta |
| Celular 844×390 | PASSOU | `f4-melhorias-celular.jpg` |
| Estoque cheio (99) desativa a compra | NÃO TESTADO | regra lida de `Perks.MAX_STOCK`; sem fixture com 99 |

**Sobre os cliques automatizados:** com a janela do Studio sem foco, o módulo de câmera padrão do Roblox mantém
o mouse travado no centro e os cliques simulados caem no meio da tela. Para o jogador (janela em foco) o
`CameraController` libera o cursor no lobby. Por isso os fluxos foram exercitados pelo atributo
`StoreQARequest` (só no Studio), que chama as mesmas funções dos botões: `kind:`, `select:`, `detail:`,
`confirm:<id>:<moeda>`, `buy:<id>:<moeda>` (= tocar CONFIRMAR), `close:x`.
