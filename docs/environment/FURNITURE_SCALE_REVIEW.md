# Etapa 2 — escala e composição dos móveis

Destino aplicado: tungtung, PlaceId 82955516040017. Alteração isolada em ServerScriptService/Server/World/HouseProps; os outros 267 scripts mantiveram comprimento e checksum antes/depois. Source conferido antes de escrever; Script Sync desligado. Sem publicação Roblox.

Build nativa completa via Download a Copy: build/TungTung_MOVEIS_ESCALA_CODEX_20261019.rbxl (715829 bytes). SHA-256: C0ACE959077D6687C84B750A728BA21E8440683681FA28F794C542EAA60E955C. Comparação das fontes embutidas com o backup confirma somente HouseProps alterado e correspondência com o disco após normalizar quebras de linha e linhas finais vazias. Limitação Lune: aviso de propriedade nova do Terrain ao ler; os arquivos nativos não foram reserializados por Lune.

## Alterações

- Incorporados os ajustes locais e57b523 e fb1821d: fator geral 1,25 → 0,85, cadeiras com multiplicador próprio 0,6.
- Bancadas contíguas acompanham a largura nova; cadeiras de cozinha/jantar aproximadas das mesas; conjunto do jantar deslocado para acomodar quatro lugares; cadeira do escritório aproximada da escrivaninha.
- Candelabros acompanham a largura da lareira; caixas empilhadas apoiadas na altura real da caixa inferior.
- Camas, mesas baixas, tapetes e guarda-roupas dos esconderijos mantêm a escala anterior para preservar a cobertura dos volumes/mecanismos existentes. Estes modelos aguardam suas etapas específicas.
- Código de colisões 41ac22b preservado no histórico, mas retirado desta versão de HouseProps: não estava no destino e pertence ao próximo item. Colisões existentes do jogo não foram removidas.

## Medidas no Studio

| Elemento | Altura após ajuste (studs) |
| --- | --- |
| Personagem do teste | 5,33 |
| Cadeiras góticas | 4,17 |
| Mesas redondas | 2,92–3,07 |
| Bancadas da cozinha | 2,73 |
| Poltronas | 3,26–3,42 |
| Sofás | 2,44–2,56 |
| Estantes | 6,31 |

## Validação

- Check local ALL GREEN: 302 testes puros; build/Test.rbxlx gerada (árvore visual antiga, NÃO substitui a integração atual).
- Cópia do backup, modificada apenas em memória: 349 testes Studio aprovados. Backup original em disco preservado.
- Destino tungtung: 349 testes Studio aprovados, zero falhas; log do servidor após inspeção sem erros/avisos. Inclui specs existentes de navegação; não equivale a campanha/PvP completos.
- Conferência visual de cozinha, jantar e estar. Evidências: docs/evidence/environment/scale-review/. Luz temporária de inspeção somente durante Play: as capturas NÃO representam nova iluminação de produção. HUD ocultado temporariamente; scripts de UI intactos.
- Play encerrado; câmera, luz e congelamento da criatura descartados. Iluminação aprovada preservada.
- NÃO TESTADO: celular físico, campanha completa e nova partida completa de Midnight Hunt. Avaliação estética e sensação de escala aguardam o humano.

Parar nesta etapa. Humano confere no Studio (Play → História), principalmente cozinha, jantar e estar. Não iniciar colisões ou substituição dos modelos antes da resposta.
