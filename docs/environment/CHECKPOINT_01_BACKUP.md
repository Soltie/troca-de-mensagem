# Checkpoint 1 — backup e comparação

Destino conferido via MCP: PlaceId 82955516040017, UniverseId 10771638828, versão 18, 268 scripts. Sem alterações de fontes, gameplay ou publicação.

Backup nativo pela opção Download a Copy do Studio: `build/TungTung_BACKUP_ANTES_CODEX_20261019.rbxl` (715687 bytes).

SHA-256: `2DA13F5E50A6427A5819BC3921BE8B77C943E5FD85403CCB51F3BAEFFFE24281`.

Backup reaberto no Studio e inspecionado via MCP: 268 scripts, 53 modelos em MansionProps, 13 entradas em MaterialService e Terrain presente. Abertura confirmada; não foi executado Play nem verificação voxel a voxel nesta etapa.

Comparação de todas as fontes com src local (normalização CRLF): 213 iguais, 28 diferentes, 27 exclusivas do Studio, nenhuma fonte local ausente do Studio. Relação completa em BACKUP_RECONCILIATION.json. O arquivo nativo foi lido pelo Lune (673 instâncias); houve aviso de tipo não suportado em Terrain.VoxelGridAssetContentMap. O backup original não foi reserializado ou modificado; essa limitação impede usar Lune para reconstruir o Terrain fielmente.

Fontes compartilhadas diferentes incluem câmera, animação, campanha, rede, schema/dados, serviços PvP e bootstrap. HouseProps também diverge. Não conectar a árvore antiga por Script Sync nem substituir módulos de forma global.

Iluminação aprovada coincide com o disco. O repositório de coordenação registra correções de salto/câmera d41b627 posteriores ao repasse. Responsável por Sync consultado na mensagem 013; nenhuma conexão nova feita.

Este checkpoint inventaria diferenças; não afirma que elas já foram mescladas. A reconciliação deve manter os sistemas atuais como base e incorporar alterações visuais seletivamente após comparação e teste.

Próximo item bloqueado pela revisão humana deste checkpoint, conforme pedido: não iniciar escala/móveis antes da confirmação.
