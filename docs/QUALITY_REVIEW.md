# Revisão após o teste humano — casa do Tung Tung

16/10/2026. Branch `codex/house-levels`, worktree `.cache/house-levels`.
Base consolidada: `6f6a6ac` (mapa, levels e ambientação das três frentes já integrados).
Código desta revisão: `a03623a` e `d39669f`.
O checkout principal, arquivos modificados e Studios de outras sessões foram preservados.
Não houve push, publicação, alteração de monetização ou mudança de dados persistentes.

## Armário e biblioteca

**Causa:** a preparação do capítulo desativava todos os objetos com a tag `Interactable`, mas
reativava apenas as portas. O armário aceitava um ID enviado diretamente pelo teste antigo,
porém não aparecia na seleção da mira do cliente. Isso mascarava o bloqueio encontrado pelos jogadores.

A preparação agora reativa todos os esconderijos pelo `WorldService`. O teste passa pela mesma
busca de alvo, cone, distância, linha de visão, estado e envio usados pelo botão E, sem forçar a
habilitação do alvo. A sequência verifica coleta das chaves, desbloqueio físico da biblioteca,
objetivo do armário, entrada, dois segundos de respiração, consumo de oxigênio, saída e próxima missão.

Outro bloqueio cooperativo foi removido: o primeiro jogador a entrar não fecha a porta de entrada
na frente dos colegas que ainda estão no jardim.

## Mapa e colisões

`HouseAccess` complementa as barreiras existentes com geometria que acompanha seus eventos:

- Biblioteca e ala ritualística fecham toda a largura, incluindo passagens aleatórias entre salas.
- Escadas superiores ficam bloqueadas também pelas laterais; o vão do porão recebe uma tampa sólida
  antes de ser liberado. Abrir o mecanismo restaura os caminhos correspondentes.
- O perímetro tem laterais e fundos contínuos, piso da saída e cerca na linha do portão. O caminho
  até a zona de fuga passa pela abertura do portão. Limites superiores impedem saltar para fora
  da propriedade a partir do mirante. Esses limites não interferem nos raycasts de interação.
- A faixa lateral do pátio frontal entre os jardins e o portão tinha trechos sem piso no nível do
  jogador. O piso agora cobre toda a largura; a regressão verifica 36 pontos no pátio e na saída.
- As correções integradas de pisos, tetos, paredes entre pavimentos, escadas, patamares e guarda-corpos
  permanecem. Passagens e escada de serviço sorteadas são restauradas antes de cada reconstrução.

O teste físico mede rotas bloqueadas antes e disponíveis depois dos eventos, paredes laterais em
todos os pavimentos, pisos, cômodos, armários, rotas de jogador/criatura e mirante sem exigir salto.

## Missões e modos

`HouseProgression` é o contrato compartilhado de dependências. Servidor, objetos de missão e HUD usam
a mesma disponibilidade. História conserva os cinco capítulos autorais, sequência contextualizada,
gravações, cartelas e cenas. O Desafio permite dividir coletas e símbolos independentes entre colegas,
mantendo pré-requisitos reais para mecanismos, pistas e puzzles; também conserva seed, passagens,
salões, escada opcional e etapas externas. Os códigos privados continuam só no servidor.

As gravações da História deixaram de aparecer no Desafio, onde poderiam comentar o objetivo errado
quando a equipe concluía tarefas em outra ordem. O guia distingue tarefas disponíveis e bloqueadas.
Nomes de cômodos aparecem em português. O reparo mostra **isolar → encaixar → testar** e somente
o botão correspondente ao passo atual fica disponível. Erros de símbolos preservam os acertos.
Na retomada após derrota, a disponibilidade deixa de consultar o capítulo transitório zero e usa
o capítulo do plano somente durante a partida. A regressão reproduz a transição e o harness final
reprova também quando o console contém um erro/aviso inesperado.

## Apresentação

- A vitrine do Tung Tung excedia a altura do painel e invadia o rodapé. A aba Jogar agora rola,
  recorta o conteúdo corretamente e mostra a vitrine inteira, incluindo o texto inferior.
- O título cabe na coluna, a dica inferior usa truncamento e o menu pode reduzir a escala em telas pequenas.
- O HUD compacto separa inventário e barras e coloca o saldo abaixo do objetivo; as gravações não
  ocupam o mesmo espaço dos recursos inferiores. Há verificações geométricas em quatro resoluções.
- Uma segunda definição antiga ao fim de `CinematicShots` sobrescrevia a abertura e o laço do menu,
  ignorando os enquadramentos novos. Ela foi removida: as câmeras externas voltam a enquadrar a
  varanda e a casa. O final autoral em três planos foi preservado.
- Iluminação, áudio por cômodo, rig, animações e opções de conforto das frentes anteriores continuam
  integrados. Não foram substituídos por um conjunto paralelo de efeitos.

## Verificação e reprodução

`lune run scripts/check`: **270 testes puros, ALL GREEN**, sem lint/tipos/formatação pendentes.
Runner físico/integrado no Studio: **280 aprovados, zero falhas**, sem erros/avisos do projeto.
História em dupla: **79 verificações**, incluindo derrota, retomada gratuita, resgate, cinco
capítulos, armário/respiração pela mira do cliente, fuga, reinício por voto e console limpo.
Desafio em dupla: **81 verificações** com os mesmos ciclos, tarefas em jardins/interiores,
reparo em três passos e console limpo. Os resultados finais registram `Playing`, capítulo 1,
porque o teste termina **depois** de vencer e reiniciar com sucesso.
As evidências do Studio e das campanhas estão em `docs/evidence/quality-review/`.
Os primeiros recibos de falha são de uma tentativa de ler no servidor um atributo escrito apenas
no cliente pelo novo teste; o recebimento foi corrigido para usar a resposta normal do servidor.
Eles são mantidos como histórico e não contam como aprovação.

Build final: `build/Casa_QUALIDADE_VALIDADA.rbxlx`. Abrir a cópia local no Studio; nenhuma conexão nova
de Script Sync é necessária, pois ela contém as fontes embutidas. As fontes reproduzíveis permanecem
no worktree desta branch. Nunca copie uma árvore `src/` inteira sobre um checkout com trabalho concorrente.

SHA-256: `97F6B3BD563234537FBCC055406E65EC42EE88A7C56AD457A3AA3725285A65F1`.
O mesmo arquivo foi copiado para a pasta `build` do projeto principal. O Studio próprio voltou a Edit;
os clientes de teste encerraram e as sessões de outros trabalhos foram mantidas.

## Limites

Os clientes da simulação são clientes reais do engine com os remotes normais. O roteiro prepara
posições por teleporte e congela a IA para repetir as interações; derrota e resgate são acionados
de forma controlada. Caminhos físicos e seleção da mira são verificados separadamente. Isso não
equivale a uma sessão humana com perseguição ativa, nem comprova diversão, susto ou equilíbrio.

As verificações de tamanho do HUD não substituem testes de toque, desempenho e leitura num celular
físico. A geometria principal da mansão continua autoral; o Desafio varia circulação, locais e tarefas.
Esta entrega é local. A versão já publicada do jogo não foi atualizada.
