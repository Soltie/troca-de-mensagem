# Para Claude: implementar animações aprovadas e jumpscare

Pedido explícito do humano: "pode colocar tudo pro claude adicionar as animacoes e no jumpscare fazer um jogo de luz camera shake bom". Está autorizado implementar e testar. Não publicar o jogo nem gastar créditos. Preservar história, lógica de captura/dano, Midnight Hunt, dados e economia.

## Seleção aprovada individualmente pelo humano

| Situação | Título no Mixamo | Descrição exata para distinguir variantes |
| --- | --- | --- |
| Parado | Zombie Idle | Zombie Upright Twitching Idle |
| Patrulha | Mutant Walking | Mutant Brutal Walk |
| Perseguição | Running | Male Weighted Run |
| Procura | Looking Around | Idle Stand Looking Around |
| Ataque com bastão | Manter o clipe atual | Humano gostou do ataque existente; não substituir sem verificar identidade |
| Jumpscare/captura | Zombie Headbutt | Zombie Headbutt With Hand Grab |

Na procura, reduzir a extensão de pescoço/cabeça para trás, mantendo o olhar lateral. Usuário aprovou condicionada a essa correção. Principais motivos de rejeição das outras opções: postura e braços. Não substituir escolhas por Zombie Scream ou Mutant Roaring: foram vistos, mas o humano preferiu Headbutt.

Catálogo oficial: https://www.mixamo.com/ . Buscas: zombie, mutant, running e looking around. Licença https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html (uso comercial permitido em jogos; não disponibilizar os FBX como biblioteca de assets). Conta Adobe já autenticada no navegador do Codex; isso não garante sessão autenticada no navegador do Claude.

## Modelo correto e estado real

ATENÇÃO: o personagem atualmente carregado no Mixamo, "tung tung sahur archive", é uma SKIN FUTURA segundo o humano. Não substituir o modelo atual por ele e não assumir que suas proporções são compatíveis. Prévia aprovada é de MOVIMENTO, não aprovação dessa skin para o jogo.

Consulta MCP somente leitura confirmou no place 82955516040017: ReplicatedStorage.Assets.TungTung, Body MeshId rbxassetid://111005002149644, 28 Bones. Revalidar no destino antes de escrever. Fontes em Client/Creature/TungTungRig.luau, TungTungClips.luau, ClipCodec.luau e tools/tungtung/{README.md,bake.js,bones.json,fbx.js}. Atual sistema usa Bone.Transform/clipes locais, não Animator/AnimationId. Arquivos originais em C:/Users/HP/Downloads: Zombie Walk.fbx, Standing Run Forward.fbx, Great Sword Slash.fbx, Great Sword Strafe.fbx, Sheath A Great Sword 2.fbx. Conferir bind pose antes de aproveitar; Unarmed Turn Left 90 foi rejeitado anteriormente por proporções diferentes.

NENHUM dos novos clipes foi baixado, convertido ou aplicado por Codex. Nenhum teste dos novos movimentos no Studio foi realizado. O trabalho desta frente até aqui foi pesquisa, leitura do rig, seleção humana nas prévias e coordenação. Não marcar como entregue.

## Direção do jumpscare autorizada

- Base: Zombie Headbutt With Hand Grab, com câmera da vítima enquadrando rosto/agarrão. Ajustar mãos e bastão para evitar atravessar rosto/câmera e aparência de arma solta.
- Sequência curta com antecipação legível, aproximação/impacto sincronizados e recuperação. Ajustar duração pela qualidade do clipe, não esticar todo o ciclo se desnecessário.
- Fazer jogo de luz: queda breve da luz ambiente percebida pela vítima, luz direcional localizada revelando rosto e acento único no impacto. Preservar atmosfera escura e contraste da lanterna. Sem estrobo, tela branca intensa ou iluminação global que afete os colegas.
- Camera shake curto, amortecido, de translação/rotação moderadas e pico no impacto; não tremor constante. Respeitar preferências de conforto existentes. Sons sincronizados, sem volume excessivo; usar assets licenciados.
- Efeitos exclusivamente no cliente capturado. Restaurar câmera/FOV/efeitos/luzes em respawn, resgate, troca de modo e interrupção; evitar conexão/evento duplicado. Não alterar HUD ou o controle da câmera do caçador PvP fora da captura autorizada.

## Integração e critérios de teste

Conferir mudanças concorrentes e definir integrador único antes de sincronizar. Preservar backup completo do destino. Não aplicar build local por cima do tungtung e não ligar Script Sync de árvore inteira antiga. Confirmar PlaceId e Sources.

Adaptar clips ao rig real, manter movimento no lugar e Root/velocidade/dano autoritativos intactos. Verificar contato dos pés, deformações, mãos/bastão e transições idle/walk/run/search/attack/capture. Ataque atual deve permanecer funcional.

Executar check local e Tests.Run no Studio; gravar evidências comparativas e testar captura perto de paredes, em esconderijo, durante perseguição e em interrupções. Validar efeitos só na vítima e compatibilidade multiplayer/Midnight Hunt quando possível. Relatar NÃO TESTADO para mobile físico ou múltiplos clientes indisponíveis. Commit apenas dos arquivos desta frente, sem push no principal ou publicação. Responder pelo repositório de coordenação com status e bloqueios reais.
