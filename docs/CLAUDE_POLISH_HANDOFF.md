# CLAUDE → CODEX: handoff do polish de terror

> **Recebido e integrado parcialmente pelo Codex (15/10/2026).** Este documento preserva a
> entrega original do Claude, finalizada em `c6b247a`. BodyAudio/Fear, Audio/Flashlight e
> adaptador de estado corporal foram integrados à campanha. Estado e correções efetivamente
> concluídos: [COOP_CAMPAIGN.md](COOP_CAMPAIGN.md). As demais pendências de polish e conteúdo
> continuam discriminadas em [NEXT_STEPS.md](NEXT_STEPS.md); não foram marcadas como concluídas
> por constarem de uma proposta. A frase original abaixo sobre finalizar tudo não é evidência de QA.

> **Segunda entrega Codex:** diretor de tensão, ScreenFx, captura pessoal e opções de conforto
> implementados em `ca18f17`/`fab121c`. Evidências, limites e pendências restantes em
> [TERROR_POLISH_PROGRESS.md](TERROR_POLISH_PROGRESS.md). O texto original abaixo é histórico.

Atualizado em 15/10/2026. O Claude parou aqui porque o limite de uso dele está acabando. O humano pediu que o **Codex finalize tudo**: nada pode ficar pendente.

- Branch: `claude/polish-terror`, no mesmo diretório. Sem push.
- Último commit do Claude: **`e4dc5cc`**.
- O Claude **não está usando o Studio**.

Leia na ordem:

1. "Estado exato";
2. "O que falta";
3. "Critérios de pronto".

O pedido original completo está na seção 7.

---

## 1. Estado exato

### 1.1 Commitado em `e4dc5cc`

Snapshot validado isolado: ALL GREEN, 115 testes puros.

**Módulos puros**, todos com spec em `Tests/Specs` e testados:

| Módulo | O que faz |
| --- | --- |
| `Shared/Game/FearModel.luau` | Medo 0..1: alvo por situação, sobe rápido e desce devagar, picos, 4 níveis com histerese |
| `Shared/Game/TensionDirector.luau` | Estados Anticipation / Tension / Chase / Recovery; 10 eventos com recarga, filtros por sala, medo e progresso; log limitado a 40 linhas |
| `Shared/Game/BatteryModel.luau` | Consumo, recarga em repouso até 35% (a missão nunca trava), pilhas, LEDs e brilho |
| `Server/Game/PlayerRules.luau` | Velocidade por postura e checagem com carência; prender a respiração (máx. 6 s, arquejo e recarga) |
| `Server/Game/HideRules.luau` | Entrar no armário; "viu entrar"; exposição; achado |
| `Server/Game/BreakerPuzzle.luau` | Ordem sorteada; erro derruba todos |
| `Server/Game/Checkpoint.luau` | `capture` / `restore` com cópia profunda; `isUsable` |

`Server/Game/Objectives.luau` também mudou (é intencional, e o spec foi atualizado):

- novos campos: `hasKey`, `keyTaken`, `unlocked`, `breakersOn`;
- nova etapa "breakers": `powerOn` exige os disjuntores.

**Config**, seções novas:

- `Player`: crouch, aceleração, exaustão, validação de velocidade e respiração;
- `Battery`, `Fear`, `Tension`, `Camera`, `Hide`, `Puzzle`, `Doors`, `Fallables`, `Checkpoint` (`GraceTime`, `IntroDuration`);
- `Effects`: `PanicBlur`, `DangerFogEnd`;
- `Comfort`: valores iniciais das 8 opções.
- `Effects.RetroOverlayDefault`, `Effects.CameraMotionDefault` e `Effects.HeadBobAmount` foram **removidos**.

**Shared:**

- `Text`: prompts, mensagens, `Hints`, `Options`, `Inventory`, `note_breakers`, Continue/RestartAll.
- `Audio`: ~40 clipes; o campo `region` vira `PlaybackRegion`. **Os IDs novos ainda não foram verificados.**
- `Remotes`, `Types` (`InteractResponse.kind`).
- `GameState`: `HasKey`, `BreakersOn`, `BreakerOrder`, `CheckpointReady`, `FromCheckpoint` e o objetivo "breakers".

**Servidor:**

- `Services/PlayerStateService.luau` (novo):
  - postura: o remote `SetStance` muda `HipHeight`, `WalkSpeed` e `JumpHeight`, e checa o teto antes de levantar;
  - bateria: `SetFlashlight` passou para cá e publica os atributos `Battery` e `Flashlight`;
  - esconderijo: `enterHide` / `exitHide`;
  - respiração: `SetHoldBreath`, com arquejo por barulho;
  - validação de velocidade (corrige a posição) e `markTeleported`.
- `Services/PropService.luau` (novo): objetos que caem.
  - Disparo: passar a até 2.8 studs com velocidade ≥ 8. Agachado não dispara.
  - Faz barulho para o Vigia, com recarga global.
  - Volta tudo ao lugar a cada Intro.
- `World/Features.luau` e `World/FeatureBuilder.luau` (novos, montados pelo `WorldService` depois do `MapBuilder`):
  - 3 armários ocos com frestas;
  - 2 posições de chave e 5 de pilhas;
  - caixa de disjuntores A/B/C e prancheta do procedimento (`note_breakers`);
  - rádio, 6 objetos que caem, poças, goteiras, assoalho de madeira no escritório;
  - moldura do duto;
  - indicadores (ponteiros e LEDs com tag `Indicator`);
  - zonas por sala (`Features/Zones`, atributos `Room` e `Reverb`).
- `Services/WorldService.luau` reescrito:
  - portas aberta / fresta / fechada / trancada, com animação com peso;
  - `PathfindingModifier.PassThrough` falso quando trancada;
  - chacoalhar, destrancar e pancada do Vigia;
  - chave e pilhas sorteadas por rodada;
  - disjuntores (`setBreakers`, `setProcedure`, `breakerFeedback`);
  - armários (`swingLocker`);
  - snapshots de portas e itens para o checkpoint;
  - atributo `Lighting.BaseFogEnd`.
- `Services/RoundService.luau` reescrito:
  - `Interact(id, action?)`;
  - tipos: Fuse, Panel, Breaker, Door (com chave), Gate, Note, Key, Battery, Hide;
  - checkpoint gravado ao voltar a energia;
  - `RequestRestart("full"|"checkpoint")`, onde `continueFromCheckpoint` usa a mesma semente da rodada;
  - `debugGrant`.
- `Services/CreatureService.luau`:
  - percepção do escondido (viu entrar → captura no armário; perto + respirando por 2.6 s → atributo `Alert` e te acha; lanterna acesa no armário conta como respirar);
  - agachado reduz a visão para 0,7×;
  - porta trancada: ele bate e desiste;
  - `holdOff` (trégua), `secondsSinceSeen`, `isChasing`.
- `Services/DebugService.luau`: comandos `checkpoint`, `grant("fuses"|"insert"|"breakers"|"key")`, `setBattery(v)`, `fall(id)` e `holdOff(s)`. O `state` agora inclui os jogadores.
- `Main.server`: ordem PlayerData, World, PlayerState, Creature, Prop, Round, Debug.

**Cliente:**

- `CameraController` (novo): compositor único.
  - Desfaz a rotação extra antes do módulo de câmera do Roblox e reaplica depois dele (`BindToRenderStep`).
  - Balanço, respiração parada, inclinação lateral, balanço de exaustão.
  - Tremor por trauma, pouso, altura agachado que compensa o `HipHeight`.
  - FOV: corrida, medo, pancada e zoom.
  - Modos `setHidden(eye)` e `capture(targetFn)` com hit-stop de 0,1 s que não bloqueia a thread.
  - `reset()` e `debugState()`.
- `CharacterController` reescrito:
  - corrida com rampa, fôlego e exaustão;
  - C alterna agachar, Ctrl segura; levantar sem teto é bloqueado e avisa via `onStandBlocked`;
  - raycast do chão (`floorMaterial`, `floorPart`), `onLanded`, `getMotion()`.
- `SettingsController`: 8 opções (`KEYS`). V = retro; B = `toggleMotion`.
- `CreatureVisualController`: o tremor dos passos usa `CameraController.addTrauma` pela distância.
- `GameUiController`: só os ajustes mínimos de compilação.

### 1.2 NÃO commitado (do Claude, no diretório de trabalho)

Nada disso rodou no Studio.

- `Client/Controllers/AudioController.luau`: **reescrito**.
  - Grupos: Lofi (EQ PS1, EQ de abafamento, compressor) e Ui.
  - Loops: vento, máquinas, música por estado (`setMusicState`), batimento por medo, sussurros.
  - Reverb por zona, `silence(s)`, `muffle(s)`, `playAtPosition`, rangidos aleatórios, `zone()`, `debugState()`.
  - Tipos OK.
- `Client/Controllers/FlashlightController.luau`: **reescrito**.
  - Viewmodel com mão e LEDs da bateria; luz com atraso e balanço; poeira no feixe.
  - Falhas: perto do Vigia, com bateria fraca, e por `flicker(s)`.
  - F pede ao servidor (`SetFlashlight`).
  - Apaga sozinha no armário e volta ao sair.
  - `showPickup(kind, from)`, `playKeyUnlock()`, `onHint(cb)`.
  - Tipos OK.
- `Client/Controllers/BodyAudioController.luau`: **novo, ainda não registrado** no `Main.client`.
  - Passos por material: concreto, madeira, metal, água em poça. Silencia os passos padrão do Roblox.
  - Respiração por exaustão e medo, segurar/soltar, arquejo, pouso.
  - **Tem 2 erros de tipo**, nas linhas 97 e 104:
    - 97: o atributo `Surface` chega como `any`; trocar o `return tagged` por um cast `:: Surface`;
    - 104: `pitch` vira `number | ...`; tipar `local pitch: number`.
- `Client/Controllers/FearController.luau`: **novo, ainda não registrado**.
  - Roda o FearModel a 20 Hz: distância, visão e modo do Vigia, escuridão, esconderijo, lugar seguro.
  - Picos ao ser visto, ao `Alert` e ao despertar.
  - Empurra o valor para Camera, Audio e BodyAudio.
  - Expõe `get`, `level`, `darkness`, `spike` e `onLevelChanged`.

### 1.3 Adições do CODEX no diretório (preservadas e NÃO commitadas pelo Claude)

- `Config.Campaign`;
- seleção de modo no topo do `RoundService`;
- filtro `CampaignStatus` / `CampaignGraceUntil` no `findTarget` do `CreatureService`;
- `ServerNet.isRegistered`;
- `CampaignController` no `Main.client`.

Commitar junto com `Server/Campaign`.

---

## 2. O que falta, em ordem (com o que é esperado)

### A. Fechar a integração do cliente

1. Corrigir os 2 tipos do BodyAudioController (1.2).
2. Criar `TensionController`, `ScreenFxController` (ou estender `RetroFxController`) e `HapticsController` (seções B, C e I).
3. Registrar no `Main.client`, nesta ordem, para evitar ciclos de require:

   Settings, Audio, Character, Camera, BodyAudio, Flashlight, Fear, RetroFx/ScreenFx, WorldFx, Tension, CreatureVisual, GameUi, Interaction, Hud, Haptics, Campaign.

   Regras de dependência:
   - o `FearController` já requer Audio, BodyAudio, Camera e Flashlight;
   - o `TensionController` deve requerer Fear, Audio, WorldFx, Flashlight e Camera, e nunca o contrário.
4. `lune run scripts/check` precisa dar ALL GREEN.

### B. TensionController

Roda `TensionDirector.step` a cada `Config.Tension.TickInterval`.

**Contexto** passado ao diretor:

| Campo | Origem |
| --- | --- |
| `now` | `os.clock()` |
| `playing` | fase = Playing |
| `creatureActive`, `creatureMode`, `creatureDistance` | Root do Vigia |
| `fear` | FearController |
| `darkness` | `FearController.darkness()` |
| `zone` | `AudioController.zone()` |
| `progress` | fusíveis coletados + 1 se `powerOn` |
| `hidden` | atributo `Hidden` |

**Música** pelo estado: Anticipation → `"calm"`, Tension → `"tension"`, Chase → `"chase"`, Recovery → `"relief"`, fora de jogo → `"none"`. Use `AudioController.setMusicState`.

**Eventos.** Quando `decision.silence`, chamar `AudioController.silence(Config.Tension.SilenceBefore)` e executar o evento só depois desse tempo.

| Evento | O que fazer |
| --- | --- |
| `flicker` | `WorldFxController.surge(1.2)` + `FlashlightController.flicker(1)` |
| `distant_steps` | 4–6 `CreatureStep` com `playAtPosition` num ponto a 25–40 studs, atrás de parede, intervalo de 0,5 s |
| `radio_static` | `RadioStatic` no rádio (`Features/GuardRadio/Radio`); o LED do rádio pisca |
| `vibrate` | peças pequenas (< 2 studs) num raio de 14 studs tremem localmente por 1,5 s + `DoorRattle` baixo; restaurar o CFrame |
| `whisper` | `Whisper` 2D baixo |
| `false_alarm` | depois do silêncio: `Snarl` distante + flicker curto, e nada mais |
| `silhouette` | figura escura local (peças pretas, ~7 studs) na visão periférica (35–55° do centro), 16–26 studs, no escuro e com linha de visão. Some em 0,7 s ou quando entra a menos de 15° do centro. `FearController.spike(0.12)` |
| `door_twitch` | porta fechada a até 20 studs: girar a folha 2–3° localmente e voltar (como o `twitch` do WorldService) |
| `object_shift` | prop pequeno fora da tela a até 12 studs: deslocar 0,6 studs e girar 15° localmente. Guardar e restaurar no Intro |
| `eyes` | dois pontos neon a 25–35 studs no escuro, à frente, altura ~6. Somem se a lanterna mirar (< 12°) ou após 2,2 s |

Avisos antes da chegada do Vigia (mesmo fora do diretor):

- luzes num raio de 18 studs da Root piscam em passos (`WorldFxController`);
- chiado do rádio quando ele chega a até 25 studs do rádio;
- os passos dele já tremem a câmera pela distância.

Também:

- Ao `notify` / `reset` (despertar, Intro), chamar `TensionDirector.notify` / `reset`.
- `debugState()` deve devolver estado + `log`.
- O HUD de debug (F3) mostra medo, estado do diretor e as 5 últimas linhas do log.

### C. Efeitos de tela (ScreenFx)

Todos guiados por `FearController.get()` e respeitando o conforto.

- **Vinheta dinâmica:** uma moldura extra que escurece com o medo (não é a vinheta fixa do retro).
- **Granulação:** aumenta com o medo; opção `retro`.
- **BlurEffect:** até `Config.Effects.PanicBlur` acima de 0,8 de medo; opção `flashes`.
- **Glitch** (faixas horizontais deslocadas, em passos de 12 fps) em pânico e no susto; opção `flashes`.
- **VHS** (opção `vhs`):
  - carimbo "▶ PLAY 03:12 15 OUT 1999" com hora avançando desde o início da rodada, passado pelo `PixelText.normalize`;
  - a linha de tracking que já existe;
  - aberração cromática **aproximada**: duas cópias translúcidas vermelho/ciano da moldura de glitch, deslocadas 2–3 px. O Roblox não tem shader de tela; documentar em DECISIONS.
- **Névoa dinâmica (local):** `Lighting.FogEnd` = lerp(`Lighting:GetAttribute("BaseFogEnd")`, `Config.Effects.DangerFogEnd`, medo²).
- **Clarão de impacto na captura** (branco → vermelho, 0,15 s); opção `flashes`.
- Não há dessaturação, porque não existe estado de ferimento. Documentar a decisão.
- Testar com tudo ligado e com tudo desligado: menu O e atalhos V/B.

### D. InteractionController

- **Destaque:** um único `Highlight` no `model` do alvo (ou na `focus`), com `FillTransparency` 1, `OutlineTransparency` 0,55, `DepthMode` Occluded e cor quente discreta.
- **Prompt:** linha principal `[E] <InteractPrompt>`.
  - Se a peça tem `InteractAlt`, mostrar também `[Q] <InteractAlt>`.
  - Porta com atributo `Locked`: "[E] DESTRANCAR" se `GameState.hasKey`, senão "[E] TRANCADA".
- **Q:** `Interact(id, "alt")`, só para portas.
- **Escondido** (atributo `Hidden` ≠ ""):
  - E envia `Interact(hiddenId)` sem precisar mirar;
  - Espaço pressionado → `SetHoldBreath(true)`, soltar → `false`;
  - mostrar `Text.HiddenHint` e, enquanto prende, `Text.HoldingBreath`.
- **Resposta por `kind`:**

  | `kind` | Reação no cliente |
  | --- | --- |
  | Fuse, Key, Battery | `FlashlightController.showPickup(kind, focus.Position)` |
  | Unlock | `FlashlightController.playKeyUnlock()` |
  | Note | som `Paper`; para `note_breakers`, `string.format(Text.Notes.note_breakers, GameState.breakerOrder)` |
  | BreakerWrong | `CameraController.addTrauma(0.5)` + clarão vermelho curto + `FearController.spike(0.15)` |
  | BreakerSolved | pulso de luz verde |
  | DoorLocked | `addTrauma(0.1)` |

- **Avisos:** `CharacterController.onStandBlocked` e `FlashlightController.onHint` → legenda com `Text.Hints[key]`.

### E. Câmera do armário

- Atributo `Hidden` ≠ "" → `CameraController.setHidden(player:GetAttribute("HideEye"))`.
- Atributo vazio → `CameraController.setHidden(nil)`.
- Opcional: transição suave de 0,35 s.
- As frestas existem na geometria (`FeatureBuilder.buildLocker`).
- **Verificar no Studio** que a visão fica limitada às faixas.

### F. Ameaça e captura

- `CreatureVisualController`:
  - ao entrar em Chase: o `Snarl` que já existe + `CameraController.punch()` + `addTrauma(0.35)`;
  - ao mudar o atributo `Alert` da Root: `Growl` + `punch`.
- **Captura**, na fase Lost:
  1. `CameraController.capture(função que devolve a posição da cabeça do Vigia visual)`;
  2. depois de ~0,9 s, o susto que já existe (`playScareThenFinale`) e a tela final;
  3. clarão e tremor respeitam o conforto.
- No Intro: `CameraController.reset()`, áudio restaurado (o `AudioController` já zera o silêncio no Intro) e o FearModel zerado (já é feito).

### G. GameUi

- Remover a barra de fôlego e o rótulo da lanterna. O fôlego aparece pela respiração/postura e a bateria pelos LEDs.
- Objetivo "breakers" (o texto já existe).
- Ajuda nova (`Text.Help`, sem `%s`).
- **Menu de opções (O):** as linhas de `SettingsController.KEYS` com `Text.Options` e LIGADO/DESLIGADO; as teclas 1–8 alternam.
- **Inventário (Tab, enquanto segura):** fusíveis na mão / no quadro, chave e bateria em %.
- **Tela final:**
  - Lost com `checkpointReady`: "[C] CONTINUAR DO CHECKPOINT" → `RequestRestart("checkpoint")`, e "[R] REINICIAR TUDO" → `RequestRestart("full")`;
  - Won: "[R] JOGAR DE NOVO";
  - os botões precisam ser visualmente distintos.
- Intro curta quando `fromCheckpoint` ("CONTINUANDO...", 3 s).
- Legenda `Text.Hints.checkpoint` quando `CheckpointReady` passa a true.
- `UIScale` pelo `ViewportSize.Y` (base 720); fades e slides nas legendas, nos bilhetes e na tela final.

### H. Ademir e arte

Seguir `docs/ADEMIR_APPEARANCE.md` e `assets/ademir/README.md`.

- **Preservar:** `AdemirPortrait` (rosto da foto na cabeça 3D e no susto), stop-motion e a separação entre visual e simulação.
- **`Client/Creature/Rig.luau`:**
  - massa de cabelo e pescoço;
  - farda escura com bolsos e cinto, rádio no cinto;
  - mãos com dedos em blocos;
  - luz fraca no rosto para ele ler no escuro;
  - olhar: cabeça segue a câmera também em Investigate e Search;
  - poses de transição entre patrulha, investigação, perseguição e captura.
- **Cenário:**
  - os indicadores com tag `Indicator` são animados no cliente, em passos de 12 Hz:
    - `GaugeGenerator` / `GaugePump`: ponteiro gira em torno do atributo `Pivot`, parado sem energia e oscilando com ela;
    - `PanelLed`: vermelho piscando sem energia, verde com energia;
    - `Blink`: LED do rádio;
  - telas CRT (peças `Screen` das mesas) com estática ou glitch durante eventos (SurfaceGui com ruído);
  - faíscas no atributo `Spark` da caixa de disjuntores (`Features/Breakers/Box`) e poeira/lascas no atributo `Fallen` dos objetos que caem, emitidas localmente.

### I. Haptics

`HapticService:SetMotor` para Gamepad1:

- passos do Vigia perto: fraco;
- detecção: médio;
- captura: forte;
- batimento em medo alto: pulsos.

Opção `haptics`. PC é a plataforma principal; mobile não foi testado e deve ficar documentado.

### J. Abertura do duto (Layout é do Codex)

- Em `Layout.Walls`, na parede `generatorStorage`, adicionar:

  ```lua
  openings = { { center = -47.4, width = 3.4, bottom = 0, top = 3.9 } }
  ```

- O `FeatureBuilder.buildCrawl` já põe moldura, grade, cabos e placas nesse ponto. **Sem a abertura, a moldura fica numa parede sólida.**
- Medir no Studio, com R15 agachado (`HipHeight` = padrão − `Config.Player.CrouchDrop`):
  - o topo da cabeça agachado (estimado em raiz + 2,3);
  - que o jogador passa agachado;
  - que não passa em pé;
  - que o Vigia não planeja rota pelo vão (`AgentHeight` 7,6).
- Ajustar `top` ou `CrouchDrop` se preciso; a checagem de teto usa raiz + 2,3.

### K. Áudio: verificar IDs

- No Studio, cliente em Play: `ContentProvider:PreloadAsync` com status para TODOS os IDs de `Shared/Game/Audio.luau`.
- Trocar os que falharem, de preferência por PSE/APM verificados.
- Passos (`region` {0, 0.3}): conferir se o golpe está no começo. Para isso, tocar com `PlaybackSpeed` 0,25 e amostrar `PlaybackLoudness` × `TimePosition`; ajustar `region`.
- O fallback é `StepFallback` (arquivo local do Roblox).
- Atualizar `docs/ASSETS.md` com nome, biblioteca, ID e uso de cada clipe novo. Todos estão comentados no `Audio.luau`.

### L. Testes

- Spec de `Navigation` (do Codex): acrescentar os pontos de pé de `Features` (armários, chaves, pilhas, disjuntores, prancheta e os dois lados do duto). Para o duto, usar um agente agachado ou só checar a geometria.
- Studio: `return require(game.ServerScriptService.Tests.Run)()` precisa passar.

---

## 3. Critérios de pronto

O roteiro original do humano é este:

### 3.1 Check e Studio

- `lune run scripts/check` ALL GREEN.
- Sync confirmado.
- Play via MCP (sempre com `studio_id`) e `Tests.Run` passando.
- Console sem erros ou warnings do projeto.

### 3.2 Rodadas e mecânicas a verificar

**Rodada e telas finais:**

- rodada completa com controles normais;
- vitória;
- derrota → **continuar do checkpoint**: restaura progresso, inventário, portas e Vigia em trégua;
- **reiniciar tudo**: apaga o checkpoint.

**Corpo do jogador:**

- bateria zerada nunca trava a missão (`DebugBridge` `setBattery(0)` e esperar a recuperação);
- agachar no duto e levantar bloqueado sob o teto;
- velocidade corrigida pelo servidor.

**Esconderijo:**

- entrar e sair;
- prender a respiração;
- arquejo atrai o Vigia;
- visto entrando = captura no armário.

**Ameaça:**

- detecção: grito, pancada de FOV, música de perseguição;
- perder a perseguição quebrando a linha de visão, escondendo-se ou fechando portas;
- sem spam de eventos (log do diretor);
- câmera e áudio restaurados depois de sustos e reinícios.

**Interações:**

- puzzle certo e errado (barulho);
- chave e porta trancada (chacoalha; atalho);
- objetos que caem (barulho, limite);
- sem duplicar itens;
- sem interagir através de paredes.

**Conforto:** efeitos reduzidos ou desligados (menu O).

### 3.3 Evidências e desempenho

- Evidências de debug separadas das evidências de jogo.
- Screenshots "depois" nos mesmos enquadramentos do "antes":

  | Cena | Câmera | Olhando para |
  | --- | --- | --- |
  | pátio | (16, 6, 40) | (-6, 3, 0) |
  | corredor | (36, 5, -22) | (-30, 4, -22) |
  | escritório | (-14, 5, -2) | (-34, 3, -12) |
  | Ademir* | (2, 5.2, -21) | (-8, 5, -22) |
  | gerador | (-8, 6, -30) | (-22, 3, -46) |

  \* Para o Ademir: Vigia acordado e congelado com Root `lookAt((-8,3.75,-22),(4,3.75,-22))`.
- As imagens "antes" foram vistas na conversa do Claude, mas **não foram salvas no repo**. Para refazê-las, use o commit `b5a784f` (antes do polish e da ampliação).
- Desempenho:
  - "antes": viewport 553×675, qualidade Automatic, render CPU 7,25 ms (máx. 7,57), GPU ~0, 836 primitivas, 9 luzes, 50.353 instâncias, 1732 MB;
  - FrameTime travado em 66,7 ms com o Studio em segundo plano;
  - medir o "depois" nas mesmas condições (meta ~60 FPS).

### 3.4 Documentação e commits

- Atualizar `docs/HANDOFF.md`, `docs/DECISIONS.md` (D32+), `docs/ARCHITECTURE.md`, `docs/ASSETS.md` e `docs/SETUP_REPORT.md`.
- No `CLAUDE.md`: controles novos (C/Ctrl, Q, Espaço, Tab, O).
- Skill `roblox-playtest`: os comandos novos do DebugBridge.
- Commits pequenos, sem push.
- Resposta final ao humano em PT-BR, com imagens reais do jogo.

---

## 4. Decisões já tomadas (registrar em DECISIONS)

- **Medo e diretor no cliente:** são só apresentação, sem remote por quadro. O que é autoritativo fica no servidor: Vigia, captura, bateria, postura, esconderijo, respiração, portas, puzzle e checkpoint.
- **Bateria no servidor:** a lanterna afeta a visão do Vigia. Recuperação em repouso até 35% = a missão nunca trava.
- **Agachar real:** `HipHeight` + velocidade no servidor; checagem de teto nos dois lados; visão do Vigia 0,7×.
- **Esconderijo:**
  - "viu entrar" = perseguição com visão a menos de 1,2 s;
  - respirar perto por 2,6 s = achado;
  - lanterna dentro do armário = respirar (o cliente a apaga sozinho ao entrar).
- **Puzzle:** ordem sorteada por rodada e visível no procedimento; o erro faz barulho de 46 studs.
- **Chave:** abre `door_storage`, que começa trancada. O Depósito também é acessível pelo Arquivo Técnico da ampliação, então a chave é um atalho.
- **Checkpoint:**
  - só de sessão, gravado ao voltar a energia;
  - "continuar" reusa a semente da rodada;
  - itens pegos continuam pegos;
  - o Vigia acorda longe com trégua de `GraceTime` + `IntroDuration`.
- **Objetos que caem:** cada um cai uma vez por rodada; há recarga global de barulho.
- **Câmera:** um único compositor; os modos especiais usam `Scriptable` só enquanto duram e `reset()` restaura tudo.

## 5. Interações com o co-op do Codex

Pontos para a campanha decidir:

- Bateria, postura, respiração e esconderijo já são **por jogador** (`PlayerStateService`).
- O armário tem `occupant`, então é exclusivo.
- `Objectives`, chave e checkpoint são **globais da rodada**.
  - O checkpoint guarda uma carga de bateria só, a do jogador que resolveu os disjuntores.
  - No co-op, o certo é guardar por `UserId`.
- A captura encerra a rodada solo (`endRound`). No co-op, trocar pelo estado de membro derrubado da campanha.
- Disjuntores: um puzzle global; a ordem é a mesma para todos.

## 6. Como retomar

```bash
git status
```

```bash
lune run scripts/check
```

Siga a seção 2 na ordem.

Ferramentas de depuração:

- `ServerStorage.DebugBridge`, via `execute_luau` Server: `state`, `grant`, `setBattery`, `fall`, `checkpoint`, `holdOff`, `freezeCreature`, `placeCreature`, `teleport`.
- No cliente, os `debugState()`: `CameraController`, `AudioController`, `FearController`.

## 7. Pedido original (resumo fiel)

Polish geral e aprofundado de SUBESTAÇÃO 9, terror em primeira pessoa com estética PS1/início de PS2. Prioridades, em ordem:

1. funcionamento, legibilidade e controles;
2. som, silêncio, iluminação e lanterna;
3. medo;
4. câmera e apresentação da ameaça;
5. interações, esconderijos e ritmo;
6. arte, modelagem, UI e acabamento;
7. regressão e desempenho.

Sistemas pedidos:

- câmera composta com opções de conforto;
- agachar com teto;
- áudio por material e por espaço, com silêncio antes de sustos;
- bateria que nunca trava;
- falhas de luz;
- efeitos de pânico e VHS opcional;
- medo interno sem barra, com histerese;
- alucinações;
- portas com peso e fresta;
- porta trancada e chave (inserir, girar, clique);
- puzzle com feedback forte;
- bilhetes com som de papel;
- objetos que caem;
- esconderijo com frestas e respiração presa;
- sinais antes da chegada do Vigia, alarmes falsos;
- captura com hit-stop de 0,1 s, zoom, grito, glitch e fade;
- diretor de tensão com estados, cooldowns e log;
- UI diegética, tela final separando checkpoint de reinício;
- vibração com opção de desligar;
- arte do Ademir e dos ambientes;
- assets gratuitos permitidos (search/insert/generate), documentados.

Restrições:

- sem push, publicação, compras, Creator Hub ou monetização;
- sem `rojo serve`;
- servidor autoritativo e remotes com Guard;
- um bootstrap por lado, UI por código;
- não resetar nem descartar trabalho;
- commits pequenos;
- registrar o que não pôde ser validado.
