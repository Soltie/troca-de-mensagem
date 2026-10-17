# Levels da propriedade do Tung Tung

> Esta é a entrega inicial dos levels. A revisão posterior corrige armários, progressão, acesso,
> menu e checkpoint: [QUALITY_REVIEW.md](QUALITY_REVIEW.md). Para jogar a versão consolidada atual,
> use `build/Casa_QUALIDADE_VALIDADA.rbxlx`; os recibos antigos abaixo conservam suas versões de origem.

16/10/2026. Fonte: branch local `codex/house-levels`, worktree `.cache/house-levels`.
Base `0dd8a27`; implementação `ce15e11`; integração do mapa `fa19cf9` por cherry-pick `c348207`.
Escada/fachada finais em `f800536`; ambientação `e1b7be1` integrada por `92b4a82`.
O checkout principal e as alterações concorrentes foram preservados. Sem push ou publicação.

## Jogar

Abra `build/Casa_LEVELS_ENTREGA.rbxlx` e escolha **Desafio**. A etapa 3 é externa; a etapa 4 também
pode ser externa conforme a seed. As demais etapas exploram a casa. História mantém seus objetivos
e o percurso fixo, com os acabamentos e correções estruturais da outra frente já integrados.

## O que mudou

- A propriedade tem jardim de inverno, estufa, oficina, pátio traseiro e mirante elevado. O anel
  de circulação conecta frente, laterais e fundos, sem atravessar o porão. Há limites externos
  para evitar quedas. Escada/rampa e guarda-corpos levam ao mirante sem exigir salto.
- Telhado inclinado, chaminés, cornijas, varanda coberta e caixilhos laterais dão silhueta à casa
  vista do jardim. Os caixilhos laterais são decorativos, sem novos furos na fachada estrutural.
- No Desafio, até 16 divisórias recebem passagens de 10 ou 24 studs. As maiores unem cômodos em salões
  de até 36 × 96 studs; as outras criam circulação lateral e opções de fuga. A seed determina presença,
  largura e as escolhas mudam por etapa. Os corredores principais e IDs existentes ficam preservados.
- A partir da etapa 3, uma escada de serviço liga o andar superior ao sótão em uma ala sorteada.
  O piso e teto recebem um recorte protegido somente no cômodo traseiro sem missão. A escadaria
  principal permanece disponível. Reinício/História restauram as peças originais antes de reconstruir.
- Tarefas externas distribuem as lembranças, pistas e puzzles pelos jardins, com a mansão visível.
  Códigos e dependências continuam no servidor e são reproduzíveis na mesma seed. A patrulha recebe
  os pontos exteriores, inclusive o mirante. O spawn da etapa externa fica diante da casa.
- O reparo de energia no Desafio exige **isolar → encaixar fusíveis → testar**. Ações fora de ordem
  não avançam nem apagam os acertos. Placas indicam o próximo passo e o progresso dos puzzles.
- Relógio, máscara, fotografia, livro, fusíveis, lanterna, chaves e artefato recebem formas próprias.
  Objetos coletados somem visualmente; detalhes não bloqueiam o raycast de interação.

## Integração

Novos módulos: `HouseLevelPlan`, `HouseLevelBuilder`, `HouseTaskProps`. Ganchos pequenos em
`HousePlan`, `HouseActivities`, `CoopSession`, `CampaignRuntime` e `WorldService`.
O mundo continua montado por código. Não há novo remote, mudança de dados persistentes ou asset enviado.

`HouseLevelBuilder` só suprime/restaura peças conhecidas e mantém o cenário complementar em
`GeneratedEstate`. A ruína esconde também o telhado novo. O build inclui o commit da frente de mapa;
não substitua uma árvore `src/` inteira em outro checkout para integrar isto.

## Validação

Recibos em `docs/evidence/house-levels/`. Check integrado: **266 testes locais, ALL GREEN**.
Runner integrado no Studio: **275 aprovados, zero falhas**, sem warnings/erros do projeto. Campanha Desafio com dois clientes
do engine: **Won, cinco capítulos, 66 verificações**. As capturas são enquadramentos de QA,
com HUD oculto e câmera posicionada, sem alterar as câmeras da versão entregue.
Testes puros cobrem 120 seeds, preservação da História, posições externas, dependências, sequência
do reparo e campanhas de 1, 2 e 6 participantes até vitória. O teste físico usa fixtures separadas,
verifica caminhos sem salto para jogador/criatura, pisos, mirante, escada interna e restauração.

Os testes de campanha usam clientes reais do engine e os remotes normais, com teleporte de setup
e IA congelada. Não medem perseguição, diversão, ritmo ou desempenho em celular físico.

## Limites

A mansão conserva a estrutura principal autoral. A variação procedural vem de passagens, salões,
escada opcional, localização de tarefas e etapa externa; não é uma casa inteira inédita por seed.
Os títulos das etapas externas variam; o conjunto de pavilhões é compartilhado. Objetivos e itens
reaproveitam as dependências da campanha. Esta entrega não adiciona dublagem ou mecânicas novas de
cooperação às tarefas. A ambientação de terror da outra frente está incluída: o conflito de
`LightingProfile` foi resolvido com o novo perfil/lanterna e a redução de bloom/exposição do mapa.
