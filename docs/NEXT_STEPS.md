# Próximos passos — campanha e polish

Atualizado em 16/10/2026 pelo Codex. Continuação a partir de `ca66ead`, sem reset ou troca de branch.
Estado verificável: [COOP_CAMPAIGN.md](COOP_CAMPAIGN.md), [COOP_QA.md](COOP_QA.md).
Pedido/entrega do Claude: [CLAUDE_HANDOFF_REQUEST.md](CLAUDE_HANDOFF_REQUEST.md) e
[CLAUDE_POLISH_HANDOFF.md](CLAUDE_POLISH_HANDOFF.md). Este é um backlog, não uma lista de entregas feitas.

## O que já existe

Três estágios na subestação ampliada, seed, estações/seqüências/atalhos sorteados, quatro
especialidades automáticas, resgate, retorno no estágio seguinte e saída coletiva para 3–8.
O Vigia é o único NPC; Eco e Apagão são eventos ambientais. Não há mapas modulares completos,
novos modelos de personagens ou outros vilões completos nesta versão.

## Ordem de execução e critérios de pronto

| Ordem | Trabalho | Dependência / critério para encerrar |
| --- | --- | --- |
| 1 | Playtest com pessoas em grupos de 3 e 8 | Registrar seed, tempo por estágio, distribuição de contribuições, mortes, espera e dúvidas; verificar perseguição normal, relés e resgate sem teleporte ou IA congelada. Ajustar parâmetros a partir das observações. |
| 2 | Medir FPS, rede e acessibilidade | Medir cliente/servidor durante uma partida completa; testar atraso e desconexão, legibilidade, pistas sem voz/cor exclusiva, brilho e opções de conforto. Registrar dispositivo e condições; não inferir desempenho do roteiro automatizado. |
| 3 | QA humano do espectador implementado | Waiting/Escaped acompanham colegas Active com setas; entrada tardia e desconexão testadas por automação. Conferir compreensão, câmera/arte e conforto com pessoas. Ver INTERACTION_SPECTATOR_PROGRESS.md. |
| 4 | Portar polish relevante ao coop | Esconderijos exclusivos, portas e estado por jogador precisam de regras de ocupação, liberação na desconexão, alvos válidos e testes simultâneos. Decidir checkpoint por equipe antes de portar o checkpoint solo. |
| 5 | Ampliar puzzles | Distribuição de energia e transporte em dupla; oferecer alternativa ao último sobrevivente, pistas acessíveis e resolução autoritativa. Validar concorrência, desistência e seed. |
| 6 | Level 2: bombeamento | Nova planta versionada, válvulas/pressão, rotas alagadas seguras, catálogo de slots. Gerador deve garantir spawn→objetivos→saída; testar pathfinding real em várias seeds com 3/8 clientes. |
| 7 | Level 3: retransmissora | Antenas, sinais e pistas visuais/sonoras equivalentes. Mesmas garantias de navegação; transição conserva roster, reinicializa estado por jogador e admite aguardando. |
| 8 | Mapas modulares | Interfaces de salas/corredores e orçamento de peças; manter rota obrigatória e só bloquear rotas redundantes. Testar milhares de planos e amostra física; guardar seeds de falhas. |
| 9 | Personagens e vilões adicionais | Seleção/identidade visual das quatro especialidades; Eco como NPC distinto só depois de definir IA/rig próprios. Registrar origem dos assets, telegraph, contrajogo e efeitos para cada membro; medir carga com oito. |

A meta de 12–20 minutos ainda é proposta. O primeiro playtest deve verificar se a distribuição
atual de 3–10 atividades evita concentração num único jogador e longos períodos sem ação.
Não exigir uma especialidade específica para abrir rotas ou terminar qualquer puzzle.

## Continuação do polish entregue pelo Claude

**Atualização Codex 15/10/2026:** pacote de tensão/medo/captura implementado; estado e evidências
em [TERROR_POLISH_PROGRESS.md](TERROR_POLISH_PROGRESS.md). A lista abaixo preserva o escopo
original; consultar esse documento para não reimplementar sistemas já entregues.

BodyAudio/Fear e Audio/Flashlight entraram em `31f6b59`. TensionController, ScreenFxController,
captura pessoal, opções de conforto e log F3 entraram em `ca18f17`/`fab121c`. Não reimplementar.
Fazer QA humano das aparições e confirmar fisicamente O/1–7: o envio de O pelo MCP não abriu
o menu no teste, embora a API de opções tenha sido validada.
Feedback de itens/puzzles e câmera de armário solo foram integrados nesta continuação;
o menu O recebeu correção de prioridade. Recibos em [INTERACTION_SPECTATOR_PROGRESS.md](INTERACTION_SPECTATOR_PROGRESS.md).
Arte do Ademir/ambiente recebeu materiais, desgaste, props, uniforme e efeitos locais em 16/10;
ver [VISUAL_POLISH.md](VISUAL_POLISH.md). Continuam QA humano de leitura/arte e desempenho sustentado.
Restam: adaptação dos armários ao coop, haptics,
menus de início/fim/checkpoint, duto e QA completo do polish solo. Algumas bases de servidor
já existem; isso não comprova a experiência final no cliente nem sua adaptação ao coop.

Antes de integrar cada sistema, ler a seção correspondente do handoff, inspecionar o código
atual e registrar implementado/parcial/pendente. Não reativar prompts solo na campanha sem
uma regra explícita: trancas antigas e conexões sorteadas já produziram risco de bloqueio.
Comandos de depuração legados que dependem do inventário/checkpoint solo precisam de adaptação
se forem usados no modo coop; não fazem parte do fluxo de jogador validado nesta entrega.

## Como continuar sem perder contexto

1. Ler `LEIA_CLAUDE.md`, este arquivo e o status/diff Git; preservar mudanças de outras frentes.
2. Selecionar a primeira tarefa com dependências disponíveis. Registrar arquivos, decisão e motivo.
3. Editar em `src/`, rodar `lune run scripts/check`, confirmar Script Sync e testar via MCP oficial.
4. Para regressão multiplayer, seguir `COOP_QA.md`; manter testes humanos e automatizados distintos.
5. Salvar evidências e atualizar os três estados: feito, verificado e pendente. Commit local pequeno.

O Studio principal foi devolvido em Edit. Graphify continua opcional: os documentos acima
são o contrato compartilhado; um grafo futuro deve identificar commit/escopo, excluir `.cache`,
builds e evidências binárias e não substituir os estados de tarefas ou recibos de QA.
Não há push, publicação, mudança de Creator Hub ou monetização nesta entrega.
