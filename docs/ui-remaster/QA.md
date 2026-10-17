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
| Votar História/Desafio, contagem de votos e "SEU VOTO" | NÃO TESTADO | mesmo remote `SelectGameMode`; precisa de Play no Studio |
| Equipe 1–6 com avatar e cor do voto; contagem para começar | NÃO TESTADO | precisa de Play (Server & Clients) |
| Mochila: ligar/desligar consumível; sem estoque leva a MELHORIAS | NÃO TESTADO | mesmas ações `loadout_on/off` |
| Moedas, nível e XP atualizam em tempo real na barra superior | NÃO TESTADO | lê os mesmos atributos do StoreService |
| Botão + Créditos abre a aba CRÉDITOS da loja | NÃO TESTADO | `Store.openTab("robux")` |
| Selo de notificação só com prêmio diário ou giro disponível | NÃO TESTADO | `DailyClaimable` / `SpinsLeft` |
| MAIS (celular) abre Prêmio Diário, Servidores, Amigos, Ajustes e fecha ao tocar fora | NÃO TESTADO | Device Emulator |
| Sem texto cortado em 1920×1080, 1366×768, 19,5:9, 16:9 e 4:3 | NÃO TESTADO | capturas pendentes |
| Smartphone físico | NÃO TESTADO | depende do dono |
| FPS / instâncias vs. baseline | NÃO TESTADO | MCP do Studio indisponível nesta sessão |

**Por que há NÃO TESTADO:** o servidor MCP `Roblox_Studio` estava conectado, mas não expôs ferramentas
(o Studio precisa de "Assistant → … → Manage MCP Servers → Enable Studio as MCP server"). Sem isso não há
Play automatizado nem captura de tela. Plano: ativar o MCP e rodar o roteiro acima, ou o dono abre
`build/TungTung_UI_REMASTER_F1.rbxlx` e confere manualmente.

**Decisões de comportamento desta fase:**
- Produtos Robux com `id = 0` (todos hoje) não aparecem como botão nos cartões de campanha. Antes apareciam
  "PASSE INDISPONÍVEL"/"BÔNUS INDISPONÍVEL" como botões mortos. A aba MELHORIAS ainda mostra "INDISPONÍVEL"
  (fase 4).
- Abas MELHORIAS, SERVIDORES e AMIGOS herdaram só o novo estilo de botão/cartão; o redesenho delas é da fase 4/6.
