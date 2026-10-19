# Floresta v2 — três mapas, três medos (20/10/2026)

Problema: os capítulos 6–8 eram o mesmo mapa (grade de árvores de bloco em volta de uma reta) com os mesmos 5 lugares
e a mesma receita (pegar, consertar, esconder, prender o ar). Decisão do humano: refazer como eu achar melhor, com os
modelos que já temos; o que não gostar, ele avisa (lista em docs/MODELOS_SUBSTITUIVEIS.md).

Regras que ficam: entrada ao sul (0, 580), saída ao norte (0, 870), tarefas dentro de |x| < 70 e 600 ≤ z < 880, rotas
largas para jogador e Tung Tung (testes ForestNavigation/ForestCampaign), 6 abrigos por capítulo.

Base visual comum: terreno de verdade (Terrain: grama, lama, rocha, água) com morros nas bordas, trilha sinuosa
(não é mais uma reta), pinheiros 3D ForestFirA/ForestFirB em escalas variadas, capim alto (TallGrass*), neblina.

## 06 · A MATA ESCUTA — mata de neblina e ravina
- Mapa: trilha em S subindo a mata densa, acampamento numa clareira à esquerda, ravina funda cortando o mapa de
  leste a oeste, com rio lá embaixo e uma ponte de corda; depois da ponte, a estrada.
- Medo próprio: a mata escuta. Folhas secas estalam (barulho para o Tung) e corvos levantam voo grasnando quando
  alguém chega perto (entregam a posição). Andar agachado evita os dois.
- Momento marcante: a travessia da ponte. Depois que o grupo passa, o Tung entra na ponte, as tábuas cedem e ele
  cai no rio (folga longa e sensação de vitória), mas a ponte some: não dá para voltar.

## 07 · NINGUÉM NO RÁDIO — lago na tempestade
- Mapa: margem com cais, lago grande no meio (água do Terrain) e a ilha do posto de rádio; chuva forte e raios.
- Medo próprio: A Voz. O rádio e as árvores chamam o nome de quem joga e mostram uma luz de lampião fora da trilha;
  quem segue a luz cai numa emboscada (o Tung aparece perto). Contra-jogada: seguir as marcas amarelas, não a voz.
- Momento marcante: a travessia de jangada puxando a corda, com o Tung batendo no cais e a jangada balançando.

## 08 · ELES OUVIRAM O SINAL — torre no morro e descida final
- Mapa: subida em zigue-zague até a torre no alto do morro, torre de verdade (escadas e patamares), descida pela
  estrada até a van.
- Medo próprio: a mata acorda. Na descida, árvores caem atravessando a estrada (pular ou desviar) e o Tung corta
  caminho pelo mato.
- Momento marcante: ligar o farol no topo (vista de toda a mata) e a corrida final até a van; o Tung pula no capô no
  último segundo (jumpscare) e cai quando a van arranca.

## Ordem de construção
1. Base comum (terreno, pinheiros 3D, trilha sinuosa, neblina) + mapa do cap. 6.
2. Folhas secas, corvos e a ponte que desaba (cap. 6).
3. Mapa do lago, A Voz e a jangada (cap. 7).
4. Morro, torre, árvores caindo e final da van (cap. 8).
5. Testes de rota por capítulo, bot jogando os 3 capítulos, fotos.

## Feito (20/10/2026)
- Cap. 6, mapa: terreno, trilha de terra, ravina com rio, pinheiros 3D, capim, acampamento, marcas do guarda.
- Cap. 6, a mata escuta (ForestHazardService): 11 manchas de folhas secas (andar em pé estala e chama o Tung;
  correndo faz mais barulho); 6 bandos de corvos em tocos que levantam voo grasnando quando alguém chega a 11 studs
  (4,5 agachado). Não verificado em jogo: o agachado silencioso (o teste por script não conseguiu agachar).
- Cap. 6, a ponte: o guincho ergue as tábuas; ao chegar do outro lado, o Tung surge na cabeceira sul, corre pela
  ponte, ela desaba no meio e ele cai no rio (volta pelo norte 22 s depois). A ponte não volta.
