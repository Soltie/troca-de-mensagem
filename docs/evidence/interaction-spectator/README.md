# Recibos de QA — 15–16/10/2026

- `probes.json`: retornos reais do Studio preservados como texto JSON. Não são inferências do código.
- `return-probe.json`: novo playtest após os ajustes finais; fixture Waiting, restart/respawn,
  CameraSubject local restaurado e runner completo com 156 aprovados.
- `client-probe.luau` / `solo-server-probe.luau`: fontes usadas na VM normal. Scripts temporários,
  criados somente durante Play via MCP; nenhum arquivo sincronizado foi editado dentro do Studio.

No solo, Config.Campaign.Enabled foi false temporariamente **no disco**, com Play parado. A volta
a true foi confirmada no Source antes do QA coop. Os scripts e fixtures desaparecem ao encerrar Play.
O check final passou com a campanha ativada: format, lint, sourcemap, tipos strict e 148 testes puros.
`lune run scripts/build` também passou e gerou a cópia descartável `build/Test.rbxlx`, ignorada pelo Git.

Oito clientes: `eight-clients-campaign.json`, `success=true`, estágio 3, Won, seed 1792143369,
125 verificações aprovadas pelo harness `CampaignHarness`. Código final em `a09113a`.
Mesmo com clientes do engine, o roteiro congela a IA e usa teleporte de setup. Não mede diversão,
balanceamento nem FPS/latência sustentados. Slots restantes de QA humano estão em NEXT_STEPS.

Limites: captura visual do armário escura; raios com a porta lógica transparente excluída passaram
na fresta central e bateram nas faixas superior/inferior. Não declarar arte/iluminação do armário pronta.
O ensaio inicial de puzzle após screen_capture usava câmera Scriptable deixada pelo plugin; foi
descartado e repetido com Custom. O registro final `soloSolvedFinal` mostra a resposta de acerto,
mas amostrou PowerOn antes da animação atrasada do servidor, portanto não é prova do instante da energia.
No primeiro ensaio de retorno o probe temporário foi apagado junto com o respawn; ele foi recolocado
num ScreenGui ResetOnSpawn=false e a verificação foi repetida com sucesso.
