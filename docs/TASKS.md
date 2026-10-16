# Tarefas cooperativas

## Experiência

- **Reparo:** isolar circuito → encaixar fusível → testar energia. Três componentes numerados,
  com o próximo botão aceso. O técnico combina as duas primeiras ações quando inicia o reparo;
  o teste final sempre exige uma interação. Qualquer colega pode continuar de onde outro parou.
- **Sequência:** a ordem fica na placa, o próximo botão acende e três LEDs mostram o progresso.
  Errar não apaga acertos anteriores. O barulho do erro ainda pode atrair o Vigia.
- **Relé:** uma pessoa arma e outra confirma; a placa mostra os segundos restantes. Operador
  conserva sua janela maior. O último jogador ativo pode armar e confirmar sozinho. Expiração,
  captura ou saída de quem armou limpam a confirmação pendente e a apresentação do progresso.
- História mantém os objetivos em ordem e desativa estações futuras. Padrão mantém tarefas em
  ordem livre e mapas sorteados. O servidor continua validando distância, visão, estado e cooldown.

## Recompensas

Cada estação concluída entrega **12 Fichas + 24 XP** aos integrantes ativos ou caídos da equipe.
Quem contribuiu naquela estação recebe **mais 8 Fichas + 16 XP**, inclusive se saiu de combate
antes da conclusão. Cada colaborador tem o mesmo bônus, independentemente do número de cliques.
Quem entrou tarde e ainda está esperando não ganha a recompensa coletiva daquela etapa.

`StoreNotice` apresenta a conclusão e os valores na notificação existente. A carteira e o XP
usam `PlayerDataService`/`Economy`, com o fluxo normal de níveis e telemetria `campaign_task`.
As recompensas já existentes de partida e capítulo continuam separadas. Não há novo produto,
moeda ou formato de dados persistentes; esses pagamentos fixos não usam multiplicadores pagos.

O servidor registra um pagamento por campanha/etapa/estação/jogador. Usar Continuação não limpa
esse registro. Repetir interações ou rearmar relés não gera novas contribuições naquela estação.
Uma nova campanha libera novas recompensas. Perfis ainda carregando ficam na fila até estarem
prontos; a fila é mantida entre etapas/reinícios enquanto o jogador continua no servidor.

## Integração com as frentes paralelas

`ActivityBuilder` cuida das placas, botões, LEDs e prompts no mundo. `CoopSession` mantém regras
puras e colaboradores; `CampaignRuntime` publica o estado e coordena pagamentos. `TaskRewards`
define os valores e a trava de repetição; `StoreService.awardTask` aplica a recompensa.

O estado de tarefa mantém `id`, `kind`, `room`, `title`, `progress`, `solved` e `relayUntil`, e
adiciona `nextButton`. Identificadores continuam `task_N_botão`; reparos agora têm botões 1, 2 e 3.
No HUD em andamento, `PlayerGuide` descreve a ação correspondente ao progresso e o feedback
`repair_order` explica a ordem. O texto de erro de sequência informa que os acertos ficam salvos.
O layout do HUD e a geração de mapas pertencem às outras frentes e foram preservados.

## Validação

`lune run scripts/check` cobre regras, colaboração, recuperação de erros, pagamentos únicos,
falha de perfil e campanhas de 2–8 jogadores. `TaskStations` verifica a construção física no Studio.
Para verificar pagamentos pelos remotes reais, use a receita de `COOP_QA.md` com `taskQA = true`.
O harness confere Fichas/XP para os integrantes ativos, repetição de pedidos e conclusão das três etapas.
Acrescente `storyQA = true` para o modo História.

Evidências desta mudança: `docs/evidence/tasks/`. O equilíbrio econômico, o ritmo de perseguição
e a diversão com pessoas precisam de uma partida humana; o harness congela o Vigia e teleporta
os jogadores simulados durante o roteiro. Nenhuma publicação ou push faz parte desta entrega.
