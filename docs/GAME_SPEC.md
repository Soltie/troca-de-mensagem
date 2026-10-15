# GAME_SPEC — especificação do jogo

> Modelo em branco. Preencha (ou descreva o jogo para o agente preencher) antes de implementar.
> O agente implementa **uma fase por vez** e só avança quando o critério de pronto da fase passar.

## 1. Conceito

- **Nome provisório:**
- **Uma frase (pitch):**
- **Gênero / referências:**
- **O que torna o jogo diferente:**

## 2. Loop principal

- **O que o jogador faz a cada minuto:**
- **Objetivo de uma sessão:**
- **Por que ele volta amanhã:**

## 3. Progressão

- **O que evolui (níveis, itens, áreas...):**
- **Moedas / recursos:**
- **O que é salvo (PlayerData):**

## 4. Monetização

> O agente não configura nada no Creator Hub; aqui é só o plano.

- **Game passes:**
- **Developer products:**
- **Assinaturas / outros:**
- **Limites (o que nunca será pago):**

## 5. Público

- **Faixa etária:**
- **Perfil (casual, competitivo...):**
- **Sessão típica (minutos):**

## 6. Plataformas

- [ ] PC
- [ ] Mobile
- [ ] Console
- [ ] VR
- **Controles por plataforma:**

## 7. Fases de implementação

| Fase | Escopo | Critério de pronto |
| --- | --- | --- |
| 1 |  |  |
| 2 |  |  |
| 3 |  |  |

## 8. Critério de pronto de cada fase

Para TODA fase, além do critério específico da tabela acima:

- [ ] `lune run scripts/check` verde.
- [ ] Playtest via MCP sem erros/warnings inesperados; testes do Studio passando.
- [ ] UI conferida com `screen_capture` (se a fase tiver UI).
- [ ] Dados novos com migração em `PlayerDataSchema` (se mudou o formato).
- [ ] Todo remote novo validado no servidor (Guard + rate limit).
- [ ] Commits pequenos; `docs/SETUP_REPORT.md` atualizado.
