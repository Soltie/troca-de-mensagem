# Continuidade — pacote de tensão, medo e captura

Responsável: Codex. Iniciado em 15/10/2026, base `0984aef`, branch `claude/polish-terror`.
Pedido humano: finalizar o pacote combinado e documentar tudo para continuação se acabar a quota.

## Escopo e estado

**PACOTE IMPLEMENTADO E COMMITADO; RESULTADO FINAL DE QA ABAIXO.** Diretor cliente de tensão, efeitos de medo e feedback individual de
perseguição/captura. Não inclui novos mapas/rigs, arte, haptics ou toda a lista de polish do Claude.
Referência: seções B/C/F de `CLAUDE_POLISH_HANDOFF.md`; `NEXT_STEPS.md` preserva o restante.

Decisão multiplayer: o modo global Chase/Capture do Vigia não deve capturar visualmente todos.
O servidor publica o alvo da ameaça; cada cliente filtra sua participação e o próprio status.
Derrubados/evacuados/aguardando não recebem sustos de jogo ativo. Resgate e transição restauram câmera.
Eventos atrasados usam geração/cancelamento; clones visuais não alteram colisão, portas ou puzzles reais.

## Arquivos entregues

- `Shared/Game/ThreatPresentation.luau` e spec puro: regras pessoais e intensidade de efeitos.
- `Client/Controllers/TensionController.luau`: executar diretor/eventos, música e log.
- `Client/Controllers/ScreenFxController.luau`: UI/blur/fog e impacto respeitando conforto.
- `Client/Controllers/ThreatFeedbackController.luau`: perseguição/captura e restauração.
- Integração pequena em `Main.client`, `FearController`, `CreatureService`, `RetroFxController` e `HudController`.

Commits locais: `ca18f17` (alvo e regras/testes puros), `fab121c` (controllers e integração).
Também foram ajustados Audio/Flashlight/WorldFx/Settings. Sem push, publicação ou troca de branch.

## Comportamento entregue

- Diretor executa Anticipation/Tension/Chase/Recovery, música correspondente, cooldowns, silêncio
  antes dos eventos e log limitado. Progresso coop usa estágio/atividades concluídas.
- Dez handlers: flicker, distant_steps, radio_static, vibrate, whisper, false_alarm, silhouette,
  door_twitch, object_shift e eyes. Visuais exigem posição/prop elegível e linha de visão.
  Contador `events` indica despacho, não garantia de uma aparição visível.
- Partes locais sem colisão/query/touch, clones de props, máscara restaurada e cancelamento por
  geração. Props/portas reais não mudam de posição. `object_shift` dura 1,2 s e retorna;
  um prop por evento limita custo e simplifica restauração.
- LED do rádio pisca no evento; aviso de luzes usa raio 18. Chiado automático por proximidade
  ao rádio ainda é refinamento pendente. Passos falsos exigem obstáculo antes do ponto sonoro.
- Vinheta/granulação pelo medo, blur acima de 0,8, faixas de glitch/chroma aproximadas, VHS e
  névoa local limitada. Não há shader de pixelização/aberração real nem dessaturação de ferimento.
- Impacto de captura respeita flashes; tremor/FOV respeitam conforto. Captura pessoal dura
  aproximadamente 1,1 s e restaura câmera; resgate/troca de estágio também liberam a câmera.
- Menu O com sete opções executáveis (1–7), atalhos V/B preservados. Haptics permanece sem
  executor e não é exposto como funcional. F3 mostra medo, estado e últimas cinco linhas do diretor.

## Verificado e limites

142 testes puros: ALL GREEN. Runner no Studio: 150 aprovados. Sync das duas raízes confirmado;
três novos controllers presentes e boot com 17 controllers, sem erro do projeto no smoke test.
Três clientes reais confirmaram ameaça/captura individuais e resgate real. IA congelada e posições
controladas: não é teste humano nem valida balanceamento. O probe anterior despachou os dez handlers
sem erro; não comprovou visualmente todas as combinações de props/ângulos. Rever aparições em playtest.
Snapshots dos oito clientes preservam falhas ChatScript/CoreGuiChatConnections do Roblox e o kick
intencional do harness, separados dos controllers do projeto.

## Checklist para retomar

1. Conferir status/diff e este arquivo; não resetar, limpar ou trocar branch.
2. Escolher uma pendência abaixo e rodar `lune run scripts/check` após editar; não reimplementar o pacote entregue.
3. Confirmar Script Sync no Dev via MCP, playtest e runner completo; testar conforto,
   alvo pessoal, captura/resgate e cancelamento dos eventos. Parar Play ao terminar.
4. Guardar evidências em `docs/evidence/terror-polish/`; atualizar feito/verificado/pendente.
5. Commits locais pequenos, sem push/publicação. Atualizar `LEIA_CLAUDE.md` e `NEXT_STEPS.md`.

Studio principal: Dev.rbxlx `cac08fd1-61f0-4a24-bb55-0018c2449664`, encontrado em Edit.
Checkpoint: 142 testes Lune e 150 no Studio passaram na primeira integração. Probe na VM normal
confirmou música calma/tensão/perseguição, alvo pessoal, captura única, restauração após 1,1 s,
efeitos desligados (blur/glitch/fog/vinheta/VHS) e despacho dos dez handlers sem erro do projeto.
Um aviso do plugin Assistant ao consultar a câmera Scriptable via MCP foi identificado como artefato
do teste, não erro do jogo. Ajustes finais de progresso/LED/raio entraram no código da regressão de oito clientes.
Check final: ALL GREEN, 142 testes. Nova simulação com três clientes confirmou alvo -1 exclusivo,
captura pela API real do runtime, impacto e câmera Scriptable apenas na vítima por ~1,1 s,
retorno a Custom e resgate por `Interact("rescue_-1")` de outro cliente. Os três consoles sem
erros do projeto. Evidência: `evidence/terror-polish/three-clients-presentation.json`.
O teste mede apresentação e integração, com Vigia congelado e teleporte de setup; não balanceamento.
O comando de teclado O do MCP retornou sucesso, mas não abriu o menu nesta sessão. A interface
e a API de opções existem; o atalho físico ainda precisa de confirmação humana.
Regressão final com oito clientes: **APROVADA, estágio 3, fase Won**, incluindo resgate, substituição
de cliente, pathfinding e atividades por remotes. Resultado em `evidence/terror-polish/eight-clients-campaign.json`.
Studio principal devolvido em Edit; clientes de teste encerrados. Código commitado, sem push/publicação.

## Próximo agente: pendências reais

**Continuação posterior:** interações, armário solo, espectador coop e correção de O estão em
[INTERACTION_SPECTATOR_PROGRESS.md](INTERACTION_SPECTATOR_PROGRESS.md). Consultar esse documento
antes dos itens históricos abaixo; o pacote de tensão desta página foi preservado.

1. Confirmar O/1–7 com teclado físico e inspecionar o menu em diferentes tamanhos de viewport.
   Se o atalho não funcionar fora do MCP, investigar `InputBegan`/`processed`; não marcar como testado por inferência.
2. Testar visualmente cada aparição/clone em salas elegíveis e o cancelamento durante o próprio
   evento (captura, resgate, Intro, respawn). O contador de despacho não substitui esse QA.
3. Medir e equilibrar numa partida humana com 3–8; nossos roteiros usam IA/posições controladas.
4. Continuar `NEXT_STEPS.md`: interações/puzzles, armário, duto, arte, haptics e menus restantes.

Para retomar: ler este arquivo, `NEXT_STEPS.md` e o handoff Claude; conferir Git e a evidência final.
Não há reserva de arquivos ou Studio pendente. Não usar Script Sync para sobrescrever alterações alheias.
