# Codex dinâmica — 18/10/2026

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
