# Features guardadas (inventário só leitura, 20/10/2026)

Fontes olhadas: `src/` atual, branches (`codex/tung-tung-sahur`, `design/ui-remaster`, `design/environment`), `backup/`, `backup_place_20261020_0715/`, `C:\Projetos\pacote\historico`, `C:\Projetos\subestacao-9`.
Não olhei ainda: `ServerStorage` e o código do place (Studio estava fechado). Fica pendente.

## A. Já no repo e ligadas (ideias A–M do usuário)
O "sopro" **já existe** e funciona com o código atual; só não vale no cap. 1 por regra (`GustRules`: "nos capítulos da casa, menos o primeiro e a fuga do incêndio").

| Feature | O que faz | Onde | Cap. 1? |
| --- | --- | --- | --- |
| Sopro que varre o corredor (J, estilo Rush) | de tempos em tempos um vento gelado corre pelo corredor, luzes piscam, derruba quem está na faixa fora de armário | `Shared/Game/GustRules`, `Services/GustService`, `Controllers/GustController`, ligado em `CampaignRuntime` | Não por regra; dá para liberar (StartGrace 60 s, Cooldown 120 s) |
| Luz guia (A, DOORS) | contorno no objetivo se o jogador ficar parado | `Controllers/GuidingLightController` | Já ativo |
| Revista do armário (C, Outlast/Granny) | Tung para na porta, jogador segura a respiração no ritmo | `Shared/Game/BreathTest`, `LockerSearchService`, `BreathTestController` | Precisa de Tung ativo; cap. 1 tem Tung dormente |
| Diretor de tensão (D, Alien: Isolation) | camada acima da IA do Tung, controla picos e folgas | `TensionModel`, `TensionDirector` | Ativo; limites de picos por capítulo |
| Passos que informam (E) | som muda com piso e andar | `CreatureService` (L190) | Ativo |
| Armário com surpresa (G, Pressure) | fração dos armários tem "algo" dentro (dois olhos) | `CursedLockerController`, `WorldService` | Cabe: sala/corredor têm armários |
| Sanidade no escuro (I, Amnesia) | breu gasta sanidade, visão perde cor | `SanityController` | Só depois de ter a lanterna; já cobre o cap. 1 |
| Corrida da fuga (M, Seek) | fuga roteirizada com incêndio | `EscapeRun*`, `EscapeRunService` | Só cap. 5 |
| Outros ligados: `FireService`, `LightningService`, `RainController`, `FootprintService`, `ForestHazardService`, `TunnelService`, `TungVisitService`, `DoorSwapService` ("A Porta que Troca") | clima, incêndio, pegadas, floresta, túnel, visita do Tung, troca de porta | `Server/Services` | Porta que Troca e pegadas cabem no cap. 1 |

## B. Fora do `src` (só no backup do place / place)
Código do Codex que o place tem e o repo não (ver `backup_place_20261020_0715/fresh/src` e `merge`):
- **PvP/Caçador:** `PvPMatchService`, `PvPLobbyService`, `Server/PvP/*` (Arena, Match, Roles, Motion, Rewards), `HunterCameraController`, `HunterViewmodelController`, `HunterPose`, `PvPHud/Input/Audio/QAController`, `PvPConfig`. Modo à parte. Não cabe no cap. 1.
- **Mansão do Codex:** `MansionDirector`, `MansionScene`, `MansionConfig`, `MansionProps.rbxm`, materiais `Mansion*`, `VaultMotion`. Outro mapa/modo. Não cabe.
- **Casa dinâmica:** `DynamicHouseService` + `DynamicHouseController`. Casa que muda; parente da "Porta que Troca". Pode caber no cap. 1, mas precisa checar contra `DoorSwap`.
- Conflitos antigos guardados: `conflitos_dono/*` (LightingProfile, PuzzleStyles, SahurMelody, HouseActivities...). Versões antigas; só consultar.
- Re-merge do PvP para o `src` já aprovado pelo usuário (PROGRESSO.md), não feito.

## C. Em `backup/` (substituído, não perdido)
`RoomScares`, `RoomScareService` e spec: sustos por cômodo duplicados com `HouseDressing.scares`. Não usar.

## D. Branches e outros projetos
- `codex/tung-tung-sahur`: base mais antiga (195 arquivos de `src` diferem, ~39 mil linhas a menos); tudo dela já está contido na branch atual, exceto o que a seção B lista.
- `design/ui-remaster`: mesma base antiga + UI; nada a resgatar para o jogo.
- `C:\Projetos\subestacao-9`: outro jogo (Subestação 9, 2–8 jogadores). Fora do escopo; não olhei por dentro.
- `git stash`: vazio.

## Pergunta ao usuário
Quais entrar no cap. 1? Candidatos que cabem: **Sopro** (liberar no cap. 1, se quiser um pico de medo; hoje é bloqueado por regra), **Armário com surpresa**, **Casa dinâmica**, **Revista do armário** (só se o Tung acordar no cap. 1). O resto fica para os outros capítulos.
