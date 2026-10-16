# Casa — camada de terror e ambientação

16/10/2026. Branch local `codex/horror-atmosphere`, base `0dd8a27` (Tung Tung novo).
Worktree: `C:\Users\xpg\Documents\roblox-teste\.cache\horror-atmosphere`.

## Resultado

A noite ganhou luz ambiente fria mais baixa, névoa azul discreta e pontos quentes locais.
Os móveis, brinquedos, cores, HUD, roda, rig e animações foram preservados nesta frente.
A lanterna agora recorta o escuro com feixe de 40°, brilho 2,7 e preenchimento menor.
O alcance e o consumo de bateria continuam iguais. Bloom contido evita halos excessivos.

As luminárias decorativas da casa passam pelo controle de sombras, além das luzes com tag.
São até duas sombras locais próximas, mais a lanterna própria; qualidade explícita 1–3
mantém o orçamento local em zero. Luzes encobertas por paredes/tetos perdem preenchimento
suavemente no cliente para reduzir vazamento entre cômodos e andares. Não há mudança de
Enabled, energia, colisão, IA ou regras do servidor. A seleção de visibilidade roda a 2 Hz.
O perfil não reduz os valores-base de pistas e efeitos de missão; a redução fixa de
brilho/alcance se aplica a Candle/NightLight. Luzes com tag seguem a modulação local existente.
As opções de conforto continuam valendo, e a ocultação arquitetural é interpolada.

O áudio usa os cômodos do catálogo da casa: reverberação de sala, banheiro e porão.
Deixa de esperar as antigas zonas industriais. Árvores e objetos decorativos sem colisão
não confundem mais a detecção de cobertura. Fora da casa, a zona é Outside.
Rangidos passam a ser de madeira, localizados e iniciados no começo do clip.
Música calma e ambiência deixam mais espaço para passos, respiração e sons da criatura.
A cada trecho espaçado de exploração calma há uma pausa de 3–5 s na música/ambiência;
ela termina quando muda o contexto e não abafa passos, perseguição ou interações.
Sons do mundo preservam os grupos de mixagem e o controle de volume de efeitos.

## Integração com o mapa

Os seis arquivos desta frente são:

- `Shared/Game/LightingProfile.luau` e `Shared/Game/Audio.luau` em ReplicatedStorage;
- `Client/Controllers/{LightingController,WorldFxController,AudioController}.luau`;
- `ServerScriptService/Tests/Specs/LightingProfile.luau`.

Não substituir src inteiro para integrar. O commit desta branch modifica somente esses
arquivos, este relatório, evidências e coordenação. O perfil incorpora o bloom/exposição
reduzidos que já estavam na frente do mapa, além da direção nova de ambientação.

A build de demonstração combina esta camada com um snapshot da frente `house-map-polish`
capturado durante a execução. A cópia congelada está em `.cache/integrated` deste worktree.
Ela inclui a arquitetura, a TV e as cenas presentes naquele snapshot. Não contém alterações
posteriores da frente `house-levels`: o mapa continua evoluindo em paralelo.
`evidence/horror-atmosphere/integrated-source.json` registra os hashes dos 199 arquivos de src.
Para o mapa final, aplicar somente a camada desta frente e repetir o build/QA.

## Validação

- Check isolado: **ALL GREEN, 261 testes puros**; três specs do engine puladas no Lune.
- Snapshot com mapa: **ALL GREEN, 263 testes puros**, mesmas três specs exclusivas do engine.
- Runner da build final no Studio: **271 aprovados, zero falhas, zero specs puladas**.
- Seis Sources da build comparados com os arquivos locais: todos idênticos.
- Preset Realistic confirmado. Build com scripts e asset TungTung embutidos; Script Sync
  aparece NotSynced nesta cópia descartável, deliberadamente. Não foi reconectada outra place.
- Cliente real: 117 luminárias no lobby, 118 com uma luz de missão; até duas sombras locais.
- Interior converge a 1; exposição 0,16 sem energia / 0,10 com energia; névoa 190 / 210.
- Banheiro: Bathroom. Porão: StoneRoom. Exterior final: Outside, Plain e inside=false.
- Pausa de som observada durante 42,5 s em exploração calma: música 0,13 → 0,02 → 0,13.
- Flashes desligados: zero luminárias variando numa amostra estática de um segundo.
- Lanterna coletada pelo remote normal de interação: accepted=true/solved; HasFlashlight=true.
  No cliente: brilho 2,7, ângulo 40°, alcance 48, Shadows=true.
- Console do Play final: zero erros/warnings do projeto; há avisos FoundationProvider/UIBlox
  dos CoreScripts do Roblox. Recibos completos preservados em evidence/horror-atmosphere.
- História com dois clientes do engine: **64 verificações, cinco capítulos, phase=Won,
  success=true**. O cabeçalho do recibo identifica esta build e o servidor de teste.
  O harness prepara posições e congela a criatura; não comprova o equilíbrio da perseguição.

As capturas usam câmera fixa e HUD oculto via sonda somente do Studio. A posição da câmera
é preparada, e a criatura foi congelada/teleportada em verificações pontuais. Isso não é
uma partida humana nem prova de balanceamento, susto subjetivo ou desempenho em celular.

## Capturas

- `evidence/horror-atmosphere/finalExterior.png`: exterior com o snapshot do mapa.
- `evidence/horror-atmosphere/finalCorridor.png`: corredor sem lanterna.
- `evidence/horror-atmosphere/finalFlashlight.png`: mesmo corredor com lanterna coletada.
- `evidence/horror-atmosphere/living.png` e `living-power.png`: sala sem/com energia.

## Entrega e reprodução

Build local: `C:\Users\xpg\Documents\roblox-teste\build\Casa_TERROR_POLISH.rbxlx`.
SHA-256: `914DB5D6E52C897B72E56CC9399520977414660C64825A04B824D22A61E21987`.

Abrir essa cópia no Studio e iniciar Play; História pode iniciar solo. F liga a lanterna
depois de recolhê-la. Os controles e a progressão existentes continuam disponíveis.
Para reproduzir a compilação integrada: entrar em `.cache/integrated`, rodar
`lune run scripts/check` e `rojo build default.project.json --output build/Casa_TERROR_POLISH_FINAL.rbxlx`.
Nada foi publicado, enviado por push ou alterado no Creator Hub.
O editor próprio foi devolvido a Edit ao terminar; as outras sessões de Studio foram preservadas.

Referências técnicas consultadas: [Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting)
e [RaycastParams](https://create.roblox.com/docs/reference/engine/datatypes/RaycastParams).
