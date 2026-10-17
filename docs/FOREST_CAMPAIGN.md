# Continuação da floresta — 16/10/2026

A fuga da casa (capítulo 5) agora é uma evacuação intermediária: a equipe atravessa o portão e começa o capítulo 6. Somente o resgate ao fim do capítulo 8 encerra a campanha. História e Desafio preservam suas regras na casa; a continuação da floresta tem dependências sequenciais nos dois modos. Jogável solo ou com até seis pessoas, conforme a configuração consolidada.

## História e missões

- **06 — As três pancadas:** alcançar a trilha, recuperar o mapa do guarda, usar um abrigo, prender a respiração por dois segundos e abrir o caminho do acampamento. A maldição saiu junto com os sobreviventes.
- **07 — O acampamento vazio:** encontrar um fusível, ler o diário, consertar o rádio em três passos, se esconder e abrir a trilha da torre. O guarda descobriu que o eco sobrevive ao incêndio; uma voz responde ao pedido de ajuda.
- **08 — Antes do amanhecer:** recuperar a bateria, restaurar o gerador, transmitir pela torre, evitar a última patrulha e acender o sinal. A van chega à estrada; a equipe precisa entrar na área do farol verde antes do tempo acabar.

O final tem três planos próprios na floresta, encerramento FIM e retorno automático da equipe ao lobby. O mapa florestal é removido e a casa/lobby é restaurada. Uma nova campanha exige votos novos. Derrota retoma gratuitamente o capítulo atual; companheiros derrubados continuam podendo ser resgatados.

## Mapa e integração

Cada etapa reconstrói sua floresta em uma região própria, a partir de seed. Chão cenográfico de 2400 × 2400 studs, bosque em camadas até a névoa, trilha principal, ramais, lanternas, paredões rochosos, seis abrigos físicos (um ocupante cada), barracas, posto de rádio, torre e van. Limites impedem sair da área jogável ou cair no vazio. Troncos próximos bloqueiam visão e movimento; árvores distantes são cenário. Os lotes de árvores cedem a thread durante a construção.

Código novo: ForestCatalog (roteiro/locais), ForestPlan (plano privado e validação), ForestBuilder (mundo/abrigos), ForestCinema (final). Integração pelo runtime/WorldService existentes. Nenhum bootstrap ou remote paralelo. Interações continuam passando por ServerNet, distância, visão, estado e cooldown; esconderijos reutilizam PlayerStateService, oxigênio, ocupação e a IA existente. As soluções não são publicadas no HUD. Recompensas e conclusão de história passam a reconhecer oito capítulos sem alterar o formato persistente dos dados ou IDs de compras.

A frente mobile/lobby foi integrada por diffs, preservando toque, mochila, HUD responsivo, votação e devolução dos avatares ao pátio. A camada de apresentação/cinema será identificada pelo commit no recibo consolidado. Nenhum worktree de outra frente foi alterado; não se deve substituir o src principal concorrente pela árvore inteira.

## Validação

Recibos finais e proveniência da build única: `docs/evidence/forest-campaign/` e `docs/THREE_CHATS_RELEASE.md`.

QA automatizado usa clientes reais, seleção/interações do cliente e remotes normais; teleporte e congelamento da IA preparam cenários. Essa verificação técnica não mede diversão, equilíbrio de perseguição ou desempenho em celular/iPad físico. Não houve push ou publicação.
