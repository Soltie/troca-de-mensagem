# Mansão dinâmica — aplicada no tungtung

Place82955516040017. Branch `codex/mansao-dinamica`, HEAD `2433045`.
A cópia local reúne a dinâmica com a reforma3D do Claude, preservando chuva,
materiais, modelos, Midnight Hunt, floresta, loja e schema8. Sem publicação Roblox.

Foram implementados 13 eventos e sete mecanismos: falhas/queda de portas,
obstáculos, piso quebrável, janela, apagão, móveis reativos, gaveta, válvula,
gerador, alavanca, empurrão cooperativo, passagem agachada e salto de móveis.
O servidor valida os pedidos, aplica limites, sincroniza e restaura o cenário.

PC: E interage/confirma/cancela, Q segura uma porta normal, Espaço atravessa
obstáculos mirados e C agacha. No celular há interação e botões contextuais.
Para jogar, use Testar no Studio e escolha a campanha.

Validação final: 335 testes locais, 347 no runner do Studio; QA na place remodelada com três jogadores
passou78 verificações. Midnight Hunt completo com três jogadores passou72,
incluindo fuga, recompensas idempotentes, limpeza e retorno à História. Janela adapta o salto à altura do jardim; NoiseLure move
e restaura os modelos3D novos. Emulação iPhone17Pro/750x381 conferida em qualidade baixa.
Evidências também registram solo69, multi76, runner342 antes
da conciliação visual final; não são resultados reexecutados dessa última versão.
A campanha completou147 verificações funcionais, incluindo oito capítulos,
final, lobby e nova votação; o teste de console reprovou só pelo asset antigo
81504106 indisponível. A perseguição com criatura ativa teve movimento normal,
mas não substitui avaliação humana de equilíbrio ou teste em celular físico.

Mansao_Dinamica.patch contém15 fontes: dinâmica e correção de compatibilidade da saída PvP, sobre a base visual
`ee2fce7` já aplicada. Compare HEAD/diffs antes de aplicar. O bundle reúne
histórico recuperável desde e23b635; não fazer push no projeto principal.
O marcador de fuga principal acompanha a altura real do Terrain para manter a
interação desobstruída; alcance e visibilidade continuam validados no servidor.
As265 fontes locais foram comparadas por SHA256 com a place. Não conectar
Script Sync de uma árvore antiga; assets/MaterialService não passam pelo Sync.

MANIFEST.json contém hashes das fontes, evidências e backup. O arquivo em
backup/ é a place ANTERIOR às mudanças e à reforma3D paralela, para recuperação;
não é uma build atual. A versão atual está no Studio compartilhado e no histórico.
