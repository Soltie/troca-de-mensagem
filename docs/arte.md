# Arte 3D + animação: cap. 1 (20/10/2026)

## Estado
- Prontos em `build/arte3d/*.glb` para a sala/hall do cap. 1: Living_CarvingDoorFrame/WallDrum/WallNight, SheetSofa, SheetArmchair,
  KnitBasket, OvalRug, PhotoFamily/KidsTumTum/Valdemar, KeroseneLamp. No place só existem `CidaRockingChair(_v2)` em `Assets.HouseArt`;
  `Living_CarvingDoorFrame` e `Living_SheetSofa` estão soltos no Workspace (importados, falta `pos_import_v2.luau` + mover p/ HouseArt).
- `HouseArt.place` cai nas peças primitivas quando o modelo não existe, então o jogo funciona sem eles; o ganho visual vem ao importar.

## Feito
- Corrigido o nome dos entalhes em `World/HouseDressing.luau` (`Living_CarvingWalk/Drum/Night` não existiam; agora usa os nomes dos GLB:
  DoorFrame, WallDrum, WallNight).

## Importado (20/10, via Open Cloud + Studio)
Living_* (11 modelos) subidos pela conta do dono e carregados por `InsertService:LoadAsset`; escalados (1 stud = 0,28 m), pivô na base,
em `ReplicatedStorage.Assets.HouseArt`. IDs: DoorFrame 82387850613713, WallDrum 119766331571979, WallNight 139399076508887,
KeroseneLamp 72491381523314, KnitBasket 89070774022341, OvalRug 101130053061860, PhotoFamily 105379977543027,
PhotoKidsTumTum 115432814014690, PhotoValdemar 83750386732975, SheetArmchair 134644723083715, SheetSofa 75342931413885.
Antigos soltos no Workspace foram para `ServerStorage.Backup_ArtStray`. Falta: prova no jogo (print no escuro) e o usuário salvar/publicar.

## Bloqueio (resolvido)
- Importar GLB no Studio exige a UI (Home → Import 3D). Computer use é negado neste thread e a fila `pedidos_tela` foi aposentada.
  O usuário (ou o agente desktop) precisa importar: Living_* da lista acima, depois rodar `build/arte3d/pos_import_v2.luau`
  (Edit) para escalar (1 stud = 0,28 m) e mover para `ReplicatedStorage.Assets.HouseArt`. Sem upload Open Cloud não há outro caminho.
- Animação: nada novo pedido pelo cap. 1 (Tung dormente; presença é por código: batidas/silhueta/quase-acerto).

## Crítico
Não rodado (nenhuma mudança visível no jogo ainda).
