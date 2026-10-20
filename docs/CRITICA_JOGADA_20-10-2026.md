# Crítica jogada: Modo História (20/10/2026)

Crítico analítico, jogando no Roblox Studio pelo MCP, place `tungtung` (82955516040017), branch `design/environment`
(13b6f55 + trabalho local não commitado do time). Nada foi editado, publicado nem conectado ao Script Sync; o único
arquivo criado é este.

Régua: DOORS, Hello Neighbor, Pressure, The Mimic, Apeirophobia, Piggy. Meta do dono: 30 a 40 min no total, 4 a 5 min
por capítulo, nota 9 ou mais.

## Como foi jogado (e limites do teste)

- Um jogador, teclado e mouse pelo MCP: ando com pathfinding + `MoveTo`, aperto E/F/Z/J pelo teclado do MCP e tiro
  print em cada momento importante. Monitor no servidor registrando a cada 0,5 s a fase, as tarefas resolvidas, o
  modo do Tung e a distância dele até mim.
- **Velocidade:** com `MoveTo`, o `CharacterController` mantém a velocidade mínima (14 × 0,45 = **6,3 studs/s**); quem
  segura W anda a 14. Por isso dou dois tempos: o **do servidor** (inclui minhas pausas para ler, parecido com quem
  hesita) e a **caminhada pura**, que deve ser dividida por ~2,2 para o tempo real andando. Fugir do Tung a 6,3 é mais
  difícil do que a 14/21; as capturas do cap. 3 levam isso em conta.
- Cap. 1 e 2 jogados do começo ao fim pela progressão normal (menu → votar História). O cap. 3 foi aberto pela ponte
  de depuração `chapter(3)`, que **pula a cena protegida**. Depois, a pedido da coordenação, o Studio foi liberado
  para o Level designer e para a thread de Luz, e por fim ficou desconectado do MCP. **Os capítulos 4 a 8 não foram
  jogados nesta sessão**; o que digo sobre o piano vem do código e não conta como teste.
- Partes com o Tung congelado ou a bateria cheia por depuração estão marcadas.

## Tempos medidos

| Cap. | Servidor | Caminhada pura (6,3 st/s) | Estimativa real (teclado) | Tung |
| --- | --- | --- | --- | --- |
| 1 · A Entrada | 510 s (8,5 min) | ~133 s | **3–4 min** (o grosso é abrir gavetas) | Dormente o capítulo inteiro |
| 2 · Ele Acordou | 245 s (4,1 min) | ~95 s | **2–2,5 min** | Acorda na 6ª de 7 tarefas; nunca a menos de 48 studs |
| 3 · A Maldição | 4 de 5 tarefas em ~12 min, com 3 capturas, 2 derrotas e 1 bug | ~180 s | sem o Tung, ~3 min | Ver Crítico 1 |

A meta de 4–5 min só é tocada no cap. 1, e só por causa da busca. A campanha da casa continua perto de 10–12 min reais
para 5 capítulos, longe dos 30–40 min.

## Notas

| Área | Nota | Por quê |
| --- | --- | --- |
| Clareza do objetivo | 7 | Painel "CAPÍTULO n/8 + tarefa" sempre visível, J explica. Falta dizer **onde** (nenhuma seta, só o nome do cômodo no J). |
| Busca de itens (gavetas/baús) | 6,5 | É a melhor ideia nova: "Vazio… procure nos outros móveis do cômodo." Mas são os mesmos 3 móveis por cômodo em todos os capítulos e o baú fujão nem acordou. |
| Enigmas | 5 | Relógio claro em 10 s, mas óbvio (03:12 aparece em toda tela). |
| Tung (medo/perseguição) | 4 | Cap. 1–2: nenhuma ameaça; cap. 3: vê de 48 studs e derruba em 3–5 s, inclusive no nascimento. |
| Luz | 4,5 | Sem lanterna a sala fica preta; a bateria acaba em ~3 min e só recarrega até 35 %; com lanterna, o teto fica branco. |
| Visual | 6,5 | Hall, sala, sótão e armário bonitos (Poly Haven); baús de busca, caixa de 3 fechaduras, livros e a mão da lanterna são blocos. |
| HUD/texto | 6 | Avisos da "Mansão" sobrepostos ao prompt da tarefa; instruções do armário em duplicata; "BÔNUS POR AJUDAR A EQUIPE" jogando sozinho. |
| Estabilidade | 6 | Nenhum erro de script do jogo, mas câmera presa (bug crítico) e cena repetida no meio do capítulo. |
| Desempenho | 8 | Mundo de 5.140 peças construído em 0,36–0,77 s; sem travadas perceptíveis nos prints. |

**Por capítulo:** cap. 1 = 6,5 (boa introdução, mas sem nenhum susto real e com escuridão total quando a pilha acaba);
cap. 2 = 5 (curto, sem ameaça, o armário é o ponto alto); cap. 3 = 4 (bonito no sótão, mas captura injusta e bug de
câmera). Caps. 4–8: sem nota (não jogados).

**Nota geral: 5,5/10** com a régua DOORS/Hello Neighbor. A evolução de atmosfera é real, mas o laço medo → fuga →
alívio ainda não existe: nos caps. 1 e 2 o Tung não ameaça; no 3 ele pega antes de dar chance de reagir.

---

## Crítico

### C1. Tung pega quem acabou de nascer no cap. 3 (sem chance de reagir)
- **Onde:** cap. 3, spawn no hall (-6, 3,6, 2); Tung "acorda" em (26, -68) ou (-26, -68).
- **O que aconteceu:** monitor do servidor: Patrol aos 0,5 s → **Chase aos 5,7 s a 48 studs** → **Capture aos 10,3 s**.
  Depois de levantar: Chase aos 26,2 s → captura aos 30,9 s → **Lost** (2 quedas solo). O "continue" reiniciou o
  capítulo e aconteceu de novo: Chase aos 57,0 s → captura aos 61,6 s. No sótão (35, 35, 0), mais tarde: Chase a 28
  studs → captura **3,5 s** depois → Lost de novo.
- **Ressalva:** entrei pelo atalho `chapter(3)`, que pula os 12 s de cena protegida. Mesmo assim, a cena protegida só
  adia: o hall é uma reta longa de visão e o Tung (17 st/s) acorda no fim dela.
- **Por que importa:** DOORS e Piggy sempre dão um sinal antes (som, luz piscando, "ele está vindo") e um lugar para se
  esconder perto. Aqui a primeira coisa que o jogador vê é a derrota, e a segunda queda já reinicia o capítulo inteiro.
- **Melhoria:** (1) folga real de 20–30 s depois de a cena acabar **e** depois de cada levantar; (2) acordar o Tung fora
  da linha de visão do spawn (porão ou andar de cima); (3) primeira perseguição de cada capítulo com velocidade de
  patrulha nos 3 primeiros segundos ("ele te viu" → sprint); (4) solo: 3 quedas, não 2, ou checkpoint por tarefa.

### C2. Câmera presa na cena de abertura no meio do capítulo
- **Onde:** cap. 3, escritório (-30, 19,6, -34,4), enigma do relógio. Câmera presa em **(0, 5, 14)**, olhando o hall.
- **Passos:** cap. 3 → fazer 4 tarefas → no escritório, ser derrubado pelo **sopro** (`LastCaptureCause=gust`) → levantar.
- **Esperado:** câmera volta para a primeira pessoa.
- **Aconteceu:** `CameraType=Scriptable` fixa em (0,5,14). O personagem segue ativo no escritório. A cena de abertura
  "CAPÍTULO 03 · A MALDIÇÃO" voltou a tocar ("PULAR CENA [ESPAÇO / A]"), mas **Espaço não pulou** e a câmera não
  voltou nem depois de 10 s. Só reiniciando o Play.
- **Console:** nada do jogo; só `The execute_luau changed camera type. Resetting…` (log do próprio MCP).
- **Ressalva:** o MCP também mexe no tipo de câmera ao rodar código; vale reproduzir à mão. Mas a cena tocando de novo
  no meio do capítulo não é coisa do MCP.
- **Melhoria:** `CinematicController` não deve reabrir a cena de abertura enquanto a fase for `Playing`; sempre chamar
  `Camera.endCinema()` em captura/queda/continue; e uma trava de segurança: se `mode=="cinema"` por mais de 15 s sem
  cena ativa, chamar `reset()`.

### C3. Lanterna: a bateria acaba e a tela fica preta (o jogador para de jogar)
- **Onde:** cap. 1 em diante (sentido em cozinha, sala de jantar, sótão).
- **Medido:** começa em 0,85 e gasta 1/170 por segundo → **apaga com ~2,5–3 min de uso**. Desligada, recarrega só
  até **0,35** (≈ 60 s de luz). No cap. 1 apagou 3 vezes; no cap. 3, 3 vezes.
- **Sem lanterna** a sala de estar e a cozinha ficam quase 100 % pretas (ver "Luz").
- **Bug junto:** depois que ela apaga sozinha, **o primeiro F não liga** (o cliente acha que ainda está "querendo
  ligada" e o F desliga). Precisa de dois F. Reproduzido duas vezes.
- **Por que importa:** em DOORS e Pressure a falta de luz é um momento de tensão curto; aqui é o estado normal da
  casa. Quem não sabe que precisa esperar recarregar acha que travou.
- **Melhoria:** dobrar a duração (1/340), recarga até 0,6, pilhas visíveis nas gavetas (o `PickupsPerRound=3` não
  apareceu nenhuma vez no cap. 1); corrigir o F duplo (ao zerar, setar `wanted=false` no cliente); ambiente mínimo nos
  cômodos para ver contornos sem lanterna.

## Alto

### A1. Caps. 1 e 2 sem ameaça nenhuma
- Cap. 1: Tung `Dormant` do começo ao fim (8,5 min). Cap. 2: acorda na 6ª de 7 tarefas e a menor distância foi 48
  studs. O único susto foi o vulto no fim do corredor do cap. 3, que é ótimo, mas é o terceiro capítulo.
- **Melhoria:** no cap. 1, um evento roteirizado por tarefa (porta batendo, pancadas no teto, o vulto cruzando a
  porta da sala aos ~2 min); no cap. 2, acordar na tarefa 4 (energia) e fazer uma patrulha que **passa** pelo
  corredor enquanto o jogador está no armário. Hello Neighbor ensina o vizinho cedo e com folga.

### A2. Avisos da "Mansão" em cima do prompt da tarefa
- **Onde:** cap. 1 hall (0, 3,6, -21,6): "[E] Destrancar o corredor…" + **"REBOCO CAINDO — OUTRO LADO LIVRE"**;
  biblioteca (-30, 3,6, -67): "[E] Ler a mensagem…" + **"A PORTA VAI CEDER — AFASTE-SE"**; cap. 2 início:
  "[E] ABRIR PORTA" + **"FORÇAR PORTA EMPERRADA"**; cap. 1, cozinha: "REBOCO CAINDO"; cap. 3, quarto
  (-39, 19,6, -1): "[E] ABRIR O BAÚ" + **"PISO RACHANDO — CONTORNE"**; cap. 1: "QUEBRAR CADEADO" sem tecla.
- Vêm de `ReplicatedStorage.Shared.Game.MansionConfig` / `Workspace.CursedHouse.DynamicMansion` (código que está no
  place e não no repo). O piso que quebra (`BreakawayFloor`, "SALTAR PISO QUEBRADO · OU CONTORNE") também aparece
  na história.
- **Por que importa:** são duas ordens ao mesmo tempo, uma delas "afaste-se", bem na hora de apertar E. Não fica claro
  se é perigo real, se é do modo História e que tecla usar.
- **Melhoria:** desligar a Mansão dinâmica no Modo História, ou dar a ela uma linha própria no topo, com ícone de
  perigo e tecla, e nunca no mesmo lugar do prompt.

### A3. Enigma do relógio (cap. 3): claro, mas óbvio
- **Print:** painel do escritório com "__:__ · QUE HORAS OS RELÓGIOS DA CASA MARCAM?" e 4 botões 0/1/2/3 em pixel.
- **Entende em 10 s?** Sim. O livro do sótão ("TODOS OS RELÓGIOS DA CASA PARARAM NA MESMA HORA. OLHE PARA ELES.") e o
  objetivo ("…na hora das fitas") dizem o que fazer.
- **Desafio real?** Não. 03:12 aparece no relógio "REC 03:12" da interface, na abertura ("03:12 / A FITA NÃO
  TERMINOU"), no "SÓTÃO / 03:12" da cena, na TV do cap. 1 e na revelação do relógio ("03:12. O mesmo horário…").
  Com só os dígitos 0–3, a resposta é quase única. Os relógios de parede analógicos, em compensação, são ambíguos de
  longe (o da sala parece 2:10).
- **No erro:** pelo código, badala alto e chama o Tung (`makeNoise 90` + `followScent`), sem zerar. No teste, o sopro
  me derrubou na mesma hora e não vi o efeito; não sei dizer se o jogador entende que "o erro chamou o Tung".
- **No escuro:** o painel e os relógios são legíveis com lanterna; sem lanterna, só o relógio iluminado pela lamparina
  (quarto) se lê. O videocassete "03:__" e o rádio-relógio "__:12" que acendem no escuro não foram vistos (a sala de
  TV fica preta, ver Luz).
- **Melhoria:** usar uma hora que **não** é 03:12 (cada relógio parado numa hora diferente, e só o da foto da família
  mostra a certa), ponteiros grandes e números legíveis, teclas 0–9 e sinal claro do erro (badalada + texto "ELE
  OUVIU").

### A4. Peças que parecem protótipo ao lado de modelos realistas
- Baús e gavetas de busca são blocos lisos com retângulos amarelos, ao lado dos baús do Poly Haven (print sótão e
  quarto). A **mesma caixa de 3 fechaduras** serve para "destrancar o corredor", "restaurar energia" e "abrir passagem".
  Livros de pista são placas com riscos. A mão da lanterna é feita de esferas e cubos verdes/vermelhos.
- **Melhoria:** trocar os 3 móveis de busca por malhas (cômoda, baú, criado-mudo); um modelo próprio para cada tarefa
  ("quadro de fusíveis", "trava do corredor"); mão com luva.

### A5. Cap. 2 curto e mecânico
- 3 fusíveis nas mesmas gavetas do cap. 1 (mesmos `search_task_*` nas mesmas posições), "restaurar energia" na
  mesma caixa e o armário. 2–2,5 min reais.
- **Melhoria:** fusíveis em lugares novos (atrás do quadro, dentro do piano, no banheiro inundado); o Tung patrulha
  enquanto se busca o último; o armário vira uma cena de verdade (ele entra no cômodo, cheira, sai).

## Médio

### M1. Escadas para cima não fazem parte da casa
- As escadas ficam num anexo atrás do hall, em z≈38 (`MainStairs`, `AtticStairs`). O pathfinding comum não acha a
  rota (rodou 121 s e saiu pela frente da casa); para subir eu precisei do caminho (16,3,18) → (16,19,56) → (32,19,57)
  → (32,35,18). Para um jogador, sem seta, achar o sótão no cap. 3 depende de explorar.
- **Melhoria:** placa "ESCADA ↑" no hall e no 2º andar, e luz quente na base da escada.

### M2. Pathfinding até portas e cozinha
- Do hall para a cozinha a rota tentou passar por (6, -17) e bateu em parede (5 travas); da sala de jantar para o hall,
  6 travas em (-10, -22). Se o Tung usa malha parecida, pode travar nesses pontos (vale checar com o teste
  `Navigation`).

### M3. Texto
- "BÔNUS POR AJUDAR A EQUIPE" em toda tarefa, jogando sozinho.
- Armário: duas legendas iguais ("E: sair. Z/LB…" e "[ESPAÇO] ver pela fresta… [Z] prender o ar · [E] sair").
- Fonte pixel sem acento: "ELE NÃO E O DONO", "RELOGIOS", "O CORAÇÃO ESTA".
- Menu: "FUJA DO TUM TUM TUM" (nome diferente do jogo).
- "Está escuro demais. Procure uma vela, uma lamparina…" aparece com a lanterna na mão (cozinha).
- A mão da lanterna cobre o fim das legendas centrais ("Recolher o primeiro fusível: concluído").

### M4. O sopro é explicado só na legenda da cena
- "Quando as luzes do corredor piscarem e o vento crescer, entre num armário…" aparece só na abertura do cap. 3, que
  muita gente pula. O sopro me derrubou no escritório no meio do enigma.
- **Melhoria:** aviso na hora (luz piscando + "ESCONDA-SE!" curto) e a primeira ocorrência nunca derruba.

### M5. Baú fujão não acordou
- No cap. 1 (sala de jantar, -13,5, 0,4, -22,6) eu cheguei e abri sem ele correr. O momento mais "Hello Neighbor" da
  casa passou batido.

## Baixo

- B1. 6 avisos "EditableImage is not accessible" no console por sessão (rosto do Ademir cai no plano B geométrico).
  Ligar o EditableImage nas configurações ou silenciar o aviso.
- B2. Bloco verde translúcido no canto da sala de máquinas (cap. 2) depois de restaurar a energia.
- B3. "[L] LOJA" cobre a barra de fôlego no canto inferior direito.
- B4. Avisos de recompensa (+20 FICHAS +40 XP) a cada tarefa disputam atenção com a pista narrativa.

---

## Bugs

| # | Título | Cap. / posição | Passos | Esperado | Aconteceu | Console |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Câmera presa em (0,5,14) após o sopro | 3 · escritório (-30, 19,6, -34,4) | Cap. 3 → 4 tarefas → ser derrubado pelo sopro no escritório | Volta à 1ª pessoa | Scriptable fixa no hall, cena de abertura reaparece, Espaço não pula | nada do jogo |
| 2 | Cena de abertura do capítulo toca de novo no meio do jogo | 3 | Igual ao 1 | Cena só no início | "CAPÍTULO 03 · A MALDIÇÃO" com "PULAR CENA", fase `Playing` | — |
| 3 | Primeiro F não religa a lanterna depois que ela apaga sozinha | 1 · cozinha (32, 3,6, -15) | Deixar a bateria zerar → esperar recarga → F | Liga | Nada; só o 2º F liga | `flashlight died (battery empty)` |
| 4 | Captura logo após o spawn | 3 · hall (-6, 3,6, 2) | `chapter(3)` ou continue | Folga antes da 1ª perseguição | Chase em 5,7 s, captura em 10,3 s, Lost em 30,9 s | `missed` → `captured` |
| 5 | Avisos da Mansão sobrepostos ao prompt | 1 · hall (0, 3,6, -21,6); 1 · biblioteca (-30, 3,6, -67); 3 · quarto (-39, 19,6, -1) | Chegar perto do objetivo | 1 prompt | 2 textos, um com ordem contrária | — |
| 6 | Pista "Está escuro demais. Procure uma vela…" com lanterna na mão | 1 · cozinha (15, 3,6, -2) | Desligar a lanterna na cozinha | Dica sobre ligar a lanterna (F) | Pede vela/lamparina | — |
| 7 | Bloco verde translúcido | 2 · sala de máquinas (≈ 24, 6, -75) | Restaurar energia | — | Bloco verde no canto do teto | — |

Todos os prints foram tirados ao vivo nesta sessão (capturas do MCP); estão referenciados pelo nome nas seções.

## Luz

Valores no cap. 1: `Brightness 0,75`, `ExposureCompensation 0,20`, `Ambient (12,11,12)/255`, `OutdoorAmbient
(36,42,58)/255`, `ClockTime 0,30`, ColorCorrection S9SceneGrade (b 0,025; c 0,26; s -0,35), Bloom 0,07, qualidade
"Automática". Prints "antes" (thread de Luz): `Luz_Hall_ComLanterna`, `Luz_Hall_SemLanterna`, `Luz_Sala_ComLanterna`,
`Luz_Sala_SemLanterna`, `Luz_Cozinha_ComLanterna`, `Luz_Cozinha_SemLanterna`.

| Lugar | Sem lanterna | Com lanterna | Transição |
| --- | --- | --- | --- |
| Exterior / entrada (cap. 1) | Fachada e porta quase pretas; batente torto parece erro de perspectiva | — | — |
| Hall | Escuro mas legível: quadros, placas e tapete aparecem | **Teto branco estourado**, parede verde bonita | — |
| Sala de estar | **Preto total**; só o texto da TV aparece | Excelente: sofá, armário, relógio, TV | **Brusca** hall → sala |
| Cozinha | Quase preto; o relógio e o armário branco ainda aparecem; pede "vela/lamparina" | Boa, xadrez muito claro e teto branco | Brusca |
| Sala de jantar / corredor dos fundos | Preto | Facho estreito, azul quando a pilha está fraca | — |
| Sala de máquinas (cap. 2) | Escura antes da energia; boa depois | — | Boa (a energia muda o cômodo) |
| Biblioteca / armário | Bonita, luz quente | — | Boa |
| Sótão (cap. 3) | Preto | Muito bonito (madeira, baús) | — |
| Escritório (cap. 3) | Painel legível só com lanterna | Painel bem legível | — |

**Resumo:** a casa não tem um "mínimo de leitura" sem lanterna, e a lanterna funciona como holofote (ilumina o teto
inteiro sem queda), então o jogo alterna entre preto e iluminado demais. DOORS e Pressure mantêm sempre um contorno
visível (luz de janela, brilho de objeto interativo) e deixam o escuro total para momentos curtos.
**Sugestões:** Ambient interno ~(22,20,22); luz fraca de janela/abajur em todo cômodo; facho da lanterna mais estreito
e com queda no teto; contorno sutil nos objetivos sem lanterna.

**Qualidade gráfica 1 vs 10:** não deu para comparar. A troca de qualidade é do cliente do Studio e o MCP saiu do ar
antes; fica pendente.

---

## Comparação

- **DOORS:** cada porta é uma decisão, com o perigo anunciado (luz piscando = Rush) e a morte explicada. Aqui o
  aviso existe só na legenda da cena, e as primeiras capturas não têm aviso.
- **Hello Neighbor:** buscar coisas escondidas em móveis é o mesmo laço, e o "Vazio… procure nos outros móveis" é bom.
  Falta o vizinho reagir ao que você mexe (aqui a busca só faz barulho) e esconderijos com risco.
- **Piggy:** capítulos curtos, mas cada um com mapa novo e 3–4 itens com uso claro (chave → porta). Aqui os itens
  repetem os mesmos móveis.
- **The Mimic / Apeirophobia / Pressure:** visual realista **consistente**; aqui o realismo do Poly Haven ao lado de
  blocos quebra a imersão.

## Cinco melhorias de maior impacto

1. **Perseguição justa:** folga de 20–30 s depois da cena e de cada queda, Tung acordando fora da visão do spawn, 3
   quedas no solo e um aviso de 1 s antes de toda captura (C1).
2. **Corrigir a câmera presa e a cena repetida** (C2). Hoje trava o jogo.
3. **Lanterna e luz:** bateria 2× maior, recarga até 0,6, pilhas que aparecem de verdade, F único, e um mínimo de luz
   em todo cômodo (C3 + Luz).
4. **Ameaça desde o cap. 1:** eventos roteirizados no 1 e o Tung acordando cedo no 2, com uma patrulha que passa
   pelo armário (A1). Isso também resolve parte do tempo curto.
5. **Limpar a tela e o visual:** tirar os avisos da Mansão do modo História, trocar os móveis de busca e a caixa de 3
   fechaduras por malhas, e dar ao relógio uma resposta que não esteja escrita na interface (A2, A3, A4).

## Pendências desta crítica

- Caps. 4 (porão, piano da Lia com teclas coloridas e 4 pontos no painel, cofre), 5 e 6–8 (floresta) não foram jogados:
  o Studio foi pedido por outras threads e depois desconectou do MCP.
- Escada do porão em (-22, 4, 13), qualidade gráfica 1 vs 10 e o erro do relógio sem o sopro: ainda falta testar.
