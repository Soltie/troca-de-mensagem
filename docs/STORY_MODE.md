# Modo História — O Último Turno

Direção e implementação inicial: 16/10/2026. SUBESTAÇÃO 9 continua com o **Modo Padrão**
cooperativo aleatório existente e recebe um **Modo História**, ambos para **2–8 jogadores**.

## Entrada e escolha

O menu aparece antes de a rodada começar. Cada integrante escolhe História ou Padrão;
o servidor guarda um voto por pessoa. Com ao menos dois integrantes e maioria absoluta,
começa a contagem de cinco segundos. Empate ou ausência de maioria aguarda votos.
O voto pode mudar antes do início; repetição do mesmo voto não reinicia a contagem.
Durante a partida, o servidor recusa trocas de modo. Ao terminar, a maioria vota com R
para voltar ao menu e escolher a próxima partida.

Esta entrega usa **um modo por servidor**, com votação da equipe. Não há teleporte,
buscador de servidores, criação de sala privada ou matchmaking entre servidores.
Um jogador que chega durante uma partida aguarda o capítulo seguinte, seguindo a
regra cooperativa existente. O limite de oito integrantes é aplicado pelo runtime;
a configuração pública de capacidade no Creator Hub não foi alterada.

## A história

Às 03:12, uma equipe de manutenção chega à Subestação 9 para investigar um apagão.
A equipe anterior desapareceu. O livro de ponto na guarita registra um funcionário que
nunca saiu: **Elias Moura**, o vigia noturno.

No acidente que condenou a instalação, Elias tentou liberar a evacuação. A central
cancelou sua ordem e exigiu que ele protegesse os circuitos. Preso à instalação pelo
acidente, ele ainda cumpre esse comando. Cada luz acesa é um posto que precisa guardar;
é por isso que ele persegue lanternas. A equipe descobre que restaurar a energia
prolonga o turno. Para sair e libertá-lo, precisa isolar o circuito principal e abrir o
portão com a alimentação independente.

O terror vem da perseguição, da informação incompleta e das ordens conflitantes.
Sem sangue ou violência gráfica. As falas são texto legendado; dublagem não foi produzida.

## Capítulos e progressão jogável

| Capítulo | Sequência fixa de objetivos | Revelação |
| --- | --- | --- |
| 1. A Equipe que Não Voltou | Reparar rádio na recepção → recuperar registro no escritório (3–1–2) → relé cooperativo no gerador | Elias nunca registrou sua saída; uma fita alerta que algo usa os olhos dele. |
| 2. Ninguém Deixa o Posto | Reconstruir fita no arquivo (2–3–1) → isolar sinal na sala de controle em dupla → reparar isolamento na galeria | A central impediu a evacuação. O acidente vinculou Elias aos circuitos. |
| 3. O Fim do Turno | Desarmar alimentação nas bombas → desligar gerador (3–2–1) → liberar relé do portão no pátio técnico em dupla | A equipe encerra o comando que mantém o Vigia no posto. |

Cada capítulo começa com **12 segundos protegidos de cinematográfica**, com três planos
de câmera e três legendas. Os participantes ficam imobilizados e o Vigia só é ativado após
a cena. Pular a cena devolve a câmera, mas mantém a espera do servidor até o grupo ficar
pronto. O conforto da câmera e a opção de pular usam CinematicController/CameraController.

As nove tarefas têm títulos narrativos nas placas. O servidor exige a ordem do roteiro;
confirmar uma tarefa futura não altera progresso. Relés pedem dois jogadores distintos;
o fallback existente permite ao último sobrevivente concluir após desconexões.
Capturas, resgates, espectadores e retorno de colegas no capítulo seguinte reutilizam
o sistema cooperativo atual. Não há save de capítulo entre sessões nesta primeira versão.

Ao concluir o terceiro capítulo, a subestação fica sem energia e o portão abre por seu
circuito independente. A equipe precisa evacuar pelo portão; a vitória mantém a regra
existente de aguardar os sobreviventes e resgates. O epílogo registra:

> ELIAS MOURA — TURNO ENCERRADO.

No rádio, uma última palavra: “Obrigado.”

## Mapa fixo

StoryPlan define explicitamente as nove salas da ala norte, suas orientações e onze
conexões. Não chama o gerador aleatório. Usa o núcleo existente da subestação e a mesma
planta em todos os capítulos e replays, para qualquer grupo de 2–8.
As estações e códigos também são constantes. A reconstrução entre capítulos restaura
o estado físico da mesma planta; não sorteia uma planta diferente. A semente de estado
é fixa, 90312. O lobby anterior à escolha ainda usa o mundo base do servidor.

O número de objetivos narrativos é sempre três por capítulo, inclusive com oito pessoas.
O grupo maior distribui cobertura, sequência, confirmação de relés e resgate; não adiciona
tarefas aleatórias nem muda o roteiro. O padrão conserva sua escala de tarefas por grupo.

## Arquivos e integração

- `Shared/Game/StoryCatalog`: roteiro, revelações, planos e legendas.
- `Server/Campaign/StoryPlan`: planta e atividades fixas.
- `Shared/Game/GameModes`: contagem pura de votos elegíveis.
- `CampaignRuntime` e `CoopSession`: seleção, trava de modo, cenas protegidas e ordem.
- `ModeMenuController`: menu e escolha pelo remote SelectGameMode, com Guard e rate limit.
- `StoryController`: objetivo narrativo, gravações e cenas via API pública CinematicController.
- `ActivityBuilder`: títulos de missão nas placas físicas.
- `Specs/StoryMode`: maioria/quórum, invariância do mapa, campanha completa 3–8,
  ordem das tarefas, duração das cenas e regressão do gerador padrão.

## Validação

Check local inicial: **ALL GREEN, 206 testes aprovados**, sem erros/warnings de lint/tipos.
Runner no Studio: **229 aprovados, zero falhas, zero specs puladas**.

| Execução | Resultado | Evidência |
| --- | --- | --- |
| Menu, um jogador, clique real em História | Voto chega ao servidor; aguarda mínimo de três | QA dirigido em StoryModeQA2; captura inline no chat |
| História, três clientes | Won, capítulo 3, 59 verificações | [story-3-clients.txt](evidence/story-mode/story-3-clients.txt) |
| História, oito clientes | Won, capítulo 3, 84 verificações | [story-8-clients.txt](evidence/story-mode/story-8-clients.txt) |
| Padrão, oito clientes | Won, capítulo 3, 134 verificações; mapas distintos | [standard-8-clients.txt](evidence/story-mode/standard-8-clients.txt) |

As campanhas verificaram seleção pelo remote de clientes, replay com mapa idêntico,
captura individual, resgate por outro cliente, distância, desconexão/reentrada,
navegação de jogador e Vigia, tarefas e saída de todos os sobreviventes.
UI de jogo e restauração da câmera foram conferidas nos clientes; as legendas ganharam
uma área própria de múltiplas linhas após uma primeira captura mostrar corte no overlay
genérico. A leitura das dimensões confirma texto contido na área de legenda.
Os títulos de cena usam uma cartela curta de capítulo e o nome abaixo, para caber também
na viewport de 812 pixels. Essa correção final de apresentação é separada do QA multiplayer.

A primeira build encontrou um atributo não cadastrado no GameState; removido antes do QA
aprovado. A primeira simulação de replay encontrou comando de teste repetido que não era
replicado ao cliente; o harness passou a usar serial. Esses ensaios iniciais não são aprovações.
Também houve aviso UIBlox/ChatScript dos CoreScripts do Studio; não é log do código do jogo.

Fontes e build descartável identificadas por SHA-256 em
[manifest.json](evidence/story-mode/manifest.json). O Dev com Script Sync foi apenas
inspecionado para confirmar as duas raízes sincronizadas, sem interromper o QA alheio.
A build final de apresentação, com a cartela curta, está identificada em
[release-manifest.json](evidence/story-mode/release-manifest.json); o runner repetido nela
teve [229 aprovados](evidence/story-mode/studio-tests.txt). No teste dirigido da cena,
Espaço cancelou a câmera em cerca de 0,12 s: modo normal, legendas ocultas, root ainda
ancorado e intervalo do servidor ainda ativo. Esse ensaio de apresentação altera apenas
atributos temporários durante Play, não a place em Edit nem os scripts sincronizados.

Para repetir a campanha com clientes simulados, abrir uma build descartável atual e executar
em Edit a receita de COOP_QA com argumentos `campaignQA=true`, `storyQA=true`,
`modeMenuQA=true`, `players=3` (depois 8). A seleção parte dos clientes pelos remotes reais.
CampaignHarness verifica que replays e capítulos preservam o mapa; também testa resgate,
entrada tardia, distância, navegação, tarefas e extração. Teleportes de setup e Vigia
congelado no harness não comprovam equilíbrio, duração ou diversão com pessoas reais.

Pendências de produção: dublagem, animações específicas de Elias nas cenas, cenário artístico
exclusivo para flashbacks, balanceamento humano com 3–8 pessoas e progresso persistente
por capítulo. A história inicial é jogável com as mecânicas e os cenários disponíveis.
