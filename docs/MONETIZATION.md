# Monetização e progressão — SUBESTAÇÃO 9

Atualizado em 16/10/2026 pelo Claude, na branch `claude/polish-terror`.

- Commits:
  - `b73ec51`: loja, economia, cosméticos, fitas, compras e trava de sessão.
  - commit seguinte: correções da UI e esta documentação.
- Sem push nem publicação.
- **Nenhum produto foi criado no Creator Hub.** O humano precisa criar os produtos e colar os IDs (seção 5).
  Até lá, as compras com Robux são simuladas **só no Studio**.

## 1. O que existe

| Sistema | Para quê (retenção / receita) |
| --- | --- |
| **Fichas** (ganhas jogando) | progresso a cada partida; alimenta baús e a loja |
| **Créditos** (comprados com Robux) | receita: itens premium e baú lacrado |
| **Níveis** (XP por partida) | sensação de avanço; marcos dão itens e títulos |
| **Calendário de 7 dias** | volta diária (cresce até 300 Fichas + 25 Créditos no dia 7) |
| **Roleta diária grátis** | hábito diário; animação e "quase" |
| **Baú de Ferramentas** (Fichas) | sorteio grátis com animação de rolo |
| **Baú Lacrado** (Créditos) | sorteio pago, com chances publicadas e PolicyService |
| **Cosméticos** | lanternas, fardas, filtros VHS e títulos (só aparência) |
| **Fitas VHS colecionáveis** | caça em cada partida; a equipe toda ganha; marcos 4/8/12 |
| **Relatório do turno** | fim de partida com Fichas, XP e níveis subindo |
| **Passe VIP** | +50% Fichas/XP, +1 giro e cosméticos exclusivos |
| **Pacote Inicial** | oferta de entrada, uma vez por conta |
| **Pacotes de Créditos** | 4 tamanhos, com bônus crescente |

Os cosméticos são de quatro tipos:

- **Lanternas:** o dono vê na mão.
- **Fardas:** os colegas veem.
- **Filtros VHS:** gradação de cor da câmera.
- **Títulos:** placa sobre a cabeça, fora da ação.

**Princípio:** nada pago dá vantagem contra o Vigia. O jogo é cooperativo de terror; vender poder
estragaria o medo e a justiça entre colegas. A receita vem de aparência, coleção e conveniência de progresso.

## 2. Regras da Roblox que isto respeita

Fontes consultadas em 16/10/2026:

- [Paid random items policy guidelines](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items)
- [Monetization overview](https://create.roblox.com/docs/en-us/production/monetization)
- [Creator Rewards](https://create.roblox.com/docs/en-us/creator-rewards.md)
- [Rewarded video ads (DevForum)](https://devforum.roblox.com/t/more-creators-can-now-use-rewarded-video-ads/3838678)

### Itens aleatórios pagos

O **Baú Lacrado** é pago com Créditos, que são comprados com Robux, por isso as regras se aplicam.

- **Chances visíveis antes da compra:**
  - no card, por raridade, em %;
  - no botão **"CHANCES (DETALHES)"**, que mostra todos os itens com % por raridade e por item.

  O botão tem rótulo descritivo; um ícone sozinho não vale.
- **Soma e arredondamento:**
  - as chances somam exatamente 100%, verificado por teste (`Specs/StoreCatalog`);
  - os arredondamentos usam 4 casas, com aviso.
- **PolicyService:**
  - `GetPolicyInfoForPlayerAsync` é consultado na entrada.
  - Com `ArePaidRandomItemsRestricted`, o servidor recusa abrir o baú pago, e a UI mostra
    "INDISPONÍVEL PARA SUA CONTA".
  - A alternativa exigida existe: **compra direta** de cada item.
  - Se a consulta falhar, o padrão é **restrito**, por conservadorismo.
- **Repetidos:** viram Fichas, então o mesmo resultado continua possível e as chances são fixas.
- **Itens gratuitos:** Baú de Ferramentas, roleta e calendário não envolvem Robux, mas mostram as chances
  mesmo assim (transparência).
- **Sem troca entre jogadores:** a regra de `IsPaidItemTradingAllowed` não se aplica.

### Compras

- **ProcessReceipt idempotente:**
  - o recibo (`PurchaseId`) e o que ele concede ficam no MESMO registro do jogador, que é salvo
    antes de responder `PurchaseGranted`;
  - se a Roblox reenviar o mesmo recibo, nada é concedido de novo.
- **Trava de sessão no DataStore** (`Server/Data/SessionLock`): uma reconexão rápida não deixa um
  servidor antigo sobrescrever compras gravadas pelo novo.
- **Pacote Inicial:** é "uma vez por conta". Uma compra repetida (que a Roblox não deixa bloquear
  no prompt) vira os Créditos do pacote, ou seja, nunca cobra por nada.

## 3. Economia (valores em `Shared/Game/StoreCatalog.luau`)

### Recompensa por partida

Antes do VIP; o VIP multiplica por 1,5.

| Fonte | Fichas | XP |
| --- | --- | --- |
| participação | 30 | 60 |
| estágio da campanha concluído | 25 | 50 |
| fusível (solo) | 10 | 25 |
| disjuntores (solo) | 20 | 40 |
| fuga/vitória | 60 | 120 |
| contribuição (coop, máx. 15) | 4 | 8 |
| fita VHS nova | 50 | 40 |

Ordem de grandeza: uma partida típica rende ~150–300 Fichas e ~300–500 XP.

### Níveis e marcos

- XP para o próximo nível: `300 + 100 × (nível − 1)`.
- Cada nível dá `60 + 15 × nível` Fichas.
- Marcos com itens: 3, 5, 8, 10, 13, 20 e 30.

### Baús

| Baú | Preço | Comum | Raro | Épico | Lendário |
| --- | --- | --- | --- | --- | --- |
| Baú de Ferramentas | 250 Fichas | 62% | 28% | 8% | 2% |
| Baú Lacrado | 120 Créditos | – | 60% | 32% | 8% |

Repetido vira Fichas: 50 (comum), 120 (raro), 300 (épico), 800 (lendário).

### Preços diretos

- Comum: 400 Fichas.
- Raro: 1000 Fichas ou 150 Créditos.
- Épico: 350 Créditos.
- Lendário: 750 Créditos.

### Produtos Robux

Preços **sugeridos**; os definitivos são os do Creator Hub. Recomendo *managed pricing*.

| Chave | Tipo | Robux | Conteúdo |
| --- | --- | --- | --- |
| `creditos_100` | Developer Product | 75 | 100 Créditos |
| `creditos_550` | Developer Product | 375 | 550 (+10%) |
| `creditos_1200` | Developer Product | 750 | 1200 (+20%) |
| `creditos_2800` | Developer Product | 1500 | 2800 (+40%) |
| `pacote_inicial` | Developer Product | 149 | 300 Créditos + Lanterna 1987 + Turno da Noite (1×/conta) |
| `vip` | Game Pass | 299 | +50% Fichas/XP, +1 giro/dia, lanterna, farda e título exclusivos |

## 4. Arquitetura

### Lógica pura (testada no Lune)

- `Shared/Game/StoreCatalog.luau`: catálogo, preços, chances, calendário, roleta, níveis, fitas e produtos.
- `Shared/Game/Economy.luau`:
  - nível;
  - compra;
  - abrir baú (sorteio injetado);
  - diário e roleta;
  - recompensa da partida;
  - fitas;
  - equipar;
  - compra Robux idempotente.

### Dados

- `Server/Data/PlayerDataSchema.luau` (v2):
  - carteira, XP, itens, equipados, fitas;
  - diário, estatísticas, recibos;
  - migração da v1.
- `Server/Data/SessionLock.luau`: a regra da trava de sessão.
- `Server/Services/PlayerDataService.luau`:
  - carrega reservando a sessão;
  - salva sem sobrescrever trava alheia;
  - libera ao sair.

### Serviços do servidor

- `StoreService`: remote `Store`, ProcessReceipt, Passe VIP, PolicyService e publicação em atributos do Player.
- `CosmeticService`: farda (BodyColors + capacete/quepe/faixas) e placa de título no personagem.
- `RewardService`: paga o fim de partida nos dois modos observando o estado replicado, sem mexer nos runtimes.
- `CollectibleService`: uma fita por partida ou por estágio, por raycast; a equipe toda ganha.
  `RoundService` e `CampaignRuntime` encaminham o id `"tape"`.

### Controllers do cliente

- `StoreController`:
  - loja (tecla L, ou Select no controle), aberta só fora da ação;
  - abas, rolo do baú, roleta e avisos.
- `CosmeticController`: skin da lanterna, manga da farda, filtro VHS e visibilidade das placas.

### Remotes

| Remote | Direção | Argumentos | Proteção |
| --- | --- | --- | --- |
| `Store` | cliente → servidor | (ação, argumento?) | Guard + rate limit 8/3 s |
| `StoreNotice` | servidor → cliente | recompensas | — |

Ações aceitas por `Store`: `claim_daily`, `spin`, `open_chest`, `buy_fichas`, `buy_creditos`, `equip`, `buy_product`.

### Atributos no Player

- Moedas e nível: `Fichas`, `Creditos`, `Xp`, `Level`, `Vip`.
- Coleção: `Owned` (JSON), `Tapes` (JSON).
- Equipados: `EquipFlashlight`, `EquipUniform`, `EquipFilter`, `Title`.
- Diário e roleta: `DailyStreak`, `DailyClaimable`, `SpinsLeft`.
- Outros: `StarterBought`, `PaidRandomRestricted`, `StoreReady`.

## 5. Passos do HUMANO no Creator Hub (obrigatórios para vender)

Os agentes não criam produtos, não publicam e não mexem no Creator Hub.

1. **Publicar a experiência.** É decisão do humano; enquanto não publicar, os dados ficam em modo mock no Studio.
2. **Criar 5 Developer Products:**
   - `creditos_100`, `creditos_550`, `creditos_1200`, `creditos_2800` e `pacote_inicial`;
   - nomes e descrições como na tabela da seção 3;
   - copiar o ID de cada um para o campo `id` em `StoreCatalog.Products`.
3. **Criar o Game Pass "Crachá de Supervisor (VIP)"** e copiar o ID para a entrada `vip`.
4. **Ativar *managed pricing* / *price optimization*** para os produtos (preços regionais), se desejado.
5. **Ativar servidores privados** (grátis ou baratos): ajuda grupos de amigos, que é o público do coop.
6. **Fazer o questionário de maturidade/conformidade.** É necessário para anúncios e alguns recursos.
   Itens aleatórios pagos não pedem rótulo extra pela doc atual, mas confira no Creator Hub.
7. **Testar uma compra real de cada tipo** em servidor publicado:
   - ver no Output `[StoreService] delivered ...`;
   - conferir os Créditos depois de sair e voltar.
8. **Antes de publicar:** confirmar o consentimento da pessoa do rosto do Ademir (já registrado em ASSETS).

## 6. Como testar no Studio

- **Compras:** com IDs = 0, clicar em comprar na aba CRÉDITOS **simula** a compra pelo mesmo caminho
  da entrega real. A mensagem é "COMPRA SIMULADA (STUDIO, SEM ROBUX)". O VIP simulado vale só na sessão.
- **DebugBridge** (servidor):
  - `storeGrant(fichas, créditos)`;
  - `endRound("Won"|"Lost")`, que também paga o relatório;
  - `tape` (posição da fita);
  - mais os comandos antigos.
- **Modo solo** (checkpoint, duto): trocar temporariamente `Config.Campaign.Enabled = false` e **restaurar**.

## 7. QA executado (16/10/2026, Studio Dev, 1 cliente)

### Testes automáticos

- **Lune:** ALL GREEN, 176 testes no commit `b73ec51`.
  Specs novos: `StoreCatalog`, `Economy`, `SessionLock`, migração v2 no `PlayerData`.
- **Studio:** `Tests.Run` com 189 aprovados e 0 falhas (inclui Navigation com o duto e os pontos novos).

### Loja e compras (remote real, cliente)

- **Diário:** resgate dá +40 Fichas; o segundo resgate é recusado.
- **Roleta:** um giro grátis; um a mais com VIP.
- **Créditos:** compra simulada de 550 Créditos.
- **Baú Lacrado:** saiu "Brigada de Incêndio" (raro), cobrando 120 Créditos.
- **Compra direta:** Lanterna Neon por 350 Créditos.
- **Equipar:** funcionou.
- **Recusas corretas:**
  - saldo insuficiente (`store_poor`);
  - item VIP sem passe (`store_locked`);
  - ação inválida (`invalid_arguments`).

### Cosméticos e jogo

- **Farda:** capacete, aba, faixas e placa no personagem; camisa do avatar removida.
- **Lanterna:** corpo neon, feixe esverdeado, manga da cor da farda.
- **Fita VHS:**
  - colocada pelo raycast no depósito;
  - de dentro da prateleira, recusada (sem linha de visão);
  - pega em seguida: +50 Fichas, +40 XP e aviso;
  - segunda tentativa recusada.
- **Fim de partida:** +80 Fichas e +175 XP, como a regra prevê.
- **Checkpoint:** a tela final mostra "[C] CONTINUAR DO CHECKPOINT" e "[R] REINICIAR TUDO", e continuar
  restaurou energia, fusíveis, disjuntores, bateria e a trégua do Vigia.
- **Campanha (padrão):** boot limpo, lobby, loja abre fora da ação e zero erros no console do projeto.

### Bugs achados no QA e corrigidos

- Roleta não animava: a aba era redesenhada no meio do giro.
- Lista de chances cortada.
- Marcos da coleção fora de ordem.

### Evidências

[evidence/monetization](evidence/monetization/):

- tela final;
- loja;
- baús e chances;
- resultado do baú;
- roleta girando e com resultado;
- créditos;
- farda.

## 8. Limitações e o que NÃO foi verificado

- **Compras reais com Robux:** nenhuma; depende do passo 5. O caminho real (`PromptProductPurchase` →
  ProcessReceipt) foi revisado, mas não executado.
- **PolicyService real:** no Studio retornou não restrito. O bloqueio do baú pago para contas
  restritas foi testado na regra pura (`Economy.openChest` com `restricted`), não com uma conta restrita real.
- **Fita no modo campanha com 3+ clientes:** não testada no Studio. O gancho no `CampaignRuntime` é o
  mesmo do solo; validar no próximo QA multi-cliente.
- **Dados:** mock no Studio. A trava de sessão foi testada na regra pura e com o MockDataStore, não com
  DataStore real em dois servidores.
- **Plataformas:**
  - vibração só para controle;
  - não testada sem controle conectado no Studio;
  - mobile não coberto.
- **Balanceamento:** preços e taxas são proposta inicial. Medir com jogadores (conversão do Pacote
  Inicial, tempo até o 1º baú, retenção D1/D7).
- **Interação do MCP:** clique simulado só funciona por caminho de instância ou coordenadas da GUI (sem o
  inset de 58 px); os botões da loja têm nomes (`Tab_*`, `Open_*`, `Buy_*`, `Spin`, `ClaimDaily`) para isso.

## 9. Próximos passos sugeridos (em ordem de impacto)

1. **Criar os produtos (seção 5) e testar compras reais.**
2. **Analytics de economia — IMPLEMENTADO:** fontes/sumidouros separados, saldo após cada evento,
   SKU e funil abrir loja → escolher oferta → comprar. `TelemetryService` usa AnalyticsService no
   servidor publicado; Studio mantém histórico limitado em memória (`DebugBridge:Invoke("analytics")`).
   Falhas de telemetria não interrompem concessões. O painel real ainda não foi validado.
3. **Passe "Turno Extra" — IMPLEMENTADO:** 30 níveis, grátis/pago, XP separado da conta, concessão
   automática e idempotente, entrega retroativa ao comprar o passe. Aba TEMPORADA na loja.
   SeasonCatalog define as datas UTC e recompensas; a primeira temporada ocorre entre
   15/10/2026 00:00 e 01/12/2026 00:00 em Brasília, com 400 XP por nível (nível 1 imediato).
   Partidas, etapas, fugas, contribuições, fitas e diário dão XP, sem aceleração por VIP.
   PlayerData v3 migra v2 preservando carteira e inventário. Cosméticos ficam na conta após o fim;
   a próxima temporada usa ID e Game Pass novos. O passe `turno_extra_s1` está com ID 0:
   simulação gratuita exclusivamente no Studio; em servidor publicado retorna indisponível.
   Criar o Game Pass e preencher ID/preço continua sendo passo humano, sem execução nesta entrega.
4. **Assinatura Roblox:** "Supervisor Mensal", com Créditos diários e farda mensal, só após medir o VIP.
5. **Emotes e gestos para o lobby/espectador**, um cosmético social visível no coop.
6. **Eventos sazonais** (Halloween/Natal) com fitas e fardas limitadas: urgência sem pagar por poder.
7. **Rewarded video ads:** quando elegível (~100 mil DAU, maturidade leve), um giro extra por anúncio.
8. **Creator Rewards:** já contam com engajamento. Sessões de 10+ min e retorno diário estão no design
   (calendário, roleta, fitas).

## 10. Retomada dos dois chats (16/10/2026)

Analytics e temporada: commit `be50b06`. Snapshot isolado desta frente: ALL GREEN, 190 testes puros.
QA integrado com animações: 224 testes no Studio; trilha grátis/paga, compra simulada, retroatividade
do nível 5, recompra bloqueada e funil de três passos conferidos no Dev. Nenhuma compra real.
Relatório consolidado e fronteira com o modo história: [TWO_CHATS_RESUME.md](TWO_CHATS_RESUME.md).
API verificada na [documentação oficial de AnalyticsService](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService).
