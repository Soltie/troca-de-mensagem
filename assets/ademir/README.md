# Ademir — rosto da referência do humano

Pedido de 2026-10-15: usar a imagem anexada como aparência do Ademir/O Vigia.

- `reference.png`: anexo original preservado, incluindo a moldura da chamada.
- `face-cutout.png`: recorte tratado com imagegen; remove moldura, nome, ícone de microfone,
  fundo e ombros; preserva o olhar, cabelo e expressão como referência.
- `face-128.png`: textura RGBA otimizada de 128 × 128 pixels, usada no jogo.
- `bake.py`: codifica os pixels da textura em `AdemirFaceData.luau` (Python + Pillow).

A textura é reconstruída uma única vez por cliente e compartilhada entre a cabeça e os dois
quadros do susto. São 65.536 bytes RGBA. Não há upload da foto, ID de asset ou acesso HTTP.
Nome e interface da chamada não aparecem na textura do jogo.

SHA-256 de `face-128.png`:
`a0fd4b25563853980275b42f24b73b0ccbdf665baab98211aa694251fdaf46cd`

## Integração

- `Client/Creature/AdemirPortrait.luau`: cria a textura e ajusta o visual do rig.
- `Client/Creature/Rig.luau`: chama `AdemirPortrait.applyToRig(parts, light)` durante o build.
- `Client/Controllers/GameUiController.luau`: usa `AdemirPortrait.createImage` em `buildFace`.

IA, colisão, captura, rede e taxas de animação permanecem no código existente.
O rosto geométrico original continua como fallback caso a API de imagem esteja indisponível.

## Reconstrução

Depois de alterar a textura otimizada, rode `python assets/ademir/bake.py`, com Pillow instalado,
e siga o ciclo normal de check/sync/playtest. A redução da saída do imagegen para 128 × 128 é
uma otimização do asset; a referência original fica preservada.

## Limite de publicação

Validar as permissões antes de publicar uma experiência: a Roblox documenta que EditableImage
requer habilitação específica em experiências publicadas. Nenhuma configuração de publicação,
conta ou Creator Hub foi alterada para esta tarefa.

Fonte técnica: [EditableImage — documentação Roblox](https://create.roblox.com/docs/reference/engine/classes/EditableImage).
