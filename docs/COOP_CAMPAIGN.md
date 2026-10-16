# Campanha cooperativa — SUBESTAÇÃO 9

> Atualização de 16/10: a geração física da ala norte e os testes por seed estão em
> [MAP_RANDOMIZATION.md](MAP_RANDOMIZATION.md). A descrição da V1 abaixo registra a base anterior.

Pedido do humano: 15/10/2026. Responsável por esta frente: Codex.
Estado: **V1 COOP ATIVADA E VALIDADA NO STUDIO; balanceamento humano e expansões pendentes**.
Código entregue nos commits locais `68f3768`, `31f6b59` e `ca66ead`, sobre o handoff Claude `c6b247a`.
Coordenação: [pedido ao Claude](CLAUDE_HANDOFF_REQUEST.md) e [aviso compartilhado](../LEIA_CLAUDE.md).

## Direção de jogo

Campanha de três estágios, com tarefas paralelas, comunicação e resgate. Duração alvo de design:
12–20 minutos, ainda sujeita a teste humano. Cada campanha tem uma seed reproduzível. Mantemos
o terror PS1 e a subestação como primeiro level; novas instalações completas vêm após validar a base.

| Estágio | Trabalho do grupo | Escalada |
| --- | --- | --- |
| 1. Reconexão | localizar e reparar circuitos em salas sorteadas | Vigia patrulha; aprender rotas |
| 2. Sincronização | ler pistas e confirmar relés com outro jogador | ruído e pressão maiores |
| 3. Evacuação | recuperar registros, estabilizar estações e reunir sobreviventes na saída | caça e extração coletiva |

Atividades devem ter variedade de local, sequência e tipo, sem gerar puzzles insolúveis. O sorteio
não pode bloquear a saída, um item obrigatório ou todas as rotas de uma sala. A primeira versão
randomiza conexões secundárias e pontos de atividade dentro da planta validada; isso não equivale
a gerar prédios inteiramente novos. Novos layouts modulares entram após uma suíte de conectividade.

## Regras para 2–8 pessoas

- Progresso de campanha compartilhado; estado de vida, especialidade e contribuições por jogador.
- Captura derruba só a vítima. Outro jogador pode resgatá-la; derrota só quando não restar ninguém
  capaz de agir. Quem ficar fora volta no estágio seguinte, reduzindo espera longa.
- Saída não encerra a rodada no primeiro jogador: sobreviventes precisam reunir-se ou confirmar
  uma decisão de evacuação com aviso/contagem. Desconexão não deixa uma vaga impossível de preencher.
- Tarefas e participação exigida escalam com o grupo no início de cada estágio. Entrada tardia não
  reescreve um puzzle em andamento; integra-se no próximo ponto seguro.
- Reinício deve depender de consenso/maioria, sem um jogador destruir a campanha dos demais.
- Interações concorrentes são aplicadas atomicamente no servidor; repetir um pedido não duplica progresso.
- Dispositivo, reviver, inventário e ações do jogador precisam de validação de fase, distância,
  linha de visão, cooldown e estado de vida. O cliente nunca informa conclusão de puzzle.
- Especialidades são bônus, não chaves obrigatórias: Técnico, Socorrista, Batedor e Operador.
  Nenhum grupo fica travado pela composição ou pela saída de uma especialidade.

## Conteúdo e fronteira de implementação

**Primeira entrega implementada:** catálogo, gerador determinístico, regras de equipe, construtor de
estações/atalhos, runtime alternativo, HUD, especialidades e eventos ambientais. Três estágios
funcionam na subestação existente; dois novos prédios completos continuam no roadmap abaixo.

Técnico acelera reparos; Socorrista acelera resgates; Batedor identifica salas com estações próximas;
Operador aumenta a janela de confirmação dos relés. O Vigia é o único NPC desta entrega.
Eco e Apagão são modificadores ambientais (ruído e cortes temporários de luz), não novos rigs/NPCs.

**Próximas expansões de conteúdo:**

1. Level 2: estação de bombeamento (válvulas, pressão e rotas alagadas).
2. Level 3: retransmissora (antenas, sinais e pistas visuais/sonoras equivalentes).
3. Ameaças: Vigia (luz/visão), Eco (ruído) e Apagão (pressão ambiental sobre circuitos).
   Variantes de regra não devem ser apresentadas como três NPCs completos se houver só um rig.
4. Personagens próprios com identidade visual e áudio; primeira versão usa os avatares existentes
   com especialidades funcionais. Novos modelos/sons precisam de origem e QA.
5. Puzzles: sequência com pista, relés entre salas, distribuição de energia, transporte cooperativo;
   nenhum exige voz, leitura de cor isolada ou todos os oito jogadores numa porta estreita.

## Arquitetura e coordenação

- `Shared/Game/CampaignCatalog`: conteúdo legível e estável, IDs de estágios/tipos/especialidades.
- `Server/Campaign/SeededRandom`: RNG puro reproduzível, sem depender de estado global.
- `Server/Campaign/CampaignGenerator`: plano e validação do sorteio, sem Instances.
- `Server/Campaign/CoopSession`: máquina de estados e regras de participação/atividades, sem Roblox.
- Construtor/adaptador do servidor: converte plano em estações e aplica decisões ao mundo.
- Serviço e UI: integração sequencial concluída após receber o handoff do Claude.

Integração preservada: `RoundService` delega para `CampaignRuntime` quando o modo é pedido;
o mesmo slot do bootstrap continua sendo o único dono da rodada. `ServerNet.isRegistered` permite
oferecer a lanterna legada só quando o PlayerStateService do polish não registrou o handler.
O filtro do Vigia ignora derrubados, espectadores, evacuados e jogadores em breve proteção de spawn/resgate.
O corpo do Vigia recua/reinicia depois de uma captura, evitando ficar preso no estado terminal legado.
Avatares do grupo não colidem entre si; a visão de interação ignora corpos de colegas para evitar bloqueio.

`Config.Campaign.Enabled = true` seleciona a campanha; false mantém o modo solo para regressão/polish.
Um teste opt-in `StudioTestService` com `{campaignQA=true, players=3}` ativa a campanha somente
na sessão de teste, mesmo com a flag desativada. Isso não altera a capacidade
da experiência no Creator Hub. O limite aplicado pela sessão é oito; capacidade publicada não foi modificada.

O HUD coop oculta o HUD solo, apresenta tarefas, equipe, resgate e extração. Portas existentes são
atalhos que podem ser abertos; inventário/checkpoint/esconderijos do polish não foram portados para
coop nesta versão. A campanha usa estações próprias em vez de duplicar o fluxo dos três fusíveis.

Ao adaptar o polish, as trancas legadas são removidas no começo do estágio e os prompts de itens
da missão solo são desabilitados. Isso impede que a combinação "porta do depósito trancada + atalho
sorteado fechado" torne uma atividade inalcançável. O modo solo conserva suas trancas e chave.
BodyAudio/Fear e os controllers de áudio/lanterna entregues sem commit pelo Claude foram integrados,
com correção de tipagem. O HUD de campanha fica acima da vinheta para leitura, tem mira e tempo de resgate.

Não substituir o trabalho de polish em andamento. O protótipo solo permanece como referência
de regressão; a integração precisa declarar explicitamente qual serviço governa a rodada, sem
dois runtimes disputarem jogador, remotes ou energia.

## Pesquisa técnica consultada

A Roblox usa servidor/cliente; as regras e os pedidos remotos precisam ser validados no servidor.
As decisões acima seguem a [fronteira cliente-servidor](https://create.roblox.com/docs/scripting/security/client-server-boundary).
Para a evidência multiplayer, usar [simulação com vários clientes](https://create.roblox.com/docs/studio/testing-modes)
e, se disponível nesta versão do Studio/MCP, [StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).
Um teste com tabelas simulando oito membros prova regras puras, não oito clientes conectados.
Os caminhos físicos também precisam do [PathfindingService](https://create.roblox.com/docs/characters/pathfinding).

## Defeitos encontrados no QA e correções

O primeiro ciclo com 3 clientes passou pela campanha inteira. Com 8, o lobby começou antes da
conexão do oitavo: sete estavam ativos, um entrou como aguardando (regra de entrada tardia).
O cálculo antigo de posição usava a ordem mutável de todos os IDs, sobrepondo um jogador ativo
e o recém-chegado. As tentativas e posições reais foram preservadas em `evidence/coop/*failure.json`
e `eight-clients-spawn-diagnostic.json`; a hipótese inicial de ser só carregamento foi corrigida.

Correções: slots estáveis e exclusivos, área de espera separada, contagem do lobby reiniciada
quando alguém entra, e barreira que aguarda modelo/Root/Humanoid e posicionamento antes de liberar
o estágio. O harness de carga reúne o lote completo e reinicia o setup antes da campanha medida;
o mínimo de produção continua 3. O mesmo harness desconecta um cliente simulado, acrescenta outro
e verifica a entrada dele somente no estágio seguinte.

No QA integrado, um rangido revelou erro de limpeza no AudioController entregue pelo Claude:
o callback `Sound.Destroying` destruía imediatamente seu pai, reentrando na destruição do filho
("Parent property ... is locked"). A remoção do ponto sonoro passou a ser adiada com `task.defer`.
A tipagem do BodyAudio também foi corrigida antes de registrar BodyAudio/Fear no bootstrap.

## Critérios de aceitação e tarefas

| Tarefa | Estado final | Evidência |
| --- | --- | --- |
| Handoff e contrato com Claude | recebido | `CLAUDE_POLISH_HANDOFF.md`, commit `c6b247a` |
| Catálogo e geração por seed | implementado | `Specs/CampaignGenerator`, determinismo e variação |
| Validar mapas/atividades | aprovado | 3.600 planos e pathfinding físico nos três estágios |
| Regras coop para grupos 3–8 | implementado | `Specs/CoopSession`, resgate, desconexão, voto, concorrência |
| Aplicar plano ao mundo | aprovado | build e ações pelos remotes de clientes do engine |
| Integrar runtime e UI | aprovado | um dono da rodada, remotes validados, estado replicado |
| Simulação integrada com 3 clientes | aprovada | `evidence/coop/integrated-three-clients-result.json` |
| Simulação integrada com 8 clientes | aprovada após correções | `evidence/coop/integrated-eight-clients-result.json` |
| Teste com pessoas | pendente | diversão, clareza, duração e tempo de espera |

Check final: **ALL GREEN, 136 testes puros**. Runner do Studio: **144 aprovados, zero falhas**.
Auditoria final de console no Play local: servidor e cliente sem warnings/erros do projeto.
Os 54 sons do catálogo carregaram como Instances de Sound; seis ciclos de destruição do áudio
posicional não deixaram pontos sonoros nem erros. Isso não mede a mixagem percebida por pessoas.

O roteiro multiplayer congela o Vigia e usa teleporte para preparar ações; demonstra fluxo,
interações e navegação, sem provar uma partida natural equilibrada. Receita e limites em
[COOP_QA.md](COOP_QA.md); próximas implementações em [NEXT_STEPS.md](NEXT_STEPS.md).
Studio principal devolvido em Edit; nenhum push ou publicação.

Limites: sem publicação, push, monetização ou promessa de desempenho antes de medir.
