# Level cap. 1
Feito no repo: `RoomScares` (puro, testado) + `RoomScareService` (registrado no Main) + legenda no MomentController. Porta que bate na 3ª chave, cadeira da Cida e 6 móveis já estavam no repo.
Falta (não está no repo, só relatado pela rodada 2): tábuas irregulares, placa da escada do porão, papel plano/sem luz na biblioteca. Presença do Tung depende de docs/codigo.md.
Não aplicado ao Studio ainda (aguardando a vaga). Teste: entrar em cada cômodo do térreo; ver legenda + efeito; 2ª chave → olhos no corredor; mover cena em Play, checar nomes "Pan"/"Chair" nos modelos.
Presença do Tung (docs/codigo.md): gatilhos padrão cobrem o cap. 1 (1ª chave batidas, 2ª silhueta, 4ª tarefa quase-acerto). Nenhuma zona extra necessária; meus sustos de cenário não duplicam (o do hall é 1ª visita, as batidas do Tung vêm na 1ª chave).

## capítulo 1 pronto (parcial)
Aplicado no place (backup ServerStorage.Backup_Cap1_Level): HouseCatalog (tarefa da cadeira da Cida), HouseProgression (ch1 com 8 tarefas), RoomScares, RoomScareService, linha no Main. Tests.Run = 439/0.
NÃO feito: tábuas irregulares, placa da escada do porão, papel plano na biblioteca (precisam de posições/olho no Studio).
Testar: História cap. 1; entrar em cada cômodo (legenda + efeito); 2ª chave → olhos no corredor; checar se panelas/cadeira do jantar mexem (nomes "Pan"/"Stove"/"Chair").

## Atualização cap. 1 (final)
Meu RoomScareService era duplicado: os sustos por cômodo e a placa do porão já existiam em `World/HouseDressing` (Dressing.scares / basementSign). Movi RoomScareService, RoomScares e o spec para `backup/` e tirei do Main e do place.
Aplicado no place: HouseDressing (sustos + placa), HouseMiniPuzzles (tábuas irregulares: ângulo, comprimento, inclinação), HouseTaskProps (carta "message" = folha fosca, sem luz, selo como indicador). Tests.Run 439/0; RoomScares e BasementStairSign existem em CursedHouse.
Testar: tábuas da cozinha desalinhadas; carta da biblioteca é uma folha lisa; entrar em cada cômodo dispara o susto (hall, cozinha, jantar, biblioteca, corredor). Push: fica com o usuário.

## Rodada 2 do cr�tico (cap. 1 v3, nota 6,0): corre��es
- Place estava velho (HouseActivities sem a cadeira da Cida): sincronizados HouseActivities, HouseMiniPuzzles, HouseProps, HouseDressing, HouseTaskProps (backup *_v2/_v3 em ServerStorage.Backup_Cap1_Level).
- 1 Cadeira da Cida: marcador da tarefa (Station) segue a cadeira. 2 Canto: cadeira e cesto movidos para (-22,5; 0; 4,5), longe da lareira/porta (pathfinding ok).
- 3 Sustos: legenda curta em cada um (hall, cozinha, jantar, biblioteca, corredor), via CampaignState.Caption.
- 4 Carta: s� o papel deitado, fundo mais escuro (removi minha folha duplicada). 5 Caixinha de m�sica vis�vel ao abrir o m�vel certo.
- Tests.Run 439/0. N�o revi o jogo a olho em todos os c�modos.
