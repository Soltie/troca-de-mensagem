# Item 4 — blocos visuais genéricos (Claude, 19/10/2026)

Começado pelo Codex (helper `HousePrimitiveFinish` + spec), concluído e integrado pelo Claude.

## O que mudou

| Bloco visto pelo humano | Causa | Solução |
| --- | --- | --- |
| Blocos cinza empilhados em cima da estante (Sala e outros cômodos) | `FacadeQuoin` (cunhais de pedra da fachada, `HouseExterior`) eram blocos maciços que atravessavam a parede de 1 stud e apareciam dentro da casa | Cada pedra virou duas placas finas por fora das duas faces da quina. Inventário: 0 pedras dentro da casa |
| Bloco cinza solto abaixo do teto de cada cômodo | `PowerLamp` (lâmpada elétrica do `HouseBuilder`) | Lustre pequeno (`Chandelier`) preso ao teto; a peça fica invisível e continua sendo a luz "Lamp" (acende com a energia: 20/20) |
| Bloquinho amarelo na parede | `Candle` dos cômodos (Furnishings) | Lamparina 3D com haste fina até o teto (do Codex); luz original intacta |
| Estantes de bloco no sótão | `Bookshelf` antigos (Furnishings) | Estante 3D (várias malhas) no mesmo volume, frente para o lado sem parede; bloco invisível com a colisão de sempre |
| Caixote liso marrom no chão (Sala, quarto, porão) e baú da Cozinha/Escritório/Símbolos | `HeavyCrate`/`Vault` do DynamicMansion (Codex-dinâmica) | Dois caixotes 3D empilhados (`HeavyCrate`) ou baú (`Vault`), soldados ao corpo; acompanham movimento e transparência; corpo intacto (tamanho, tags, atributos, colisão) |
| Suporte da campanha (`AntiquePedestal`) | — | Mesa baixa 3D no mesmo volume (do Codex) |

`render()` agora aceita modelos com várias malhas (estica cada uma pela mesma proporção por eixo).
Nada novo colide, recebe raycast ou toque. Sem downloads, uploads ou custos: só a biblioteca `MansionProps` existente.

## Fora do item 4

- Bloco vermelho no chão da Cozinha / caixote no corredor antes da "PASSAGEM SELADA": eram os caixotes do DynamicMansion
  (cobertos acima) e itens de missão. Os itens de missão (chave, fusível, lanterna, peças de tarefa) são do **item 5 (Codex)**.
- Lareira, grama, chuva, movimentação e efeitos de tela continuam no backlog.

## Validação

- `HousePrimitiveFinish`, spec e `HouseExterior`: StyLua, Selene e luau-lsp strict sem erros; `lune run scripts/test` 302.
  O `scripts/check` completo hoje falha só em `HouseTaskProps.luau` (arquivo reservado ao Codex, em edição pelo item 5).
- Candidato `TungTung_BACKUP_ANTES_CODEX_20261019.rbxl`: `Tests.Run` **354/354**, console sem erros do jogo.
- Destino `tungtung` (82955516040017), NotSynced, aplicação seletiva de 4 scripts (2 atualizados conferidos por soma de
  verificação contra o HEAD, 2 novos), numa gravação "Claude: item 4 - blocos visuais genericos": **354/354**, sem erros,
  6/6 corpos dinâmicos vestidos, 20/20 lâmpadas acendem com energia. 269 → 271 scripts. Nada publicado.
- Capturas (luz de trabalho temporária só no cliente de teste, a casa real continua escura): `docs/evidence/environment/item4/`.

NÃO TESTADO: interação humana com os caixotes empurráveis do DynamicMansion; evento FurnitureMove depois das colisões do
item 3 (alerta do handoff, não investigado nesta rodada); celular físico. Cópia nativa completa não foi baixada antes da
aplicação: a mudança é reversível pelas versões do HEAD (HouseProps/HouseExterior) e remoção dos 2 scripts novos.
