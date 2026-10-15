# Ademir — aparência baseada na foto

Implementado em 2026-10-15, durante o desenvolvimento do protótipo pelo Claude Code.

## Resultado

O Vigia/Ademir usa o rosto derivado da foto fornecida pelo humano, na frente da cabeça 3D e
nos dois quadros da tela de susto. A textura foi tratada por imagegen para retirar a interface
da chamada e tornar o rosto legível. Cores da roupa, pele e cabeça acompanham a referência.
IA, captura, rede e animação permanecem na implementação existente.

O código usa um único EditableImage de 128 × 128 compartilhado pelas três imagens. Os pixels
ficam no repositório; não houve upload nem publicação da foto. O rosto geométrico anterior
serve como fallback se a API estiver indisponível.

Arquivos e reconstrução: [assets/ademir/README.md](../assets/ademir/README.md).

## Validação

Para preservar o Play em andamento em `Dev.rbxlx`, foi criado um build descartável com
`rojo build default.project.json --output build/AdemirPreview.rbxlx`, aberto em outra instância
do Studio. Não foi iniciada nenhuma sincronização adicional e não foi usado `rojo serve`.

- `lune run scripts/check`: **ALL GREEN**; 73 testes puros, zero falhas.
- Testes do Studio: **79 passed, 0 failed, 0 skipped specs**.
- Criatura ativada no ambiente de prévia: cabeça com atributo `Appearance = AdemirPhoto`,
  textura presente e olhos/boca geométricos ocultos.
- SurfaceGui com `AlwaysOnTop = false`, respeitando a oclusão pelo mundo.
- Cabeça e os dois quadros do susto referenciam o mesmo EditableImage de 128 × 128.
- Rodada reiniciada: aparência preservada após a ativação replicar; susto ocultado corretamente.
- Console do cliente: nenhum erro ou warning inesperado do projeto. O aviso conhecido de
  `FoundationProvider` vem dos CorePackages da Roblox. A observação de API depreciada de
  `RoundService.LoadCharacter` já existia antes da alteração de aparência.
- Capturas conferidas visualmente: [no corredor](evidence/ademir/in-game.png) e
  [tela de susto](evidence/ademir/scare.png).

A criatura foi congelada e a câmera posicionada por ferramentas de depuração apenas nessa
prévia para conferir o visual. A tela de susto também foi exibida diretamente para inspeção.
Estas capturas verificam aparência; não são evidência de uma rodada completa jogada.
O Play da prévia foi parado ao final. A sessão original do Claude em `Dev.rbxlx` foi preservada.

## Continuidade

A integração está em `Client/Creature/Rig.luau` e `Client/Controllers/GameUiController.luau`.
As chamadas a `AdemirPortrait` devem ser preservadas nas próximas alterações desses arquivos.
Um Play já em andamento conserva os módulos antigos: iniciar um novo Play para carregar o novo rosto.

Antes de uma futura publicação, conferir o requisito de habilitação da API descrito no README do asset.
Nenhuma configuração de publicação foi alterada nesta tarefa.
