# Codex integrador — estado em 18/10/2026

## Escopo e origem

Responsável por reunir a floresta/remaster/Tum-Tum da referência com o experimento atual, preservando Midnight Hunt e demais melhorias do receptor.

Referência local: `C:/Users/xpg/.codex/worktrees/tum-tum-hunt/roblox-teste`, branch `codex/forest-tumtum-export`, HEAD `08f697cf557fc9851d4844bb7121e1283742448c`. Checkout principal antigo/dirty foi preservado.

## Estado verificado do destino

- MCP: `tungtung`, PlaceId `82955516040017`, UniverseId `10771638828`.
- Editor em Edit na retomada. Raízes ReplicatedStorage e ServerScriptService: `NotSynced`.
- Fontes do destino incluem `PvPMatchService`, `PvPLobbyService`, `PvPMatch`, `PvPConfig`, `HunterCameraController` e menu Midnight Hunt. Não substituí-los pelo Tum-Tum antigo.
- A árvore já contém ForestBuilder/ForestLayout/ForestThreat/ForestCinema; conteúdo ainda será comparado por arquivo.
- Nenhum script ou asset do destino foi alterado por esta frente até este registro.

## Reserva proposta

Preparação de snapshot/manifesto e comparação local de campanha/floresta/câmera. A publicação no lugar compartilhado fica pendente do backup e reconciliação das reservas do colega. Ainda não há conexão Script Sync desta frente.

## Evidência da referência (não do destino integrado)

Pacote tem 236 fontes Luau. Relatório registra 302 testes locais, 315 Studio, campanha História dupla 148, Desafio dupla 150 e Tum-Tum 3 clientes 45. Limites e versões exatas estão no relatório do pacote. Isso não é resultado de QA do Midnight Hunt atual.

## Próximos passos

1. Salvar backup completo atual e extrair fontes para comparação.
2. Reconciliar reservas com o parceiro; receber seu HEAD e alterações atuais.
3. Unir contratos em cópia isolada, validar check/build e Studio.
4. Revalidar hashes do destino antes da aplicação; documentar alterações e entregar fontes/build únicas.
