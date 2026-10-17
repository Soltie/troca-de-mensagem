# Tung Tung Sahur — começar aqui

Versão atual de 17/10/2026: vãos da casa corrigidos, floresta de terror com 26 objetivos e epílogo com Tung Tung Sahur e Crocodilo Armadilho. Oito capítulos e modos História/Desafio preservados. Relatório: [FLORESTA_TERROR_FINAL.md](docs/FLORESTA_TERROR_FINAL.md).

Pasta independente: `C:/Users/xpg/Documents/tung-tung-sahur`.
Separação realizada em 17/10/2026. Código base: `19ace468f25f780b58b9c7625b533c0c26f9f9ec`.

## Jogar/testar

Abra [TungTungSahur.rbxlx](build/TungTungSahur.rbxlx) no Roblox Studio.
O arquivo contém o código e os assets do jogo. Para essa build pronta, basta testar pelo Studio;
não é necessário conectar Script Sync. No teste cooperativo, use Server & Clients.

## Adicionar código

Abra esta pasta como projeto no seu editor/chat. Edite somente o `src/` desta pasta.
Use uma sessão/janela do Studio própria para este jogo.

A place [Dev.rbxlx](places/Dev.rbxlx) foi gerada como mundo base, sem scripts.
A conexão do Script Sync ainda precisa ser feita nessa nova place:
associe `src/ServerScriptService` a ServerScriptService e `src/ReplicatedStorage`
a ReplicatedStorage, escolhendo **Keep Disk**. Confirme ambos como **SyncedAsRoot**.
O asset da criatura, quando existente, também vive nessa árvore de ReplicatedStorage.

Use somente um integrador com Script Sync por place. Cada jogo deve apontar para seu próprio
`src/`; não conecte as duas pastas à mesma place nem reaproveite uma conexão antiga.
Nunca rode `rojo serve`. Identifique o `studio_id` correto antes de cada teste MCP.

```powershell
Set-Location 'C:/Users/xpg/Documents/tung-tung-sahur'
lune run scripts/check
rojo build default.project.json --output build/TungTungSahur.rbxlx
```

## Proveniência e validação

- Base copiada sem alterações de gameplay, com histórico Git local próprio.
- `lune run scripts/check`: **ALL GREEN**, 283 testes aprovados,
  zero falhas; 7 specs exclusivas do Studio puladas no Lune.
- Build atual: `9703A276DD3FE5EFD62CB7F15E1B3CBAC27A8BA9BBCA5D565A74A874F6583D13`. A remasterização anterior foi preservada em `build/TungTungSahur_ANTES_TERROR.rbxlx`.
- Auditoria das fontes embutidas: consulte `build/TungTungSahur.audit.json`.
- Relatório da versão: [VISUAL_REMASTER.md](docs/VISUAL_REMASTER.md).
- A separação original é histórica. Os novos testes e limites de QA estão em `docs/FLORESTA_TERROR_FINAL.md`.
- Repositório independente, sem remote configurado e sem push/publicação.
- A pasta original `roblox-teste` e os worktrees anteriores foram preservados.
  Caminhos e reservas nos documentos antigos são históricos; esta pasta é a raiz deste projeto.

Abra dois chats/projetos, um em cada pasta, para desenvolver os jogos simultaneamente.

O README antigo do template está preservado em [docs/README_TEMPLATE_HISTORICO.md](docs/README_TEMPLATE_HISTORICO.md).
