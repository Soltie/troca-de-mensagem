# Continuidade — interações, armário e espectador

Continuação Codex de `f421565`, em 15/10/2026, mesma branch `claude/polish-terror`.
Sem reset, push, publicação ou novos assets. Este documento separa o código entregue do QA humano.
Concluído em 16/10/2026, código em `a09113a`. Studio Dev devolvido em Edit, clientes de teste
encerrados, nenhuma reserva. Script Sync íntegro nas duas raízes, campanha padrão ativada.

## Implementado

- `InteractionController`: destaque único ocluído, prompt E/Q e tranca conforme chave no solo;
  animação de coleta/chave, papel e procedimento com ordem real, feedback de acerto/erro de puzzle.
  O servidor continua validando as ações. Respostas de outra rodada/fase/status são descartadas.
- Armário solo: câmera limitada por `HideEye`, E sai sem mirar, Espaço prende/solta respiração;
  perda de foco solta a respiração. Captura e respawn liberam a câmera.
- Prompts, bilhetes e legendas vivem em `InteractionUi`, preservados quando o coop desliga o HUD solo.
  A campanha usa o mesmo prompt e mantém suas regras atuais: armários/itens solo desativados;
  Q não reativa a porta solo na campanha.
- `SpectatorController` e `SpectatorRules`: Waiting/Escaped acompanham apenas colegas Active vivos,
  com câmera no olho do colega, sem movimento livre. Setas esquerda/direita trocam o alvo;
  desconexão, nenhum alvo e retorno ao jogo são tratados. Downed mantém a visão do próprio resgate.
  O radar da especialidade scout só aparece enquanto o jogador está Active.
- Lanterna e seu modelo local deixam de iluminar/aparecer para membros fora de jogo.
- Menu O: ação de alta prioridade evita o conflito com zoom da câmera padrão da Roblox.
  Referência: [ContextActionService](https://create.roblox.com/docs/reference/engine/classes/ContextActionService),
  [CameraInput oficial](https://github.com/Roblox/avatar/blob/main/ReferenceBodyCreator/StarterPlayerScripts/PlayerModule/CameraModule/CameraInput.lua).

## Verificado

Check local: ALL GREEN, 148 testes puros. Studio: 156 aprovados, zero falhas, boot de 18 controllers.
As duas raízes do Script Sync foram confirmadas. O solo foi selecionado temporariamente no arquivo
Config para regressão; `Campaign.Enabled=true` já foi restaurado.

No solo: E real via MCP entrou/saiu do armário; Espaço confirmou HoldBreath e o prompt correspondente.
Lanterna apagou/restaurou. Captura no armário passou por capture e voltou a normal, sem prompt ativo.
Q entreabriu a porta; chave/fusível geraram PickupFx, destrancar gerou KeyFx, bilhete mostrou a ordem
A - C - B da rodada. Erro do disjuntor gerou legenda, trauma e pulso; conforto desligou o pulso.
Sequência correta devolveu SISTEMA RELIGADO (o teste não mediu o instante posterior da energia).
O abre/fecha e 1 alterna a opção via MCP após a correção. Isso não é teclado físico humano.

Multiplayer dirigido: três clientes, captura real, espera pelo prazo real de resgate e transição
Downed→Waiting. Waiting passou a spectate, setas reais do MCP trocaram -3/-2 e E não mostrou
prompt nem destaque. SpotLight/PointLight locais estavam desligados. Um quarto cliente entrou
tarde como Waiting e acompanhou os ativos. Desconectar o alvo trocou para o sobrevivente;
wipe encerrou o espectador. Vigia congelado: não é teste de perseguição/balanceamento.

Regressão posterior com três clientes: fixture Waiting controlada, câmera spectate, reinício real
da campanha e respawn; o jogador voltou Active, modo normal, câmera Custom com CameraSubject
no próprio Humanoid e banner oculto. O probe fica em ScreenGui com ResetOnSpawn=false;
a primeira tentativa perdeu sua BindableFunction temporária no respawn e foi repetida.
Runner completo repetido na versão final: 156 aprovados, zero falhas.
Recibos e fontes dos probes em [evidence/interaction-spectator](evidence/interaction-spectator/).

Campanha final com oito clientes: **APROVADA**, estágio 3 / Won, seed 1792143369 e 125 verificações.
Incluiu resgate real por remote, rejeição de distância, desconexão/substituição, entrada tardia
retornando no estágio seguinte, pathfinding e extração coletiva. Arquivo `eight-clients-campaign.json`.
Check final ALL GREEN, 148 testes; build descartável aprovado. Consoles solo e servidor dos probes
sem warnings/erros do projeto; os oito consoles inteiros não foram auditados individualmente.

As consultas de módulos foram executadas na VM normal por scripts temporários durante Play.
O MCP cria outra VM para require: não usar seu estado como prova do runtime. Uma primeira tentativa
de criar Source de dentro do próprio script de teste foi recusada por capability e descartada.
O screen_capture deixou a câmera Scriptable durante uma tentativa; o probe de mira foi corrigido
para restaurar Custom antes de mirar. Essa tentativa de puzzle foi repetida e não conta como falha do jogo.

## Próximas pendências

QA visual humano em iluminação normal (a captura do armário permaneceu escura); raios de geometria
confirmaram passagem central e bloqueio nas faixas. Conferir mouse limitado e legibilidade com pessoas.
Portar ocupação/liberação de armários ao coop requer mudança explícita no runtime, ainda pendente.
Próxima implementação disponível: definir esconderijos por jogador no CampaignRuntime, liberar
ocupação ao desconectar/capturar/trocar estágio e validar alvos do Vigia. Não habilitar os prompts
solo como atalho; eles continuam desativados pelo runtime da campanha.
Continuam em NEXT_STEPS: playtest humano 3–8, desempenho/latência, haptics, arte, menus/checkpoint,
duto, puzzles novos e níveis físicos adicionais. Não representam entregas desta continuação.
