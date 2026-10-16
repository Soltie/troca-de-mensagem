# Evidências — tensão, medo e captura

Data: 15/10/2026. Base `0984aef`. Fonte/limites: [TERROR_POLISH_PROGRESS.md](../../TERROR_POLISH_PROGRESS.md).

- `check.txt`: format, lint, tipos, sourcemap e 142 testes puros aprovados.
- `three-clients-presentation.json`: três clientes reais do engine, estados e amostras na VM normal.
  Apenas Player1 recebeu Chase/captura; Player2/3 mantiveram câmera normal. A vítima recebeu impacto,
  retornou à câmera normal em ~1,1 s e foi resgatada pelo remote real Interact após setup de distância.
  Conforto desligado: blur/glitch/vinheta/fog opcional/VHS zerados, FOV base 72, sem erros do projeto.
- `client-probe.luau`: fixture de QA temporário; não faz parte do bootstrap nem é publicado.
- `studio-tests.txt`: 150 testes aprovados no runner do Studio.
- `eight-clients-campaign.json`: regressão final de oito clientes aprovou três estágios, resgate,
  desconexão/substituição, navegação, puzzles remotos e extração coletiva; fase final Won.
- `eight-client-console-snapshots.json`: mensagens cruas de nove clientes (inclui o substituído).
  Preserva erros ChatScript/CoreGuiChatConnections do engine e kick esperado do harness;
  nenhum erro de controller do projeto foi observado nesses snapshots, feitos antes do término.
- `source-manifest.json`: commit e hashes do código final.

O probe é criado como Script com RunContext Client **durante Play**, nunca em Edit, para acessar
o cache de require dos controllers normais. Um require diretamente na VM do MCP cria outra cópia
e não serve para ler o estado real. Depois, a VM do MCP consulta PlayerGui.TerrorQA (BindableFunction).

O probe possui `state`, `settings(bool)`, `setting({key,value})`, `preview(name)`, `spike(amount)` e
`sample` (40 amostras a 50 ms). `preview` só existe no Studio e respeita jogador ativo/fora de Chase.
Criar os scripts temporários somente em sessão de teste própria; parar Play remove tudo.

Receita do teste de três clientes: StudioTestService.ExecuteMultiplayerTestAsync(3,{terrorQA=true,players=3}),
aguardar roster/Playing, congelar a IA via DebugBridge, instalar probe e publicar no Root Mode=Chase,
ThreatTargetUserId=-1. Armar sample nos três clientes; chamar Runtime.lose(Player1) em Script temporário
na VM normal do servidor. Teleportar Player2 para perto da vítima, marcar teleporte no PlayerStateService,
e chamar o remote Interact("rescue_-1") pelo cliente Player2. Conferir status Active e encerrar com EndTest.

Amostras `at` são intervalos nominais; não são medição precisa de latência/FPS. Os testes controlam
posição/IA, sem comprovar diversão ou equilíbrio. Avisos UIBlox/CorePackages e o aviso explícito
do Assistant que restaura CameraType após execute_luau são artefatos do engine/ferramenta e separados
de erros do projeto. Para validar a captura sem esse efeito, o probe amostra a câmera na VM normal
e só é consultado depois do retorno a Custom.
