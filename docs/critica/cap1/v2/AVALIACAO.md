# Avaliação do capítulo 1 (v2) — crítico exigente

Data: 20/10/2026. Place `tungtung` no Studio, Play local, 1 jogador. Nada foi editado, salvo nem publicado.
Os props novos (lençol, fotos, cesto, kit 7–17) ainda não estavam importados e não receberam nota.
Régua: DOORS, Hello Neighbor, Pressure, The Mimic, Apeirophobia. Meta: ~5 min por capítulo, nota ≥ 9.

## Como joguei

Votei em História no menu e joguei o cap. 1 inteiro, de "Entrar na casa" até "Ler a mensagem". Usei pathfinding +
`MoveTo` e as teclas E/F pelo MCP, sem teleporte. Para medir, rodei um monitor no servidor (fase, tarefas, modo do Tung,
bateria) e somei a distância percorrida. Errei de propósito a tábua e o banquinho de boné. Depois, pelo atalho de
depuração `chapter(4)`, só para ver o painel do piano.
Limite: o `MoveTo` anda a 6,3 studs/s (um jogador com W anda a 14), e eu parava para inspecionar; por isso dou o tempo
medido **e** uma estimativa para um jogador honesto.

## Tempo

| Trecho | Log do servidor | Observação |
| --- | --- | --- |
| Menu → controle na mão | 59,5 s | Sem cena de abertura; só a legenda "FITA: Aqui é a Cida…" no portão |
| Entrar na casa + lanterna | 59,5 → 120,9 s (61 s) | Inclui 12,8 s de caminhada até o hall |
| Caixinha da Lia (chave da sala) | 120,9 → 274,4 s (154 s) | Inclui minha espera de 40 s pela fita da TV, que não tocou |
| Tábua Oca (chave da cozinha) | 274,4 → 373,3 s (99 s) | Inclui 1 erro proposital |
| Banquinho que Foge (3ª chave) | 373,3 → 483,7 s (110 s) | Inclui 1 erro proposital |
| Porta que Troca + portão das 3 chaves | 483,7 → 637,8 s (154 s) | Inclui minha investigação do gatilho |
| Biblioteca | 637,8 → 695,0 s (57 s) | Fim do capítulo |
| **Total** | **635,5 s (10,6 min)** | **435 studs andados** |

**Estimativa para um jogador honesto** (andando a 14 st/s e explorando ~3× o caminho direto, mais o tempo real de
cada puzzle): **3,5 a 4,5 min.** Fica abaixo dos ~5 min, e o Tung não acrescenta tempo nenhum (não aparece).

## Notas por cômodo (0–10)

| Cômodo | Nota | Por quê (prints) |
| --- | --- | --- |
| Hall | 6,5 | Bonito com a lanterna (papel de parede, quadros, tapete). O teto ainda fica quase branco (04). As placas menores e sem brilho ficaram pequenas demais para ler sem parar (03, 04). O fundo do corredor sem lanterna é preto puro (03). |
| Sala de estar | 7 | Melhor cômodo: viga, cômoda, mesa e sofá; sem lanterna dá para ler sofá, TV e armário (06). Destoam o pião do Juca (cilindro vermelho liso no tapete) e um cubo brilhante sobre a mesa (05). Os móveis de busca continuam blocos pretos (07). |
| Cozinha | 5,5 | O piso agora é de madeira (ok), mas as 6 tábuas claras formam uma cruz simétrica no chão, peça de jogo à vista (08, 09). Sem lanterna, só as tábuas e os armários brancos aparecem. |
| Sala de jantar | 6 | Cadeiras góticas, candelabro e quadro bons (13). Os banquinhos são caixas lisas e o "boné" é um bloco de textura amassada (14). A luz da lanterna puxa tudo para azul-acinzentado. |
| Corredor (portão das 3 chaves) | 4,5 | A caixa de 3 fechaduras continua um bloco com uma "lâmpada" azul em cima (22). Sem lanterna, o corredor fica preto (27). O entalhe do Tum Tum é um contorno de linhas finas, quase invisível (23). |
| Biblioteca | 6 | Armário, estantes, poltrona e livro aberto bonitos, mas uma **placa branca flutua** acima do livro com "ELE NÃO É O DONO. O CORAÇÃO ESTÁ SOB A CASA" e **brilha no escuro** (24, 25, 26). Parece protótipo. |

## Puzzles e momentos (0–10)

| Item | Nota | Funciona? | Problema |
| --- | --- | --- | --- |
| Caixinha da Lia | 6,5 | Sim. Com a lanterna apagada, o som 3D (`PianoKey`, vol 0,9) toca na gaveta certa e se acha pelo ouvido. Legenda nova: "Na caixinha de música da Lia, a chave presa na corda…". | Só **3** móveis de busca na sala nesta partida (o pedido fala em 6). O objeto é uma gaveta-bloco preta; não aparece caixinha de música nenhuma (07). Não testei o limite de 26 studs com a luz acesa. |
| Tábua Oca | 6 | Sim. 1º E bate ("Toc, toc… Escute o som. Aperte E de novo…"); a oca soa grave e longa (velocidade 0,50) e a errada aguda (1,25). Errar mostra "Craaac! Tábua errada. A casa ouviu." (11). O 2º E na certa revela a chave. | O prompt "[E] LEVANTAR A TÁBUA" fica **em cima** da legenda (10, 11). Não vi os Olhos no Veio depois do erro. A legenda da chave ainda é a antiga ("A mesa está posta…"), e o pião do Juca embaixo é um cilindro (12). |
| Banquinho que Foge | 6,5 | Sim. O de boné, usado com a lanterna, foge cerca de 4 studs: "O banquinho de boné fugiu da luz e a pilha caiu!" (bateria 0,29 → 0,245) (15). Dois banquinhos certos: "Falta mais um em cima", depois "PEGAR A CHAVE NA VIGA" (17). | O boné não parece boné (14). A pilha montada ainda mostra "[E] LEVAR O BANQUINHO PARA AS MARCAS" (16). Nada no cenário avisa que o boné tem medo de luz antes do erro. |
| Porta que Troca | 4 | Quando dispara, funciona: a porta bate, 3 batidas ("Knock"), o teleporte para a sala e a fala da Dona Cida. | **Gatilho fraco**: a porta da sala de jantar ficou aberta e eu saí ao hall pelo vão sem tocar nela (18). Só disparou quando fiquei a menos de 5 studs do centro do vão (19). Ao abrir, aparece **"Isso não dá para fazer agora."** junto da fala (20), o que lê como erro. A cadeira da Dona Cida não estava virada para a porta na chegada (21). Parece mais bug do que susto. |
| Fita da TV | 3 | — | Fiquei 20 s a 12 studs da tela: nenhuma fala. A primeira linha da fita apareceu no portão de entrada, antes do controle, provavelmente disparada quando a câmera de carregamento passou perto da TV. |
| Duração | 6 | 3,5–4,5 min estimados | Abaixo de 5 min; sem o Tung, nenhum trecho estica. |
| Luz | 6 | Sala legível sem lanterna (grande melhora). | Corredor, cozinha e fundo do hall pretos; teto do hall ainda claro com a lanterna; tom azulado em tudo; a placa da biblioteca brilha. |
| Tung | 3 | — | **Dormant o capítulo inteiro**; no fim, a silhueta passa a 95 studs e não se vê. Não dá para testar carência, levantar nem perseguição andando 1,5 s. |
| Som | 6,5 | Caixinha 3D, toc grave/agudo, batidas da porta. | A fita da TV não tocou; muitas camadas 2D tocando juntas (música, tensão, perseguição, alívio, coração, sussurros); nenhum som de presença do Tung. |
| Medo | 3,5 | — | Nenhuma ameaça. O único susto (Porta que Troca) dá para evitar sem querer e termina com mensagem de erro. |
| Lanterna | 7,5 | ~6 min de luz contínua (0,85 → 0,49 em 133 s); recarga até 0,60; F liga na 1ª vez depois de apagar; lanterna de época na mão boa. | A mão segue feita de esferas. |
| Avisos da Mansão no cap. 1 | 10 | Nenhum apareceu. | — |
| "Está escuro demais" com a lanterna acesa | 10 | Não apareceu (só como dica na tela de carregamento). | — |

## Tung no menu

Os olhos estão no rosto de frente (01). De lado, o brilho dos olhos fica **saltado para fora**, como bolinha na frente
do rosto (02). Não deu para ver as costas: há uma parede do cenário colada atrás dele. O modelo é o original (madeira,
bastão), não o derretido.

## Bugs

| # | Título | Onde | Passos | Esperado | Aconteceu |
| --- | --- | --- | --- | --- | --- |
| 1 | Porta que Troca não dispara pelo vão | Sala de jantar → hall, porta house_door_5 (-8, 5, -36) | Pegar a 3ª chave; sair pelo vão aberto em z=-36 (passar a 5,4 st do centro) | Porta bate e avisa | Nada; só um "Snarl" distante. Só disparou a < 5 st do centro, com a porta fechada (18, 19) |
| 2 | "Isso não dá para fazer agora." na Porta que Troca | Mesma porta | Esperar a batida e apertar E | Só a fala da Dona Cida | Mensagem de erro + fala (20) |
| 3 | Cadeira da Dona Cida fora do quadro | Sala de estar, chegada em (-12,5, 3,6, -4) | Atravessar a porta trocada | Cadeira em (-20, 0, -4) virada para a porta | `CidaRockingChair_v2` em (-17,4, 0, 6,5), fora da vista (21). O `moveChair` procura qualquer "RockingChair" (há 5 no mapa) |
| 4 | Fita da TV não toca ao chegar | Sala, TV (-35,5, 5,3, -15,7) | Ficar a < 14 st da tela por 20 s | 3 falas da fita | Nenhuma; a 1ª fala apareceu no nascimento (00) |
| 5 | Prompt sobre a legenda | Cozinha, tábuas (26, 0, -4) | Bater numa tábua | Textos separados | "[E] LEVANTAR A TÁBUA" sobreposto ao "Toc, toc…"/"Craaac!" (10, 11) |
| 6 | Prompt errado na pilha | Sala de jantar (-39,9, 4,1, -36) | Empilhar os 2 banquinhos | Prompt some ou vira "subir" | "[E] LEVAR O BANQUINHO PARA AS MARCAS" continua (16) |
| 7 | Placa de pista flutuando e brilhando | Biblioteca (-31, 4,2, -71,4) | Entrar na biblioteca | Pista no papel/livro | Placa branca solta no ar, legível no escuro (24–26) |
| 8 | Preso no topo da escada do porão | (-21,9, 3,6, 13,4), entre FacadeSill e StairFacade | Cap. 4, ir do hall ao painel do porão | Caminho até a escada | A rota trava nesse canto; a StairWellGuard (z=22) bloqueia o acesso direto e a escada começa em z≈55, pelo patamar dos fundos, sem nenhuma placa (30) |
| 9 | Sem cena de abertura | Início do cap. 1 | Votar História | Cena de 12 s | Tela "CARREGANDO" e depois controle direto (00) |
| 10 | Brilho do olho do Tung saltado | Menu, vista de lado | — | Brilho dentro da órbita | Bolinha na frente do rosto (02) |
| 11 | Placa ESTRELA/LUA ilegível e fio no painel | Cap. 4, porão (-31, -10, -7,4) | Olhar o painel com e sem lanterna | Os 4 nomes legíveis | "ESTRELA" escuro sobre escuro; sem lanterna "LUA" some; um fio preto atravessa a placa; disco branco liso no chão (28, 29) |

Console: nenhum erro do jogo; só os 6 avisos "EditableImage is not accessible" e os avisos de UIBlox do Studio.

## Cap. 4, painel do piano

Fonte com serifa e acentos ("MÚSICA", "BASTÃO", "COMEÇA"): ok. As placas de nome não brilham, mas "ESTRELA" (preto
sobre preto) quase não se lê, e sem lanterna "LUA" desaparece e "SOL" e "BASTÃO" mal aparecem (29). O texto do painel
se lê com e sem lanterna. Os 4 quadrados de cor são planos e lisos.

## Nota geral do cap. 1: **5,5 / 10**

Os puzzles agora são ideias boas e funcionam (som, luz, peso), e a sala melhorou muito. Mas o capítulo não tem medo:
o Tung não existe aqui, a Porta que Troca dá para evitar sem querer e termina com mensagem de erro, a fita da TV não
toca. E várias peças ainda gritam "protótipo": placa flutuando, caixa de fechaduras, banquinhos-caixa, tábuas em cruz.

## O que leva a 9, por dono

**Level designer**
- Porta que Troca: fechar a porta sozinha quando a 3ª chave for pega, ou disparar por volume no cômodo inteiro (não
  por 5 st do centro); travar o vão até a troca acontecer.
- Caixinha da Lia com 6 móveis de verdade; tábuas espalhadas de forma irregular, misturadas ao assoalho, e não em cruz.
- Placa "ESCADA ↓ PORÃO" no hall e caminho do porão sem o canto-armadilha em (-22, 4, 13).
- Um susto por cômodo no cap. 1 (passos no andar de cima, porta batendo, a silhueta passando no corredor a 20 st, não 95).

**Luz**
- Teto do hall sem estourar com a lanterna; corredor e cozinha com um mínimo de leitura (uma lamparina fraca cada).
- Tirar o tom azul da lanterna (mais quente, perto da lanterna de época).
- Placas do piano legíveis sem lanterna (pintura clara sobre madeira escura), e a placa da biblioteca sem brilho.

**Artista 3D**
- Caixinha de música visível na gaveta; pião do Juca e chave com modelo de verdade; boné que pareça boné.
- Banquinhos, móveis de busca e caixa de 3 fechaduras em malha; o entalhe do Tum Tum em relevo que pegue luz.
- A carta da biblioteca como papel no livro, não placa no ar.

**Animador**
- Banquinho que foge com animação (pulinho, tremida) em vez de deslizar; a porta batendo com tranco; a cadeira da Dona
  Cida balançando quando ela fala.
- Mão da lanterna com dedos de verdade (hoje são esferas).

**Desenvolvedor**
- Corrigir os bugs 1–4 e 6: gatilho da porta, "door_swapped" sem mensagem de erro, `moveChair` pegando a cadeira certa
  (`CidaRockingChair_v2`), fita da TV que só dispara com o jogador controlando (não durante o carregamento).
- Disparar a cena de abertura do cap. 1 de novo.
- Mostrar os Olhos no Veio depois do erro na tábua (não apareceram).
- Fazer o Tung existir no cap. 1 mesmo dormindo: pancadas no teto, a silhueta perto, um "quase" sem captura.

**UI**
- Nunca mostrar o prompt "[E]" e a legenda no mesmo lugar (separar em duas linhas ou esconder o prompt enquanto a
  legenda está na tela).
- Tirar "BÔNUS POR AJUDAR A EQUIPE" jogando sozinho; placas do hall um pouco maiores.
- Dica curta no 1º contato com o banquinho de boné ("Ele não gosta de luz").

## Prints (docs/critica/cap1/v2/)

00_entrada_sem_cena_de_abertura · 01_tung_menu_frente_olhos_no_rosto · 02_tung_menu_lado_brilho_do_olho_saltado ·
03_hall_sem_lanterna · 04_hall_com_lanterna_teto_claro · 05_sala_com_lanterna_piao_e_cubo_brilhante ·
06_sala_sem_lanterna · 07_puzzle_caixinha_da_lia_sem_caixinha_visivel · 08_cozinha_sem_lanterna_tabuas_claras ·
09_cozinha_com_lanterna · 10_bug_textos_sobrepostos_tabua · 11_puzzle_tabua_errada ·
12_puzzle_tabua_oca_chave_pião_cilindro_legenda_antiga · 13_sala_de_jantar_com_lanterna ·
14_puzzle_banquinho_de_bone_bloco · 15_puzzle_banquinho_fugiu_da_luz · 16_puzzle_banquinhos_empilhados_prompt_errado ·
17_puzzle_chave_na_viga · 18_bug_porta_que_troca_nao_dispara_pelo_vao · 19_porta_que_troca_bateu ·
20_bug_porta_que_troca_isso_nao_da_para_fazer_agora · 21_bug_chegada_sala_sem_cadeira_da_cida ·
22_portao_tres_chaves_caixa_bloco · 23_corredor_entalhe_quase_invisivel · 24_biblioteca_com_lanterna_placa_flutuando ·
25_biblioteca_sem_lanterna_placa_brilha · 26_fim_cap1_placa_branca_de_perto · 27_corredor_sem_lanterna_preto ·
28_cap4_painel_piano_com_lanterna · 29_cap4_painel_piano_sem_lanterna_LUA_some · 30_bug_preso_escada_porao_-22_4_13

Faltaram: o print da sala de jantar sem lanterna, o do Tung de perto no jogo (ele não apareceu no cap. 1) e o das
costas do Tung no menu (parede atrás dele).
