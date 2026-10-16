# Recibos — polish visual, 16/10/2026

- `before-office.png`: build de `9d40d44`, sem reset do diretório ativo.
- `after-office.png`, `after-control.png`, `after-generator.png`, `after-workshop.png`, `after-vigia.png`:
  camada visual final, câmeras controladas, energia ligada, HUD/filtro 2D ocultos só na fixture.
- `capture-flat-rejected.png`: captura descartada; não comprova arte. Uma nova instância de Studio
  renderizou a cena corretamente, preservando o Dev com Script Sync.
- `runtime-probes.json`: cinco imagens, 330 faces, LEDs/CRT/poeira e console da prévia; desligar energia
  reduziu telas ativas de seis para zero. Memória indicada é de pixels, não a memória total de GPU.
- `check-isolated.txt`: saída real do check na cópia com somente a camada visual sobre `9d40d44`.
- `eight-clients-final.json`: oito clientes, três estágios, Won, 125 verificações, seed 1792136884.
- `client-probe.luau` / `server-probe.luau`: scripts temporários de QA em Play (VM normal).

As capturas do Vigia usam posição de chão corrigida e orientação controlada; IA congelada.
Um ensaio inicial passou y=4 como chão e o colocou alto demais; essa imagem foi substituída pelo
recibo correto, sem alterar o código de movimento do jogo. A primeira textura de tinta estava
contrastada demais; a ferrugem nativa exagerava a cor e foi substituída por Metal com máscara local.

Condições do desempenho: prévia 812×675, qualidade Automatic, câmera fixa e vários Studios abertos,
incluindo testes multiplayer locais. O primeiro conjunto foi limitado a ~15 FPS em background;
outro conjunto de 600 quadros marcou ~51,2 FPS, p95 ~24,2 ms e pico de ~0,71 ms no step da arte.
São amostras curtas em condições diferentes, não comparação antes/depois nem garantia de 60 FPS.
Medir numa partida humana e no hardware alvo continua necessário.

Fonte da camada: commit `fdb50c4`. A cópia integrada desse commit contém também o commit independente
do Claude `9e3931e`; futuras mudanças da outra frente não estão cobertas por estes recibos.

Integração: `integration-tests.txt` tem 163 aprovados / 1 falha no novo teste do duto.
`duct-baseline-9e3931e.txt` reproduz a mesma falha sem a camada de arte (157 aprovados / 1 falha).
Essa comparação confirma a origem independente da arte; o duto não está aprovado por esta entrega.
