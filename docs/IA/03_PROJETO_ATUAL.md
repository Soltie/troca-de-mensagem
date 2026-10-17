# Tung Tung Sahur: direção e implementação atual

Base corrente antes deste pacote: d975d86 (correção de câmera/mouse após menus e cenas), sobre f703b38/d2db940/ca0aec9. Deriva da frente da casa e remasterização, mas agora é repositório independente.

## O que é o jogo

Terror em primeira pessoa na casa amaldiçoada e na floresta, com o perseguidor Tung Tung Sahur. Oito capítulos: os cinco primeiros na casa, os três últimos na mata. A floresta atual tem 26 objetivos, pistas de rádio/mecanismos, esconderijos e resgate físico. A vitória apresenta Tung Tung e Crocodilo Armadilho no epílogo e anuncia continuação; a continuação completa não foi implementada.

- Config.House.Enabled=true e Campaign.Enabled=true.
- Equipe atual: 1–6 jogadores. Planos HousePlan/ForestPlan também impõem esse limite, embora utilitários herdados possam admitir até 8. Não aumentar só Config sem revisar planos, spawns, HUD e testes.
- Story é apresentado como História: objetivos guiados e progressão narrativa.
- Standard é apresentado como Desafio: variações/rotas e dependências próprias; nos cinco capítulos da casa permite dividir tarefas; na floresta as novas dependências continuam guiadas.
- Lanterna, itens, inventário e preferências fazem parte da progressão da casa. HasFlashlight importa; não presumir lanterna adquirida desde o primeiro frame.

Docs herdadas ainda mencionam subestação, Vigia, fusíveis e 2–8 jogadores. Para este jogo prevalecem Config, House/Forest catalogs/plans, README atual e este guia.

## Fluxo e módulos próprios

Main → RoundService → CampaignRuntime cria Session.new(..., house=true). CoopSession incorpora inventário da equipe, checkpoint, dependências e estados. HousePlan gera capítulos 1–5 e delega 6–8 a ForestPlan; ambos mantêm soluções no servidor.

| Módulo/família | Responsabilidade |
| --- | --- |
| Shared/Game/HouseCatalog | salas, capítulos/objetivos e pistas públicas da casa |
| Shared/Game/HouseProgression | dependências por modo/capítulo; não colocar solução de puzzle no catálogo público |
| Server/Campaign/HousePlan, HouseLevelPlan | plano privado determinístico, variação por seed/modo e realocação das tarefas |
| Server/Campaign/HouseActivities | adapta interações da casa, inventário e eventos da progressão |
| Shared/Game/HouseLayout, HouseEnvelope | geometria/aberturas/contratos físicos usados pelos builders |
| World/HouseBuilder, HouseArchitecture, HouseLevelBuilder | construção e reconstrução dos andares/níveis |
| World/HouseAccess | acesso exterior/fundação e porão; não recolocar solo no espaço subterrâneo |
| World/HouseFurniture, HouseScenery, HouseTaskProps | mobília/decoração/apresentação das tarefas |
| World/HouseTelevision + Shared/Game/HouseBroadcast | televisão/transmissão; cliente TelevisionController |
| Shared/Game/HousePreferences | preferências persistentes permitidas e validação |
| Shared/Game/ForestCatalog | capítulos 6–8, áreas, pistas e 26 objetivos (8 + 9 + 9) |
| Server/Campaign/ForestPlan | plano e validação da mata, ordem de canais/soluções determinísticas |
| World/ForestLayout, ForestBuilder | trilhas, árvores, abrigos, tarefas/rádio/torre/resgate |
| Shared/Game/ForestThreat | regras do perseguidor e apagões por capítulo da mata |
| Shared/Game/ForestCinema | especificação visual do epílogo; integrada ao CinematicController |
| Server/Campaign/Endings | regras de final ligadas ao runtime |
| Shared/Game/Presentation, VisualQuality | diretrizes de apresentação/qualidade usadas pelos controllers |
| Server/Game/CoinPlan + Services/CoinService | distribuição e coleta autoritativa de moedas/gema, pagamento via StoreService |
| Client/Controllers/CoinController | animação/feedback de moedas; não decide coleta ou valor |
| Client/Controllers/TouchControlsController | entrada touch; requer QA real em dispositivo |
| Client/Controllers/TelevisionController | apresentação local da televisão/transmissão |
| Client/Controllers/UiFeedbackController | feedback visual/sonoro da UI |
| Client/Creature/TungTungRig, TungTungClips | rig e animação local do perseguidor |
| ReplicatedStorage/Assets/TungTung.rbxm | modelo binário versionado; Rojo inclui, Script Sync não transporta |

## Atenção à arquitetura herdada

Workspace da casa usa Tags.WorldFolder=CursedHouse; o nome técnico do modelo da criatura continua Vigia. Não confundir nome interno com a identidade do jogo. Confirmar o Root e modo/Active antes de concluir que o mesh está faltando.

CampaignState publica Inventory, EscapeEndsAt, LastClue, Ending e informações narrativas além do resumo coop. Player publica HasFlashlight, HouseSupplies, HousePreferences e feedback; os controllers observam o estado. UseHouseItem e SetHousePreference são remotes próprios; moedas não precisam de pedido de coleta do cliente.

Cinco capítulos da casa + três da floresta precisam preservar inventário e retomada. A extração final é física. A cena da van cria atores e farol temporários, limpa ao terminar/pular e deixa a cartela de continuação; não conceder vitória só por tocar uma cinemática local.

A arquitetura da casa tem vários andares e porão; World/HouseAccess, HouseEnvelope e specs geométricas existem para evitar buracos no solo, paredes bloqueando portas e fundação preenchendo salas subterrâneas. Testar seeds/modos e reconstruções, não só uma captura.

Na mata, preservar rotas da pessoa e da criatura, aproximações das tarefas, esconderijos, pistas anteriores aos puzzles e legibilidade na escuridão. A luz própria da cabeça do Tung Tung fica desligada nesses capítulos; o jogador precisa enxergar com a lanterna/fontes do cenário.

## Dados, assets e câmera

Schema atual 6; StudioMode=mock. Não sobrescrever com a versão 4 da Subestação. Preferências incluem conforto/áudio/qualidade e são validadas no servidor. IDs de mesh/textura/áudio precisam de acesso na experiência de destino; ter o .rbxm local não concede permissão Roblox automaticamente.

A correção d975d86 recupera controle do mouse depois de menus/cinemáticas. Preservar a negociação de câmera entre CharacterController, CameraController, SettingsController, MainMenuController e CinematicController. Não criar outro controlador que force mouse/câmera por frame para esconder o sintoma.

## Versão e QA anteriores

[FLORESTA_TERROR_FINAL.md](../FLORESTA_TERROR_FINAL.md) registra 283 testes puros, 295 no Studio; História dupla 148 verificações e Desafio dupla 150, com limites dos últimos ajustes explicitados no relatório. A correção de câmera é posterior: [CAMERA_MOUSE_FIX.md](../CAMERA_MOUSE_FIX.md) registra outro runner isolado com 295 aprovados e as transições de cursor verificadas, mas o giro físico do mouse continua dependendo de teste humano. O QA de câmera não representa uma repetição completa das duas campanhas.

Boot esperado: 16 services e 34 controllers. A fonte contém 225 arquivos Luau; todos são indexados neste pacote. A build incluída é reconstruída a partir do HEAD documentado, incluindo a correção de câmera; os QA antigos não validam automaticamente esses bytes novos.

Build regenerável: lune run scripts/build. Para nomear: rojo build default.project.json --output build/TungTungSahur.rbxlx (criar build/ antes se necessário). Preferir cópia da build completa ao iniciar um arquivo de desenvolvimento com sync, para preservar o modelo binário.

Balanceamento com a criatura ativa, medo, áudio subjetivo e performance em celular físico continuam exigindo partida humana. Não afirmar isso a partir dos fixtures automatizados.
