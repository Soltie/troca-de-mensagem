# Como testar a campanha cooperativa

Fonte: `src/ServerScriptService/Tests/CampaignHarness.luau` e documentação de
[StudioTestService](https://create.roblox.com/docs/reference/engine/classes/StudioTestService).

O harness só é iniciado no Studio, com argumentos explícitos de teste. Clientes simulados executam
o HUD e enviam `Interact` pelos mesmos remotes do jogo. O servidor usa teleporte de setup e congela
o Vigia durante as ações do roteiro; isso não comprova equilíbrio de perseguição nem diversão humana.

## Receita reproduzível

1. `lune run scripts/check` precisa passar.
2. `lune run scripts/build` gera a place descartável com scripts embutidos.
3. Abrir **essa cópia local** no Studio, sem conectar Script Sync a outra pasta de trabalho.
4. Identificar o `studio_id` correto por `list_roblox_studios`. Não usar o Studio de outro agente.
5. Em Edit, via MCP, executar para três clientes:

```lua
task.spawn(function()
	local ok, result = pcall(function()
		return game:GetService("StudioTestService"):ExecuteMultiplayerTestAsync(3, {
			campaignQA = true,
			players = 3,
		})
	end)
	print("[CampaignQAResult3] " .. game:GetService("HttpService"):JSONEncode({ ok = ok, result = result }))
end)
return "QA iniciado"
```

6. Ler os logs/resultado no editor de origem. Um teste aprovado tem `ok=true`,
   `result.success=true`, `stage=3` e `phase="Won"`.
7. Repetir com os dois valores `8` e o marcador `CampaignQAResult8`.
8. Confirmar que a sessão terminou e os clientes de teste foram fechados. O harness chama `EndTest`;
   há watchdog para falha/timeout. Não encerrar uma sessão alheia para liberar esta.

O editor continua em Edit durante a simulação; o MCP pode listar outros Studios sem nome. Use
`get_studio_state` para distinguir o servidor e cada cliente. Todos os calls levam `studio_id`.
Capturas dos clientes comprovam o HUD. `LogService:GetLogHistory()` permite filtrar somente o
marcador final, sem misturar avisos do UIBlox/CoreScripts com erros do projeto.

## O que o roteiro verifica

- 3 ou 8 clientes do engine conectados, roster correspondente e posições de spawn distintas.
- Setup forma o lote completo antes de reiniciar a campanha medida; o mínimo normal continua 3.
- Captura individual não encerra a rodada da equipe; outro cliente resgata via Interact e tempo real.
- Pedido remoto distante é recusado sem alterar progresso.
- Uma desconexão real de cliente **simulado** não perde a rodada; `AddPlayers(1)` substitui a vaga.
- Entrada tardia aguarda o estágio seguinte e depois torna-se ativa, sem reescrever o puzzle atual.
- Caminhos físicos para jogador e Vigia até todas as estações do plano de cada estágio.
- Reparos, sequências e relés distintos resolvidos pelos clientes, usando distância, visão e cooldowns.
- Escala de atividades por grupo e transições dos três estágios.
- Um sobrevivente sair não termina a partida dos outros; vitória só após a extração da equipe.

## Testes que continuam separados

`Specs/CampaignGenerator` verifica 3.600 planos, seed, conectividade lógica e rejeição de planos inválidos.
`Specs/CoopSession` verifica grupos 3–8, resgate expirado, wipe, votos, concorrência/repetição,
desconexão, fallback do último sobrevivente e limpeza de uma equipe vazia.
Esses testes puros não substituem a simulação com clientes.

Ainda é necessário playtest humano com 3–8 pessoas e medição sustentada de FPS/latência. O roteiro
automatizado desloca jogadores pelo servidor e congela a IA; não representa uma partida normal completa.

## Resultados desta entrega (15/10/2026)

Código final: `ca66ead`, mais os commits `31f6b59` e `68f3768`, sobre Claude `c6b247a`.
Campanha ativada como padrão. Evidências em [evidence/coop](evidence/coop/README.md):

- `check-global.txt`: 136 testes puros, ALL GREEN (format/lint/tipos/sourcemap/testes).
- `studio-tests.txt`: runner completo no Dev, 144 aprovados e zero falhas.
- `integrated-three-clients-result.json`: três clientes do engine, três estágios, Won.
- `integrated-eight-clients-result.json`: oito clientes, após corrigir spawn e áudio, Won.
- `final-hud.png`: HUD final em Play local, aguardando o mínimo de três jogadores.
- `audio-instance-preload.json`: 54 entradas de áudio, 49 IDs únicos, carregamento aprovado.
- `audio-lifetime.json`: seis ciclos da função real de áudio posicional, zero erros/resíduos.

O console final do Play local (servidor e cliente) não apresentou warnings/erros do projeto.
Isso não equivale a auditoria individual de todos os oito consoles durante toda a simulação.

A primeira tentativa de preload passou strings diretamente ao ContentProvider e registrou
falhas incompatíveis com Sounds já carregados. `audio-preload.json` foi preservado como
**procedimento descartado**, não como falha vigente do jogo. A auditoria válida usou Instances
de Sound, conforme [ContentProvider](https://create.roblox.com/docs/reference/engine/classes/ContentProvider),
verificou IsLoaded/TimeLength/status e destruiu os objetos temporários. Não comprova mixagem
humana, desempenho sustentado ou disponibilidade dos assets numa futura publicação.
