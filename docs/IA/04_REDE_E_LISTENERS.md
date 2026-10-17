# Rede, listeners e estado replicado

Este guia é o contrato conceitual; os pontos exatos de registro/uso estão em [07_INVENTARIO.md](07_INVENTARIO.md) e [CODE_MAP.json](CODE_MAP.json). Fonte principal: Shared/Net/Remotes e Server/Net/ServerNet. Nunca criar um remote fora de DEFINITIONS.

## Remotes comuns aos dois jogos

| Nome / tipo | Sentido | Entrada e dono no servidor | Consumidor / resultado |
| --- | --- | --- | --- |
| SelectGameMode / Function | cliente → servidor | Standard ou Story; CampaignRuntime valida membro e Lobby | MainMenuController; voto aceito não é início imediato; maioria absoluta e mínimo da equipe |
| Interact / Function | cliente → servidor | id com formato/tamanho validado, ação opcional use/alt; CampaignRuntime ou RoundService solo | InteractionController; resposta de domínio + estado publicado |
| RequestRestart / Function | cliente → servidor | opção de restart, permitida pelas regras/fase; runtime selecionado | UI/Continue; voto/checkpoint/retomada conforme modo |
| SetFlashlight / Event | cliente → servidor | boolean; PlayerStateService (fallback do runtime se não registrado) | atributos de lanterna/bateria; afeta percepção da criatura |
| SetStance / Event | cliente → servidor | Stand/Crouch; PlayerStateService valida condições físicas/teto | corpo/postura autoritativos e apresentação |
| SetHoldBreath / Event | cliente → servidor | boolean; PlayerStateService valida estado/esconderijo | respiração/oxigênio/ruído conforme projeto |
| SetLook / Event | cliente → servidor | pitch numérico limitado; PresenceService | atributos para animação de cabeça/lanterna de colegas |
| Store / Function | cliente → servidor | ação + argumento opcional; StoreService valida política/preço/posse/moeda | StoreController e fluxos de vantagens |
| StoreNotice / Event | servidor → cliente | payload emitido pelo StoreService | StoreController recebe OnClientEvent, mostra saldo/recompensa/aviso |
| StoreTrack / Event | cliente → servidor | open/view + oferta; TelemetryService valida | analytics do funil; não compra nem concede recompensa |
| Lobby / Function | cliente → servidor | servers, join/jobId ou friend/userId; LobbyService | listagem/entrada; sucesso local não prova teleporte publicado |

RemoteFunction retorna envelope de transporte: {ok=true, data=resultadoDoHandler} ou {ok=false, error=motivo}. Um ok=true pode carregar uma recusa de domínio em data (ex.: accepted=false); conferir ambos. Rejeições de transporte incluem rate_limited, invalid_arguments e internal_error.

Não duplicar os handlers da fachada RoundService e CampaignRuntime: só um runtime é escolhido. ServerNet rejeita registro duplicado. Guard valida quantidade e tipo dos argumentos; o runtime ainda precisa validar autoridade, proximidade e possibilidade da ação.

## Remotes adicionais do Sahur

- UseHouseItem / Function: battery, oxygen ou decoy. CampaignRuntime só consome estoque de membro Active, em fase válida, com recurso/necessidade aplicáveis. Atualiza HouseSupplies e estado do jogador; não aceitar uma quantidade vinda do cliente.
- SetHousePreference / Event: chave permitida e número 0..1. CampaignRuntime valida HousePreferences e persiste a preferência em data.house.preferences.

Esses dois não existem em Subestação 9. Não adicioná-los lá apenas para fazer código compartilhado compilar.

## Estado replicado que funciona como eventos

| Canal | Quem publica | Quem observa / por que |
| --- | --- | --- |
| ReplicatedStorage.CampaignState | CampaignRuntime.publish | CampaignController, menus, história/cenas, espectador e efeitos; fase/etapa/mode/roster/tasks/votos/tempos |
| ReplicatedStorage.GameState | GameState + runtime | Character/Camera/Audio/WorldFx/Threat e HUD; compatibilidade de Phase/PowerOn/CreatureActive |
| atributos de Player | runtime e PlayerState/Store/Perk/Presence services | status, papel, graça de resgate, postura, recursos, preferências e feedback por jogador |
| Workspace + Tags | World/Activity builders e services | CollectionService encontra interagíveis/luzes; UI usa InteractId/Prompt/Enabled/Distance |
| Workspace.Vigia.Root | CreatureService | Mode/Active/ThreatTargetUserId e transformação; CreatureVisual/ThreatPresentation representam a ameaça localmente |
| StoreNotice | StoreService | feedback pontual de recompensa/compra, diferente do estado contínuo |

Roster/Tasks e outros campos podem ser JSON serializado em atributos: usar a forma publicada, tratar ausência durante boot/rebuild e não confiar no cliente como autoridade. Serial de evento evita confundir dois avisos com o mesmo texto; confira CampaignFeedbackSerial, StorySceneSerial e, no Sahur, CoinPickupSerial.

## Famílias de listeners

| Listener/callback | Papel | Cuidado ao alterar |
| --- | --- | --- |
| Players.PlayerAdded / PlayerRemoving | dados, adesão da equipe, estado, cosméticos e cleanup | tratar jogadores que já existem quando Start roda |
| Player.CharacterAdded / Humanoid eventos | rebind de corpo/câmera/luz/estado e morte | não manter referência ao Character antigo |
| game:BindToClose | salvar e liberar dados | respeitar timeout; não bloquear indefinidamente |
| RunService.Heartbeat | movimento/estado/IA e relógio do servidor | evitar trabalho pesado duplicado; preservar intervalos/repath |
| RenderStepped / BindToRenderStep | câmera, rigs e efeitos locais | prioridades, cenas e restauração do mouse |
| UserInputService / ContextActionService / botões GUI | ações locais e foco | menus, TextBox, gameProcessed e touch podem consumir o input |
| GetAttributeChangedSignal / AttributeChanged | reconciliar estado replicado | leitura inicial + atualização; estado pode ainda não existir |
| CollectionService sinais de tag / DescendantAdded | objetos e efeitos em mapas reconstruídos | remover conexões/refs quando o objeto some |
| CreatureService.onCapture / setPlayerAdapter / handlers de continuação | injeção entre services/runtime | callback no runtime real, registrado uma vez; não criar segunda instância via require do MCP |
| DebugBridge.OnInvoke / bridges locais de QA | inspeção da VM real no Studio | nunca expor por remote nem deixar grant/teleporte em produção |

O inventário lista as ocorrências por arquivo/linha, inclusive listeners UI, chamadas de remote, funções locais e públicas. Pode haver sinais conectados por helpers/aliases que a busca lexical não reconhece. Para rastrear um caso, buscar o nome do atributo/remote, abrir produtor + consumidor, inspecionar a fase e validar no Play.

## Exemplo de investigação

Se E não interage: conferir input/menu/cena → alvo com tag/atributos → chamada Interact e envelope → registro do handler no runtime escolhido → validação de distância/visão/estado → regra CoopSession → publish e listener do HUD. Não “corrigir” ignorando validação do servidor.

Se a câmera trava depois de uma cena: conferir flags de cinema/menu, CameraController/CharacterController/Settings, restauração de MouseBehavior/CameraType e bindings. No Sahur, a base deste pacote já contém a correção d975d86; não voltar ao comportamento anterior com um controlador paralelo.
