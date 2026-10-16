# Evidências — tarefas cooperativas — 16/10/2026

## Resultado

- Pasta compartilhada: `lune run scripts/check` **ALL GREEN**, **248 passed, 0 failed**,
  cinco specs exclusivos do Roblox pulados no Lune. Formatação, lint e tipos strict aprovados.
- Commit isolado de tarefas, sobre `a885224`: **ALL GREEN**, **243 passed, 0 failed**,
  cinco specs exclusivos do Roblox pulados. A diferença são os cinco testes do guia da frente HUD.
- Build integrada `build/TasksFinalQA.rbxlx`: runner **275 passed, 0 failed, 0 skipped specs**.
  Relatório observado pelo MCP em `studio-suite.log`. A execução anterior teve o mesmo resultado.
- **Padrão, 2 clientes do engine:** **107 verificações**, três etapas concluídas, evacuação `Won`.
- **História, 2 clientes do engine:** **86 verificações**, três capítulos concluídos, evacuação `Won`.
  `TasksStoryObserved` registra o estado final de forma compacta.
- Revisão posterior preservou o progresso dos relés já concluídos quando o autor sai/é capturado.
  A build final `build/TasksReleaseQA.rbxlx` passou **29 testes direcionados no Studio**
  (CoopSession, TaskRewards, TaskStations, StoryMode), sem erros/warnings do projeto.
  Check compartilhado 248 e isolado 243 repetidos após essa correção, ambos ALL GREEN.
- Os roteiros usam o remote real `Interact`, verificam pagamento de Fichas/XP, repetição de pedido,
  resgate, desconexão/reentrada e extração. Na primeira etapa um cliente é removido deliberadamente;
  o substituto aguarda a etapa seguinte, portanto o sobrevivente usa o fallback solo de relé.
- Play local final e sessões de teste encerrados. Studio de QA deixado em Edit. Nenhum erro ou
  warning do código do projeto observado; houve ruído UIBlox/FoundationProvider do Roblox.

## Arquivos

- `standard-2.log` / `story-2.log`: linhas do log nativo do servidor, filtradas por escopo do projeto.
  Elas preservam cada verificação individual. `RESULT` longo é truncado pelo log nativo.
- `studio-suite.log`: boot e resultado final do runner, obtidos via MCP/LogService.
- `studio-release.log`: regressão direcionada após a correção final.
- `repair-ready.jpg` / `repair-progress.jpg`: captura do engine, estação em 0/3 e 2/3, próxima ação
  e recompensa visíveis. Fixture e câmera temporárias existiram somente durante Play.
- `source-audit.json`: comparação do Source no XML da build com o disco, normalizando CRLF.
  **12/13 idênticos**: todos os módulos/testes de tarefas, StoreController e PlayerGuide idênticos.
  O CampaignController recebeu depois ajustes paralelos de tamanho do texto e de sobreposição
  de avisos do HUD; o delta está registrado. As três mensagens específicas das tarefas permanecem.
- `release-source-audit.json`: **13/13 Sources idênticos** ao disco na última build, incluindo
  a correção dos relés e os ajustes paralelos do CampaignController.
- `hud-integration.patch`: somente os ajustes de textos/instrução desta frente sobre o HUD novo.
  Já estão aplicados na pasta compartilhada; o patch permite preservá-los em futuras integrações.

SHA-256 da build integrada testada:
`71E344D9105F879E0626B45883B7CB899190629654D09AC90B595DE2FAC7BCAF`.

SHA-256 da build final, depois da correção dos relés:
`1747928D7FC88AB3DC7AC5F740A50F0426C02FCCE6E84337C546FA18611A67EE`.

## Limites e isolamento

O StudioTestService desta instalação retornou `nil` ao editor e registrou timeout ao encaminhar
o resultado final. Por isso, a conclusão foi verificada nos logs individuais do servidor, nas
asserções finais de extração e no estado replicado, além do observador compacto da História.
O retorno `ok=true` do editor, sozinho, não foi usado como aprovação.

A build integrada inclui as frentes de mapa/HUD presentes no disco na hora do build. O commit
`codex/task-activities` guarda somente tarefas/recompensas e adapta as mensagens do HUD anterior;
não contém o layout do HUD novo nem alterações de trailer. No runtime, a publicação preexistente
de `relayUntil` continua pertencendo à frente de HUD. Os arquivos compartilhados foram preservados.

Foram usados perfis mock em cópia local, não o servidor publicado. As duas raízes do Studio
principal consultado estavam `NotSynced`; esta entrega não afirma validar Script Sync nessa place.
Não houve push, publicação, alteração de acesso, Creator Hub ou compra. O equilíbrio econômico,
a dificuldade com o Vigia ativo e a diversão humana continuam dependendo de uma partida real.
