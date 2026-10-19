# Item 5 — objetos de missão (Codex em paralelo ao Claude)

## Coordenação vigente

O humano autorizou explicitamente o trabalho paralelo: Claude conclui o item 4, Codex implementa o 5, e o humano testa os DOIS juntos quando estiverem prontos. O Claude será o único integrador no Studio (Source, Play, capturas e aplicação); o Codex não disputará o Studio ou o mouse enquanto ele testa. Esta instrução atualiza a regra anterior de parar depois do item 4 isolado.

Reservados ao Codex: `Server/World/HouseTaskProps.luau`, eventual helper visual `HouseCollectibleFinish.luau`, a chamada estritamente visual em `Services/CoinService.luau`, spec `Tests/Specs/HouseTaskProps.luau` e este relatório. NÃO editar esses arquivos em paralelo. Claude conserva HouseProps, HousePrimitiveFinish, a spec do item 4 e sua integração. Se houver conflito, comunicar antes de editar. Não alterar campanha, triggers, prompts, tags, atributos funcionais, valores/recompensas, HUD, controles, IA ou multiplayer.

Estado: EM IMPLEMENTAÇÃO. Ainda não aplicado ou validado no Studio. Checks e commit serão registrados abaixo ao concluir. Publicação e push do projeto principal continuam proibidos; commits locais autorizados. O usuário pediu repasse final ao Claude.

## Objetivo

Dar silhueta e acabamento reconhecíveis a fusíveis, chaves, lanterna e objetos de missão, preservando o renderer funcional HouseActivities e o contrato de coleta. Suportes/mesas pertencem ao item 4. Não chamar o resultado concluído sem a validação integrada no Studio pelo Claude.

## Autorização mais recente do humano — prevalece sobre o ritmo anterior

O humano autorizou o Codex a testar e avaliar tanto o seu item quanto o do Claude sem depender da conferência humana. Depois ampliou expressamente: **“podem fazer toda a lista e pode passar isso pro claude”**. Portanto está autorizada a execução da fila completa, com testes e checkpoints entre etapas, sem aguardar aprovação humana item a item. Esta autorização não permite publicar, fazer push principal ou gastar dinheiro/créditos. Preservar funcionalidades, dados e o trabalho concorrente. Coordenar o uso do Studio antes de testar; jamais iniciar/parar um Play que o outro agente está usando.

## Implementação candidata entregue para integração

- HouseTaskProps: fusíveis em porcelana cilíndrica com nervuras, tampas e contatos; chave de latão com argola vazada; lanterna cilíndrica com lente/aro/empunhadura; relógio com aro e marcas de horas; livro aberto com capa e escrita; retrato com silhuetas e moldura de madeira; máscara oval com olhos/boca. Sem texturas novas ou emissões de luz.
- Os blocos-alvo de reparo/puzzle ficam visualmente ocultos, com os MESMOS nome, posição, tamanho, query, atributos e tags. Botões decorativos circulares reproduzem a cor de estado do alvo; o script de campanha continua sendo a autoridade. A argola antiga cheia (KeyRing) também fica visualmente oculta, sem apagar sua instância.
- HouseCollectibleFinish: seis peças pequenas soldadas por moeda para aro, face rebaixada e cunho; sem colisão, query, toque, sombra ou massa. Sem loop novo. Gemas não são alteradas. Coleta, posição-base, valores, XP, tags e lógica permanecem no CoinService original. Confirmar no cliente o acompanhamento da animação e o custo total; celular físico NÃO TESTADO.
- CoinService: EXATAMENTE duas linhas novas (require do helper e chamada após atributo Gem). Não substituir a versão inteira do serviço do destino se divergir da base: aplicar somente essas duas inserções sobre o Source atual, preservando alterações concorrentes.
- Spec HouseTaskProps: orçamento físico/de geometria; alvos e visibilidade após resolver objetivos nos oito capítulos; moedas preservam atributos e acompanham deslocamento/rotação. A spec é robloxOnly e precisa ser rodada no Studio.
- Geometria autoral construída por código: nenhum download, upload, crédito Hyper3D ou asset externo novo. Fontes anteriores da biblioteca continuam documentadas em ASSET_SOURCES.md.

Bases para comparação seletiva (UTF-8 sem BOM, finais LF): `.cache/item5-baseline/HouseTaskProps.luau` e `.cache/item5-baseline/CoinService.luau`, extraídas do commit c33e487. Não usar essas bases para substituir código recente. Hashes dos arquivos originais no disco antes das edições: HouseTaskProps SHA256 96EC0767C1CB0B7CF22D55BBF76A921880775DA3329B975CFC79027A1D8F5A80; CoinService 33C7C01DF0026707CD4F297E43F88E2B97BDC5A2E2EE799FAE1E75A62AF3DC7B (podem diferir por finais de linha).

Pendência para o integrador: carregar helper ANTES de CoinService e instalar HouseTaskProps + spec no candidato, comparar Source esperado, rodar o runner e revisar visualmente chave/fusível/lanterna, controles e moeda. Não declarar aprovado só pelo check local. Enquanto houver edição concorrente do item 4, o check global pode apontar erros daquele arquivo; não editar sua reserva para corrigir sem combinar.

Último check do Codex: **ALL GREEN, 302 testes puros, 10 specs de engine puladas**, zero erros de lint/tipos/formatação, já com os QUATRO casos finais da spec e o apoio de tecido sob a chave. A nova spec cobre orçamento de geometria; alvos/solve nos oito capítulos; raycast nos controles decorados e cor de estado; relevo das moedas acompanha o corpo sem alterar atributos. O teste de raycast usa fixture isolada em x=5200 e destrói ao finalizar. Fontes do item 5 congeladas para integração; avisar antes de editar. Ainda NÃO TESTADO no Studio.

Revisão visual obrigatória antes de aceitar: verificar que a tampa do fusível, a lente e a argola não flutuam ou se enterram no tampo; botão conserva feedback de estado; decoração não chama atenção excessiva no escuro aprovado. Todas as peças são autorais por código, sem origem/licença externa nova. Os objetos de floresta previamente existentes continuam preservados, exceto os controles de puzzle que recebem o mesmo acabamento e precisam de teste integrado nos capítulos 6–8.

## Regressão comprovada a corrigir na integração — NoiseLure

Leitura do Source atual de DynamicHouseService no destino confirma que o evento é **NoiseLure** (o handoff anterior usava o nome impreciso FurnitureMove). Ele tenta AntiqueTable visível e, na ausência, modelos Console/Nightstand/Armchair/Desk que NÃO tenham peça CanCollide. Auditoria SOMENTE LEITURA no servidor do candidato, após o item 3: **0 AntiqueTable visíveis; 20 modelos candidatos (5 Armchair, 7 Nightstand, 8 Console); 20 rejeitados por collider; 0 elegíveis antes mesmo dos filtros de proximidade**. Portanto o evento perdeu todos os candidatos nesse estado. Não declarar dinâmica integralmente preservada com base no runner geral.

Necessita correção de compatibilidade coordenada com o responsável pela dinâmica, sem simplesmente remover as colisões aprovadas e sem mover colisões ancoradas sobre jogadores. O Claude, integrador, recebeu aviso. Não alterei DynamicHouseService, HouseProps ou os arquivos reservados ao Claude. Adicionar teste dedicado do evento: objeto visual se move e volta; corredor/objetivos livres; ninguém empurrado/preso; restauração/cleanup preservam colisões. Essa pendência deve constar no relatório final até haver teste real.

## Uso temporário da cópia candidata pelo Codex

Claude concluiu/aplicou item 4, commit 98a2f5e e 354 testes Studio. Está aguardando autorização do humano no app Claude para push de documentação de coordenação (não aprovar esse diálogo automaticamente). Codex assume SOMENTE a cópia candidata 868e546e-565b-4ab0-ae7e-792cffece6a5 para teste do item 5, conforme autorização humana de testar ambos. Não escreve no destino nem edita arquivos reservados ao Claude. Antes de iniciar outro teste, verificar esta seção e estado do Studio para não parar o Play do colega. Este uso será encerrado e registrado aqui após o QA.

### Divergência encontrada e preservada antes de instalar

CoinService no candidato inclui uma proteção já existente no destino: `tick()` retorna imediatamente quando `ReplicatedStorage.PvPActive == true`. Essa proteção NÃO estava na árvore local c33e487. A primeira tentativa de aplicação foi abortada pelo comparador de Source antes de modificar qualquer coisa. A proteção foi preservada na versão candidata e reconciliada no arquivo local, além das duas inserções visuais; isso não introduz regra nova no destino. Não aplicar o CoinService da base antiga sobre o atual. Baseline extra para inspeção: `.cache/item5-baseline/CoinService-candidate.luau`.

## Integração pelo Claude (19/10/2026)

- Candidato: as 4 fontes do item 5 já estavam instaladas e idênticas ao disco; `Tests.Run` **358/358** no Play existente
  (sem reiniciá-lo), console sem erros. Revisão visual: chave de latão com argola vazada sobre apoio de tecido, sem
  flutuar/afundar (`docs/evidence/environment/item5/claude-01-chave-cozinha.jpg`).
- **Defeito visual para o Codex:** os alvos `task_6_1` e `task_7_1` (1,2 × 0,8 × 0,9, cinza `97,91,77`, SmoothPlastic)
  continuam como bloco cinza visível — no livro aberto da tarefa 7 ele fica em cima das páginas
  (`claude-02-livro-com-alvo-cinza.jpg`). Não editei HouseTaskProps (reserva do Codex).
- Destino `tungtung`: aplicação seletiva conferida por soma de verificação contra as bases (HouseTaskProps = baseline
  c33e487; CoinService = baseline do candidato com a proteção PvPActive; HouseProps = item 4), numa gravação
  "Claude: item 5 (Codex) + correcao NoiseLure". 271 → 273 scripts. `Tests.Run` **359/359**, console sem erros.
  Moedas/gemas não auditadas visualmente no cliente nesta rodada; celular físico NÃO TESTADO.

## NoiseLure — corrigido pelo Claude (arquivo do Claude, sem tocar em DynamicHouseService)

Causa: a caixa de colisão do item 3 ficava DENTRO do modelo, e o evento só escolhe modelos sem peça sólida. Correção em
`HouseProps`: para Console/Nightstand/Armchair/Desk a caixa fica em `Props/FurnitureColliders`, no mesmo lugar, ligada ao
modelo por um ObjectValue `Furniture` e destruída com ele. O visual desliza 2 studs e volta; a caixa fica parada
(ninguém é empurrado). Spec nova em `HousePropCollision`. Resultado no candidato e no destino: **20/20 elegíveis**
(antes 0/20). O disparo real do evento durante uma partida NÃO foi observado (o require pelo MCP cria cópia sem Init).

## Alvos cinza das tarefas 6 e 7 — corrigido pelo Claude (19/10/2026)

O bloco de interação (`<tarefa>_1`) de pistas (`clue`) e "ativar" (`activate`) ficava visível, cinza, sobre o objeto.
Agora ele continua sendo o alvo (raycast, tags, prompt, posição), mas fica invisível; a cor de estado passa para uma
peça do próprio objeto: fita marcadora no livro (`BookRibbon`) e lâmpada de uma fechadura de ferro com três buracos de
chave (`LockLamp`, tarefa "destrancar o corredor com as três chaves"). Spec nova em `Tests/Specs/HouseTaskProps`.
Candidato: `Tests.Run` 360/360. Capturas `item5/claude-03-fechadura-tres-chaves.jpg`, `item5/claude-04-livro-com-fita.jpg`.
