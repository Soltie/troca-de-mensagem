# CLAUDE — handoff do polish de terror (vivo)

Atualizado: 15/10/2026 (em andamento). Branch: `claude/polish-terror` (mesmo diretório do Codex, sem worktree
própria). Sem push. Este arquivo é atualizado durante o trabalho; o estado abaixo é o real neste momento.

## Pedido (resumo fiel)

Polish geral e aprofundado de SUBESTAÇÃO 9 para virar uma experiência coesa de terror em primeira pessoa,
estética PS1/início de PS2. Ordem de prioridade do humano:

1. funcionamento, legibilidade e controles;
2. som, silêncio, iluminação e lanterna;
3. sistema de medo;
4. câmera e apresentação da ameaça;
5. interações, esconderijos e ritmo;
6. arte, modelagem, UI e acabamento;
7. regressão e desempenho.

Inclui:

- câmera composta;
- agachar com teto;
- áudio por material e espaço;
- bateria que nunca trava a missão;
- medo interno, sem barra;
- diretor de tensão com estados;
- alucinações;
- portas com fresta e porta trancada com chave;
- puzzle com feedback;
- esconderijo com respiração presa;
- objetos que caem;
- checkpoint de sessão;
- captura com hit-stop;
- opções de conforto;
- arte do Ademir e do cenário;
- testes e documentação.

Restrições:

- sem push, publicação, compras ou monetização;
- sem `rojo serve`;
- servidor autoritativo;
- código só em `src/`;
- commits pequenos.

## Decisões (e por quê)

- **Arquivos novos em vez de editar o mapa do Codex:** `Server/World/Features.luau` (dados) e `FeatureBuilder.luau` (montagem), chamados pelo
  `WorldService` depois do `MapBuilder`. Assim as duas frentes não colidem.
- **Medo e diretor de tensão no CLIENTE:** são só apresentação, sem remote por quadro. A ameaça real (Vigia, captura) continua 100% no servidor.
- **Bateria simulada no SERVIDOR** (por jogador), publicada em atributo `Battery`. A lanterna ligada afeta a visão do Vigia, então o cliente não decide.
  A pilha desligada "descansa" até 35%, para a missão nunca travar.
- **Agachar com efeito real no servidor:** `HipHeight` e velocidade mudam lá, e o teto é checado no cliente e no servidor.
  A câmera compensa o "pulo" físico para a transição ficar suave.
- **Esconderijo:** fuga real.
  - Se o Vigia não viu entrar, perde o rastro.
  - Se ele ficar perto e você respirar (sem prender), ele te acha.
  - Lanterna acesa dentro do armário conta como respirar.
- **Puzzle de disjuntores** entre "fusíveis no quadro" e "energia".
  - A ordem é sorteada por rodada e está no procedimento na parede.
  - Errar faz barulho, o que atrai o Vigia.
- **Checkpoint:** gravado ao voltar a energia.
  - Guarda objetivos, portas e trancas, carga, itens pegos e a ordem dos disjuntores.
  - "Continuar" (tecla C) é diferente de "reiniciar tudo" (tecla R).
- **Co-op 3–8 (pedido repassado pelo Codex):** não mudei o escopo do polish por conta própria.
  Os sistemas novos já são por jogador onde importa (bateria, postura, esconderijo, respiração, velocidade).
  Os objetivos ainda são globais da rodada.

## Estado

### Pronto (código + testes puros verdes no Lune)

- Puros, todos com spec:
  - `Shared/Game/FearModel.luau`
  - `Shared/Game/TensionDirector.luau`
  - `Shared/Game/BatteryModel.luau`
  - `Server/Game/PlayerRules.luau`
  - `Server/Game/HideRules.luau`
  - `Server/Game/BreakerPuzzle.luau`
  - `Server/Game/Checkpoint.luau`
- `Server/Game/Objectives.luau` agora tem chave, disjuntores e o objetivo "breakers".
  É mudança intencional; o spec foi atualizado.
- `Config` ganhou Battery, Fear, Tension, Camera, Hide, Puzzle, Doors, Fallables, Checkpoint e Comfort.

### Escrito, ainda NÃO integrado nem testado no Studio

- Cliente:
  - `Client/Controllers/CameraController.luau`: compositor único.
  - `Client/Controllers/CharacterController.luau`: reescrito com peso, exaustão, agachar e pouso.
  - `Client/Controllers/SettingsController.luau`: 8 opções.
- `Server/Services/PlayerStateService.luau`: postura, bateria, esconderijo, respiração e validação de velocidade.
- `Server/World/Features.luau` e `FeatureBuilder.luau`:
  - armários, chave e pilhas;
  - disjuntores e procedimento;
  - rádio;
  - objetos que caem;
  - poças, goteiras e assoalho;
  - moldura do duto;
  - indicadores;
  - zonas de reverb.
- `Shared/Game/Audio.luau` (IDs novos ainda NÃO verificados com PreloadAsync), `Text.luau`, `Remotes.luau`, `Types.luau`.

### Falta (em ordem)

1. Integrar:
   - `WorldService`: features, portas com fresta e tranca, disjuntores, checkpoint;
   - `RoundService`: interações novas, checkpoint, `RequestRestart(mode)`;
   - `CreatureService`: esconderijo, agachado, porta trancada;
   - `PropService`: objetos que caem;
   - `Main` do servidor e do cliente.
2. Fazer o check ficar ALL GREEN.
3. Cliente:
   - áudio: passos por material, respiração, camadas, reverb por zona, música por estado, abafamento;
   - lanterna com LEDs, poeira e balanço;
   - medo e tensão: `FearController` e `TensionController`, com alucinações;
   - efeitos de tela.
4. Interações no cliente:
   - destaque;
   - Q para entreabrir;
   - animações de pegar e de chave;
   - câmera do armário e respiração;
   - bilhetes com som de papel.
5. Captura (hit-stop, zoom, grito, glitch e fade), telas finais com checkpoint, menu de opções (O), inventário (Tab) e UIScale.
6. Arte: Ademir (cabelo, pescoço, farda, mãos, olhar), equipamentos, telas com estática.
7. Abertura do duto no `Layout`: parede `generatorStorage`, z = -47.4, largura 3.4, topo 3.9.
   O arquivo é do Codex; vou registrar a alteração.
8. Validação completa no Studio, medição de desempenho, documentação (HANDOFF, DECISIONS, ARCHITECTURE, ASSETS, SETUP_REPORT) e commits.

## Remotes, atributos e APIs novos

- Remotes:
  - `SetStance("Stand"|"Crouch")` (evento);
  - `SetHoldBreath(bool)` (evento);
  - `Interact(id, action?)`, com ação `"alt"` = entreabrir/fechar porta;
  - `RequestRestart(mode?)`, com `"full"` ou `"checkpoint"`;
  - `SetFlashlight` passou do RoundService para o PlayerStateService.
- Atributos no Player:
  - `Stance`, `Battery` (0..1), `Flashlight`;
  - `Hidden` (id ou ""), `HiddenAt`, `HiddenSeen`, `HideEye`;
  - `HoldBreath`, `Gasps`.
- Atributo no Character: `StandHipHeight`.
- `InteractResponse.kind`: o cliente anima o resultado aprovado.

## Studio

- Uso apenas a place local `Dev.rbxlx` (studio `cac08fd1…`). O shared place não é tocado.
- Antes de cada Play leio `LEIA_CLAUDE.md`.
- Estado atual: **não estou usando o Studio**.

## Como retomar

1. `git status` e `git diff`: as mudanças sem commit são todas desta frente, exceto `Server/Campaign/`,
   `CampaignCatalog`, `docs/COOP_CAMPAIGN.md` e os specs Campaign/Coop, que são do Codex.
2. Rodar `lune run scripts/check`.
   Hoje só faltam os erros de tipo esperados pela integração pendente (ver "Falta").
3. Seguir "Falta" na ordem.
