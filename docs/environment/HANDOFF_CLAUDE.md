# Repasse do Codex para o Claude — autorizado pelo humano

O humano pediu explicitamente: “passe tudo pro claude fazer”. Continue o trabalho existente, sem reiniciar a reforma e sem descartar alterações. O Codex encerrou seus Plays e não continuará editando esta frente em paralelo.

## Pedido e ritmo de entrega

Reforma visual completa do Tung Tung Sahur, terror estilizado com detalhes realistas, qualidade ambiental inspirada em DOORS/The Mimic, assets próprios ou gratuitos com licença individual verificada, performance para celular. Fazer **um item por vez**, testar/aplicar no Studio e **parar para o humano conferir antes do próximo**. O item atual autorizado é o **4 — blocos visuais genéricos**. Fila completa: [ENVIRONMENT_BACKLOG.md](ENVIRONMENT_BACKLOG.md), incluindo os pedidos novos de lareira, grama de referência, chuva, movimentação dos personagens/Tung Tung e vinheta/ruído.

Não publicar, não configurar playtesters, não fazer push do projeto principal e não gastar créditos/dinheiro. O pedido anterior de publicação foi cancelado pelo humano. Não alterar HUD, menus, UI, economia, IDs, dados, recompensas, história, objetivos, IA, rotas, layout ou lógica multiplayer. A revisão de efeitos de tela foi adicionada separadamente; não autoriza redesenhar interfaces. Manter prompts, tags, atributos, colisões e referências das peças funcionais. Movimento novo ainda é apenas backlog, sem autorização para alterar velocidades/IA/controles.

## Fonte e destino

- Workspace deste PC: `C:/Projetos/tung-tung-sahur`, branch `design/environment`, HEAD `c33e487`.
- Place oficial `tungtung`, PlaceId **82955516040017**, Universe **10771638828**. Revalidar IDs e estado pelo MCP antes de escrever.
- Últimos Studios: destino `6289d463-9045-41f3-933a-fdb78ca4eebb`; candidato `868e546e-565b-4ab0-ae7e-792cffece6a5` (`TungTung_BACKUP_ANTES_CODEX_20261019.rbxl`). **Ambos devolvidos a Edit neste repasse.**
- Script Sync está desligado intencionalmente: a árvore local não contém toda a integração recente do destino. Não ligar Sync nem substituir scripts em massa. Não usar a build local como substituta do tungtung.
- Midnight Hunt, filas, salas privadas, campanha, floresta, Tum-Tum e correções de salto/câmera do destino devem permanecer.
- Coordenação autorizada: https://github.com/Soltie/troca-de-mensagem, clone `.cache/codex-coordenacao`. Último commit conhecido `bec7bb6`, mensagem `mensagens/2026-10-19-017-codex-ambiente-hp.md`. Fetch antes de publicar documentação. Pode fazer push só nesse repositório de coordenação, nunca force push. Registrar que o Claude assumiu a reserva. Não editar `MansionScene`/`DynamicHouseService` ou sistemas compartilhados sem coordenar.
- `CONTEXTO_DESIGN_CODEX.md` é arquivo preexistente do usuário, não apagar/adicionar ao commit por engano.

## Entregas já aplicadas

1. Backup/reconciliação: `docs/environment/CHECKPOINT_01_BACKUP.md` e `BACKUP_RECONCILIATION.json`.
2. Escala e composição: commit `66b9ca9`, aplicado ao destino. `HouseProps` usa FURNITURE=0.85; KEEP preserva volumes de cama, mesa baixa, esconderijo e tapetes. Cadeiras específicas 0.6. Relatório `FURNITURE_SCALE_REVIEW.md`.
3. Colisões: commit `c33e487`, aplicado ao destino. Caixas invisíveis simples para 23 tipos de móveis, malhas sem colisão/query/toque. Spec `HousePropCollision`; 302 testes puros e 351 testes no Studio aprovados, candidato e destino. Relatório `FURNITURE_COLLISION_REVIEW.md`.

Backups completos nativos (não confundir com scripts):

- `build/TungTung_BACKUP_ANTES_CODEX_20261019.rbxl`, 715687 bytes, SHA256 `2DA13F5E50A6427A5819BC3921BE8B77C943E5FD85403CCB51F3BAEFFFE24281`.
- `build/TungTung_MOVEIS_ESCALA_CODEX_20261019.rbxl`, 715829 bytes, SHA256 `C0ACE959077D6687C84B750A728BA21E8440683681FA28F794C542EAA60E955C`.
- Ainda não foi salva cópia nativa completa após item 3; recuperar usando a cópia anterior + commit. Salvar nova cópia antes da integração do item 4.
- Lune deserialize acusa propriedade Terrain tipo 0x23 desconhecida. Pode ler para auditar; **não reserializar a place completa pelo Lune**, risco de perder Terrain. Usar Download a Copy do Studio.

## Item 4: alterações locais NÃO COMMITADAS e NÃO aplicadas ao destino

Arquivos de implementação:

- `src/ServerScriptService/Server/World/HousePrimitiveFinish.luau` (novo).
- `src/ServerScriptService/Server/World/HouseProps.luau` (apenas require + chamada Finish.build no final).
- `src/ServerScriptService/Tests/Specs/HousePrimitiveFinish.luau` (nova spec).

Implementação atual é candidata, exige revisão visual antes de aceitar:

- AntiquePedestal da campanha: visual LowTable ajustado ao volume original; corpo fica invisível, mantém colisão, luz e referência. Modelo visual em pasta separada `PrimitiveFinish` para `HouseActivities.refresh()` não reexibir o corpo nem esconder a mesa ao coletar o item.
- Candle diretamente em Furnishings: substitui cubo por Lantern com haste fina até o teto. Mantém PointLight original, sem acrescentar luz ou mexer na iluminação aprovada.
- HeavyCrate e Vault de DynamicMansion: malhas Crate/SeaChest com margem de 0.015 stud por face, soldadas ao corpo original; acompanham posição/rotação e transparência. Corpo mantém tamanho, transparência, tags, atributos, colisões, referência e mecanismos; recebe madeira escura como fundo.
- Hook DescendantAdded atende reconstrução de capítulos; modelos são removidos ao destruir o corpo; guard evita duplicatas.
- Reutiliza biblioteca existente `ReplicatedStorage.Assets.MansionProps`, sem downloads/uploads/custos. Os quatro modelos usados têm uma única MeshPart alinhada. Verificar se esticar o Crate até 5×3.6×3 não piora proporções; rejeitar se feio.

Validação atual:

- Check completo inicialmente ALL GREEN: 302 puros, 9 specs Studio puladas, lint/strict/format aprovados. Uma tentativa restrita do Selene falhou no download do API dump; nova execução com rede autorizada passou.
- No candidato foram instaladas as três fontes e executado o runner: **352 passaram, 1 falhou**, exclusivamente comparação exata de float da luz (0.9 vs 0.899999976). Corrigi no disco para tolerância 0.001. **Essa última correção ainda NÃO foi retestada e NÃO chegou ao Source do candidato.** Não declarar 353 verdes sem rodar novamente.
- O destino continua com as fontes do item 3. Não foi instalado nem o helper em runtime no destino. Apenas câmera/HUD temporários foram usados durante Play; Stop já os descartou.
- Não há ainda capturas antes/depois válidas do item 4, nem relatório final nem commit. Uma captura nativa mostrou o destino em vez do candidato, e a tentativa seguinte detectou interação humana; não usar como evidência de resultado.
- É necessário concluir o inventário do item 4: livros cinza, suportes/caixotes genéricos, bloco amarelo na parede, bloco vermelho na cozinha e caixote perto da passagem selada. NÃO marcar todo o item concluído só porque o helper cobre quatro nomes. Objetos de missão propriamente ditos ficam no item 5; documentar onde a classificação se sobrepõe.

## Alertas concretos para investigar

- `DynamicHouseService` escolhe móveis Console/Nightstand/Armchair/Desk para evento FurnitureMove somente se o modelo não tiver nenhuma peça CanCollide. As novas colisões do item 3 podem deixar esse evento sem candidatos. Ainda NÃO foi comprovado por teste dedicado. Investigar, coordenar e relatar antes de afirmar dinâmica integralmente preservada. Não editar lógica compartilhada silenciosamente.
- Bookshelf tem malhas Books/Body com SurfaceAppearance ColorMaps e tint cinza; conferir carregamento real no cliente antes de atribuir os blocos cinza somente à cor. IDs existentes: 99639947827414, 134263184779293, 96413295064141. Não fizeram parte das alterações atuais.
- A lareira rejeitada está em item separado; não trocar agora junto com o 4. A imagem da grama de The Mimic também é referência futura, não alterar jardim durante item 4.

## Continuação recomendada

1. Ler arquivos novos/diff, backlog e coordenação; assumir reserva e revalidar Studio correto.
2. Concluir os blocos faltantes com qualidade visual; preservar lógica/colisões, sem mudar fontes antigas concorrentes.
3. Atualizar a spec corrigida no candidato e rodar checks + runner Studio, capturas e teste de interação/movimento/limpeza.
4. Salvar checkpoint completo nativo do destino, auditar fontes atuais e aplicar SOMENTE os arquivos desta frente se continuarem NotSynced e sem alterações concorrentes. Nunca sincronizar árvore inteira.
5. Rodar QA no destino e comparar manifestos para comprovar scripts externos preservados. Registrar warnings Roblox/CorePackages separadamente de erros do jogo.
6. Documentar `ASSET_REPLACEMENTS.md`, `ENVIRONMENT_QA.md`, relatório específico e evidências. Commit local pequeno só dos próprios arquivos e atualizar coordenação. Sem push principal/publicação.
7. Entregar item 4 ao humano para conferir e aguardar antes de iniciar o 5.

## Ferramentas e observações

- MCP oficial Roblox_Studio disponível; sempre `studio_id`. `mcp__blender` disponível, Blender 5.1 aberto. Não presumir créditos Hyper3D autorizados.
- Native computer use funciona neste Codex via pacote `@oai/sky` no node_repl; o Claude precisa usar as ferramentas realmente disponíveis na sessão dele. CUA daqui não oferece controle nativo.
- Janela Studio conhecida 1315142; reconsultar lista, nunca confiar em handle/coords velhos. O mesmo app pode mostrar o destino enquanto MCP testa o candidato; conferir título/contexto.
- Se acusar interação humana, observar de novo antes de agir; não brigar pelo mouse. Para cópia completa usar File → Download a Copy, nunca Publish.
- `lune run scripts/check` precisa PATH com `$env:USERPROFILE\.rokit\bin`. Testes Studio: `return require(game.ServerScriptService.Tests.Run)()` durante Play.
- DebugBridge e câmera fixa só em Play. O require direto de WorldService pelo MCP deu “used before Init” em uma leitura; `workspace.CursedHouse` existia corretamente. Não confundir esse require isolado com falha de boot.

Referências visuais salvas: `docs/evidence/environment/backlog/fireplace-reference.png` e `grass-the-mimic-reference.png`. Estão no backlog e não foram implementadas.
