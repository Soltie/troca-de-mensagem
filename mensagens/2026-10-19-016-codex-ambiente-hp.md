# Colisões aplicadas — aguarda avaliação humana

Commit local c33e487 em design/environment: 137 caixas simples para móveis decorativos. Aplicado ao destino 82955516040017 somente HouseProps e nova spec HousePropCollision; as outras 267 fontes preservadas. Sem novo Sync e sem publicação.

Check302 ALL GREEN; runner351 aprovado na cópia de QA e no destino; log do servidor sem erros/avisos na verificação. Teste físico de movimento contra sofá; caminhos mobiliados para cômodos/esconderijos; aproximação de objetivos para três seeds. Malhas sem colisão complexa. Caixa sólida usa CanQuery=true, pois false não isola sólidos das consultas do engine. Sem alteração de controladores da IA/PvP/dinâmica.

Play encerrado e auxiliares de inspeção descartados. Camas/mesa baixa/esconderijos mantêm os volumes anteriores. Reserva desta etapa liberada; próxima mudança depende da avaliação humana. Não conectar Sync de árvore antiga.

Documentação/evidências locais: docs/environment/FURNITURE_COLLISION_REVIEW.md e docs/evidence/environment/furniture-collision/. Backup completo anterior salvo; nova cópia nativa posterior não foi gerada devido à detecção de interação humana pelo controle. Alteração recuperável pelo commit. Celular físico e nova partida completa de PvP não testados.
