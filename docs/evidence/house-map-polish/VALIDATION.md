# Recibos — mapa e apresentação da casa

## Check e empacotamento

- `check.txt`: ALL GREEN; 262 testes puros aprovados, zero falhas, três specs exclusivos do Studio.
- `source-audit.json`: 198 scripts no disco e 198 no arquivo, nenhuma diferença/extra,
  preset Realistic preservado.
- Arquivo final: `C:\Users\xpg\Documents\roblox-teste\build\Casa_POLISH_FINAL.rbxlx`.
- SHA-256: `A95151DB3701277FF9307630022BDF6681D09024CB59A46EA482993BD8C3F748`.
- O arquivo é cópia byte a byte de `build/Casa_POLISH_ENTREGA.rbxlx` do worktree desta branch.

## Testes do Studio

A revisão anterior à proteção lateral contínua das rampas passou em 270 testes do runner,
inclusive pathfinding de jogador/criatura, 20 seeds por capítulo, esconderijos e retorno do ritual à floresta.
O runner inclui medições físicas novas de piso, fachada e teto, além do grafo de navegação.
`studio-final.txt`: **270 aprovados, zero falhas, zero specs pulados** sobre a build entregue.
O console desse Play terminou sem erros ou warnings do projeto; os avisos FoundationProvider/CorePackages
do Studio foram classificados à parte. Pular a cena restaurou câmera normal, letterbox zero e legenda oculta.

## Campanhas

- `standard-2-pre-guard.json`: Desafio com dois clientes, 64 verificações, cinco capítulos, Won.
  Esse ensaio antecede a proteção lateral contínua e a correção de carregamento concorrente.
- `story-6-initial-failure.json`: tentativa inicial interrompida no capítulo 1; um personagem teve
  timeout de spawn durante restart rápido. Motivou a correção de pedidos de spawn já satisfeitos.
- `story-6-client-start-failure.json`: repetição não reuniu todos os clientes no prazo do harness.
  Fechamos somente as prévias locais antigas desta sessão para liberar recursos antes do próximo ensaio.
- `story-6-final.json`: História com seis clientes na build entregue, **68 verificações, cinco capítulos e Won**.
  Todos os seis participantes entraram como Active; resgate individual, recusa de coleta distante,
  respiração, puzzles, ausência de duplicatas e fuga foram aprovados. `story-6-progress.json`
  preserva o log até o fim do capítulo 4, sem warnings/erros do projeto naquele intervalo.

## Visual

`television.png` e `hall-before-final-light.png`: câmera local posicionada apenas para inspeção,
na versão antes do último ajuste das luminárias das rampas. A televisão funciona com mensagens por capítulo;
o hall não expõe mais a floresta/vazio entre os pisos. Não são capturas de percurso humano normal.
`hall-final.png`: hall da build entregue, com a iluminação final das escadas.
Na captura do capítulo 1, o root da casa tinha 2.438 peças e 118 luzes, incluindo objetos daquela etapa.

## Limites do método

Os testes de campanha usam clientes reais do engine, remotes normais, inventário, esconderijo, respiração,
resgate, checkpoints e extração. O harness congela a IA e teleporta jogadores para preparar as ações.
Isso não mede diversão, equilíbrio contra a criatura ativa ou desempenho em celular físico.
As falhas iniciais foram preservadas como recibos, sem serem confundidas com a validação final.
