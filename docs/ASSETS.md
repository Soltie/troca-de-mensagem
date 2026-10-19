# ASSETS — origem, uso e licença

**Atualização visual — 16/10/2026:** [VISUAL_POLISH.md](VISUAL_POLISH.md) registra a nova camada
de arte. Texturas originais de desgaste são geradas em `Shared/Game/SurfacePatterns.luau`,
cinco bitmaps RGBA de 32×32 (20 KiB) compartilhados localmente por cliente via EditableImage/Texture.
`ArtBuilder`/`Props` e `UniformDetails` acrescentam modelos de primitivas; o rosto original continua
preservado. Materiais Metal/Concrete/Wood e partículas embutidas da Roblox (`smoke_main.dds`,
`sparkles_main.dds`) completam a camada. Nenhum modelo/textura externo foi importado ou publicado.
As referências fotográficas foram apenas consultadas; nenhuma foi usada como asset.

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

### Áudios do polish de terror (acrescentados em 15–16/10/2026)

Verificação em 16/10/2026 no Studio (cliente em Play, `PreloadAsync` + Sound parentado):
**54/54 clipes de `Audio.luau` carregados com duração > 0**. Os passos usam só um trecho do arquivo
(`region` → `Sound.PlaybackRegion`). O início de cada golpe foi medido tocando a 0,25× e amostrando
`PlaybackLoudness`: concreto, madeira e metal começam em 0,01–0,02 s; a água tem o respingo em 0,49 s,
por isso o trecho dela é 0,47–0,82 s.

| Chave | ID | Nome no Creator Store | Criador | Uso no jogo |
| --- | --- | --- | --- | --- |
| WindInterior | 9125742262 | Plasma Trails Constant Airy Whooshing Windy (SFX) | ProSoundEffects | vento nas frestas (0,45×) |
| Machinery | 9118748093 | Rumble Constant Roar Energy Building 2 (SFX) | ProSoundEffects | máquinas com energia (0,6×) |
| Drips | 9120527007 | Water Drip Single Drops Into Tin Bucket 2 (SFX) | ProSoundEffects | goteiras 3D |
| CreakWood | 9114496002 | Floor Creaks Short Med Wood Creaks 19 (SFX) | ProSoundEffects | rangidos do prédio / assoalho |
| CreakMetal | 9116770610 | Metal Popping Constant Muffled Buckling 8 (SFX) | ProSoundEffects | estalos de metal |
| Whisper | 9043347008 | DISTURBED WHISPERS 02 | APMOfficial | sussurros com medo alto |
| RadioStatic | 9119974504 | Television Turn On And Off 1 (SFX) | ProSoundEffects | chiado do rádio do vigia |
| MusicTension | 1843867314 | Tension Repeat Drones 29 | APMOfficial | música de tensão |
| MusicChase | 1837843534 | Deliberate Pain (Fast Bass) | APMOfficial | música de perseguição |
| MusicRelief | 1843755486 | Mid-Tone Drone 51 | APMOfficial | calmaria pós-perseguição |
| StepConcrete | 9114523629 | Foot Stomp 7 (SFX) | ProSoundEffects | passo em concreto (trecho 0–0,3 s) |
| StepWood | 9120880067 | Wood Grab Muted Thuds 15 (SFX) | ProSoundEffects | passo em madeira; som de pegar item |
| StepMetal / KeyTurn / BreakerToggle | 9120102763 | Toggle Switch Metal Industrial Equipment 18 (SFX) | ProSoundEffects | passo em metal; tranca; disjuntor |
| StepWater | 9125701986 | Mud Puddle Splash Shallow Water Impacts Hit 13 (SFX) | ProSoundEffects | passo em poça (0,47–0,82 s) |
| Breath1–4 | 9114555699 / 9114555659 / 9114555843 / 9114556046 | Gasp Trouble Breathing 3 / 1 / 4 / 7 (SFX) | ProSoundEffects | respiração (ritmo pelo medo/exaustão) |
| Gasp | 9114556036 | Gasp Trouble Breathing 8 (SFX) | ProSoundEffects | fôlego acabou no armário |
| DoorBang | 9114432643 | Fire Door Frantic Knocks 2 (SFX) | ProSoundEffects | Vigia batendo na porta trancada |
| DoorRattle | 9117906668 | Prison Bars Rattle 3 (SFX) | ProSoundEffects | porta trancada chacoalhando |
| DoorLatch / LockerLatch | 9114435018 | Fire Door Latch Open And Close 9 (SFX) | ProSoundEffects | trinco de porta e de armário |
| BreakerFail | 9125550914 | Engine Abuse Metal Hits On Various Engine Parts 4 (SFX) | ProSoundEffects | disjuntor na ordem errada |
| Paper | 9114385821 | Fax Paper Flutter 13 (SFX) | ProSoundEffects | bilhetes |
| Fall_bucket / Fall_extinguisher | 9116502787 / 9116501934 | Metal 50 Gallon Drum (SFX) | ProSoundEffects | objetos que caem |
| Fall_cans / Fall_bottles | 9120188626 / 9120188618 | Toolbox Impact Wood Metal Hits Fall Crash 11 / 10 (SFX) | ProSoundEffects | objetos que caem |
| Fall_pipes | 9116886745 | Metal Tank Impact 3 (SFX) | ProSoundEffects | canos caindo |
| Fall_box | 9126090979 | Table Falls Impact On Concrete Various Versions 9 (SFX) | ProSoundEffects | caixa caindo |
| FireCrackle | 236387093 | Fireplace Crackle | Jontizm (Creator Store, grátis) | focos do incêndio final |
| AmbFireRoar | 2787093357 | forest fire | Festivereinhard2 (Creator Store, grátis) | rugido do incêndio final |
| BeamCrack | 9120819447 | Wood Crack Deep Clunky Scrapes Crackling 4 (SFX) | ProSoundEffects | viga em chamas caindo |
| WoodSplinter | 9126240449 | Wood Crack Thick Splintering Bursts Creaking 2 (SFX) | ProSoundEffects | madeira estalando no fogo |

Também do cliente Roblox: `StepFallback` (`rbxasset://sounds/action_footsteps_plastic.mp3`, trecho 0–0,26 s)
e `Land` (`action_jump_land.mp3`). Os passos padrão do personagem são silenciados pelo `BodyAudioController`.

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
- **Texturas de imagem externas:** continuam sem uso. A versão de 16/10 acrescenta as máscaras
  autorais de baixa resolução acima. Não há pixelização do render completo (ver DECISIONS).
