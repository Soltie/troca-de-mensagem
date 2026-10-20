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

## Prova no jogo (Play, 20/10)
Print: `docs/critica/arte_cap1_sala_sofa.jpg` (sala, câmera fixa por script, UI escondida). Colocados em `CursedHouse.LivingDressing`: OvalRug, SheetSofa,
KnitBasket, PhotoFamily, PhotoKidsTumTum, PhotoValdemar, KeroseneLamp. Escala do sofá ok (8,3 x 2,9 x 4,6 studs, proporcional à TV e à poltrona).
Problemas: (1) SheetArmchair e os 3 entalhes (Carving*) NÃO aparecem no jogo: o código do place é mais antigo que o repo (sem as linhas de
entalhe/poltrona); precisa sincronizar `HouseDressing`. (2) No print o sofá parece de couro com almofadas, sem lençol visível: conferir se a
textura do lençol carregou. (3) Prints seguintes saíram pretos (só poeira), provável efeito de luz/cena do jogo; sem prova em lanterna.
Atualização: place sincronizado (só faltava o rename dos entalhes; o resto do HouseDressing já era igual ao repo). Play confirma os 3 entalhes
no jogo. SheetArmchair não é usado por nenhum código (precisa de posição na sala, falta definir). Sofá sem lençol visível segue em aberto.
Correção do lençol: o sofá original (11,8 studs) engolia o lençol do artista (8,3). `HouseDressing` agora esconde o original
(`hideOriginal`, mantém colisão) quando o modelo do artista existe; mesma regra para a poltrona da sala (-36,5; -15,5) com `Living_SheetArmchair`.
Aplicado no repo e no place; `lune run scripts/check` ALL GREEN. Conferido por números no Play (originais com Transparency 1, lençóis nas
mesmas posições); print visual não consegui (capturas saem pretas), então a conferência visual fica com o Crítico.
Nota: não rodei Crítico (a prova em jogo é dele).

## Bloqueio (resolvido)
- Importar GLB no Studio exige a UI (Home → Import 3D). Computer use é negado neste thread e a fila `pedidos_tela` foi aposentada.
  O usuário (ou o agente desktop) precisa importar: Living_* da lista acima, depois rodar `build/arte3d/pos_import_v2.luau`
  (Edit) para escalar (1 stud = 0,28 m) e mover para `ReplicatedStorage.Assets.HouseArt`. Sem upload Open Cloud não há outro caminho.
- Animação: nada novo pedido pelo cap. 1 (Tung dormente; presença é por código: batidas/silhueta/quase-acerto).

## Crítico
Não rodado (nenhuma mudança visível no jogo ainda).

## Olho do Tung no menu (Crítico 6,0, rodada 1) — preparado, NÃO aplicado ao place
Causa: o brilho do olho (`MenuStage` `Eye1/Eye2`, bolinha Neon 0,2) ficava em z = -0,93 no osso da cabeça = superfície do rosto; de lado metade salta para fora.
Correção só no repo (`UI/MenuStage.luau`): z -0,8 (recuado 0,13) e bolinha achatada 0,2 x 0,2 x 0,1. Modelo e textura do Tung intocados (Assets.TungTung).
Outras cópias: jumpscare, perseguição e UI de itens usam `TungTungRig` (só `eyeLight` + peças Neon do modelo), sem bolinha; nada a mudar.
Medida offline (Blender, TungTung_MaoNova_v4 no osso Head): frente do rosto ~12,7 cm na altura do olho; profundidade da órbita não dá para fechar sem a escala do rig, então o valor é estimado.
Aplicar: colar as 2 mudanças no `MenuStage` do place (Studio com o Level) e conferir o menu de lado. check ALL GREEN.
