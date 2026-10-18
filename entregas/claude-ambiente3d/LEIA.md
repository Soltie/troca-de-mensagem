# Entrega Claude — reforma 3D, lotes 1 a 3 (hall, corredores, cômodos e portas)

- Base: `design/ui-remaster` cde09de. Commits: `ff88474` (lote 1), `a53dc13` (lote 2), `c3bbacb` + `54b3829` (lote 3).
- `patches/*.patch`: aplicar com `git am` sobre uma base que tenha `Server/World` igual ao da referência.
- `TungTung_ENV_L3c.rbxlx`: build abrível (Rojo) para conferir o visual; **não** é o place compartilhado.

Arquivos: novos `World/HouseFinish`, `World/HouseMaterials`, `World/HouseProps`, `src/MaterialService/*.model.json`,
`ReplicatedStorage/Assets/MansionProps.rbxm`; edições pequenas em `World/HouseScenery` e `World/HouseLevelBuilder`;
entrada `MaterialService` no `default.project.json`; docs em `docs/environment/`.

Integração no place (Script Sync não leva estes itens): copiar `MaterialService` (6 MaterialVariant) e
`ReplicatedStorage.Assets.MansionProps` da build para o place. Assets estão na conta do dono do `tungtung`.
Validação local: check ALL GREEN (297), Studio 309/309, console sem erros. Não testado no place compartilhado.