# Integração no experimento tungtung — 18/10/2026

## Base e preservação

Destino solicitado: `tungtung`, PlaceId `82955516040017`, UniverseId `10771638828`. Backup completo nativo salvo pelo humano e conferido contra a leitura oficial MCP: **250 scripts, nenhuma divergência**. SHA-256 do backup: `6939b214eae5d6d45a58a1edfa496d0b8d7d6533d8530d8ef152e284678ae1cc`.

Referência nossa: commit `08f697cf557fc9851d4844bb7121e1283742448c`, branch `codex/forest-tumtum-export`. A cópia atual do destino foi registrada em `d9bd32c` numa worktree isolada. A raiz definitiva é `codex/tungtung-live-integration`, criada a partir da implementação `cd23069`. Nenhum reset ou substituição do checkout principal. O pacote anterior e o histórico da caçada antiga permanecem no canal de entregas.

Comparação: **186 fontes iguais, 39 divergentes, 25 exclusivas do destino, 11 exclusivas da referência antiga**. Inventário completo em `evidence/shared-integration/comparison.json`. Todas as 250 fontes recebidas continuam no projeto final; oito receberam integração localizada. Os 11 arquivos antigos da caçada não são inicializados junto do Midnight Hunt.

## Decisões por sistema

| Sistema | Estado recebido do destino | Decisão |
| --- | --- | --- |
| Floresta | ForestCatalog/Plan/Layout/Builder/Threat/Cinema e rig Armadilho já iguais à referência | Preservados; validar capítulos 6–8, 26 objetivos 8/9/9, van e epílogo na build final |
| Casa/fundação | HouseEnvelope/HouseAccess/HouseBuilder e navegação iguais à referência | Preservados, com o mapa atual |
| Campanha | CampaignRuntime tem bloqueios PvP e lógica da floresta atual | Preservar; recuperar proteção de restart e respawn de morto/ausente ao voltar ao lobby |
| Caçada | Midnight Hunt novo: fila, papéis, captura/transporte/resgate, ritual, portas, matchmaking/salas | Preservar todos os módulos e contratos do receptor; não ativar TumTumService paralelo |
| Câmera | CameraController com recuperação do ponteiro e provider HunterCameraController | Preservar a câmera atual e validar olhar com RMB solto/menus |
| UI/loja/conforto | Menu/loja/componentes/ícones/configurações mais recentes | Preservar remaster; unir somente a espera dos avisos pelo epílogo e visibilidade do holder |
| Dados | Duas linhas distintas usaram schema7: tumTum antigo e pvp atual | Schema8 mantém ambos, saneia campos e conserva wallet/XP/recibos/progresso. Sem converter moeda nem conceder recompensas |
| Rede/boot | Remotes PvP/ServerNet e um Main de cada lado | Preservados integralmente. Nenhum remote novo |
| Mundo/assets/settings | Backup completo contém o estado atual | Builder altera somente Source; todos os demais chunks ficam byte a byte |

## Oito arquivos integrados

| Arquivo | Alteração |
| --- | --- |
| Client/Controllers/StoreController | ForestEpilogueVisible adia avisos e oculta toasts durante cena/cartela; mantém loja nova |
| Shared/Config | SchemaVersion 8 |
| Shared/Types | Perfil tumTum preservado junto de pvp |
| Server/Campaign/CampaignRuntime | restart não interrompe PvP; respawn dos mortos/ausentes no lobby |
| Server/Data/PlayerDataSchema | Reconciliação dos dois schemas7, sanitização fechada do legado |
| Tests/Specs/PlayerData | Casos com as duas origens, recibos/carteiras/progresso, corrupção e migração repetida |
| Tests/Specs/PvPMatch | Expectativa de schema8 na migração atual |
| Tests/PvPHarness | Aguarda menu visível após a abertura antes de validar a entrada em cada cliente |

Os outros 242 arquivos atuais não foram alterados. O comportamento competitivo, os tempos atuais e a economia do Midnight Hunt continuam os do receptor. Os módulos/arquivos completos da referência antiga podem ser recuperados pelo bundle/pacote anterior, sem substituir o runtime mais recente.

## Build nativa e auditoria

`tools/build_shared.luau` verifica o hash exato da base, a lista completa de fontes e a multiplicidade das strings antes de modificar o chunk Source. Não adiciona/remove instâncias. Os demais chunks binários são copiados literalmente, incluindo INST/PRNT, modelos, propriedades novas do Terrain, Lighting, AvatarSettings, nomes, atributos e tags.

`tools/audit_shared.luau` relê base e build, compara os 1500 chunks e só aceita diferenças em propriedades Source. Conferiu **uma diferença Source e 1499 chunks idênticos**, além das 250 classes/fontes embutidas correspondendo ao disco. O leitor do Lune avisa que não entende Terrain.VoxelGridAssetContentMap; ele é usado só para conferir fontes, nunca para regravar o mundo. O chunk original dessa propriedade foi preservado integralmente.

Build: `build/Tungtung_INTEGRADO.rbxl`. SHA-256 atual: `92f7f7a19a388afcd780f3d278ac1ebdfd37cc69ff35b5225872f92484bfdb62`. Recibo e auditoria ficam ao lado do arquivo.

## Validação desta build

- Baseline atual: check ALL GREEN, 320 testes puros.
- Integração final: check ALL GREEN, **323 testes puros**, sem erros de lint/tipos.
- Studio da cópia `Tungtung_INTEGRADO.rbxl`: **335 aprovados, 0 falhas**, boot 18 services/40 controllers.
- Captura confirmou menu atual com Midnight Hunt e opções História/Desafio.
- Midnight Hunt com três clientes: 72 verificações registradas no servidor, até a retomada da História após limpeza. Callback indisponível após interrupção; não se inventa um payload final recuperado.
- História em dupla: RESULT success=true, 148 verificações, oito capítulos, derrota/retry, floresta, van/final, retorno ao lobby e nova rodada. Callback expirou em 300s; servidor concluiu em 302,8s. Evidências filtradas e resumo recuperado em evidence/shared-integration/.
- Midnight Hunt com seis: **success=true, 98 verificações**, incluindo segunda rodada, rotação do caçador e desconexão. Callback completo em midnight-6-tool.json.
- Runner após instalação no próprio destino: **335 aprovados, 0 falhas**, boot 18 services/40 controllers. Play encerrado.
- Câmera: o teste de seis validou provider FPS, FOV80, rig e mãos; no destino, LockCenter com RMB/LMB soltos e sem modal visível. A tentativa de rotação por VirtualInput foi rejeitada pelo engine com cursor is not locked, mesmo com a propriedade LockCenter. O teste de posição absoluta também não mediu rotação. **Não há comprovação de mouse físico nem de rotação automática nesta integração**; os erros de sondagem estão guardados. A câmera do receptor foi preservada, sem alterar seu código com base nessa limitação de automação.

Avisos internos UIBlox/FoundationProvider foram observados. Não foi observado erro de módulo do jogo no primeiro Play. Hardware físico, equilíbrio/diversão e persistência live não foram validados. Studio usa MockDataStore.

## Coordenação e estado de instalação

Documentação/mensagens publicadas no canal autorizado https://github.com/Soltie/troca-de-mensagem. Mensagens 001 e 002 pedem que o outro agente identifique branch/HEAD/reservas e registre todo o processo. Ainda não houve resposta registrada do outro agente até o fechamento desta entrega. A autorização para esse canal não inclui push no repositório principal nem publicação no Roblox.

**Integração aplicada ao lugar compartilhado nesta sessão do Studio.** ReplicatedStorage e ServerScriptService estão SyncedAsRoot, sem exceções nos scripts; as 250 fontes correspondem ao disco, com schema8. Workspace original (Terrain, SpawnLocation, Baseplate, Camera) e os 31 descendentes de Assets preservados.

Raiz definitiva: `C:/Users/xpg/Documents/tungtung-integrado`, branch `codex/tungtung-live-integration`, implementação `cd23069`. Só este PC está conectado como integrador. O vínculo lembra essa pasta; não mova/apague suas raízes enquanto estiverem sincronizadas.

O primeiro vínculo criou uma subpasta de exportação; foi desativado e a cópia gerada foi preservada em backup. O diálogo no caminho sob .cache propôs remover pastas; essa operação foi cancelada. Na raiz definitiva fora de .cache, o diálogo mostrou corretamente somente os oito arquivos modificados, sem adições/exclusões; Keep Disk aplicou a integração. Não foi executada exclusão de instâncias.

Não houve publicação no Roblox ou alteração de DataStores live. Fonte verificada no editor compartilhado não prova que o colega já sincronizou seu PC nem que a versão publicada foi atualizada.
