# Codex integrador — entrega aplicada em 18/10/2026

## Estado atual

Raiz definitiva: `C:/Users/xpg/Documents/tungtung-integrado`, branch `codex/tungtung-live-integration`, HEAD `e23b6359e4128def6e6b96a343a817896875f90e`.

Destino: `tungtung`, PlaceId `82955516040017`, UniverseId `10771638828`. Oito arquivos de integração aplicados por Script Sync. ReplicatedStorage e ServerScriptService são SyncedAsRoot desta raiz/src; todas as 250 fontes conferem com o disco, sem exceções. Os 31 descendentes de Assets e o Workspace foram preservados.

**Este é o único integrador conectado.** Não conecte outro PC/raiz às mesmas instâncias simultaneamente. Envie mensagem com branch/HEAD, alterações e reservas. Mantenha seu próprio arquivo em agentes/ atualizado. Nenhuma resposta do parceiro foi recebida até este fechamento.

Não há Play desta frente reservado: testes encerrados. Não houve publicação Roblox, mudança de Creator Hub, DataStores live ou push no repositório principal.

Pacote atual: `entregas/Tungtung_PROJETO_INTEGRADO_2026-10-18.zip`, 721 arquivos, fontes/build/manifesto/ferramentas/relatório/evidências/bundle.

- ZIP: `328dbd49f1daddbb92a7a62887a9d057443011158e7adade1f1af898c21e0dcb`.
- Build: `92f7f7a19a388afcd780f3d278ac1ebdfd37cc69ff35b5225872f92484bfdb62`.
- Baseline: `d9bd32c`; implementação: `cd23069`.
- Build conserva 1499 dos 1500 chunks do backup byte a byte; só Source mudou.

Validação: 323 puros;335 Studio no destino;História dupla148 (success=true recuperado do servidor após timeout);caçada3 com72 checks até a retomada da História (callback interrompido, sem payload final);caçada6 com98 checks/success=true. Recompensa idempotente, vitória/final, limpeza, nova rodada/rotação e desconexão verificadas.

Câmera do receptor preservada: caçada verificou provider FPS/FOV80/rig/mãos. No destino há LockCenter com ambos os botões soltos. A tentativa de medir rotação via VirtualInput foi rejeitada pelo engine por cursor não bloqueado; **não considerar mouse físico ou rotação automática aprovados**. Hardware, diversão/equilíbrio e persistência live continuam externos.

Próximo agente: leia o relatório atual e o manifesto, registre sua frente e responda em mensagens/ antes de editar o mesmo conjunto. Preserve Midnight Hunt/menus/loja/floresta/schema8; não restaure a caçada antiga como runtime paralelo.

---

## Histórico inicial — superado pelo estado acima

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
