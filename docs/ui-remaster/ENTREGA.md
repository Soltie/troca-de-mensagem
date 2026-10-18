# Entrega — Remaster de UI/UX do Tung Tung Sahur

17/10/2026 · branch `design/ui-remaster` (a partir de `codex/tung-tung-sahur` @ `7a7f4ca`) · nada publicado, nada enviado por push.

## 1. Onde está

| Item | Local |
|---|---|
| Código | `C:\Projetos\tung-tung-sahur`, branch `design/ui-remaster` (6 commits) |
| Build para testar | `build/TungTung_UI_REMASTER_FINAL.rbxlx` (gerada por `lune run scripts/build`; pasta `build/` é ignorada pelo Git) |
| Auditoria | [AUDITORIA.md](AUDITORIA.md) |
| QA por fase, com status e evidências | [QA.md](QA.md) |
| Capturas antes/depois | `docs/evidence/ui-remaster/` (antes = as 6 imagens de `REFERENCIAS/` do briefing) |
| Ideias não implementadas | [OPORTUNIDADES_FUTURAS.md](OPORTUNIDADES_FUTURAS.md) |

## 2. Telas prontas vs. pendentes

| Tela | Estado |
|---|---|
| Menu principal / lobby (barra de perfil e moedas, trilho com ícones, 4+MAIS no celular) | PRONTA, testada PC/celular/tablet |
| Jogar: campanhas ilustradas, 8 capítulos, votação, equipe, mochila | PRONTA, voto testado até iniciar a partida |
| Loja: grade com miniaturas reais, detalhe com 3D girável, comprar/equipar com confirmação | PRONTA, compra e equipar testados |
| Melhorias e consumíveis (níveis, efeito atual/próximo, mochila separada da compra) | PRONTA, compra e mochila testadas por clique real |
| Passe de temporada (trilha horizontal grátis/paga com arte real) | PRONTA |
| Diário (7 dias) | PRONTA, resgate testado |
| Roleta (roda real, fatias = chance real, resultado do servidor) | PRONTA, 3 giros conferidos com o prêmio do servidor |
| Baús (barra de chances, confirmação, rolo) | PRONTA, abertura testada |
| Coleção (marcos com recompensa real) | PRONTA; estado "fita encontrada" sem captura |
| Créditos (Robux) | PRONTA; produtos sem ID ficam desativados ao vivo |
| Servidores / Amigos | PRONTAS; listas reais só no jogo publicado |
| Ajustes (seções, estado por texto e cor, volumes) | PRONTA |
| HUD de partida | HARMONIZADO (mesma informação e posições; ícones próprios) |
| Derrota (recomeço grátis com contagem) | PRONTA |
| Tela final do protótipo solo (`GameUiController.Finale`) | FORA DO ESCOPO: a campanha não a usa |
| Loading / tutorial contextual | NÃO FEITO nesta entrega (a abertura cinematográfica existente cobre o início) |

## 3. Figma e Hyper3D

Não usados: nenhum conector ou app desses serviços estava disponível nesta sessão. Toda a arte é **gerada por código**:
32 pictogramas pixel-art 12×12 (`Client/UI/Icons.luau`), miniaturas e modelos 3D dos itens montados a partir das
cores e materiais do `StoreCatalog` (`Client/UI/ItemPreview.luau`), cartões de campanha e roleta desenhados com
frames. Por isso **não há nenhum asset ID novo** para publicar ou autorizar.

## 4. Arquivos alterados e prova de que economia e dados não mudaram

`git diff --stat 7a7f4ca..HEAD -- src` toca 18 arquivos, todos de **interface do cliente**, um módulo puro de
apresentação (`Shared/Game/StoreView.luau`), textos e testes.
`git diff --name-only 7a7f4ca..HEAD` sobre `ServerScriptService/Server`, `StoreCatalog`, `Economy`, `Perks`,
`Season`, `SeasonCatalog`, `StoryRewards`, `Shared/Net`, `Config` e `Types` retorna **vazio**: preços, XP,
chances, recompensas, produtos, remotes, DataStore e regras de capítulo estão intactos.

Mudança de texto global: `Text.luau` deixou de remover acentos de toda a interface. Isso só existia para a antiga
fonte Arcade, que hoje aparece apenas em placas do cenário; essas continuam normalizando no próprio builder.

## 5. Verificação

- `lune run scripts/check`: ALL GREEN, 297 testes puros (eram 283; +14 novos: `MenuUi`, `StoreView`).
- Runner do Studio na build final: **309 aprovados, 0 falhas, 0 pulados**. Console do cliente limpo.
- Telas exercitadas no Studio com o MCP, em PC (1094×674) e celular/tablet simulados (`MenuViewportQA`).
- Desempenho medido (instâncias da UI): menu 790; loja 1.302; diário+roleta 873; temporada 1.276
  (antes da otimização sob demanda: 3.141 e 179 ms → 63 ms).

## 6. O que ainda depende de você

1. **Testar num celular de verdade** (toque, legibilidade, áreas seguras). A simulação do Studio não substitui o aparelho.
2. **Criar os Developer Products / Game Passes** no Creator Hub e colar os IDs em `StoreCatalog.Products`. Hoje todos
   têm `id = 0`: ao vivo, botões de Robux ficam desativados ("AINDA NÃO ESTÁ À VENDA") e ofertas no menu ficam ocultas.
3. Testar com 2–6 pessoas (equipe, votos, resgate) e uma partida completa com o Tung Tung ativo.
4. Revisar e aprovar a remaster; depois juntar o branch `design/ui-remaster` ao principal.

## 7. Como publicar (só quando você aprovar)

```powershell
cd C:\Projetos\tung-tung-sahur
git switch codex/tung-tung-sahur
git merge design/ui-remaster
lune run scripts/check
lune run scripts/build
```

Abra `build/Test.rbxlx` no Studio, confira e use **File → Publish to Roblox** na sua experiência. Nada disso foi
feito por esta entrega.
