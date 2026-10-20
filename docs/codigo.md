# Código (agente CODE) — cap. 1

Estado: feito no **repo**; **NÃO aplicado ao place** (Studio estava aberto sem place: "Place is not open").

## Presença do Tung (cap. 1)
Três momentos novos (`Shared/Game/ChapterMoments`, visual em `MomentController`, disparo em `ChapterMomentService`):
- `knocks`: 5 pancadas na parede (som `DoorBang` grave, tremor leve), de um lado do jogador ou de `at`.
- `silhouette`: silhueta com bastão a ~20 studs à frente do jogador, cruza 7 studs de lado em 1,1 s e some (sem piscar).
- `nearmiss`: pancada forte colada nas costas, poeira, tremor 0,75, luz pisca.

Gatilhos padrão (só modo História, cap. 1): 1ª chave = `knocks`; 2ª chave = `silhouette`; 4ª tarefa = `nearmiss`.

**API para o level design**
- Servidor: `ChapterMomentService.presence("knocks" | "silhouette" | "nearmiss", at: Vector3?)`.
- Sem código: peça no mapa com a tag `TungPresenceZone` e atributo `Presence` (texto). Dispara quando um jogador entra no volume da peça
  (uma vez por capítulo; atributo `Once = false` repete a cada 30 s). A peça deve ficar invisível, sem colisão. O `at` das
  batidas é a posição da peça.

## Bugs
- "Isso não dá para fazer agora." na porta trocada: `door_swapped` agora é ignorado em `CampaignController` (e `""` em `Text.Messages`).
- `moveChair` só move a cadeira da Dona Cida (`CidaChair`, marcada em `HouseProps`); fallback por região da sala de estar.
- Fita da TV: conta a posição do corpo (≤ 20 studs na horizontal, ±8 em Y) e só 4 s depois do spawn; não dispara com a câmera de carregamento.
- Banquinhos: marcados/pilha pronta travam o `[E] LEVAR O BANQUINHO...` (via `target.locked`); se o banquinho fugir, tudo destrava.
- Olhos no Veio: agora na parede mais próxima (raycast 4 direções), neon maior com luz, fade-in e piscada; fallback no ar.
- Cutscene de abertura do cap. 1: já existe no repo (`StoryCatalog` cena 1, 8 s, `StoryController`); depende do código do place estar atualizado — verificar ao aplicar.

## Pendente (precisa do Studio com o place aberto)
Luz v4, dedos da lanterna, tranco de porta (`WorldService.animateDoor`), `FurnitureMotionController`, correções de menu/UI do cap. 1;
lâmpada fraca no corredor e na cozinha (precisa das posições no mapa).

## Como testar
`lune run scripts/check` (ALL GREEN). No Studio: iniciar História cap. 1; pegar 1ª e 2ª chave; criar peça com tag `TungPresenceZone` e `Presence`.

## Aplicado ao place (20/10, 2ª passada)
Backups em `ServerStorage.Backup_Code_Cap1` e `Backup_Code_Cap1_b`.
- Luz v4: `LightingController` + `LightingProfile` (tetos 50%), lanterna mais quente e dedos da mão (`FlashlightController`).
- Tranco de porta: trecho de `animateDoor` em `WorldService` aplicado por cima do código do place (PvP/Mansão intactos).
- `FurnitureMotionController` criado e registrado em `Client/Main`; `GameUiController` com o aviso acima da legenda.
- Lampiões fracos (`HouseLights.dimLamps`): hall/corredor (7, 5.6, -20) e cozinha (26, 5.6, -19), luz 0,45, alcance 15.
- Não aplicado: `MainMenuController` (menu; place tem o código do PvP, mesclar à parte). Play ok, 62 controllers, testes 439/439.

## Rodada 3 (crítico v3 = 6,0) — aplicada ao place
Backup: `ServerStorage.Backup_Code_Cap1_c`. Play ok, testes 439/439, `moment knocks` publica em CampaignState.
- C1 caixinha no sofá: `FurnitureColliders` entram no sorteio como obstáculo (HouseActivities) e `hasSight`/`visible` atravessam `FurnitureCollider` e `Sheet*` (CampaignRuntime, InteractionController).
- Porta que Troca: ao chegar a 7 st da porta armada ela bate de novo (serragem, 3 s trancada) e os 20 s recomeçam; sem ninguém perto, só desfaz após 120 s.
- Tung: além das batidas (1ª chave) e vulto (2ª), a cada 35–60 s do cap. 1 (depois da 1ª chave) repete batidas/vulto (`ChapterMomentService`).
- "Está escuro demais": com lanterna na mão manda ligar (F); a de "procurar vela" só sem lanterna.
- Prompt vs legenda: prompt sobe acima da caixa inteira da legenda (`GameUiController`).
- Legenda da chave da cozinha atualizada (`HouseCatalog`).
- Luz: 4 lampiões (hall, cozinha, jantar, biblioteca; luz 0,7 alcance 20); lanterna menos azul já no place (filtro incandescente).

## Rodada 4 (cap. 1 → nota 9)
No repo (aplicar ao place; `Backup_Code_Cap1_*` guarda as versões anteriores):
- Vulto: `clearDirection` acha o caminho livre; corpo mais claro + luz fria atrás (era invisível no escuro); some quando a lanterna o ilumina (<14°, <26 st). Segundo aparecimento: ao chegar a 10–18 st da porta do jantar após a 2ª chave (`ChapterMomentService`). **Encaixe da Arte:** modelo `ReplicatedStorage.Assets.TungSilhouette` (pivô nos pés, frente +Z) substitui o vulto improvisado.
- Porta que Troca: câmera (cinema 3 s) olha a cadeira da Cida na chegada (`DoorSwapController`).
- Dica "Está escuro demais / Ligue a lanterna" suprimida durante a tarefa `cida_talk` (`SanityController`; `Tasks` agora leva `event`).
- Prompt `[E]` fica ≥ 44 px acima da legenda (`GameUiController`).
- **Visita do Tung** (ameaça jogável): `Shared/Game/TungVisit` (regras puras + spec), `TungVisitService` (servidor), `TungVisitController` (cliente), `CreatureService.visitShow/visitMove/visitHide/forceCapture`.
  - Aviso 20 s (10 s com `early`): pancadas e rangidos da escada, luz pisca, legendas da Cida. Depois ele aparece em (8,0,20), passa pelo hall, entra no cômodo com mais jogadores (Sala/Cozinha/Jantar), pausa 3 s no meio, 2 s diante do armário e volta.
  - Visto = capturado (mesmo caminho do golpe: cai/rasteja ou derrota no solo): fora do armário a ≤10 st; com lanterna ≤34 st; correndo ≤22 st; escondido só é visto com lanterna acesa a ≤7 st dele parado no armário. 1,5 s de graça ao aparecer.
  - Gatilho padrão: 25 s após a 2ª chave. **API do Level:** `TungVisitService.start({ early = true?, room = "Living"|"Kitchen"|"Dining"? })` (Melodia errada → `early = true`). Estado em `CampaignState.VisitPhase/VisitEndsAt/VisitRoom/VisitSerial`. Uma vez por capítulo; zera ao reiniciar.
  - Rotas e armários: ver docs/level.md. O corpo é o real (`Assets.TungTung` desenhado pelo `CreatureVisualController`), cérebro desligado.
