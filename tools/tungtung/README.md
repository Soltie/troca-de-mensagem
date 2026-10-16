# Tung Tung — modelo e animações

Origem: `tung tung-20261016T193115Z-1-001.zip` (raiz do repositório principal, não versionado).
Contém a malha (OBJ + texturas PBR 2048²) e seis FBX do Mixamo com o mesmo esqueleto (33 ossos).

## O que está no jogo

| Arquivo | Conteúdo |
| --- | --- |
| `src/ReplicatedStorage/Assets/TungTung.rbxm` | Modelo importado no Studio (malha com esqueleto, 28 ossos, SurfaceAppearance) |
| `src/ReplicatedStorage/Client/Creature/TungTungClips.luau` | Animações convertidas (gerado, não editar) |
| `src/ReplicatedStorage/Client/Creature/ClipCodec.luau` | Decodificação pura dos clipes |
| `src/ReplicatedStorage/Client/Creature/TungTungRig.luau` | Clona o modelo e escreve `Bone.Transform` a cada quadro |

Assets enviados para a conta do dono (importador 3D + upload de imagens, 16/10/2026):

- Malha com esqueleto: `rbxassetid://111005002149644` (escala 4,2: 8,0 × 7,46 × 3,37 studs)
- Cor `rbxassetid://71421127786076`, normal `rbxassetid://88828750077938`,
  rugosidade `rbxassetid://124558417113945`, metal `rbxassetid://123416759825160`

As animações **não** são assets do Roblox: o `bake.js` lê as curvas do FBX e grava o delta de cada osso
em relação à pose de ligação, já no espaço do importador (rotação de 180° em Y e escala 4,2).
Por isso não há upload de animação nem dependência de permissões de Animation.

## Regerar os clipes

```bash
node tools/tungtung/bake.js "<pasta>/Zombie Walk.fbx" tools/tungtung/bones.json \
  src/ReplicatedStorage/Client/Creature/TungTungClips.luau \
  "walk=<pasta>/Zombie Walk.fbx" "run=<pasta>/Standing Run Forward.fbx" \
  "slash=<pasta>/Great Sword Slash.fbx" "strafe=<pasta>/Great Sword Strafe.fbx" \
  "sheath=<pasta>/Sheath A Great Sword 2.fbx"
```

`bones.json` guarda o `Bone.CFrame` de cada osso lido no Studio depois da importação; o script compara
a pose de ligação convertida com esses valores e aborta se a diferença passar de 0,01.
Clipes em laço (`walk`, `run`, `strafe`) têm o deslocamento do quadril removido (andam no lugar);
o deslocamento real vem da `Root` do servidor.

`Unarmed Turn Left 90.fbx` ficou de fora: veio de um esqueleto com proporções diferentes e deformava o corpo.

## Uso no jogo

`CreatureVisualController` escolhe o clipe pelo estado e pela velocidade da `Root`:
parado = guarda com respiração, andando = `walk` (até 3,2x), acima de 5 studs/s = `run`,
busca parada = `strafe`, captura/pancada em porta/início da perseguição = `slash`.
Sem `Assets.TungTung` na place (place antiga ou Script Sync sem o rbxm), volta ao boneco low poly.
