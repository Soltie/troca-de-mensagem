# Tung Tung Sahur — fundação, floresta e epílogo

17/10/2026. Projeto: `C:/Users/xpg/Documents/tung-tung-sahur`.
Base preservada: `b147ad0`. Subestação 9 e os outros checkouts não foram alterados.

## Entrega

Abra `build/TungTungSahur.rbxlx` ou `build/TungTung_HORROR_FINAL.rbxlx`.
São cópias da mesma build com código e asset da criatura embutidos.
SHA-256: `9703A276DD3FE5EFD62CB7F15E1B3CBAC27A8BA9BBCA5D565A74A874F6583D13`.
Para desenvolver, continue editando somente o `src/` deste projeto.
Não conecte a build às fontes antigas de roblox-teste.

## Casa: causa e correção

Os pisos laterais não encostavam na fachada: havia faixas de 2–4 studs descobertas.
Além disso, o corpo principal da casa e o vestíbulo formam uma fundação em L;
o recorte externo junto ao vestíbulo ficava sem terreno no nível do jardim.
Pelos vãos, era possível cair e enxergar a parte inferior do cenário.

`HouseEnvelope` descreve seis volumes permanentes de solo, recortados pela fundação.
`HouseAccess` constrói esses volumes fora dos cômodos subterrâneos. O solo chega
a oito centésimos de stud abaixo dos pisos existentes, evitando superfícies coincidentes.
Ele não depende da seed, da variante de jardim nem da reconstrução de cada capítulo.
As trancas e o acesso real ao porão continuam funcionando.

A regressão física lança raios numa malha de dois studs em toda a área externa,
antes e depois de três reconstruções da propriedade; também testa explicitamente
as emendas da fachada e o recorte do vestíbulo. Um raio dentro do porão verifica
que o conserto não preencheu o volume subterrâneo. Rotas do jogador e da criatura
continuam cobertas pelos testes de navegação existentes.

## Floresta: cobertura e direção

A reserva anterior removia árvores de praticamente todo o miolo jogável:
ramais de 30 studs se sucediam sem deixar espaço para a vegetação.
`ForestLayout` agora reserva a trilha central, aproximações das tarefas,
entradas dos seis abrigos, construções e área de resgate. Os outros espaços
recebem árvores próximas, com copas maiores e sombra.

No Desafio em dupla, seed 1792276879, foram contadas 515 árvores próximas,
196 delas dentro da faixa central de 130 studs de largura. A contagem varia com a seed.
Os oito lotes de geração cedem a thread; as rotas permanecem transitáveis pelos dois agentes.

Placas centrais que tapavam a vista foram deslocadas para as laterais e viradas para
quem chega do sul. Caminhos repetidos deixam de criar cópias idênticas do mesmo piso.
Marcas do guarda, postes baixos, troncos partidos, mesa com pratos e avisos dão contexto
ao acampamento abandonado.

O perfil da mata usa ambiente frio, névoa mais próxima e menos luz de preenchimento.
A última revisão ajustou somente ambiente, outdoor, cor da névoa e exposição: conserva
silhuetas azuladas nas sombras, em vez de depender de preto uniforme para criar medo.
Uma entrada de depuração `DebugBridge:Invoke("forestChapter", 6..8)`, protegida por
`RunService:IsStudio()`, prepara um capítulo pelo runtime real para inspeção local.
Não é um remote, não existe como ponte em servidor publicado e não desbloqueia progresso real.
A lanterna do jogador continua funcional. O Tung Tung fica sem o PointLight da cabeça
nesses capítulos: ele aparece pela luz do jogador e pelas fontes reais do cenário.

A patrulha e a investigação ficam mais rápidas, e a velocidade da perseguição cresce
moderadamente entre os capítulos 6 e 8, conservando vantagem para a corrida do jogador.
O alcance de visão aumenta 16%, com as mesmas verificações de linha de visão, agachamento,
ruído e esconderijo. Não há rastreamento novo através de paredes.

Os apagões das lanternas da trilha duram seis segundos, com intervalos de 24/20/16 segundos.
Mecanismos e transmissões provocam sete segundos de apagão. Música calma dá lugar a
drone de tensão, silêncio e pancadas laterais, respeitando o mixer existente.
Marcas de orientação e o farol do resgate permanecem disponíveis.

## Tarefas e história

A floresta passa de 17 para 26 objetivos: oito no capítulo 6, nove no 7 e nove no 8.
Os cinco capítulos da casa e os oito capítulos totais foram preservados.

- **A Mata Escuta:** mapa rasgado, aviso do guarda, manivela, guincho, esconderijo,
  respiração e abertura da próxima trilha.
- **Ninguém no Rádio:** fusível, diário com frequência, circuito, puzzle de quatro
  canais, fita de emergência, transmissão, esconderijo e acesso à torre.
- **Eles Ouviram o Sinal:** bateria, antena caída, reparo, código de autenticação,
  puzzle de canais, chamada do resgate, última varredura e corrida para a van.

Pistas precedem os puzzles; a ordem dos canais é reproduzível e validada no servidor.
Acertos permanecem salvos depois de um erro. Itens visuais próprios foram acrescentados
para mapa, bateria, manivela, antena, fita e receptor. História recebe novas gravações,
revelações e pistas sobre uma segunda voz e um segundo perseguidor.
Desafio mantém seu modo e variações; os novos objetivos da floresta têm dependências guiadas.

## Epílogo

A extração física continua obrigatória. A vitória inicia a sequência com resgate,
revelação de Tung Tung Sahur, apresentação do Crocodilo Armadilho e cartela de continuação.
O crocodilo é um modelo geométrico autoral, com mandíbula, dentes, patas, cauda e placas
de armadura; existe somente como cenário local do epílogo.

As figuras são iluminadas pelo farol da van; o Tung Tung não recebe luz própria.
Os atores e o farol temporário são removidos ao acabar/pular a cena.
A cartela aparece nos dois modos, inclusive depois de pular a cinematográfica:

> PRÓXIMO JOGO — A MANSÃO DO ARMADILHO
>
> Vocês fugiram da casa e da floresta.
> Tung Tung Sahur e Crocodilo Armadilho estão procurando vocês.
> A caçada está só começando.

O retorno automático ao lobby passa de 22 para 34 segundos para acomodar o epílogo.
A chamada apresenta a continuação; o próximo jogo completo não foi implementado neste pedido.

## Verificação

Os recibos finais ficam em `docs/evidence/forest-horror/`.
A auditoria de `build/TungTung_HORROR_FINAL.audit.json` confere os 225 arquivos Luau embutidos
contra o disco, sem ausentes, extras ou diferenças, e o preset Realistic/Future.
`validation-history.json` preserva tentativas anteriores e distingue os bytes de cada build.

As imagens com sufixo `fixture` usam preparação explícita de cena/câmera, sem representar
uma campanha vencida. O epílogo foi inspecionado com ambos os atores, remoção após a cena,
cartela visível e TextFits=true nos quatro textos. As primeiras imagens da trilha ainda
mostram as placas antes da correção e não aprovam o visual final.

- Check local: **283 aprovados**, zero falhas, lint/tipos/formatação verdes; sete specs
  do engine ficam fora do Lune.
- História em dupla: **148 verificações**, oito capítulos, derrota/retomada, resgate,
  fuga, lobby e nova votação, antes dos últimos ajustes de placas, solo e luz.
- Desafio em dupla: **150 verificações**, os mesmos ciclos completos, sobre a geometria
  final; a revisão posterior mudou apenas quatro constantes do perfil de luz.
- Observador no cliente do Desafio: os dois atores presentes aos 6 e 11 segundos,
  luz própria desligada; atores removidos e cartela legível aos 16 e 21 segundos.
  Todos os textos da cartela retornaram TextFits=true.
- Runner sobre os bytes finais: **295 aprovados, zero falhas, zero specs puladas**.
- Inspeção final pelo runtime real, via salto de QA: capítulo 6 em Playing,
  oito objetivos, lanterna presente, luz própria da criatura desligada e patrulha
  ativa/descongelada andando de z=684,9 até z=705,7 em dois segundos.
  Captura do jogo: `forest-runtime-final.png`.
- As últimas mudanças após as campanhas em dupla foram os quatro valores de luz
  e a entrada de depuração exclusiva do Studio; as regras normais da campanha não mudaram.
- Boot final: 16 services e 34 controllers. Console sem erros do projeto;
  avisos UIBlox/FoundationProvider pertencem ao CorePackages do Roblox.
- Studio final `67efdd23-1206-4ba0-8d91-c507e9fce420` devolvido a Edit.

Código em `ca0aec9` (solo/fundação) e `d2db940` (floresta/epílogo).
Os arquivos e commits são locais; o manifesto registra os bytes entregues.

O QA de campanha usa dois clientes reais do engine, remotes e seleção de alvo normais.
Teleporte e congelamento da IA apenas preparam interações repetíveis; esse teste
não comprova susto, diversão, equilíbrio com a criatura ativa ou desempenho em celular físico.
Esses aspectos precisam de uma partida humana. Nenhum conteúdo foi publicado ou enviado por push.
