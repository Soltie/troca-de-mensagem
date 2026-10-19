
## Pedidos de 19/10/2026 (madrugada) — feitos (1–6, 8); 7 aguarda escolha do humano
1. Abertura: plano "TRÊS PANCADAS" refeito (silhueta na porta, recorte frio, relâmpago, tele); legendas só depois do título.
2. Lanterna: foco redondo definido; luz "bugando" em alguns cômodos (revisar as 4 luzes somadas e a falha proposital).
3. Tung Tung dourado e brilhante demais: deixar mais escuro/fosco e assustador (jogo e cenas).
4. Porta que fecha sozinha: animação, leve tremor e batida alta.
5. Fresta segurada demais: cair no chão, levantar, folhas do guarda-roupa abrindo mais.
6. Portas: apertar E várias vezes enchendo a barra; som a cada batida, leve aumento de FOV; ao abrir, som mais alto e tremor.
7. Barricada "INTERDITADO" da escada parece solta no cômodo (explicar e propor alternativa).
8. Pancada do Tung Tung: em vez de morrer, o jogador cai e fica rastejando (animação de rastejar) até ser resgatado.

## Anotado para depois do incêndio (19/10/2026)
9. Chaves mais escondidas: dentro de gavetas (abrir a gaveta para achar) ou em lugares menos óbvios — "está tudo
   muito fácil". Fazer só depois de terminar o capítulo do fogo (gasolina, isqueiro, casa desmoronando).

## Teste jogado de todos os capítulos (19/10/2026, bot com pathfinding, Tung Tung congelado)
Todas as tarefas dos capítulos 1–8 foram cumpridas andando; nenhum erro no console. Tempos só andando:
cap. 1 ≈ 64 s · cap. 2 ≈ 50 s · cap. 3 ≈ 2 min · cap. 4 ≈ 80 s · cap. 5 ≈ 3 min + fuga · cap. 6 ≈ 2 min ·
cap. 7 ≈ 2 min · cap. 8 ≈ 2 min. Não verificado andando: a saída final da floresta (cap. 8; coberta pelos testes).

Achados de design (não são bugs):
- Capítulos curtos e fáceis: itens em pedestais à vista, perto um do outro.
- Enigmas de 4 botões dá para resolver no chute: errar só faz barulho e não zera o progresso.
- Cap. 1 sem ameaça: o Tung Tung fica adormecido o capítulo inteiro.

## Ideias de melhoria (19/10/2026)
1. Itens escondidos de verdade: gavetas, armários, baús, debaixo da cama (abrir com som), lugar sorteado a cada partida.
2. Enigma que pune o chute: errar zera a sequência, faz barulho alto e chama o Tung Tung.
3. Susto roteirizado por capítulo (cap. 1: vulto na janela no relâmpago, porta batendo atrás, passos no andar de cima).
4. Avisos antes do perigo: luz piscando e bastão ecoando antes de ele aparecer (estilo DOORS), para ser justo com crianças.
5. Variedade do Tung Tung: espiar pela porta, bater na parede do cômodo ao lado, ficar parado ouvindo.
6. Dica automática se o jogador ficar perdido (> 60 s sem progresso): sussurro/ponteiro da lanterna pisca.
7. Modos de dificuldade (Criança / Normal / Pesadelo): velocidade do Tung Tung, fogo, quantidade de itens.
8. Recompensas de rejogar: conquistas (sem ser pego, speedrun), fitas VHS e finais diferentes.
9. Teste em celular (fogo, chuva e desmoronamento são pesados) e revisão de botões na tela.

## Ideias trazidas de outros jogos de terror (pesquisa de 19/10/2026)
Fontes: DOORS, Pressure, The Mimic, Piggy e Granny (Roblox/mobile); Alien: Isolation, Amnesia, Outlast, FNAF,
Dead by Daylight, Resident Evil 2 e Lethal Company (PC/console). Ordenadas por "mais impacto com menos trabalho".
A. Luz guia (DOORS): parado 20 s sem progresso, uma luz azulada fraca acende no próximo objetivo; ao morrer, uma
   dica curta do que deu errado. Substitui a ideia 6 (dica automática).
B. Batimento do coração (Dead by Daylight): dentro do raio do Tung Tung, batida que acelera e fica mais alta; na
   perseguição vira música de caçada. Hoje o aviso já tem luz/tremor/TUM; o coração dá leitura à distância.
C. Ele revista esconderijos (Outlast/Granny): se VIU você entrar, abre o armário ou revista 1–2 móveis do cômodo
   antes de ir embora. Dá um mini-jogo de "segurar o ar no ritmo" (DOORS/Figure): errar 3 vezes = pancada.
D. Diretor de tensão (Alien: Isolation): camada acima da IA que mede tensão (tempo desde o último susto, distância,
   vida) e manda o Tung Tung "ir ver o jogador" ou "dar uma folga". Evita longos vazios e evita acosso sem fim.
E. Passos que informam (Mr. X): o passo dele muda com o andar (acima/abaixo mais abafado) e com o material; o
   jogador aprende a ler onde ele está só pelo som. Já começado (passos mais altos); falta o abafamento por andar.
F. Monstro que te obriga a NÃO olhar (Pressure/Eyefestation, Lethal/Bracken): um segundo "espírito" da casa
   (quadro, boneca) que só anda quando você não olha, e punir quem fica encarando. Variedade sem mexer no Tung Tung.
G. Esconderijos com surpresa (Pressure/Void Mass): 1 em 10 armários tem "algo" dentro — espiar pela fresta antes de
   entrar mostra olhos; entrar sem olhar = pancada. Recompensa quem usa a fresta (já existe o Espaço).
H. Som vira perigo (Granny/Lethal): derrubar vaso, pisar em caco, correr em assoalho velho, chat de voz por
   proximidade (Roblox tem) — tudo chama o Tung Tung. Dá sentido ao "andar devagar".
I. Recurso que acaba (Amnesia/Outlast/FNAF): lanterna já tem pilha; ideia extra: ficar MUITO tempo no escuro faz a
   visão tremer/sussurros (sanidade), e luz de vela acesa recupera. Faz o jogador procurar luz, não só fugir.
J. Entidade que pune ficar parado (DOORS/Rush e Ambush): de vez em quando um "sopro" varre o corredor inteiro;
   as luzes avisam 3 s antes; quem não entrar num armário ou numa porta leva pancada. Cadência tipo DOORS.
K. Mini-jogos físicos (Piggy/Pressure): cadeado de combinação, gerador que precisa girar, fusível que precisa
   encaixar no ritmo — em vez de só apertar E. Dá "mão na massa" para criança.
L. Modos para rejogar (Piggy): "Infecção" (quem é pego vira ajudante do Tung Tung, batendo nas portas) e "Traidor"
   (um jogador sabe onde ele está). Para o PvP já existente do Codex.
M. Começo lento e pico no fim (DOORS/Seek): corrida roteirizada no capítulo 5 com portas fechando atrás e obstáculos
   para pular; já temos o fogo — faltam obstáculos de pulo e um "corredor que desaba" na hora certa.

Decisão do humano (19/10/2026): fazer todas, do mais fácil ao mais difícil, menos:
- F (coisa que só anda quando não olham): o humano vai fazer o MODELO 3D; implementar quando ele entregar.
- H (som vira perigo): não fazer.
- K (mini-jogos físicos): anotado para depois.
- L (modos Infecção/Traidor): adiada pelo humano em 19/10/2026, fica na lista para depois.
Ordem combinada: B, E, A, I, G, J, C, M, D; depois o móvel da chave que foge (perninhas e olhinhos), o encaixe de cada novidade e o polimento. L fica para depois.
Feitas e testadas: B, E, A, I, G, J, C, M, D. G (2 de cada ~10 armários por capítulo; olhos vermelhos numa fresta escura até 14 studs,
respiração; entrar sem olhar = porta abre, queda no chão, barulho 70 que chama o Tung; fotos em
docs/evidence/environment/locker).
J (capítulos 2-4, ~1 a cada 3-4 min depois de 60 s): luzes do corredor piscam e o vento cresce por 3 s, depois uma
parede de névoa gelada corre de parede a parede (38 studs/s). Quem fica na faixa fora de armário leva pancada (fluxo
da captura, causa "gust", com dica). Depuração: DebugBridge "gust". Fotos em docs/evidence/environment/gust.
C: quando o Tung Tung alcança alguém no armário (viu entrar ou ouviu), ele para na porta e começa a revista:
5 batidas, um anel fecha sobre o círculo e o jogador aperta Z/Espaço/clique/toque na hora. 3 erros = pancada
(causa "search"); passou = ele desiste e vai patrulhar longe ("Ele não te ouviu..."). Sair do armário no meio
= falha. Foto em docs/evidence/environment/search.
M (fuga do capítulo 5, EscapeRun/EscapeRunService/EscapeRunController): medido pela distância de quem vai na frente
no caminho de fuga. Portas dos cômodos ao lado batem depois que o grupo passa; duas vigas em chamas despencam à
frente no corredor do porão, com o chão pegando fogo dos dois lados (pular passa limpo; andar esquenta 0,6);
o corredor desaba atrás do grupo a 15 studs/s (andar perde, correr ganha), deixa entulho sólido e derruba quem
fica para trás (causa "collapse", com dica). Depuração: DebugBridge "blaze". Fotos em docs/evidence/environment/escape.
D (TensionModel/TensionDirector): tensão 0..1 por capítulo com fases Build/Peak/Relax (CampaignState.Tension e
TensionPhase). Pancada = folga de 35 s (o Tung se afasta, sem sopro); pico acaba em 30 s ou quando ele perde o grupo;
calmo demais por 70 s = ele investiga perto de alguém. Sopro só em Build; sustos esperam o pico passar.
Móvel fujão (RunawayStash): em cada capítulo, uma das chaves (sorteada) fica num móvel que acorda quando alguém
chega perto com a tarefa liberada: olhinhos de desenho e perninhas pretas com bolinhas, chacoalha e foge pelo
cômodo aos pulinhos (até 4), olhando para quem persegue; cada pulo faz barulho. Encurralado ou alcançado numa
pausa, cansa, senta ofegando e abre normalmente. Fotos em docs/evidence/environment/runaway.
Jumpscare (JumpscareController): quando o Tung Tung derruba alguém (pancada ou porta do armário), só para quem foi
pego: imagem congela e o som some; "TUM"... "TUM" no escuro; ele aparece colado (cópia local do modelo animado,
rosto centralizado, luz de baixo) e avança erguendo o bastão com rugido; pancada com clarão (se flashes),
tranco e câmera tombando; corte para o preto e volta. Interface e mão da lanterna somem durante o susto. O rosto 2D
piscando da tela de derrota foi aposentado (fica um corte seco para o preto). Foto em docs/evidence/environment/jumpscare.
