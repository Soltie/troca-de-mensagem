# Evidências da remasterização

Build final: `Casa_VISUAL_REMASTER_FINAL.rbxlx`, SHA-256
`7824AA430DE79B8CE486DF2DCC7B6E9FA23D28B4B7FDBDCDFEA8AB9374A96E33`.

- `baseline-check.txt` / `baseline-audit-summary.json`: base ce42900, 216 fontes,
  mesma build original de SHA 8BFA4E4A…; o checkout principal não é a origem das fontes.
- `final-check.txt`: 279 testes puros, seis specs do engine puladas, ALL GREEN.
- `studio-runner-final.json`: 290 testes sobre os bytes finais, zero falhas/puladas.
- `build-audit.json`: 219 fontes e classes comparadas ao disco, hashes e preset efetivo.
- `reproducibility.json`: segundo build independente com SHA idêntico.
- `profile-cycle.json`: quatro escolhas aceitas pelo servidor; amostras durante a adaptação
  de bloom. A amostra OFF aguarda quatro segundos. Não é benchmark de GPU.
- `device-layout.json` e capturas: geometria verificada e emulação, não celular físico.
- `cleanup-fixture.json`: três ciclos de builders 6→7→8 e retorno dos caches ao baseline.
- `save-confirmation.json`: autosave mock reconhecido explicitamente na mensagem do cliente.
- `challenge-client-*.json`: sondas nas VMs reais de dois clientes da build final;
  preferências diferentes, energia ligada no capítulo 4, logs gráficos sem erro nessa coleta.
- `challenge-duo-final.json`: 156 verificações aprovadas, incluindo vitória e nova partida.
- `story-duo-final.json`: 154 verificações aprovadas na mesma build final, com vitória e nova partida.
- `story-forest-off-final.json` / `story-after-lobby-*.json`: preferências nas VMs reais durante
  a floresta e depois da vitória/retorno/nova votação. Sombras opcionais zeradas em OFF.
- `story-client-*.json`: sondas da História. Um cliente registra também falhas de CreatorType
  em CoreGui/TopBar/StarterScript do engine; esses registros não são apagados nem confundidos
  com um erro de SettingsController. As asserções gráficas dessas sondas passaram.

## Capturas

Antes/depois: câmera fixa, energia desligada, FOV 65, desktop 1116×605.
Corredor `(0,6,8) → (0,6,-35)`; fachada `(0,12,115) → (0,18,20)`;
floresta `(0,8,620) → (0,7,720)`, capítulo 6, seed 42.
Espera de adaptação antes das novas capturas: quatro segundos. HUD escondido pela sonda do
Studio. Floresta de comparação é fixture do builder, com referências de features de teste;
não representa uma partida humana. A captura da vitrine também prepara a rolagem do menu.

`before-*` foi recapturado da build original auditada. `after-*` e telas de dispositivos usam
`Casa_VISUAL_REMASTER_QA.rbxlx`; a apresentação é igual à final. A diferença posterior limita-se
à espera de inicialização/convergência no mecanismo Studio-only de QA, sem mudar renderização.

## Histórico, não aprovação final

`preliminary-story.json`: 150 verificações de uma build intermediária, anterior ao perfil
funcional da floresta e correções posteriores. Não aprova a build final.

`story-startup-failure.json`: o cliente podia receber o atributo de QA antes de registrar seu
listener. Corrigido lendo também o pedido inicial. `story-v2-result.json` concluiu 154 checks
servidores, mas sua primeira asserção gráfica cliente era antecipada e falhou; não é aprovação
do console cliente final. A v3 espera convergência com deadline, mantendo as asserções.

Execuções concorrentes do StudioTestService retornaram `nil`, sem resultado de campanha.
Não contam como aprovação. As regressões finais são executadas em sequência.

`story-v2-*` são diagnósticos intermediários; `iteration-check.txt` e
`settings-desktop-initial.jpg` também são históricos. As capturas de apresentação permanecem
válidas somente nos limites descritos acima.

## Criatura / PBR

`asset-fetch-probe.json` preserva a falha da consulta isolada às quatro URIs de imagem.
`model-instance-preload.json` confirma o sucesso da malha quando a instância real é usada;
`creature-showcase.jpg` mostra o aspecto de madeira renderizado. A consulta por URI não
determina a causa e não prova que a SurfaceAppearance está quebrada. Sem alteração no modelo,
UV, PBR, esqueleto, animações geradas, uploads ou IDs. Canais normal/roughness/metalness não
foram certificados individualmente pelo teste visual.

## Limites

Fixtures, teleporte e IA congelada preparam cenários do roteiro cooperativo. Seleção e
interação continuam passando pela mira e remotes normais. Os testes não medem diversão,
balanceamento, susto subjetivo, FPS ou comportamento em hardware móvel físico.
Avisos UIBlox/FoundationProvider são classificados como mensagens do engine, não do projeto.
Os Studios originais de outras frentes foram preservados.
