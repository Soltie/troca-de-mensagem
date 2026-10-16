# Polish de iluminação e pós-processamento — 16/10/2026

> Correção posterior de build: o Studio ignorava o preset novo ao migrar uma place sem Technology
> explícita. Os dois projetos agora incluem Technology=Future junto de Realistic/true.
> Roundtrip e execução confirmados em [BUILD_AUDIT.md](BUILD_AUDIT.md).

Tratamento implementado sobre `b01d4fb`: noite fria, iluminação de emergência vermelha e luzes
internas com leitura mais clara. Sombras voltam a definir volumes. O bloom, a vinheta e a
granulação pesam menos na imagem. Materiais, texturas, modelos, planta e regras permanecem
os mesmos. O menu inicial pertence à frente do Claude e não entra neste commit.

## Implementação

- `LightingProfile`: parâmetros e cálculos puros de cor, exposição, adaptação, névoa,
  falhas de luz e seleção de sombras.
- `LightingController`: único compositor de gradação artística, exposição e névoa local.
  Consulta cobertura acima da câmera a cada 0,35 s e interpola interior/exterior e energia.
  `S9SceneGrade` é a camada artística; `RetroGrade` continua sendo o filtro cosmético.
  O filtro padrão é neutro sobre a nova direção. Filtros equipados continuam funcionando.
- `WorldService`: luz ambiente fria, reflexos discretos, névoa base de 142/164 studs e
  sombras globais. Energia e lâmpadas continuam sendo decididas pelo servidor.
- `Build`: só a propriedade CastShadow de peças opacas com colisão mudou.
  Peças decorativas sem colisão e peças transparentes não passam a projetar sombras.
- `WorldFxController`: cache de luminárias e até duas sombras de luzes próximas, reavaliadas
  a cada 0,5 s. Qualidade gráfica explícita 1–3 desliga essas sombras locais; automático
  mantém o orçamento. Lanternas dos colegas continuam sem sombras.
- Lanterna própria: feixe de 42°, brilho base 2,25 e sombras; luz de preenchimento menor.
  Alcance e regras de bateria permanecem iguais nesta frente.
- Bloom: intensidade 0,19, tamanho 14 e limiar 1,65. DOF distante de 0,07 apenas durante
  cenas com movimento habilitado; jogo normal fica sem DOF.
- VHS: scanlines de transparência 0,91, 48 pontos de granulação e vinheta mais estreita.
  Blur máximo de pânico 3,5; névoa de perigo converge para 64 studs e depois recupera a base.
  Desativar flashes estabiliza as luminárias e desativa clarões; V continua controlando o overlay.

O preset `LightingStyle=Realistic` / `PrioritizeLightingQuality=true` está nos dois arquivos
de projeto. A place Dev já aberta recebeu essas duas propriedades em Edit para o QA local.
Script Sync transporta scripts; uma place existente precisa conservar também o preset de Lighting.
Os builds gerados pelos projetos já o incluem. Nenhuma place publicada foi alterada.

## Validação

- Cópia isolada `.cache/lighting-polish/candidate`: ALL GREEN, **213 testes puros**, zero
  falhas, quatro specs exclusivas do Roblox puladas no Lune. Inclui cinco testes novos.
- Check integrado durante a edição paralela: ALL GREEN, **234 testes puros**, zero falhas.
- Studio Dev final: **257 aprovados, zero falhas, nenhuma spec pulada**. Contagem inclui a frente
  paralela presente naquele momento; não significa que ela faz parte deste commit.
  A revisão de menu `7a69977` já estava no HEAD nessa execução; a anterior passou com 255 testes.
- Script Sync confirmado lendo Source do controller e do perfil em Edit.
- O build final isolado foi gerado. Sua nova instância de Studio ficou na tela de login e não
  executou QA; o teste de engine reportado acima é do Dev já autenticado, não desse build isolado.
- VM real do cliente: interior converge a 1; exposição 0,16 sem energia e 0,10 com energia;
  névoa 142/164; DOF zero fora da cena. Energia foi alternada pelo DebugBridge do servidor.
- Com 53 luminárias e energia ligada, só duas tinham Shadows=true, próximas à câmera.
- Conforto: 52 luminárias comuns com brilho-base estável, zero divergências. A sirene é
  verificada separadamente porque desligada tem brilho zero, não o brilho-base.
- Equipar sépia mudou RetroGrade para contraste 0,18 e preservou S9SceneGrade em 0,10.
  Voltar ao padrão restaurou RetroGrade a branco/contraste zero.
- Sonda final após o ajuste de captura: CFTV desligado, DOF zero; lanterna própria habilitada
  com Shadows=true, brilho 2,25, alcance 48 e ângulo 42°.
- Medo/pânico na VM real, com ameaça/estado preparados só no cliente durante QA: amostra de
  névoa 66,38 e blur 2,83; após remover a ameaça e sair da apresentação Playing, névoa voltou
  a 141,99997 (base 142) e blur zero. Registro completo em `fog-runtime.json`.
- Console: nenhum erro de execução dos controllers de iluminação. Apareceram avisos já
  externos ao escopo: UIBlox/FoundationProvider, falha de download de mesh/animação de avatar
  e consulta de política de monetização indisponível no Studio. Não são uma execução limpa
  de todos os serviços externos.

Não houve medição representativa de FPS em celular/PC fraco nem avaliação com jogadores humanos.
O limite de luzes é um controle de custo, não uma promessa de desempenho medido.

## Capturas e reprodução

Originais em [evidence/lighting-polish](evidence/lighting-polish). Antes: build de `b01d4fb`.
Depois: Dev com o código de iluminação sincronizado e alterações paralelas ainda não commitadas.
Posições e FOV 65 são iguais; a proporção da viewport difere, então não é comparação pixel a pixel.
HUD/menu foram ocultados e o CFTV desativado em runtime para avaliar o cenário.
A imagem com energia ligada usa setup local das mesmas luzes e valores do perfil; a chamada
real de WorldService.setPower foi verificada separadamente, antes de reiniciar o Play.
A imagem da lanterna/VHS usa apresentação Playing preparada localmente para mostrar a mão
e o overlay, sem iniciar uma partida cooperativa nem provar comportamento da IA no servidor.

| Cenário | Antes | Depois |
| --- | --- | --- |
| Pátio | [antes](evidence/lighting-polish/before-exterior.png) | [depois](evidence/lighting-polish/after-exterior.png) |
| Recepção sem energia | [antes](evidence/lighting-polish/before-reception.png) | [depois](evidence/lighting-polish/after-reception.png) |
| Recepção com energia | — | [depois](evidence/lighting-polish/after-powered-reception.png) |
| Lanterna e VHS | — | [depois](evidence/lighting-polish/after-flashlight-vhs.png) |

Após `lune run scripts/check`, iniciar Play. A sonda só existe no Studio:

```lua
-- Client: câmera de comparação; oculta UI e remove o tratamento CFTV do lobby.
local probe = game.Players.LocalPlayer.PlayerGui.LightingQA.Probe
probe:Invoke("camera", Vector3.new(-4, 4, -8), Vector3.new(-4, 3, -22))
-- Pátio: Vector3.new(2, 4, 30), Vector3.new(-8, 4, -8)
return probe:Invoke("state")
-- Ao terminar: probe:Invoke("release") e parar Play.
```

```lua
-- Server: energia real na VM do WorldService (ponte somente no Studio).
return game.ServerStorage.DebugBridge:Invoke("lightingPower", true)
```

O MCP pode deixar o viewport focado no servidor depois do runner/chamadas Server; nesse estado
a captura falhou com `missing field data`. Para captura, usar o viewport Client e passar posições
explicitamente a screen_capture. A sonda não existe fora do Studio e o Play é encerrado após QA.

APIs conferidas na documentação oficial de [pós-processamento](https://create.roblox.com/docs/environment/post-processing-effects),
[Lighting](https://create.roblox.com/docs/reference/engine/classes/Lighting) e
[modos de teste](https://create.roblox.com/docs/studio/testing-modes).
