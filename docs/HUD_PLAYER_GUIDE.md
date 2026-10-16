# HUD e orientação do jogador — 16/10/2026

Abra a build local **C:\Users\xpg\Documents\roblox-teste\build\HudGuide_ENTREGA.rbxlx**.
O arquivo não foi publicado e não muda uma sessão que já esteja aberta.

## O que mudou

- Ordem de serviço compacta com objetivo, setor, progresso e instrução de interação.
- Marcador do próximo setor com distância. História mantém ordem obrigatória; Padrão indica uma sugestão e permite ordem livre.
- Reparos explicam os acionamentos de E; sequências direcionam à placa física, sem revelar sua solução; relés explicam confirmação por duas pessoas e mostram a janela restante.
- Dicas por etapa, lembretes de sobrevivência e prioridade para resgate de colegas caídos.
- H abre o guia com missão, tarefas, papel, equipe, sobrevivência e controles. TAB mostra enquanto pressionado. O painel rola com mouse e tem botão para fechar; interações com o mundo ficam suspensas enquanto ele está aberto.
- Espera protegida após pular cinematográfica, resgate, entrada tardia, transição e evacuação recebem instruções específicas.
- Lanterna, fôlego e postura no rodapé. A porcentagem de fôlego considera a melhoria equipada.
- Objetivo narrativo deixou de ocupar um painel separado. Gravações e cinematográficas continuam no StoryController.
- Prompts e legendas ganharam tipografia e contraste coerentes. Menu e abertura preservados.

## Validação

- Check isolado: ALL GREEN, 240 testes puros aprovados, zero falhas; quatro specs exclusivos do Studio pulados no Lune.
- Runner na build anterior ao ajuste final de sobreposição de avisos: 263 aprovados, zero falhas, zero specs pulados.
- História com dois clientes reais do engine: três capítulos, resgate, desconexão/reentrada, tarefas pelos remotes e evacuação aprovados (57 verificações). Essa execução foi anterior aos ajustes finais de rolagem/espera/estado do HUD; o servidor de atividades é o mesmo.
- Capturas visuais em viewports 1116×645 e aproximadamente 812×600. Na menor, todos os textos principais tiveram TextFits=true; o guia teve canvas de 741 px para área de 393 px. Rodar o mouse moveu CanvasPosition a 170 px; clique real fechou o guia.
- Padrão com dois clientes do engine: três etapas, mapas variados, resgate, tarefas e evacuação aprovados (62 verificações). Após essa execução, apenas a visibilidade do aviso sobre gravações foi ajustada e conferida em Play.
- Auditoria final: 171/171 Sources idênticos à cópia isolada, sem scripts extras ou ausentes; preset de iluminação válido.
- Console: boot aprovado, nenhum erro do código do projeto observado. Houve avisos FoundationProvider/UIBlox dos CoreScripts do Studio.
- Fixtures de apresentação alteraram apenas atributos temporários durante Play. Simulador devolvido à viewport padrão; Play local encerrado.

## Isolamento e integração

A pasta compartilhada recebeu alterações concorrentes de mapa e recompensas durante esta tarefa. Uma execução do check nessa pasta falhou em ProceduralLayout enquanto esse trabalho estava em andamento. Esses arquivos foram preservados.

A build acima vem do worktree **C:\Users\xpg\.codex\worktrees\hud-player-guide\roblox-teste**, base 88aae72, com as melhorias do HUD. Ela conserva o Source local do TrailerController capturado na primeira build desta tarefa. As alterações concorrentes de mapa/recompensas não foram incluídas na build isolada.

As melhorias do HUD também estão nos arquivos correspondentes da pasta compartilhada; no CampaignRuntime a mudança desta tarefa é somente publicar relayUntil. Integrar as mudanças concorrentes exige novo check e nova build. Não sobrescrever o runtime completo com esta cópia isolada.

Não houve push, publicação, mudança de acesso ou Creator Hub. A compreensão e o equilíbrio com jogadores humanos precisam ser conferidos no próximo teste.
