# Itens 6–9 — guarda-roupa, portas, sofá, lareira (e tapete, janela)

Feito pelo Claude em 19/10/2026 no candidato (`build/TungTung_BACKUP_ANTES_CODEX_20261019.rbl`). Modelos escolhidos pelo
usuário (Poly Haven ou feitos por ele no Hyper3D). Nada publicado.

| Peça | O que mudou | Onde |
| --- | --- | --- |
| Guarda-roupa do esconderijo | Modelo de 2 portas do usuário (Hyper3D). Prateleira do meio removida, portas separadas, ajustado ao volume do armário (5 × 9,2 × 3,5). Portas abrem para fora, presas na dobradiça (quina da frente), seguindo o ângulo da HideDoor com interpolação curta. Madeira escurecida de leve (`SurfaceAppearance.Color` 196,186,178). Som próprio: trinco + rangido ao abrir, batida + trinco ao fechar (trechos curtos dos arquivos PSE). | `HouseProps.wardrobeModel`, biblioteca `WardrobeDouble` (atributos `PivotIsFrontFloor`, `HingeX` = 2, `HingeZ` = −0,38) |
| Orientação do esconderijo | Armário inteiro (fresta, entrada, saída, frente) girado 90° para ficar de frente para a porta do cômodo, não de lado. Camas/baú (Bedroom, Child, Tunnel) não mudam. | `HouseBuilder` (bloco dos `hide_*`) |
| Portas internas | Porta do usuário (Hyper3D) como porta dupla: duas folhas de 4,5 × 11 no vão de 9. Folha A soldada ao painel; folha B gira espelhada na outra ombreira. Painel invisível, mas continua colisão, prompt, som e PathfindingModifier. | `HouseFinish.doubleDoor`, biblioteca `DoorLeaf` |
| Sofá | Sofa 03 (Poly Haven) 35% maior (`SOFA = 1.35`): na escala real o assento ficava abaixo do joelho do boneco. | `HouseProps` |
| Poltrona | Modern Arm Chair 01 (Poly Haven), estofada. | biblioteca `Armchair` |
| Lareira | Lareira refeita no Blender (geometria limpa). | biblioteca `Fireplace` |
| Tapete | Malha própria + tecido Dirty Carpet (Poly Haven, escolha do usuário): borda vinho, filetes, medalhão e franja. | biblioteca `PersianRug` |
| Móvel da TV | Bloco cinza vira o aparador 3D `Console`. | `HousePrimitiveFinish` |
| Janela oeste (z = 12) | O "quadrado branco": vidro bege a 0,3 parecia painel liso e metade dava para o reboco do bloco da escadaria. Vidro escuro quase transparente em todas as janelas desse tipo; na ala oeste a abertura ficou do tamanho da moldura externa (8,5) e ganhou moldura + cortinas (`WindowSet`). | `HouseBuilder`, `HouseScenery`, `HouseProps.common` |

## Testes

- `lune run scripts/check`: ALL GREEN (302 testes puros).
- Studio, candidato: `Tests.Run` 359/359 (inclui rotas e esconderijos), console sem erros do jogo.
- Sobreposição: os 17 guarda-roupas e os 2 sofás não cruzam outras peças.
- Portas: 20/20 com as duas folhas; abrir e fechar conferidos por captura.
- NÃO TESTADO: celular físico, partida multiplayer real.

Capturas em `docs/evidence/environment/{wardrobe,doors,sofa,rug,window}/`.
