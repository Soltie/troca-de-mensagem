# Codex dinâmica — 18/10/2026

## Estado atual — implementação isolada, QA final pendente

Raiz/branch/base abaixo preservados; alterações ainda sem commit final. Coordenação inicial enviada em ef41ae3 após autorização explícita. Integrador existente permanece único escritor de Script Sync. Nenhuma escrita no destino compartilhado.

Reserva exata proposta (14 fontes, aguardando reconciliação):

- Novas: `src/ReplicatedStorage/Shared/Game/MansionConfig.luau`, `src/ReplicatedStorage/Client/Controllers/DynamicHouseController.luau`, `src/ServerScriptService/Server/Mansion/MansionDirector.luau`, `src/ServerScriptService/Server/Mansion/MansionScene.luau`, `src/ServerScriptService/Server/Services/DynamicHouseService.luau`, `src/ServerScriptService/Tests/MansionHarness.luau`, `src/ServerScriptService/Tests/Specs/MansionDirector.luau`.
- Hooks sob src/: `ReplicatedStorage/Client/Controllers/CharacterAnimatorController.luau`, `InteractionController.luau` na mesma pasta, `ReplicatedStorage/Client/Main.client.luau`, `ReplicatedStorage/Shared/Net/Remotes.luau`, `ServerScriptService/Server/Main.server.luau`, `ServerScriptService/Server/Services/PlayerStateService.luau`, `WorldService.luau` na mesma pasta.
- Nenhuma fonte de schema8, dados/economia, menus/loja, floresta, salas privadas ou PvP modificada. Sem alteração de modelos/meshes/Terrain em Edit.

Resultados e limites:

- 13 eventos, sete mecanismos, travessias/co-op e ruídos ligados à IA existente; cenário temporário em runtime.
- Check atual ALL GREEN/330 testes puros, zero erros/warnings de lint.
- Studio nativo isolado, PlaceId0 e NotSynced: 56 verificações solo e 73 com três clientes em versões intermediárias.
- Rodada posterior encontrou janela obstruída por StairFacade e HUD móvel sobreposto. Duas correções locais aguardam atualização/reteste; runner engine e regressões finais também pendentes. Não considerar QA final aprovado.
- MCP bloqueia edição com `MCP tool call requires approval, but approval policy is never`. Humano autorizou todas as ações apenas para Roblox_Studio; configuração salva, sessão ainda não recarregou.
- Patch de preparação SHA256 `8007c9886765998d4ec66e7b7c5f9ff61559b75fc38219914640a362afcc2225`; aplicação/reversão conferidas contra base/local.
- Entrega local em `C:/Users/Gabriel/Documents/Codex/2026-10-17/con/outputs/Mansao_Dinamica/Entrega_Local/LEIA.md` (caminho não portátil); sem build nativa final nem aplicação compartilhada.

Solicito reconciliação e aplicação pelo vínculo existente somente após QA final. Construtor nativo atual limita a 250 fontes; novos módulos levam a 257. Preservar chunks de assets/mundo, não substituir por build Rojo simples. Sem publicação ou push do projeto principal.

## Histórico inicial — superado pelo estado acima

- Frente: mansão dinâmica solicitada pelo humano, sem recriar mapa/progressão/PvP.
- Raiz local: `C:/Users/Gabriel/Documents/Codex/RobloxProjetos/tungtung-dinamica`.
- Branch: `codex/mansao-dinamica`; HEAD/base: `e23b6359e4128def6e6b96a343a817896875f90e`.
- Pacote integrado atual baixado deste canal; SHA-256 conferido com README. Cópia anterior `be49f7c` preservada em outra raiz e já superada pela base integrada.
- Estado: auditoria e implementação isolada. Nenhuma escrita no destino, nenhum Script Sync conectado por esta frente. MCP inicialmente sem Studio aberto; humano informou que abrirá tungtung.
- O integrador existente continua o único escritor de Script Sync. Não considero ausência de resposta como aceite de reserva.

## Reserva proposta, aguardando reconciliação

Novos módulos próprios: `Shared/Game/MansionConfig`, `Server/Mansion/*`, `Services/DynamicHouseService`, `Controllers/DynamicHouseController`, testes dedicados. Hooks mínimos previstos em Main de cada lado, Remotes, WorldService/CreatureService e interação/câmera/movimentação conforme auditoria. Lista exata será atualizada antes da entrega.

Não reservar/alterar schema8, dados/economia, menus/loja, floresta, salas privadas ou módulos competitivos. Não alterar modelos/terrain/meshes/propriedades em Edit; eventos de cenário serão limitados ao runtime, restauráveis e condicionados à segurança de rotas.

## Decisões e pendências

- Preparar mudanças em branch isolada, comparar contra base e testes antes da integração.
- Solicitar ao integrador aplicação do patch pelo seu vínculo atual; não editar fontes sincronizadas via MCP.
- Validar solo, multicliente, perseguição, restauração e desconexão na cópia de QA; validar destino só depois de integração combinada.
- Testes desta frente ainda não executados. Resultados antigos não são prova desta nova implementação.
