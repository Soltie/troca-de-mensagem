# QA, manutenção e pontos de extensão

## Rotina por tarefa

1. Identificar raiz, branch, HEAD, arquivos alterados e reservas em LEIA_CLAUDE.md. Tratar reservas antigas como histórico até confirmar o estado atual. Declarar arquivos da tarefa antes de concorrer com outro chat.
2. Ler AGENTS.md, a skill local relevante, este pacote e os módulos envolvidos. Não editar o jogo vizinho por require/caminho compartilhado.
3. Editar no disco. Executar lune run scripts/check; só corrigir formatação dos arquivos próprios em trabalho concorrente. Um format global pode alterar arquivos de outra sessão.
4. Se usar sync, confirmar raízes/destino/Sources. Se usar build, rebuild e reabrir o arquivo novo.
5. Listar Studios, escolher instância pelo arquivo/place e estado. Não parar Play/gravação de outra sessão.
6. Iniciar Play, conferir boot/console, rodar Tests.Run em Server e cenários de gameplay com clientes adequados. Capturar UI/cena no cliente.
7. Conferir vitória, derrota, reinício/continuação, resgate, desconexão e nova votação quando o fluxo afetado depender deles. Conferir caminho normal além de fixtures.
8. Encerrar o Play próprio; registrar logs/limites; stage explícito, revisar diff e commit local. Push/publicação dependem do escopo autorizado.

## Comandos

~~~powershell
rokit install
lune run scripts/check
lune run scripts/test
lune run scripts/sourcemap
lune run scripts/build
~~~

check encadeia format check, lint, sourcemap, análise strict e testes puros. scripts/test roda o subconjunto puro; specs robloxOnly puladas no Lune precisam do engine. ALL GREEN local não prova que o código chegou ao Studio.

Antes de alterar src/, ler [.agents/skills/luau-conventions](../../.agents/skills/luau-conventions/SKILL.md).
Para QA, ler [.agents/skills/roblox-playtest](../../.agents/skills/roblox-playtest/SKILL.md). Ela nasceu no template: a linha antiga de PingController/PingService é histórica; esses módulos não fazem parte dos bootstraps atuais.

## Runner e estado real

No execute_luau, datamodel_type=Server, com Play rodando e studio_id correto:

~~~lua
return require(game:GetService("ServerScriptService").Tests.Run)()
~~~

Esperado: zero falhas. Para ler o estado da instância REAL dos services, não fazer require de CampaignRuntime/CreatureService na VM do MCP e tomar o resultado como o estado em execução. Usar a ponte criada por DebugService:

~~~lua
local bridge = game:GetService("ServerStorage"):FindFirstChild("DebugBridge")
assert(bridge and bridge:IsA("BindableFunction"), "DebugBridge missing")
return bridge:Invoke("state")
~~~

Ler a tabela commands do DebugService para outros comandos. A ponte só existe no Studio. Comandos grant/teleport/freezeCreature/forestChapter são preparação técnica; teste que os usa deve declarar isso e não provar equilíbrio/dificuldade/diversão.

execute_luau em Edit deve ser leitura. Mutações, fixtures e testes com efeitos devem acontecer numa cópia descartável em Play. Não chamar multi_edit para corrigir fonte sincronizada.

## Receitas de extensão

**Nova tarefa/objetivo:** alterar catálogo/plano/regra pura do jogo correto; criar metadados e construção física; integrar no runtime sem revelar soluções privadas; publicar resumo; apresentar prompt/HUD/feedback; pagar recompensa uma vez; testar ordem/dependências/erro/distância/duplicata e rebuild/restart.

**Nova sala/rota:** alterar layout e builder, portas/vãos/collision/raycast, spawns, posições das atividades, navegação dos dois agentes e iluminação. No Sahur, incluir fundação/perímetro/porão e seeds/modos. Na Subestação, preservar mapa fixo de História e sorteio de Padrão.

**Novo service/controller:** contrato Name/Init/Start, API explícita, registro único e ordem no Main; não criar Script solto. Para listeners de Character/mapa reconstruído, testar rebind/cleanup.

**Novo efeito/som/cena:** integrar Camera/Transition/Cinematic/Audio existentes, respeitar volumes/conforto/ReducedMotion, fases, espectadores e skip; restaurar câmera/mouse/input/atores/luzes ao fim, interrupção, derrota e restart.

**Novo item/compra/recompensa:** StoreCatalog/Economy/StoreService/RewardService e schema se necessário; validar política, posse, preço, saldo e idempotência no servidor. IDs reais e testes de compra exigem autorização específica; não inventar IDs nem dizer que mock comprova compra real.

**Novo atributo/remote:** localizar produtor e consumidores, documentar formato e defaults, testar ausência inicial/rebuild; no remote usar Guard+rate limit e validar autoridade no handler. Não criar handlers duplicados nos runtimes.

## Diagnóstico rápido

| Sintoma | Investigar primeiro |
| --- | --- |
| Jogo espera jogadores | mínimo do Config e votos/maioria; Subestação precisa de pelo menos 2 |
| Não existe CampaignState | boot interrompido, runtime selecionado, source/build errados |
| Função nova ausente no Studio | raiz/destino do sync ou build aberta antiga |
| Root da criatura existe, visual não | assets/rig/permissão de mesh, Controller e modo/Active |
| Cliente duplicou HUD/câmera | segundo bootstrap/Starter* ou conexões repetidas |
| Teste puro verde e engine falha | spec robloxOnly, navegação/collision/Source diferente |
| Ler service via MCP dá estado vazio | outra VM/cache de require; usar DebugBridge |
| Saldo volta ao reiniciar Studio | perfil mock não persiste; conferir StudioMode sem habilitar APIs reais automaticamente |
| Sahur não tem lanterna no início | progressão HasFlashlight/inventário da história; não burlar no cliente |
| Input não volta depois de menu | câmera/cena/settings e MouseBehavior; conferir correção d975d86 do Sahur |

## Evidência mínima para a próxima IA

Entregar commit/branch/raiz, arquivos tocados, check/log, build usada, studio_id observado, runner, cenários e capturas relevantes, estado final de Play/sync, pendências reais e limitações de QA. Diferenciar revisão de código, teste puro, teste engine, fixture e partida humana.

Neste pacote a alteração é de documentação e do indexador, sem mudança de gameplay. Os checks locais são reexecutados; os números de QA de engine dos relatórios de versão continuam evidência anterior, não um novo playtest. A configuração no computador do colega e a permissão dos assets na experiência dele ainda precisam ser verificadas lá.
