# Coordenação — Tung Tung Sahur

Repositório autorizado pelo humano para trocar fontes, documentação e mensagens entre os agentes.

## Estado

- Destino: experiência **tungtung**, PlaceId **82955516040017**, UniverseId **10771638828**.
- Preservar a versão atual do destino, incluindo **Midnight Hunt**, filas e salas privadas.
- Nossa referência: `codex/forest-tumtum-export`, commit `08f697cf557fc9851d4844bb7121e1283742448c`.
- **A integração no destino ainda está em andamento.** A referência entregue não comprova que o lugar compartilhado foi atualizado.

Leia [o estado do integrador](agentes/codex-integrador.md), [a mensagem inicial](mensagens/2026-10-18-001-codex.md) e [o prompt do parceiro](PROMPT_PARCEIRO.md).

## Fontes recebidas

`entregas/Sahur_PROJETO_COMPLETO_2026-10-18.zip` contém código, build abrível, assets versionados, ferramentas, evidências e bundle Git da nossa referência.

SHA-256: `10B58D7A21FC724F2B9ECBD325772DA2404F740A1C88BCF5046DF9954866E514`.

Extraia em uma pasta separada e leia `LEIA_PRIMEIRO.md`, `MANIFEST.json` e `projeto/docs/INTEGRACAO_FLORESTA_TUMTUM.md`. O pacote não deve substituir o projeto receptor inteiro.

## Protocolo

1. Cada agente mantém seu próprio arquivo em `agentes/`, com identificador, raiz/branch/HEAD, estado, reservas, decisões, testes e pendências. Caminhos locais não são caminhos portáveis.
2. Mensagens em `mensagens/` recebem nomes únicos com data, sequência e autor. Respostas citam a mensagem original. Não apagar nem reescrever mensagens de outro agente.
3. Antes de alterar arquivos compartilhados, consultar mensagens e reservas. Ausência de resposta não significa reserva aceita. Mudanças podem ser preparadas isoladamente.
4. **Um único integrador de Script Sync por place.** Proposta atual: Codex deste PC faz a consolidação final; aguarda identificação das reservas do parceiro antes de conectar qualquer raiz.
5. Fazer fetch e reconciliar o histórico antes de cada push. Nunca force push. Não enviar credenciais, sessões privadas ou dados pessoais.
6. Push neste repositório de coordenação foi autorizado pelo humano. Isso não autoriza push no repositório principal, publicação no Roblox ou mudança de dados live.
7. Registrar evidência por versão. Testes do pacote de referência não validam automaticamente a integração final.

## Preservação

Backup completo antes de integrar. Não usar reset/clean nem substituir `src/` inteiro. Script Sync leva scripts e pastas; mapa, modelos, Terrain e propriedades precisam ser preservados separadamente. Não editar scripts sincronizados dentro do Studio.
