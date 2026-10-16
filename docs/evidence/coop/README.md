# Evidências da campanha coop

Data: 15/10/2026. Código final em `ca66ead`; procedimento e limites em [COOP_QA.md](../../COOP_QA.md).
`final-source-manifest.json` identifica os hashes do código atual e as bases dos recibos.

| Arquivos | Interpretação |
| --- | --- |
| `check-global.txt`, `studio-tests.txt` | Validação final: 136 testes puros e 144 no Studio. |
| `integrated-three-clients-result.json`, `integrated-eight-clients-result.json` | Resultados finais integrados, com clientes do engine e remotes reais. Vigia congelado e teleporte de setup: não são playtest humano de equilíbrio. |
| `eight-clients-result.json`, `check-isolated.txt` | Validação anterior isolada, base mapa `b95ea08`; não representa todo o polish integrado. |
| `check-foundation.txt` | Check dos seis arquivos da base pura sobre Claude `c6b247a`. |
| `core-integration.patch`, `snapshot-manifest.json` | Snapshot histórico do QA isolado com flag desativada fora do teste. Não aplicar sobre o código final. |
| `eight-clients-*-failure.json`, `eight-clients-spawn-diagnostic.json` | Tentativas falhas e diagnóstico preservados; sobreposição de spawn corrigida antes do resultado final. |
| `three-clients.png`, `eight-clients.png` | Capturas multiplayer anteriores ao último ajuste de ordem do HUD. |
| `final-hud.png` | HUD final, Play local no lobby; não é captura de oito clientes. |
| `audio-preload.json` | Descartado: auditoria inicial com strings, metodologia inadequada. Não usar como resultado vigente. |
| `audio-instance-preload.json` | Auditoria válida: 54 entradas/49 IDs únicos, Sounds carregados. |
| `audio-lifetime.json` | Seis ciclos de limpeza do método real de áudio posicional; sem resíduos/erros. |

Não há medição de FPS/latência sustentada nem sessão com 3–8 pessoas nestes arquivos.
Os resultados JSON não comprovam ausência de erro em cada console cliente individual durante toda a sessão.
