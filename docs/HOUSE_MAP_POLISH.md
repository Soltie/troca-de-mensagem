# Casa — correção estrutural e polish de apresentação

Data: 16/10/2026. Branch local: `codex/house-map-polish`, baseada em `0dd8a27`
(`claude/final-polish`), a versão da casa mostrada nas capturas do pedido.
O checkout principal continua em `claude/polish-terror`; seus arquivos modificados foram preservados.
Não houve publicação nem push.

## Problemas encontrados

- A escadaria tinha apenas uma passarela central e dois patamares estreitos por nível.
  O restante da projeção ficava aberto, expondo o vazio e o subsolo entre rampas.
- As paredes de cada andar terminavam em 15 studs, mas os níveis estavam separados por 16.
  Faltavam fechamento lateral do porão, teto do corredor superior e continuidade no acesso ao hall.
- Pathfinding conseguia traçar rotas, mas isso não comprovava a integridade do restante do piso/envoltória.
- As câmeras e legendas da abertura ainda enquadravam as coordenadas da subestação.
- As cenas de capítulo duravam quatro segundos, enquanto o seletor de legendas esperava
  quatro segundos por linha: duas das três linhas nunca eram exibidas.
- A cartela do capítulo permanecia sobre o segundo enquadramento; mensagens de objetivo também
  disputavam espaço com as celebrações de intervalo.

## Implementação

### Estrutura e circulação

`Shared/Game/HouseLayout` concentra níveis, limites, escadas e recortes dos pisos. `HouseArchitecture`
preenche cada nível até as fachadas, deixando aberto somente o vão da escada que chega àquele piso.
Há guarda-corpos nos vãos, proteção contínua nas laterais das rampas, corrimãos e degraus visuais.
A colisão de caminhada continua sendo uma rampa contínua para evitar prender personagens nos espelhos.

Paredes e lintéis agora fecham a altura completa entre pavimentos. O subsolo recebe fundação e
fechamento frontal; o último corredor tem teto. Patamares conectam corredor e escadas sem a antiga
fresta no encontro. Os cinco capítulos, cômodos, alturas e destinos dos objetivos foram mantidos.

Molduras, lambris, rodapés, frisos, vigas, placas voltadas para o corredor e iluminação de patamar/escada
reforçam a leitura dos acessos. Detalhes pequenos não bloqueiam raycasts de interação ou navegação.

### Materiais e assets

Paredes usam reboco; subsolo usa tijolo; pisos usam madeira ou ardósia. Tetos deixaram de parecer
paredes de madeira. Vidros estruturais deixaram de emitir neon, a iluminação colorida dos cômodos foi
suavizada, e bloom/exposição foram reduzidos. Moedas metálicas preservam forma e cor, com menos halo.

Uma televisão CRT foi construída por código na sala de estar, com gabinete, seletores, tela emissiva
suave e transmissão por capítulo. `TelevisionController` atualiza a tela a 8 Hz somente a até 55 studs;
o movimento da linha de varredura respeita as opções de movimento e flashes. Não há vídeos remotos,
uploads novos, soluções de puzzle expostas ou dependência nova de EditableImage para essa televisão.
Os assets e clips existentes do Tung Tung foram preservados.

### Cinema, animação e narrativa

Abertura, laço do menu e fuga usam a varanda em z=64 e o portão em z=98. A abertura mantém nove
segundos e a aparição existente do Tung Tung; a caminhada da varanda faz um arco contínuo com velocidade
da animação proporcional ao deslocamento, eliminando a inversão instantânea de direção.

Cada capítulo da História tem dois planos de quatro segundos. `CinematicController` passa a ser dono
único das legendas e da cartela; a cartela sai no segundo plano, e pular restaura a apresentação normal.
`HouseBroadcast` fornece três falas por capítulo, também usadas pela televisão. Mensagens de descoberta
somem durante o intervalo para não cobrir as recompensas.

A história agora conecta a fita, o relógio parado às 03:12, a família desaparecida, a máscara e o coração.
A revelação é que a criatura também está presa à casa. A ordem de objetivos e os puzzles continuam iguais;
as pistas de símbolos/código continuam derivadas do plano privado do servidor.

### Carregamento concorrente de personagens

O QA com seis clientes revelou um timeout no primeiro capítulo durante restart rápido. Pedidos enfileirados
de join/restart podiam recarregar novamente um avatar já pronto ou descartar um carregamento recém-concluído
porque o capítulo tinha mudado durante `LoadCharacterAsync`. O runtime agora reaproveita esse avatar fresco
para a versão vigente e ignora pedidos já satisfeitos. Não aumenta timeouts nem altera regras de progresso.

## Reprodução

Abra a build `Casa_POLISH_FINAL.rbxlx` entregue na pasta `build` do projeto principal.
Ela contém código e o asset existente do Tung Tung; não precisa trocar o Script Sync da place compartilhada.
Escolha História para ver as cenas por capítulo; Desafio preserva variações de itens e códigos.

Fonte isolada: `C:\Users\xpg\Documents\roblox-teste\.cache\house-map-polish`.
Para reproduzir: `lune run scripts/check`, depois
`rojo build default.project.json --output build/Casa_POLISH_FINAL.rbxlx`.

## Validação

Recibos finais e resultados ficam em `docs/evidence/house-map-polish/VALIDATION.md`.
Check completo: ALL GREEN, 262 testes puros. Runner na build entregue: 270 aprovados, zero falhas.
História com seis clientes: 68 verificações, cinco capítulos e Won, após a correção de spawn.
Desafio em dupla: 64 verificações e Won em revisão anterior à última proteção lateral/correção de spawn.
O runner físico agora mede pisos de patamares, fechamento externo entre níveis e cobertura,
além de verificar rotas sem salto para jogador e criatura, esconderijos e saída do ritual para a floresta.
O teste de geração também verifica posições e aproximações dos objetivos para 20 seeds em cada capítulo.

As capturas `television.png` e `hall-before-final-light.png` documentam inspeção local com câmera posicionada
para QA. Foram feitas antes do último ajuste de luminárias das escadas e da proteção lateral invisível.
`hall-final.png` mostra a revisão entregue. O console do Play final ficou sem erros/warnings do projeto.

## Limites

Este trabalho corrige a estrutura e melhora a apresentação; não substitui todos os móveis e modelos por
assets artísticos novos. Móveis decorativos herdados continuam sem colisão. A geometria da mansão é fixa;
o Desafio varia objetivos/itens/códigos dentro dela, não gera uma nova planta arquitetônica por rodada.
As falas novas são legendadas, sem dublagem. Os clips existentes foram reaproveitados, sem animações
novas de corpo inteiro. Destruição e outros efeitos herdados não receberam simulação física nova.

Os roteiros de campanha congelam a IA e teleportam os clientes para preparar ações. Sucesso automático
não comprova ritmo, perseguição, diversão ou desempenho em celular físico. Esses pontos precisam de jogo humano.
