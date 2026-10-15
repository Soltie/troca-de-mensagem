# Expansão do mapa — SUBESTAÇÃO 9

15/10/2026. Responsável: Codex. Coordenação: [LEIA_CLAUDE.md](../LEIA_CLAUDE.md).

## Resultado

O núcleo original ganhou cinco áreas: oficina, galeria de cabos, sala de controle, arquivo técnico
e pátio de transformadores. A circulação forma um anel: entrada da oficina → galeria → controle
→ arquivo → pátio técnico → pátio frontal. Também há conexões com escritório, corredor, gerador,
depósito e bombas. O jogador e o Vigia podem usar essas rotas para contornar o núcleo.

O mapa continua com três fusíveis. Posições, IDs, quadro, spawn, portão e zona de vitória foram
preservados. As áreas novas servem à exploração e às rotas de fuga; não são novos objetivos obrigatórios.

| Medida nominal no chão | Antes | Depois |
| --- | ---: | ---: |
| Áreas das salas, incluindo pátio técnico | 4.000 studs² | 10.920 studs² |
| Pátio frontal | 3.520 studs² | 6.160 studs² |
| Soma dessas áreas | 7.520 studs² | 17.080 studs² |

São áreas dos retângulos do Layout, antes de descontar paredes e móveis. O conjunto ficou **2,27×**
maior por essa medida. `Building` continua sendo o núcleo original; `Compound` define o perímetro
ampliado, de x=-68 a 72 e z=-78 a 44. Não usar `Building` como limite de todas as salas.

## Planta esquemática

Norte está em cima. Os vãos entre setores são livres; portas interativas antigas permanecem.

```text
                x=-68       -40          4          40          72
z=-78           ┌────────────┬────────────┬───────────┬───────────┐
                │ GALERIA    ↔ CONTROLE   ↔ ARQUIVO   ↔ PÁTIO     │
                │ DE CABOS   │            │           │ TÉCNICO   │
z=-50           ├────↕───────┼────↕───────┴────↕──────┤           │
                │            │ GERADOR   │ DEPÓSITO   │  T-01..04 │
z=-26           │ OFICINA     ├───────────┴────────────┤           │
                │            ↔ CORREDOR                ↔           │
z=-18           │            ├─────────┬───────┬───────┤           │
                │            ↔ ESCRIT. │ RECEP.│BOMBAS ↔           │
z=0             └────↕───────┴─────────┴───↕───┴───────┘     ↕     │
                │                 PÁTIO FRONTAL                    │
z=44            └──────────────────[ PORTÃO ]──────────────────────┘
                                      ↓ SAÍDA
```

## Arte e integração

- Oficina: bancada, estantes, armários e divisória com vão de oito studs, quebrando a linha de visão.
- Galeria: tubulações e bobinas; travessia central livre.
- Controle: consoles, monitores apagados e diagrama elétrico.
- Arquivo: estantes e mobiliário afastados da ligação leste-oeste.
- Pátio: quatro transformadores com aletas e isoladores, pórticos, cabos e cerca contínua.
- Placas de orientação e marcações no chão indicam o anel e o retorno ao gerador/saída.
- Novas luminárias usam as tags existentes: acendem com a energia e apagam ao reiniciar.
- As árvores determinísticas agora respeitam `Compound`, evitando vegetação dentro das alas.

`Expansion.luau` é um módulo construtor chamado pelo `MapBuilder`; não é um Service e não exige
um novo bootstrap. Layout mantém os dados puros. Pisos e paredes continuam no construtor existente;
o novo módulo monta coberturas, mobiliário e exterior técnico. Sem novos assets externos ou áudio.

## Correção no código existente

O QA revelou que `WorldService.isInsideBuilding` só reconhecia o retângulo original. Entrar pela
oficina deixava o objetivo de entrada pendente. A consulta agora usa `Layout.isIndoor`: reconhece
as salas cobertas e exclui o pátio técnico. Mantém a condição de altura já existente. O ajuste foi
feito após a autorização do humano para melhorias necessárias em outras frentes, e registrado
previamente no aviso ao Claude. Não altera o sistema de objetivos nem a máquina de estados da rodada.

## Validação executada

- Check local: **ALL GREEN**, 76 testes puros, 0 falhas; 2 specs exclusivos do Studio pulados no Lune.
- Sync: ambos os serviços `SyncedAsRoot`; Layout, MapBuilder e Expansion `SyncedAsDescendant`.
- Studio `Tests.Run`: **84 passed, 0 failed, 0 skipped specs**.
- Navegação real por PathfindingService para jogador e Vigia até os objetivos antigos e as novas áreas.
- Anel das alas alcançável para ambos mesmo com o volume inteiro do núcleo bloqueado temporariamente.
- Portão fechado: sem rota de fuga pelo perímetro ampliado, partindo de três pontos do pátio.
- Personagem atravessou a entrada da oficina: objetivo mudou de entrada para busca dos fusíveis.
- Navegação MCP: controle → arquivo → pátio técnico → portão → saída, sem teleporte nesses trechos.
- Interações via remotes reais: 3 fusíveis → quadro → energia → portão → `Won`; reinício → `Intro`,
  zero fusíveis, portão fechado e luzes de força apagadas. Teleporte de debug foi usado para chegar
  aos pontos dos fusíveis e do quadro; Vigia congelado nessa verificação. Não é playthrough humano.
- Vigia ativo na galeria: perseguiu o jogador e capturou em x=-54, z≈-69; rodada chegou a `Lost`.
- Mundo: **1.265 peças**, construção registrada em **15 ms** nesta execução. Não é benchmark de FPS.
- Com energia: 17 luminárias internas e 5 refletores acesos; sem energia/reinício: 0 desses acesos.
- Console: nenhum warning/erro do projeto. Houve ruído conhecido UIBlox e avisos do Assistant ao
  restaurar o tipo da câmera após capturas automatizadas; não são mensagens do jogo.
- Play encerrado; Studio liberado em Edit.

Capturas reais, com iluminação e filtro do jogo:

| Oficina sem energia | Controle com energia | Pátio com energia |
| --- | --- | --- |
| [captura](evidence/map-expansion/workshop-unpowered.png) | [captura](evidence/map-expansion/control-powered.png) | [captura](evidence/map-expansion/switchyard-powered.png) |

## Trabalho simultâneo e próximos testes

Durante o fechamento surgiram edições de outro agente em `Shared/Config.luau` para novas mecânicas.
Essas mudanças foram preservadas e ficam fora da entrega do mapa. O QA acima usou o runtime
carregado antes da integração dessa frente. O check adicional isolado usa o HEAD base mais os arquivos
do mapa; o recibo fica em `docs/evidence/map-expansion/check-isolated.txt`.
Resultado isolado: **ALL GREEN** (76 testes), build `Test.rbxlx` concluído. Base `b5a784f` e
SHA-256 de cada arquivo sobreposto constam em `snapshot-manifest.json`.

O Claude respondeu em `LEIA_CLAUDE.md`, confirmou a divisão e registrou que usará Features/FeatureBuilder
para objetos no núcleo. Sua mudança planejada de trancar o depósito mantém uma rota alternativa pelo
arquivo técnico; validar a interação da chave/porta na rodada integrada.

Claude: após terminar sua frente, repetir check global, sync e Play com ambas integradas. Antes de
alterar Layout/MapBuilder/WorldService, conferir o diff do mapa e este contrato. Se adicionar
esconderijos, baterias ou puzzles, manter os corredores e vãos livres e atualizar os testes de Navigation.

Ainda faltam: balanceamento humano das distâncias de fuga, FPS sustentado em primeiro plano,
multiplayer e QA conjunto com as mecânicas novas do Claude. Não houve push nem publicação.
