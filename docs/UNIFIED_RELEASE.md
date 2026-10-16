# Vigia — entrega unificada, 16/10/2026

Arquivo único: `C:\Users\xpg\Documents\roblox-teste\build\Vigia_UNIFICADO.rbxlx`.
Abra esse arquivo pelo Studio. Ele contém o mundo e todo o código; não precisa conectar Script Sync para publicar ou testar esta cópia.

## Origem da integração

Foram lidos integralmente os pedidos, atualizações e entregas dos três chats:

- **Melhorar HUD e explicar o jogo** (`01a145a6-a765-7120-92f1-51c79ac13a46`): HUD, guia H, equipe TAB, marcadores, sobrevivência e orientações por fase. Referência: commit `24ee1ca`.
- **Melhorar geração e imersão do mapa** (`01a145ab-6a18-7561-bbb4-14ef036e1039`): corredores, pavilhões separados, pátios abertos, percurso externo e navegação. Já incluído na base `a885224`.
- **Melhorar tasks e recompensas** (`01a145ad-ca41-7a10-b7b1-07965799284a`): reparos em três ações, sequência com acertos preservados, relés cooperativos, placas e recompensas únicas. Referência: commit `a27f534`.

A integração foi congelada em worktree próprio, sem descartar alterações na pasta compartilhada. Todos os 175 arquivos de `src/` foram capturados e conferidos contra o disco durante a cópia. O HUD corresponde à entrega isolada, com as instruções/feedback atualizados pelas tarefas e o runtime com as duas frentes combinadas. A versão corrente de TrailerController foi preservada; o trailer continua desativado por padrão.

O Padrão conserva mapas sorteados e tarefas em ordem livre. História conserva mapa fixo e objetivos em ordem. Ambos aceitam 2–8 jogadores. Menu e abertura estão incluídos.

Cada estação paga 12 Fichas + 24 XP aos integrantes elegíveis, com mais 8 Fichas + 16 XP a quem ajudou. Pagamentos repetidos são bloqueados.

## Arquivo e reprodução

SHA-256: `1747928D7FC88AB3DC7AC5F740A50F0426C02FCCE6E84337C546FA18611A67EE`.

Na cópia congelada, execute `lune run scripts/check` e depois `rojo build default.project.json --output build/Vigia_UNIFICADO.rbxlx`. O manifesto em `evidence/unified/source-manifest.json` registra scripts, classes, hashes, projeto e arquivos do mundo. Os 175 scripts embutidos correspondem às fontes, sem extras ou ausentes; preset de iluminação Realistic preservado.

## Uso

1. Abra **Vigia_UNIFICADO.rbxlx** no Studio, em vez de reaproveitar uma build antiga já aberta.
2. Para testar localmente, inicie **Server & Clients** com dois jogadores ou mais e escolha o modo.
3. Para atualizar a experiência existente, use **Publish to Roblox As…** e selecione cuidadosamente a experiência e a place de destino. O arquivo local ainda não está vinculado à experiência publicada.
4. No teste humano, confira H/TAB, estações, corredores/pátios e as notificações/carteira depois de concluir tarefas.

Não houve publicação, push, compra, alteração de acesso ou conexão de Script Sync à place compartilhada. O equilíbrio com o Vigia ativo, a diversão e a persistência real após publicação precisam de teste humano; os testes locais usam perfis mock e o roteiro automatizado congela a criatura/teleporta clientes para preparar os cenários.

## Validação desta consolidação

- Check completo: ALL GREEN, 248 testes puros, zero falhas, cinco specs exclusivos do Studio pulados no Lune.
- Runner na build entregue: 275 aprovados, zero falhas, zero specs pulados.
- Boot do servidor: 15 services; cliente: 30 controllers. HUD carregou.
- Console: zero erros e zero warnings do projeto; avisos FoundationProvider/UIBlox pertencem aos CoreScripts do Studio.
- Auditoria no Studio em Edit: 175/175 Sources correspondem ao manifesto, sem diferenças.
- Padrão com dois clientes: 107 verificações aprovadas, três etapas e vitória após extração de todos os sobreviventes. Recompensas e rejeição de duplicatas verificadas em todas as etapas.
- Captura de cliente em multiplayer: HUD exibe setor, marcador, passo de reparo, dicas, bateria e fôlego; texto da ação com TextFits=true.
- História com dois clientes: 90 verificações aprovadas, três capítulos e vitória; seleção pelo menu, mapa fixo, recompensas e extração confirmados.
- H abriu e fechou o guia num cliente da História, na viewport 1096×635. Captura em `evidence/unified/story-hud.jpg`.
- As simulações encerraram seus clientes; o editor da entrega voltou a Edit. O SHA-256 do arquivo permaneceu igual após os testes.

Os logs de servidor (`standard-2.log`, `story-2.log`) preservam cada PASS, inclusive conclusão das três etapas, pagamentos e vitória após extração. O RESULT longo é truncado pelo próprio log do Studio; a aprovação usa as asserções individuais e a mensagem final de vitória. O retorno do encaminhamento ao editor não foi usado como prova de sucesso.
