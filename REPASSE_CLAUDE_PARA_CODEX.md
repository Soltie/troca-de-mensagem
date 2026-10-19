# Repasse do Claude para o Codex deste PC — reforma 3D do Tung Tung Sahur

Escrito em 19/10/2026, quando o limite de uso do humano chegou a 90%. Leia inteiro antes de mexer.
Responda ao humano em português do Brasil, curto e direto.

## 1. Estado agora

- **Place `tungtung` (PlaceId 82955516040017), Team Create, NÃO publicado** — já contém a reforma 3D (lotes 1–7)
  e o item 1 da lista (iluminação escura). 266 scripts, `Tests.Run` 347/347, console sem erros do jogo.
  Foi aplicado pelo MCP do Studio (sem Script Sync). Para testar: abrir `tungtung` no Studio → Play → História.
- **Branch local:** `design/environment` neste repositório (commits `ff88474` … `e57b523`). Base antiga
  (`design/ui-remaster`). Último commit `e57b523` = item 4 (escala), **não testado em jogo e não aplicado no place**.
- **Versão sobre o código integrado do place** (o que realmente vale para o tungtung): em `.cache/claude-repasse/`
  - `base-integrada-e23b635.bundle` — histórico do projeto integrado (branch `codex/tungtung-live-integration`, HEAD e23b635);
  - `0001…0011-*.patch` e `ambiente3d-sobre-e23b635.bundle` — meus commits por cima de e23b635
    (0001–0010 estão no place; 0011 = escala, falta testar/aplicar).
  - Para montar: `git clone -b codex/tungtung-live-integration base-integrada-e23b635.bundle integ && cd integ &&
    git am -3 ../0001*.patch …` (ou `git pull` do outro bundle). Check nessa árvore: ALL GREEN (328).
- **No place e fora do Script Sync (já aplicados):** 13 MaterialVariant em `MaterialService`,
  `ReplicatedStorage.Assets.MansionProps` (53 modelos), `Workspace.Terrain` Decoration=true / GrassLength=0.55.
- O place também tem os 7 módulos do Codex-dinâmica (Mansion*, DynamicHouse*); o `Client/Main` tem as duas linhas
  (`DynamicHouseController` e `RainController`). Não apagar nenhuma.

## 2. Como o humano quer trabalhar (importante)

1. **Um item por vez, seguindo a prioridade abaixo.** Fazer, **um teste sólido no final** (não dez), aplicar no
   tungtung e **parar para ele conferir** jogando.
2. Quando ele disser **"anote"**, só registrar; não mexer.
3. Não publicar no Roblox, não push no repo principal, não mexer em UI/HUD/regras/economia/IDs.
4. Referência de luz **aprovada** por ele: a Cozinha no capítulo 1 (escura, ladrilho xadrez, luz quente pontual).

## 3. Lista dele, na ordem de prioridade

| # | Problema | Estado |
| --- | --- | --- |
| 1 | Iluminação clara/chapada; quer casa ESCURA, lanterna como fonte principal | **FEITO e APROVADO** (`World/HouseLights.luau`, `Shared/Game/LightingProfile.luau`) |
| 2 | Avisar o integrador sobre o Script Sync | feito (canal GitHub, mensagens 009–011) |
| 3 | Boneco pulando sozinho | **resolvido** sem mudança ("já parou") |
| 4 | Móveis grandes demais (cadeira maior que o jogador) | **código pronto (e57b523 / patch 0011), FALTA testar e aplicar.** `FURNITURE` 1.25→0.85 em `World/HouseProps.luau`; cama, mesa baixa, guarda-roupa e tapetes mantêm tamanho (`KEEP`) por cobrirem colisões antigas |
| 5 | Móveis sem colisão (atravessa sofá/mesa/estante) | pendente. Sugestão: caixa invisível `CanCollide=true, CanQuery=false` do tamanho da base dos móveis grandes; depois rodar HouseNavigation |
| 6 | Restos primitivos: blocos cinza na estante da Sala; caixote liso no chão; bloquinho amarelo na parede (vela por cômodo do `HouseBuilder`); bloco vermelho na Cozinha; caixote no corredor antes da "PASSAGEM SELADA" | pendente |
| 7 | Itens de missão em bloco (fusível = bloco bege; chave/moeda em cima de caixote) | pendente. Trocar só o visual (`Campaign/HouseActivities`), manter peça, prompt, atributos, tags, colisão |
| 8 | Guarda-roupa do esconderijo horrível (meu modelo + `WardrobeLeaf` soldada à HideDoor em `HouseProps.wardrobeDoor`) | pendente. Modelo bom, porta própria; HideDoor, prompt e câmera intactos |
| 9 | Portas dos cômodos horríveis (`MansionDoor`, `HouseFinish.dressDoor`) | pendente |
| 10 | Sofá feio/fora do estilo (Sofa_01 creme) | pendente. Vitoriano, escuro, gasto |
| 11 | Grama do Terrain feia (lâminas enormes amarelo-oliva) | pendente. Menor GrassLength, cor mais escura/fria, ou Decoration=false |
| — | Testes que faltam | celular físico; partida humana completa (som da chuva x avisos da criatura); câmera dentro do guarda-roupa; floresta com lanterna; mouse físico |

## 4. Como aplicar no place sem Script Sync (o que funcionou)

1. Projeto Rojo só com os arquivos alterados (pastas espelhando ReplicatedStorage/ServerScriptService) →
   `rojo build x.project.json --output "<pasta do RobloxStudioBeta.exe>/content/X.rbxm"`.
2. Studio com o tungtung aberto, MCP `execute_luau` em **Edit**: `game:GetObjects("rbxasset://X.rbxm")[1]`; para cada
   script: existente → `ScriptEditorService:UpdateSourceAsync`, novo → `Clone().Parent`; tudo dentro de
   `ChangeHistoryService:TryBeginRecording`.
3. **Antes**, comparar o Source do place (soma de verificação) com a versão esperada — nunca sobrescrever trabalho alheio.
4. Play local → `require(game.ServerScriptService.Tests.Run)()` → `LogService` sem erros. Parar o Play.

## 5. Dicas que custaram caro

- Com duas ou mais janelas do Studio abertas, a captura de tela do MCP derruba o Studio. Use uma só.
- `screen_capture` vem com um quadro de atraso: posicione a câmera, espere, capture.
- Câmera de QA no cliente: `PlayerGui.LightingQA.Probe:Invoke("camera", pos, alvo)`; esconder HUD desabilitando ScreenGuis.
- `Terrain.Decoration`/`GrassLength` não são acessíveis por script; mudar pelo painel Properties.
- Assets enviados estão na conta do humano (mesma do tungtung). IDs de texturas em `tools/environment/texture_ids.json`.
- Docs completos da reforma: `docs/environment/` (AUDIT, ASSET_SOURCES, ASSET_REPLACEMENTS, ENVIRONMENT_QA).
