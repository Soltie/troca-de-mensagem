# Contexto operacional para a IA — Tung Tung Sahur

Preparado em 17/10/2026 a partir do repositório independente **tung-tung-sahur**, branch **codex/tung-tung-sahur**. Destinatário: IA de outro desenvolvedor. Este pacote transfere conhecimento e fontes; não transfere uma sessão de IA nem instala/conecta o Studio do outro PC.

## Ordem de leitura

1. [Entrada e prompt](../../LEIA_IA_COLEGA.md) e [AGENTS.md](../../AGENTS.md).
2. [01 — Roblox, ferramentas, Script Sync e MCP](01_ROBLOX_E_MCP.md).
3. [02 — arquitetura, services e controllers](02_ARQUITETURA.md).
4. [03 — sentido e módulos deste projeto](03_PROJETO_ATUAL.md).
5. [04 — remotes, eventos, atributos e listeners](04_REDE_E_LISTENERS.md).
6. [05 — compartilhar, GitHub, bundle, branches e integrador](05_COLABORACAO_E_ENVIO.md).
7. [06 — QA, receitas de extensão e diagnóstico](06_VALIDACAO_E_RECEITAS.md).
8. [07 — inventário de funções/dependências/listeners por fonte](07_INVENTARIO.md), consultado sob demanda; [JSON](CODE_MAP.json) para busca estruturada.

## Identidade e precedência

Este é **Tung Tung Sahur**, não Subestação 9. Config atual: 1–6 jogadores, schema 6, StudioMode=mock, 16 services e 34 controllers. Ler os Main para confirmar a ordem.

O pedido atual do responsável e AGENTS.md têm precedência operacional. Para entender implementação: fonte deste clone + Config + HEAD/diff atual; depois este pacote e o [relatório da versão](../FLORESTA_TERROR_FINAL.md). Documentos antigos do template/roblox-teste descrevem decisões históricas; caminhos, reservas, Studio IDs, números de QA e acessos externos precisam ser revalidados.

Os projetos foram separados e estão sem remote configurado no momento desta preparação. Não presumir que o antigo GitHub roblox-teste contém este HEAD. Não reutilizar o src/ do outro jogo nem sincronizar ambos na mesma place.

## O que está comprovado

O índice usa hashes de todas as fontes; listas de functions/requires/listeners são extração lexical, não prova de execução. Os checks locais deste pacote são registrados em [VALIDACAO_LOCAL.json](VALIDACAO_LOCAL.json). QA de engine anterior fica nos relatórios de versão; este trabalho documental não iniciou nem alterou Play de outras sessões.

A IA receptora deve verificar localmente instalação, MCP, sync/build, permissões de assets e acesso GitHub/Roblox. Não existe prova remota de que o PC do colega está pronto antes dessa verificação.
