# GAME_SPEC — SUBESTAÇÃO 9

> Direção atual (16/10/2026): campanha cooperativa de **3–8 jogadores**, três estágios,
> seed, atividades, atalhos e uma ala norte modular reconstruída por rodada/estágio.
> A geração física está descrita em [MAP_RANDOMIZATION.md](MAP_RANDOMIZATION.md).
> Especificação e estado de validação em
> [COOP_CAMPAIGN.md](COOP_CAMPAIGN.md); testes em [COOP_QA.md](COOP_QA.md).
> `Config.Campaign.Enabled = true` seleciona esse modo. A descrição abaixo preserva o
> protótipo solo como referência de regressão, selecionável com a flag false.

> Protótipo de terror atmosférico, estética PS1/início do PS2. Uma rodada de 5–10 minutos,
> um jogador, PC (teclado e mouse), primeira pessoa.

## 1. Conceito

- **Nome:** SUBESTAÇÃO 9
- **Pitch:** 03:12, a energia de uma pequena subestação elétrica no meio do mato caiu. Você é o técnico
  do turno da noite: troque os três fusíveis do quadro principal e saia pelo portão. Algo ficou lá dentro.
- **Referências:** Silent Hill (névoa e rádio), Signalis/Haunted PS1 (low poly, paleta curta),
  Fatal Frame (escuridão com intenção).
- **Diferencial:** **a luz é faca de dois gumes.** A lanterna é necessária para enxergar, mas deixa
  você visível de muito mais longe. A criatura, **O Vigia**, se move em *stop-motion* (poses a ~10 quadros
  por segundo) enquanto o jogo roda liso a 60 FPS.

**Narrativa mínima:** a ordem de serviço explica a missão; três bilhetes na instalação contam que o vigia
noturno "nunca saiu do turno" e que "ele segue a luz". Sem diálogos.

**O Vigia:** figura alta (≈7,5 studs), magra e curvada, braços até os joelhos, casaco de vigia escuro e
rasgado, rosto liso cinzento com dois olhos pálidos que brilham. Silhueta reconhecível no fim de um corredor.

## 2. Loop principal

1. Explorar no escuro com a lanterna (liga/desliga).
2. Encontrar um fusível → barulho → O Vigia acorda/investiga.
3. Evitar ser visto: desligar a luz, quebrar a linha de visão, usar os laços entre salas, correr (fôlego limitado).
4. Levar os fusíveis ao quadro na Sala do Gerador.
5. Energia volta → O Vigia caça → abrir o portão elétrico e fugir.

- **Sessão:** 5–10 minutos; morte reinicia a rodada inteira (tecla R ou botão).
- **Por que jogar de novo:** posições dos fusíveis variam por rodada (2 pontos possíveis em cada sala).

## 3. Progressão

Só dentro da rodada (sem progressão persistente):

| Etapa | Gatilho | Efeito |
| --- | --- | --- |
| Introdução | início da rodada | cartela de texto, controles, objetivo "Entre na subestação" |
| Exploração | entrar no prédio | objetivo "Encontre os fusíveis (0/3)" |
| Despertar | 1º fusível (ou 2 min) | luzes piscam, stinger, O Vigia começa a patrulhar |
| Escalada | cada fusível | Vigia mais rápido; a partir do 2º ele "fareja" sua posição de tempos em tempos |
| Clímax | 3 fusíveis no quadro | energia volta, rugido, O Vigia caça; portão liberado |
| Fim | passar o portão / ser pego | tela de vitória ou derrota + reiniciar |

Nada é salvo entre rodadas (PlayerDataService continua no template, sem uso no jogo).

## 4. Monetização

Fora do escopo do protótipo. Nenhuma.

## 5. Público

- **Faixa etária:** 13+ (tensão e susto, sem sangue nem violência gráfica).
- **Perfil:** fãs de terror indie/retrô, sessões curtas.
- **Sessão típica:** 5–10 min.

## 6. Plataformas

- [x] PC (teclado e mouse) — alvo do protótipo
- [ ] Mobile / Console / VR — não verificados

**Controles (PC):**

| Tecla | Ação |
| --- | --- |
| WASD + mouse | andar e olhar (primeira pessoa) |
| Shift (segurar) | correr (fôlego limitado) |
| F | lanterna liga/desliga |
| E | interagir (mirar no objeto) |
| R | reiniciar (nas telas finais) |
| V | filtro retrô liga/desliga (scanlines, vinheta, granulação) |
| B | balanço/tremor de câmera liga/desliga (conforto) |
| H | mostrar/ocultar ajuda |
| F3 | painel de debug (FPS, estado da criatura) |

## 7. Fases de implementação

| Fase | Escopo | Critério de pronto |
| --- | --- | --- |
| 1 | Mapa gerado por código, personagem 1ª pessoa, câmera, lanterna, interação (mirar + E) | dá para andar por todas as salas; prompts aparecem; interação validada no servidor |
| 2 | Fusíveis, quadro, portas, portão, O Vigia (patrulha/detecção/perseguição/captura), rodada (intro, vitória, derrota, reinício) | rodada completa jogável pelo caminho normal; reinício restaura tudo |
| 3 | Direção de arte (paleta, névoa, luz), áudio, UI retrô, efeitos ajustáveis, conforto | capturas conferidas; console limpo; FPS medido |

## 8. Critério de pronto de cada fase

Para TODA fase, além do critério específico da tabela acima:

- [ ] `lune run scripts/check` verde.
- [ ] Playtest via MCP sem erros/warnings inesperados; testes do Studio passando.
- [ ] UI conferida com `screen_capture` (se a fase tiver UI).
- [ ] Dados novos com migração em `PlayerDataSchema` (se mudou o formato).
- [ ] Todo remote novo validado no servidor (Guard + rate limit).
- [ ] Commits pequenos; `docs/SETUP_REPORT.md` atualizado.

## 9. Limites técnicos assumidos (validados na doc/Studio)

- Sem shader/pixelização de tela no Roblox: o "retrô" vem de paleta, neblina clássica (`Lighting.Fog*`),
  sombras globais desligadas, poucos polígonos, fonte pixel (`Enum.Font.Arcade`), sobreposição 2D
  (scanlines/vinheta/granulação) e animação em passos.
- `Lighting.Technology` e `MaterialService.Use2022Materials` não são acessíveis por script (testado):
  não dependemos deles.
- Mundo, luz, UI e criatura são gerados por código a partir de `src/` (reprodutível); áudio por IDs
  do Creator Store listados em `docs/ASSETS.md`.
