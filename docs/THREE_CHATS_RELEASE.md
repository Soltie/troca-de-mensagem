# Entrega consolidada dos três chats

Data: 17/10/2026. Build única: `build/Casa_COMPLETA_3_CHATS.rbxlx`.

## Conteúdo

- **Expandir geração de levels** (`01a146fe`): casa, jardins, circulação, qualidade anterior,
  controles de toque, mochila, HUD responsivo, telas estreitas e retorno automático ao lobby.
- **Adicionar níveis de floresta** (`01a14795`): capítulos 6–8 após a casa, trilha, acampamento,
  torre, abrigos, perseguição, rádio, van de resgate e recompensas para oito capítulos.
- **Melhorar transições e microinteraçõ** (`01a1479d`): abertura, cortes, cartelas, legendas,
  máscaras de câmera, movimento reduzido e resposta visual de botões.

As frentes já tinham começado a integrar mobile e floresta. O fechamento foi interrompido antes
de resolver dois conflitos textuais de `CinematicController` e antes do QA da versão com cinema.
O chat `01a147a5` retomou esse estado no worktree da floresta, resolveu os conflitos, preservou
o final `ForestCinema` e importou os últimos ajustes mobile de menu, loja e espectador.

## Fontes e preservação

Base: `1e77a1c`. Camada cinema: `50ee074abf8e3e34d9292c054bbcf25fb9558ff8`.
Mobile foi absorvido do estado em disco de `.cache/house-levels`, com hashes dos arquivos
originais e integrados em `docs/evidence/three-chats/integration-sources.json`.

Fontes consolidadas: `C:/Users/xpg/.codex/worktrees/forest-campaign/roblox-teste`.
O checkout principal e as cópias dos outros chats foram preservados. Backup anterior à retomada:
`.cache/three-chats-recovery-original.zip` no worktree da floresta.

Esta entrega é uma place com fontes embutidas por `rojo build`. Nenhum `rojo serve` foi usado.
Os 216 arquivos Luau da build foram comparados ao disco após normalização XML de quebras de
linha. Não é necessário conectar Script Sync para testar esse arquivo; não conecte a place
consolidada a uma árvore antiga de fontes.

## Validação

- Check completo: **276 testes locais**, zero falhas; formatação, lint e tipos verdes.
- Runner da build consolidada no Studio: **287 aprovados**, zero falhas e zero specs puladas.
- Boot: 16 services e 34 controllers, incluindo `UiFeedbackController` uma única vez.
- Menu observado no cliente com História e Desafio, oito capítulos e apresentação ativa.
- Console sem erros do projeto; aviso `FoundationProvider` em CorePackages/UIBlox é do Roblox.
- História em dupla: **128 verificações** até vitória, retorno automático ao lobby e nova partida.
  Recibo em `docs/evidence/three-chats/story-duo.json`. Depois dessa execução mudou apenas
  o texto do cabeçalho do HUD: o papel continua no guia e deixa de colidir com o destino.
- A build final repetiu os **287 testes do Studio**. Medição de cabeçalho: `TextFits=true`
  para capítulo e destino, com 158 px de separação em uma viewport desktop.
- Desafio em dupla na build final: **130 verificações**, oito capítulos, resgate,
  retorno automático ao lobby, limpeza dos estados, nova votação e nova partida.
  Recibo em `docs/evidence/three-chats/challenge-duo.json`.
- Studios de QA devolvidos a Edit e clientes de teste encerrados pelo engine.

SHA-256 da build final: `8bfa4e4a6d9358b8b0737b623a618b1f04be64c9afa9102001440b02c3d9f192`.

## Para testar

Abra `C:/Users/xpg/Documents/roblox-teste/build/Casa_COMPLETA_3_CHATS.rbxlx` no Roblox Studio,
pressione Play e vote em História ou Desafio. A casa leva à floresta; a vitória final exige
chegar à van após o sinal. Ao terminar a cena, a equipe volta ao lobby e pode votar novamente.

O QA automatizado usa clientes do engine, seleção/interações do cliente e remotes normais.
Teleporte e congelamento da IA preparam cenários; não são avaliação humana de equilíbrio,
diversão, sustos, desempenho ou toque em celular físico. A entrega é local, sem push/publicação.
