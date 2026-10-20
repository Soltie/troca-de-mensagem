# PROGRESSO (atualizado 20/10/2026)

## Feito / aprovado
- História "A Casa de Madeira" 9.1; banco de puzzles no papel 9.0.
- "A Porta que Troca" (modo história: a casa troca o que há atrás de uma porta em momentos fixos por capítulo) design 9.1.
- Novo jumpscare (agarrar/de cima) aplicado. Lanterna em primeira pessoa = PeriodFlashlight.
- Ícones v3 9.0 (upload pendente → IDs em `UI/IconAssets.luau`).
- Preview 9.0 em `build/arte3d` (ainda NÃO importados no place; pedidos antigos 018–022): uniforme v5, manequim v9, ursinho, estantes, vitral, marca de trilha, lustre, bancada, tapete.
- Menu v3 aplicado (mockup https://claude.ai/artifact/P64pm47AHtQtKujV74eE3u); vídeo não gravado; 3 correções de menu + UI do cap. 1 no repo.
- Backup do place: `ServerStorage.Backup_Place_20261020_0715` + `backup_place_20261020_0715/`.

## Falta
- Cap. 1 v2 in-game: nota 5.5 (sem medo, Tung dormente; 12 bugs). Rodada 2 escrita no repo pelo level designer (porta bate na 3ª chave, susto de cenário por cômodo, tábuas irregulares, placa do porão, passo da cadeira da Dona Cida, banquinho que pula), NÃO aplicada ao place.
- Dívidas: presença do Tung no cap. 1; "Isso não dá para fazer agora" com fala da Cida; moveChair pega qualquer RockingChair (5 no mapa); fita da TV não toca em 12 st / 1ª fala no spawn; prompt da pilha de banquinhos; sem cutscene de abertura no cap. 1; "Olhos no Veio" some após erro de tábua; cap. 4 piano com fio preto + disco branco.
- Re-merge do PvP para o src (usuário aprovou); gancho de ruído de cena (`CreatureService.makeNoise`).
- No repo, não no place: porta com tranco (`WorldService.animateDoor`), `FurnitureMotionController` (cadeira de balanço), dedos da mão da lanterna, luz v4 (tetos 50%, lanterna mais quente; luz v3 = 8.4).
- `TungTung_Candidato` precisa de prova de corpo inteiro antes de trocar modelo.
- Sync do place com o repo (Rojo) e primeira checagem contra o código PvP/Mansão do Codex.

## Decisões
- Tom nível DOORS; refs Hello Neighbor (favorita), DOORS, Bendy; barra visual = top Roblox.
- Modo história 30–40 min (~4–5 min/capítulo). Capítulo N+1 só após o crítico aprovar o N.
- Gasolina removida (lata = óleo de máquina do Valdemar "ÓLEO — OFICINA").
- Tung oficial = `Assets.TungTung` (`TungTung_Quebrado` quebrado).
- Crítico aprova com nota >= 8 (antes 9), máx. 2 rodadas por item.
- Sem controle de tela (fila `pedidos_tela` aposentada → `backup/pedidos_tela`).
