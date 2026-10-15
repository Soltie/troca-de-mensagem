# ASSETS — origem, uso e licença

Princípio: **tudo que é visual é reconstruído a partir do repositório**. O mapa, os props, a luz, a
UI e o Vigia são gerados por código com primitivas (`Part`/`Wedge`/`Cylinder`). Não foi inserido
nenhum modelo de terceiros: nada de scripts externos para auditar. Nenhum asset foi comprado,
gerado com `generate_*` nem publicado.

Áudio é referenciado por ID (o arquivo fica na Roblox). Todos os IDs abaixo foram **verificados
carregando no Studio** com `ContentProvider:PreloadAsync` (status `Success`, duração > 0) em 2026-10-15.
O registro em código fica em `src/ReplicatedStorage/Shared/Game/Audio.luau`.

## Áudio (Creator Store, gratuito)

As bibliotecas **Pro Sound Effects** e **APM Music** são parceiras de licenciamento da Roblox.
Os áudios são públicos e gratuitos no Creator Store para uso em experiências Roblox
("Courtesy of Pro Sound Effects / APM Music" na descrição de cada um). Evitei uploads anônimos
de origem incerta.

| Chave (`Audio.luau`) | ID | Nome no Creator Store | Criador | Uso no jogo |
| --- | --- | --- | --- | --- |
| AmbExterior | 9112834179 | Neighborhood Ambience 4 (SFX) | ProSoundEffects | grilos/noite no pátio |
| AmbInterior | 9112839511 | Oil Refinery Ambience 2 (SFX) | ProSoundEffects | ronco grave dentro do prédio (tocado a 0,4×) |
| Music | 1837172508 | The Fear Within | APMOfficial | trilha de tensão depois que o Vigia acorda |
| Heartbeat | 9043365842 | HEARTBEAT 02 96BPM | APMOfficial | batimento por proximidade/perseguição |
| LampBuzz | 9112823813 | Light Bulb Buzz 2 (SFX) | ProSoundEffects | zumbido de 3 luminárias com energia |
| GeneratorHum | 9112889082 | Transformer Hum 1 (SFX) | ProSoundEffects | zumbido do quadro/gerador ligado |
| Growl | 9125469893 | Creature Growls Lion Deep Guttural Rumbling (SFX) | ProSoundEffects | rosnado ocasional do Vigia (3D) |
| Snarl | 9125475724 | Creature Vocal Spider Growl Belch Hiss Snarl (SFX) | ProSoundEffects | quando ele te vê |
| Roar | 9113980319 | Creature Mix Giant Crab Monster Roar Growl 1 (SFX) | ProSoundEffects | captura/jumpscare |
| ChaseLoop | 9113985466 | Creature Roar Constant Deep Throaty Growls 3 (SFX) | ProSoundEffects | loop 3D durante a perseguição |
| StingerAwaken | 1841353932 | Rising Fear Hit 2 | APMOfficial | o Vigia acorda |
| StingerCapture | 1846887425 | Evil Mind 9 | APMOfficial | derrota |
| StingerWin | 9042971851 | An Ending, A Beginning Sting | APMOfficial | vitória |
| Switch | 9119727134 | Switch Impact On Flip Up Large Metal 2 (SFX) | ProSoundEffects | quadro, energia, pegar fusível (agudo) |
| Flashlight | 9114479860 | Flashlight On Off Clicks 5 (SFX) | ProSoundEffects | lanterna |
| Door | 9114145921 | Door Long Squeaks On Close 2 (SFX) | ProSoundEffects | portas; portão (grave, 0,55×) |

## Áudio embutido no cliente Roblox (sem upload)

| Chave | Caminho | Uso |
| --- | --- | --- |
| CreatureStep | `rbxasset://sounds/action_jump_land.mp3` | passo pesado do Vigia (0,42×), sincronizado com as poses |
| UiBlip | `rbxasset://sounds/volume_slider.ogg` | bilhetes / recusa |
| (padrão do Roblox) | sons de passos do personagem | passos do jogador |

## Fontes (embutidas no Roblox)

- `Enum.Font.Arcade`: UI e placas. A fonte só tem as maiúsculas acentuadas Ã e Ç (testado), por isso
  os textos passam por `Shared/Game/PixelText.luau`.
- `Enum.Font.SpecialElite`: bilhetes e quadro de avisos (máquina de escrever, acentuação completa).
- `Enum.Font.PermanentMarker`: pichação "ELE SEGUE A LUZ".

## Rosto do Ademir / Vigia (fornecido pelo humano)

- Pedido do humano, implementado por **outra sessão de agente** em 2026-10-15 e preservado aqui.
- `src/ReplicatedStorage/Client/Creature/AdemirFaceData.luau`: pixels RGBA 128×128 em Base64, gerados
  a partir de `assets/ademir/face-128.png` (`assets/ademir/bake.py`, Python + Pillow).
- Exibido via `EditableImage` local (sem upload, sem ID de asset, sem HTTP). Há fallback para o
  rosto geométrico se a API não estiver disponível.
- Detalhes, reconstrução e validação: `assets/ademir/README.md` e `docs/ADEMIR_APPEARANCE.md`.
- **Antes de publicar:** a foto é de uma pessoa real. Confirme o consentimento dela e as permissões
  de `EditableImage` em experiências publicadas (exige habilitação específica, segundo a doc da Roblox).

## Não usados (decisão)

- **Modelos do Creator Store (`insert_asset`)**: cada um traria estilo próprio (incoerente com o low
  poly da paleta curta) e viveria só na place, não no disco. Primitivas resolveram melhor.
- **`generate_*`**: produziria assets enviados à conta e de estilo imprevisível. Não foi necessário.
- **Texturas de imagem**: o "PS1" vem de cor por vértice (cor sólida por peça), xadrez de pisos,
  névoa e luz. Não há pixelização de render no Roblox (ver DECISIONS).
