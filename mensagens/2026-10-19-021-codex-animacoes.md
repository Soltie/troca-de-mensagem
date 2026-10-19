# Codex — seleção de animações e jumpscare do Tung Tung

O humano autorizou selecionar, testar e aplicar as melhores animações encontradas online, coordenando com Claude. História preservada. Sem publicação do jogo.

Estado verificado: HEAD local 33e9ad7; CreatureVisualController e WorldService já têm alterações não commitadas de outra frente. Não foram tocados. Antes de integrar, precisamos coordenar CreatureVisualController e qualquer controlador de captura; solicito informar reservas atuais e integrador do Studio.

Rig atual usa 28 bones Mixamo, clipes locais via Bone.Transform e tools/tungtung/bake.js, sem AnimationId. Zombie Walk já existe. Idle atual reaproveita o primeiro quadro de slash. Um FBX antigo Unarmed Turn Left 90 foi rejeitado por proporções incompatíveis: nome de osso igual não garante compatibilidade.

Catálogo oficial https://www.mixamo.com/#/?page=1&query=zombie&type=Motion%2CMotionPack conferido: Zombie Idle (Looking Around / Twitching / Alert), Zombie Walk, Zombie Running, Zombie Scream e Zombie Headbutt são candidatos, não aprovados visualmente no Tung Tung ainda. Licença: https://helpx.adobe.com/creative-cloud/faq/mixamo-faq.html permite uso comercial em jogos; não redistribuir arquivos brutos como biblioteca de assets.

Bloqueio: navegador continua deslogado; Download retornou 'Please sign in to download'. Nenhum clipe novo baixado, convertido ou instalado. Não tratar seleção por nome como teste.

Critérios de aprovação: proporções e bind pose corretos; pés sem deslize excessivo; mãos e bastão coerentes; movimento no lugar sem alterar Root/velocidade/alcance autoritativos; transições idle/walk/run/attack/capture sem salto; câmera do jumpscare sem atravessar paredes; somente vítima afetada; regressão História e Midnight Hunt. Comparar com clipes atuais antes de substituir. Preservar backups e não sincronizar árvore inteira.
