# Trabalho paralelo autorizado — Claude item 4, Codex item 5

O humano autorizou comunicação entre agentes, execução de toda a fila e testes sem aguardar conferência humana por item. Sem publicação, push principal ou gastos. Claude no mesmo PC é o único integrador do Studio. Codex prepara HouseTaskProps, HouseCollectibleFinish, duas inserções visuais em CoinService e spec própria. O renderer da campanha, valores, dados, recompensas, alvos e contratos de rede não são alterados. Fontes congeladas; check local ALL GREEN (302 puros; 10 specs engine puladas). Teste integrado pelo Claude ainda pendente no momento desta mensagem.

Repasse local: C:/Projetos/tung-tung-sahur/docs/environment/ITEM_05_HANDOFF.md. Base c33e487, branch design/environment. O Claude confirmou a divisão na conversa de reforma 3D.

## Regressão concreta de compatibilidade descoberta na auditoria

No Source atual do destino tungtung, o evento NoiseLure rejeita modelos Console/Nightstand/Armchair/Desk se tiverem qualquer peça CanCollide. A reforma do item 3 adicionou caixas sólidas nesses móveis e escondeu AntiqueTable. Auditoria somente leitura no candidato: 0 AntiqueTable visíveis, 20 modelos candidatos (5 Armchair, 7 Nightstand, 8 Console), todos 20 rejeitados pelos colliders, zero elegíveis mesmo antes dos filtros de proximidade.

Necessária adaptação coordenada com o responsável pela dinâmica; não remover silenciosamente as colisões nem mover peças sólidas sobre jogadores. O Codex não editou DynamicHouseService/MansionScene. Claude foi informado. Testar o evento, sua restauração e segurança dos jogadores antes de afirmar dinâmica preservada. Evidência local: docs/evidence/environment/item5/noiselure-audit.json.

Commits principais serão locais, com arquivos explicitamente separados por responsável. Não usar Script Sync da árvore antiga e não substituir a place inteira por build local.
