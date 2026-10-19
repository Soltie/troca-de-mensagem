# Proposta — item 12 (movimentação), lanterna e filtro de cor

Nada disto foi implementado. Medições feitas em 19/10/2026 no Studio de teste. Fotos em
`docs/evidence/environment/proposals/`.

## Item 12 — movimentação

### Tung Tung (só visual, no cliente; IA, velocidades e colisão não mudam)

| Problema medido | Causa | Proposta |
| --- | --- | --- |
| Na patrulha (9 studs/s) ele "corre em câmera lenta" | O clipe de andar só cobre 1,55 studs/s; acima de 5 studs/s entra o clipe de corrida a 0,55× | **12A:** misturar andar e corrida pela velocidade (pesos contínuos, ciclos sincronizados), sem troca brusca. **12A+ (melhor):** você baixa no Mixamo um andar ameaçador (ex.: "Zombie Walk") e eu faço o bake com `tools/tungtung/bake.js` |
| Vira de uma vez nas esquinas | O servidor gira a raiz até 580°/s nos pontos do caminho; o cliente só suaviza 55 ms | **12B:** suavizar o giro no visual (até ~240°/s com aceleração) e inclinar o corpo de leve na curva |

### Jogadores (só visual)

| Problema | Proposta |
| --- | --- |
| As poses dos colegas (agachar, inclinar, lanterna na mão) atualizam a 30 Hz e "pulam" | **12C:** 60 Hz para quem está a menos de 35 studs, 15 Hz para quem está longe (custo igual ou menor) |
| Andando agachado, a perna faz o passo de pé (passada longa com joelho dobrado) | **12D:** passada mais curta e mais lenta agachado (ajuste da trilha de andar) e um leve balanço de quadril |
| Animações padrão do Roblox | **12E (opcional):** animações próprias de andar/correr/agachar. Exige subir animações no Creator Hub, que é passo seu |

Não mudam: controles, velocidades (14 / 21 / 5,5), fôlego, colisões, IA e o que é enviado entre jogadores.

## Lanterna e escuridão

| | Hoje | Proposta |
| --- | --- | --- |
| Brilho do feixe | 2,7 | 4,6 |
| Alcance | 48 studs | 62 studs |
| Abertura | 40° | 50° |
| Luz em volta da mão | 0,11 (5 studs) | 0,25 (8 studs) |

Fotos: `lanterna-atual.jpg` × `lanterna-proposta-filtro-A-atual.jpg`. Fora do feixe continua escuro. A visão do Tung
Tung com a lanterna ligada (50 studs) não muda. Opcional: subir o ambiente sem energia de 9 para 14 (formas
aparecem de leve no escuro).

## Filtro de cor (ColorCorrection, por cima do perfil atual)

| Opção | Ajuste | Foto |
| --- | --- | --- |
| A — atual | leve azul, saturação −0,10, contraste 0,12 | `lanterna-proposta-filtro-A-atual.jpg` |
| B — frio | azulado, saturação −0,25, contraste +0,14 | `filtro-B-frio.jpg` |
| C — sépia | âmbar antigo, saturação −0,30, contraste +0,14 | `filtro-C-sepia.jpg` |
| D — verde doentio | verde pálido, saturação −0,28, contraste +0,16 | `filtro-D-verde.jpg` |

Todas as fotos usam a lanterna da proposta, para comparar só a cor.

## Aplicado em 19/10/2026 (escolhas do humano)

- Lanterna nova (brilho 4,6, alcance 62, 50°, luz da mão 0,25/8) e filtro de cor B (frio) em `LightingProfile`.
- Chuva mais transparente e gotinhas na tela ao ar livre (`RainController`, `RainLens`, até 10 gotas, só Média/Alta).
- Trovão com tremor leve de câmera (respeita a opção de tremor).
- Atmosfera de fora: lua e ambiente mais fracos, refletores da fachada e lanternas bem mais fracos, poucas janelas
  acesas, luz quente saindo da porta, banco de névoa que vem e vai só ao ar livre (`Profile.fogBank`).
- Sala/cômodos: guarda-roupa do esconderijo no canto da fachada, de frente para a porta; estante da sala removida;
  móveis que ocupavam esse canto foram para oz 7,5.
- Cercas em volta da casa removidas (o muro de tijolo e o portão continuam fechando o terreno); portão da floresta em
  ferro forjado.
- Item 12 (movimentação) continua só proposto.
