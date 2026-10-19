# Etapa 3 — colisões dos móveis

Aplicado no Studio do tungtung, PlaceId 82955516040017. Sem publicação Roblox, Script Sync ou alterações de UI/iluminação/controle/economia. Mudanças de fontes restritas a HouseProps e à nova spec HousePropCollision; as outras 267 fontes mantiveram comprimento/checksum.

## Implementação

- 137 caixas simples ancoradas no mapa inicial, uma por móvel decorativo sólido: sofás, poltronas, cadeiras, mesas, estantes, armários decorativos, bancadas, baús, caixas e outros móveis grandes.
- Caixas inteiramente transparentes, sem toque/sombra e recuadas 0,1 stud em cada lateral do volume do modelo. Acompanham escala, orientação e reconstrução do móvel; malhas continuam sem colisão complexa.
- Camas, mesas baixas e guarda-roupas de esconderijo preservam as colisões originais. Não foram movidos prompts, tags, objetivos, portas ou esconderijos.
- Caixas sólidas são consultáveis: CanQuery=false não exclui peças com CanCollide=true conforme contrato do engine. Não foi usado esse falso isolamento do commit antigo 41ac22b. Rotas e áreas de aproximação de objetivos foram verificadas com os volumes presentes. Não há mudança de código da IA, mas móveis sólidos agora podem obstruir linhas que atravessem seu volume físico.

## Evidências

- Check ALL GREEN: 302 testes puros, 8 specs exclusivas de Studio puladas; build/Test.rbxlx gerada. Esta build da árvore visual antiga não substitui a integração atual.
- Cópia de QA: 351 testes Studio aprovados, zero falhas.
- Destino: 351 testes Studio aprovados, zero falhas; zero erros/avisos no log do servidor durante a verificação.
- Teste físico força um corpo de tamanho semelhante ao jogador contra o sofá durante 1,2 s e verifica que ele se aproxima e não atravessa.
- Fixture com mobília real verifica caminhos para todos os cômodos e saídas dos esconderijos, com agentes do jogador e da criatura sem pular. Verifica também volumes dos objetivos/abordagem em três seeds e capítulos internos 1–5.
- Primeiro teste da biblioteca reprovou porque a fixture não atualizava ProgressionBarriers ao liberar os portões. Confirmado também sem colisões novas; corrigida somente a preparação do teste com HouseAccess.refresh. Nenhuma barreira da campanha foi alterada.
- Runtime: 137 caixas válidas, zero malhas colidindo, zero configurações inválidas. validation.json registra os dados.
- Capturas na pasta furniture-collision mostram sofá normal e caixa ciano de diagnóstico. Cor/visibilidade, câmera e luz de inspeção existiram só durante Play e foram descartadas ao parar.

Backup recuperável anterior completo: build/TungTung_MOVEIS_ESCALA_CODEX_20261019.rbxl. Aplicação desta etapa recuperável pelo diff/commit dos dois arquivos. A nova cópia nativa posterior não foi salva: o controle detectou interação humana na janela e bloqueou a operação; não foi substituído o backup anterior.

NÃO TESTADO: celular físico, nova campanha completa, nova partida completa de Midnight Hunt, avaliação manual de toda combinação de móveis/layouts. Testes existentes aprovados não equivalem a garantia de ausência de qualquer interferência.

## Conferência humana

Studio → Play → História: tentar atravessar o sofá e as mesas, contornar as estantes e acessar portas/esconderijos. Play de QA encerrado e auxiliares descartados. Parar aqui e aguardar o humano antes do item 4.
