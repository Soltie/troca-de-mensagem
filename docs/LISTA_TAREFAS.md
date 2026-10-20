# Lista de tudo que falta fazer (20/10/2026)

Base: `docs/JOGO_COMPLETO.md`, `docs/ANOTACOES_20-10-2026.md`, `docs/AVALIACAO_GERAL_20-10-2026.md`.
Quem: **U** = usuário, **C** = código, **L** = level/roteiro, **A** = arte/animação, **K** = crítico.
Marque `[x]` ao terminar. Ordem = prioridade.

## 0. Decisões do usuário (destravam o resto)
- [ ] U — Regra do git: push no GitHub (`claude/design-environment`) ou bundle local? Escrever num lugar só.
- [ ] U — Lista da v1: o que entra no lançamento (sugestão: caps. 1–8 jogáveis e curtos, sem prólogo/coração/escolha final).
- [ ] U — Fotos antigas de domínio público na sala: sim ou não.
- [ ] U — Liberar a Yoshi como playtester (Gerenciar colaboradores → Jogar).
- [ ] U — Publicar a versão atual (Arquivo → Publicar no Roblox) quando quiser testar online.

## 1. Fechar o capítulo 1 em nota 9 (P0)
- [ ] K — Nota da jogada com a Visita do Tung; corrigir só o que ele apontar (máx. 2 rodadas).
- [x] C/L — Tábua Oca com pista: bilhete do Juca ou fita, sinal visual (pregos, serragem, fresta), legenda "toc… cheio / toc… OCO!".
- [x] C — Carta da biblioteca: reta ao lado do livro, texto novo "ELE NÃO NASCEU MAU. FOI A MÁQUINA. — C." numa fonte com acento, abrir grande na tela antes do "Objetivo concluído!".
- [x] C/A — Vulto com o modelo de verdade do Tung escurecido (sem olhos vermelhos); vale para o cap. 1 e o cap. 2.
- [x] C — Apagar os olhos que ainda brilham: vulto, buracos do túnel, cor "olhos no veio" da arte.
- [x] L — Cortar picos do cap. 1 (regra: no máx. 2 picos, 40 s de calma): menos vulto repetido; sopro longe da Visita.
- [ ] C — Conferir a câmera de 3 s da Porta que Troca olhando a cadeira.
- [x] C — Trocar os textos de lore velha do cap. 1 (título "01 · A CASA DE MADEIRA", carta).
- [ ] L — Acertar a Melodia do Corredor: 3 ou 4 teclas, no hall ou no corredor (docs divergem).
- [ ] U — Salvar o place e fazer o push no fim.

## 2. Antes do capítulo 2 (P1)
- [x] C — Desligar o sistema Mansão no Modo História inteiro (B6).
- [x] C — Lanterna: 1º F não liga depois que a bateria acaba (B4); dura ~3 min e recarrega só até 35% (B5).
- [x] C — Túnel do Tung: não mergulhar nos primeiros ~60 s de cada capítulo (ajuda o B2).
- [x] C — Folga "Relax" do Tung de 35 s → ~20 s, e atacar quem está a < 6 studs e à vista.
- [ ] C — Trazer PvP/Caçador e Mansão do place para o `src`; depois ligar o Rojo (`sync.project.json`) e mesclar o `MainMenuController`.
- [x] A/U — Importar os modelos prontos de `build/arte3d` (máquina, coração, cadeira, baú, piano, relógio, cofre, kit 018–022) com prova no escuro.
- [x] C — Puzzles seguindo o banco v2: cofre "perdoa o erro"; resposta não escrita num papel (livro "03:1_", placas do cofre).
- [x] C — Fonte pixel com acento ("NECESSÁRIOS", "BASTÃO", "NÃO") e "BÔNUS POR AJUDAR A EQUIPE" jogando sozinho (B7).

## 3. Capítulo 2 na história nova (P2, depois do 9 no cap. 1)
- [ ] L/C — Fusíveis da Família conferidos em jogo.
- [ ] L/C — Baú fujão do Juca com a chave (encurralar fechando portas).
- [ ] C — Armário Vivo: o Tung sai de um guarda-roupa na primeira perseguição.
- [ ] L/C — Estufa: vasos que olham + alavanca enterrada; Porta que Troca Sala de Máquinas → Estufa.
- [ ] C — Dona Cida cantarola a melodia (reforço para o piano); tamborzinho no Quarto Infantil.
- [ ] C — Tung inofensivo no cap. 2 (B3): acordar antes e chegar perto.
- [ ] A — Gavetas e caixas diferentes do cap. 1 (B9).
- [ ] K — Nota do cap. 2 (meta 4–5 min).

## 4. Capítulos 3 a 5 (P3)
- [ ] C — Cap. 3: folga no spawn (Tung fora da visão, 20–30 s, aviso de 1 s antes de capturar) (B2).
- [ ] C — Conferir em jogo os puzzles 1 (Sombra do Pêndulo), 2 (Relógio Pintado), 8 (Retrato que Olha).
- [ ] L/C — A Casa Fecha (estante fecha a escada) + Tung sai do guarda-roupa + fuga pelo túnel.
- [ ] C — Foto da culpa com o texto novo; escada do sótão com placa (B8).
- [ ] C — Cap. 4: conferir Dueto da Lia e Sussurro do Juca; Cego da Catacumba; raízes + serra + escada presa.
- [ ] C — Coração do Tum Tum como mecânica (passar, guardar, isca).
- [ ] C — Capturado vira móvel + 60 s + resgate com três batidas.
- [ ] C — Cap. 5: Ritmo da Sobrecarga; acordar a família no fogo; Porta que Troca no incêndio.
- [ ] A/C — Cenas: Sahur gigante, carro atolado.
- [ ] A — Piano, cofre, catacumba e capela com modelos (hoje blocos).
- [ ] C — Textos de lore velha dos caps. 3–5 ("sala ritualística", "artefato", "coração da casa", fitas 2–8).
- [ ] C/U — Conferir a escada do porão (o bot ficou preso em −22, 4, 13).
- [ ] K — Nota de cada capítulo.

## 5. Floresta e final (P4)
- [ ] L — Esticar caps. 6–8 para 4–5 min (hoje ~1 min): tarefas espalhadas, perigo no caminho.
- [ ] L/C — Cap. 6: Marcas que Mentem, Árvore-Mãe sussurra, esconde-esconde com o Tung, capturados da vila, pegadas, machadinha.
- [ ] L/C — Cap. 7: Sons da Margem conferido, raízes que prendem, toco falante, diário do Valdemar.
- [ ] L/C — Cap. 8: Valdemar na torre, defender o farol, **final com escolha** (devolver o coração ou fugir), conquista "Amigo de Volta".
- [ ] A — Torre, farol, van, jangada, cais, cabana, ponte, rádio com modelos; clarear trechos pretos.
- [ ] C — Textos sem "mansão" nos caps. 6–8; gancho final novo.
- [ ] C — Verificar agachar silencioso nas folhas.

## 6. Prólogo e acabamento (P5)
- [ ] L/A/C — Prólogo: esconde-esconde na Fonte, lanterna no Pátio do Relógio, cena da lamparina (Tum Tum pequeno, fim de tarde).
- [ ] C — "A casa aprende" (armário mais usado tranca, caminho mais usado range).
- [ ] C/A — Menu igual ao esboço: fundo preto, luz laranja única, sombra, serragem, botões sem caixa, painéis na paleta.
- [ ] A/U — Ícones v3 (upload) e badges oficiais (o usuário cria no Creator Hub).
- [ ] A — Mão da lanterna com malha; móveis de busca e buracos do túnel com modelo.
- [ ] C — Luz: uma fonte prática acesa por cômodo; tirar o que estoura no feixe; placas de cômodo menores.
- [ ] L/C — Mais enigmas (`docs/IDEIAS_PUZZLES.md`): retratos que viram, batidas na parede, duas alavancas.

## 7. Testes com gente (antes de lançar)
- [ ] U — Jogar com teclado e mouse do começo ao fim.
- [ ] U — Jogar em dupla (coop nunca testado com 2+).
- [ ] U — Jogar no celular.
- [ ] K — Nota geral final (alvo ≥ 8).

## Depois (v2)
Corredor infinito; móvel que anda e enxerga pistas; manequins que andam com a luz; verniz, tocha, apito; jangada no
ritmo; TV de sintonia; casa dinâmica; A Mansão do Armadilho (próximo jogo).

## Feito em 20/10 (noite)
- Modelos `House_*`, `Basement_*`, capturados e `Shop_Uniform` subidos pela Open Cloud (`scripts/upload.ps1`, IDs em
  `assets_ids.md`) e carregados em `Assets.HouseArt` (35). Piano, relógio, cofre, máquina, coração, baú e quadro de luz
  já estavam lá. No jogo: baú e cômoda de busca (`HiddenStash`), banquinho e boné (`HouseMiniPuzzles.stools`), livro
  com carta (`HouseTaskProps`). Kit do porão, estantes, fogão, bancada, banheira, beliche, lustre, manequim, vitral e
  serragem estão importados mas **ainda sem lugar no mapa**.
- Mansão desligada no Modo História (`DynamicHouseService.active`, só no place).
- Lanterna: dura 7 min, recarrega até 75%; o 1º F volta a ligar depois de a pilha acabar.
- Vulto = o Tung de verdade escurecido (`MomentController`); olhos do túnel sem brilho.
- Carta reta na página do livro do artista, texto novo com acento, abre grande na tela.
- Tábua Oca: bilhete do Juca no chão, serragem e fresta na oca, legenda "OCO!" / "cheio".
- Túnel espera 60 s no início do capítulo; lembretes de presença no cap. 1: no máx. 2, a cada 80–120 s.
- Cofre perdoa o erro; título "01 · A CASA DE MADEIRA"; "BÔNUS POR AJUDAR" só com 2+ jogadores (place).
