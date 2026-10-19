# Polimento do salto e correção do mouse — pedido direto do humano

Aplicado no tungtung82955516040017 via MCP, sem Sync adicional e sem publicação.
HEAD local d41b62736acfb19e17fd9c0db0894be254ee9688, branch codex/mansao-dinamica.
[Pacote incremental](../entregas/codex-dinamica/Polimento_Salto_Camera_2026-10-18.zip).
SHA256: 0900b5899a7f4d567b7daf9d7a1dff13d62930f01a3fb690a5783601168df789.

Antes das duas correções, incorporei ao disco as quatro fontes de iluminação já presentes na place (HouseLights, HouseScenery, LightingProfile e sua spec), commit c338392. Luz aprovada preservada. Não apliquei o patch0011 de escala nem outros itens do repasse do Claude, pois o pedido atual é salto/câmera.

Salto: curva compartilhada VaultMotion, preparação, apoio dos braços, pernas assimétricas recolhidas e recuperação no pouso;0,88s, avanço por Heartbeat e interpolação visual antes da câmera. Rota/apoio/distância continuam validados no servidor. Restaura colisões, AutoRotate e limpa os atributos de interpolação. Animação procedural no rig, sem novos IDs externos, com movimentos de câmera respeitando conforto.

Câmera: Modal dos botões agora só é ativado se a hierarquia inteira estiver visível. Botões de painéis fechados não interferem na primeira pessoa; painéis abertos seguem liberando cursor. Validação física: câmera girou39,11° com delta97/13 e botão direito solto no evento e ao final (movimento/foco por clique esquerdo, sem arrastar).

Check337 ALL GREEN; runner Studio349; QA com dois jogadores77, incluindo janela, obstáculo, cooperação, restauração e isolamento do PvP. Sonda modal: oculto=false; aberto=true/Default; fechado=false/LockCenter; zero modais ativos em painéis ocultos.
268 fontes comparadas por SHA256, sem divergências. Partida completa de Midnight Hunt não foi repetida nesta revisão;72 é evidência da versão anterior. Console conserva avisos preexistentes de asset81504106/EditableImage com fallback/UIBlox, sem erro novo dos módulos alterados.

Pacote: sete fontes mais relatório, patch sobre c338392, bundle incremental desde2433045 e evidências. A imagem de pose usa pausa em43% e luz temporária de QA, identificadas no relatório. Todos os auxiliares eram exclusivos de Play e foram descartados ao parar.
Studio em Edit. Não sincronizar árvore antiga sobre esta versão. O bundle inclui a conciliação da iluminação; não usar só o patch sobre uma base sem c338392.
