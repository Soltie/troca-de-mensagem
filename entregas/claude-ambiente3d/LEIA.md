# Entrega Claude — reforma 3D, lotes 1 a 7

- Base: `design/ui-remaster` cde09de. Branch de trabalho: `design/environment`.
- Commits: `ff88474` (1 hall/corredores), `a53dc13` (2 PBR/móveis), `c3bbacb` + `54b3829` (3 cômodos/portas),
  `72722be` (4 planta dos cômodos e assets restantes), `5f8bcc8` (5 fachada, jardim, luz interior),
  `7071e4d` (6 grama do Terrain, chão PBR, mato, chuva), `cdafb2f` (7 floresta, ladrilho, escada, guarda-roupa).
- `patches/0001..0008`: aplicar com `git am` em ordem sobre uma base com `Server/World` igual ao da referência.
- `TungTung_ENV_L7.rbxlx`: build abrível (Rojo) para conferir o visual; **não** é o place compartilhado.

## O que o Script Sync NÃO leva (copiar da build para o place)

1. `MaterialService`: 13 MaterialVariant (Mansion*, Garden*, ForestFloor, DirtTrail, SandPath, RoofSlate, MansionTiles).
2. `ReplicatedStorage.Assets.MansionProps` (53 modelos, inclui mato alto e pinheiros).
3. `Workspace.Terrain`: marcar **Decoration = true** e **GrassLength = 0.55** (propriedade de place; não dá por script).
   Sem isso o chão continua com textura, só sem a grama animada.

Assets estão na conta do dono do `tungtung`. Sons novos: PSE 9112856553 (chuva) e 9120018692 (trovão).

## Validação local

check ALL GREEN (302 puros), Studio 314/314 no estado inicial, console sem erros do jogo. Detalhes e o que ficou
NÃO TESTADO em `docs/environment/ENVIRONMENT_QA.md` (celular físico, partida humana, câmera real no guarda-roupa).
Nada de UI/HUD, regras, IDs, recompensas ou colisões foi alterado; o que é só visual não colide nem recebe raycast.
