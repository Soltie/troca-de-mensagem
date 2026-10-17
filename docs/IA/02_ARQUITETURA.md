# Arquitetura e contratos comuns

Este texto explica o padrão compartilhado. [O projeto atual](03_PROJETO_ATUAL.md) e o código desta raiz resolvem divergências entre os jogos. Nomes herdados como Vigia, Campaign e Standard podem continuar no Sahur; renomear tudo sem necessidade cria uma migração grande.

## Mapa do repositório

| Caminho | Papel / fonte da verdade |
| --- | --- |
| src/ServerScriptService/Server/Main.server.luau | bootstrap único do servidor, cria remotes e registra services |
| src/ReplicatedStorage/Client/Main.client.luau | bootstrap único do cliente, registra controllers; Script RunContext Client |
| src/ReplicatedStorage/Shared/Loader.luau | chama todos os Init e depois todos os Start, respeitando a ordem das listas |
| Server/Services | serviços de engine, persistência e integração do runtime |
| Server/Campaign | planos privados, estado puro da equipe e runtime da campanha |
| Server/Game | regras puras do protótipo e economia/telemetria |
| Server/World | construção versionada de mapas, geometria, props, passagens e arte |
| Client/Controllers | entrada local, UI, câmera, áudio e apresentação |
| Client/Creature, Client/UI | rig/poses/visual e helpers da interface |
| Shared/Game | catálogos/metadados e modelos compartilhados; não guardar segredo de puzzle aqui |
| Shared/Net | registro de remotes, validação de argumentos e token bucket |
| Server/Data | schema, migrações, mock e SessionLock |
| ServerScriptService/Tests | runner, TestKit, specs e harness de campanha |
| places/world, *.project.json | mundo base/layout/preset usados pelo Rojo |
| assets/ e src/ReplicatedStorage/Assets | arquivos binários versionados; conferir inclusão no build e permissões dos IDs Roblox |
| .agents/skills | instruções portáteis de convenções, Script Sync e playtest; estão no clone |
| build/, .cache/, sourcemap.json | gerados; não são o código oficial nem via normal de contribuição |

Os caminhos abreviados Server/..., Client/... e Shared/... desta documentação são relativos às árvores acima.

## Boot e escolha de runtime

O servidor cria ReplicatedStorage.Remotes antes de Loader.boot(services). Init prepara; Start conecta listeners e começa loops, usando task.spawn quando precisa ceder a execução. Um erro interrompe o boot e deve ser corrigido na fonte.

O slot RoundService é uma fachada: se CampaignMode.enabled() for true, retorna CampaignRuntime; caso contrário, executa a rodada solo herdada. Os dois NÃO podem registrar os mesmos handlers/loops simultaneamente. Main injeta PlayerStateService pelo setPlayerAdapter quando a API existe. Não registrar CampaignRuntime mais uma vez como service.

O cliente aguarda game.Loaded e passa os controllers ao Loader. Não adicionar outro Script de bootstrap. Uma cópia em Starter* pode executar junto com o bootstrap atual, duplicando câmera, UI, input e conexões.

## Services: responsabilidades

| Service | Responsabilidade e integração principal |
| --- | --- |
| PlayerDataService | load/update/save, mock/real, autosave, PlayerAdded/Removing/BindToClose; usa schema e lock |
| TelemetryService | economia/funil StoreTrack; histórico local de QA no Studio; AnalyticsService no servidor ao vivo |
| StoreService | saldo, compras/equipamento/progressão/consumíveis, recibos e StoreNotice; nunca aceitar preço do cliente |
| WorldService | cria/reconstrói mundo e aplica energia/portas/portão/passagens/objetos |
| PlayerStateService | bateria, postura, esconderijo, oxigênio/respiração conforme projeto; trata SetFlashlight/SetStance/SetHoldBreath |
| PresenceService | SetLook validado; orientação visual de cabeça/lanterna dos outros jogadores |
| LobbyService | descoberta/entrada em servidores pelo Lobby; MemoryStore/teleporte têm limites fora do Studio |
| CreatureService | posição e percepção autoritativas da criatura, pathfinding/ruído/captura; callback onCapture |
| PropService | integração de props/eventos de ambiente e efeitos que dependem do servidor |
| CosmeticService | aplica cosméticos autorizados a partir dos dados |
| CollectibleService | fitas/colecionáveis, coleta e recompensa sem duplicação |
| RoundService / CampaignRuntime | único dono do ciclo da partida, interações, seleção de modo, equipe e progressão |
| RewardService | paga resultados/progresso segundo regras; evitar duplicação no replay/restart |
| PerkService | resolve vantagens compradas/desbloqueadas e ganchos de resgate/continuação |
| DebugService | cria ServerStorage.DebugBridge só no Studio; inspeção/fixtures, nunca comando remoto público |

CoinService só existe no Sahur atual e está documentado no guia do projeto. Funções reais, assinaturas e linhas de todos os módulos estão no [inventário](07_INVENTARIO.md).

## Controllers: responsabilidades

| Controller | Função |
| --- | --- |
| SettingsController | preferências locais, conforto e volumes; serve os demais efeitos |
| TransitionController | fades, letterbox, pálpebras, cartelas e transições |
| AudioController | mixer/camadas/trilhas/stingers e reação ao estado |
| CharacterController | controle do corpo, corrida/agachamento/fôlego e políticas de entrada |
| CameraController | primeira pessoa, offsets, FOV, trauma e modo cinema |
| CharacterAnimatorController | poses do jogador e representação dos colegas |
| BodyAudioController | passos/respiração e som corporal |
| FlashlightController | luz e modelo locais da lanterna, pedido SetFlashlight |
| FearController | intensidade de medo local segundo o estado e ameaça |
| LightingController | apresentação de luz/exposição conforme o projeto |
| RetroFxController | tratamento retrô/overlays e preferências |
| WorldFxController | apresentação de luzes e efeitos do mundo |
| ArtController | materiais/detalhes/efeitos locais de arte |
| TensionController | diretor de tensão/eventos locais canceláveis |
| ScreenFxController | blur/fog/overlays ajustados ao conforto |
| ThreatFeedbackController | feedback da captura, susto e restauração da câmera |
| CreatureVisualController | render do perseguidor; o Root autoritativo vem do servidor |
| GameUiController | HUD/guia/objetivo/feedback e telas herdadas |
| InteractionController | mira/prompt/input e chamada Interact; não decide conclusão ou recompensa |
| HudController | diagnóstico local; não confundir com HUD principal |
| HapticsController | vibração conforme preferências/dispositivo |
| CosmeticController | apresentação dos cosméticos autorizados |
| StoreController | loja, ofertas, notificações e telemetria; não concede saldo |
| CampaignController | HUD da campanha/equipe/tarefas/feedback, lendo CampaignState |
| SpectatorController | câmera e UI de espectador segundo status/regras |
| CinematicController | abertura/cenas de etapa/finais; restaura câmera, input e atores |
| MainMenuController | menu inicial e votação de modo; ModeMenuController antigo foi substituído |
| ContinueController | UI de continuação/retomada ligada às regras do servidor |
| StoryController | gravações, legendas, cenas e progresso narrativo |
| TrailerController | ferramenta de gravação exclusiva do Studio, inativa no fluxo normal |

Sahur acrescenta CoinController, TouchControlsController, TelevisionController e UiFeedbackController. Consulte a ordem exata de cada bootstrap; a tabela acima descreve responsabilidades, não uma ordem alternativa.

## Estado, eventos e fronteiras

O fluxo de uma interação normal é:

~~~text
input local → InteractionController → Remotes.Interact
 → ServerNet (rate limit + Guard + pcall)
 → CampaignRuntime (fase/membro/distância/visão/cooldown)
 → CoopSession (regra pura) + WorldService (efeito físico)
 → publish (CampaignState/Player/GameState)
 → controllers observam atributos → HUD/áudio/câmera/feedback
~~~

CampaignState replica um resumo, não a solução privada dos planos. GameState mantém atributos compatíveis com áudio/câmera/efeitos do protótipo. Player mantém status individual, lanterna, bateria e feedback. Tags/atributos em Shared/Game/Tags conectam interagíveis, luzes, mundo e criatura.

Eventos internos não são todos remotes: callbacks como CreatureService.onCapture e adapters de estado/loja ligam os services; BindableFunction cruza VMs para depuração; GetAttributeChangedSignal/AttributeChanged e sinais de CollectionService atualizam clientes. Localize cada uso e seu dono no inventário, confirme o contexto no corpo.

Loops Heartbeat/RenderStepped/BindToRenderStep devem respeitar fase, cenas e cleanup. Ao recriar personagem/capítulo/rig/UI, desconectar a conexão antiga ou manter um dono persistente que rebinda os descendentes. Não resolver vazamento criando mais um loop.

## Persistência e dinheiro

PlayerDataService já usa SessionLock com UpdateAsync, renovação e liberação na saída. O TODO de “sem trava de sessão” em documentos antigos do template está ultrapassado para estas fontes. Isso não equivale a uma auditoria completa de concorrência em produção.

Para mudar formato: Types.PlayerData + PlayerDataSchema + Config.Data.SchemaVersion + migração e spec de dados antigos/corrompidos. Não copiar o schema de um jogo sobre o outro: as versões atuais divergem.

Config.Data.StudioMode controla só Studio. Ao vivo, o código usa DataStore real; falha de load não deve sobrescrever dados com defaults. Em Studio real, o nome recebe sufixo _Studio. Receipts, políticas e IDs ficam em StoreService/StoreCatalog; valores zero ou QA simulado não provam compra real.

## Convenções para acrescentar conteúdo

Ler [.agents/skills/luau-conventions](../../.agents/skills/luau-conventions/SKILL.md) antes de editar src/. Todo arquivo --!strict; tabs, 120 colunas, identificadores em inglês, comentários PT-BR, logs via Logger. Requires relativos na mesma árvore e @game/... entre serviços.

Nova regra sem engine: módulo puro + specs. Novo serviço/controller: contrato Name, Init?, Start? e registro no Main único. Novo remote: DEFINITIONS + ServerNet + Guard em todos os argumentos + rate limit + rejeição dos inválidos; preservar o tipo Result e o retorno de domínio. UI: Controllers + UI/Create/FieldHud, sem edição manual do Studio.
