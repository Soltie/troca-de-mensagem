---
name: roblox-playtest
description: Ciclo de teste no Roblox Studio via MCP oficial (Roblox_Studio) - achar o studio_id, rodar playtest, ler console, rodar testes com execute_luau, screen_capture e parar. Use depois de editar código em src/ ou quando pedirem para testar/verificar algo no Studio.
---

# Playtest via MCP (Roblox_Studio)

Pré-requisito: `lune run scripts/check` verde. Studio aberto com `places/Dev.rbxlx` e Script Sync ativo.

## Passo a passo

1. **studio_id**: `list_roblox_studios` -> pegue o `studio_id` da place "Dev". TODA chamada leva `studio_id`.
2. **Estado**: `get_studio_state`. Se já estiver em Play, pare antes (`start_stop_play`) para começar limpo.
3. **Sync chegou?** (antes do Play) `execute_luau` com `datamodel_type = "Edit"`:
   ```lua
   local s = game:GetService("ServerScriptService"):FindFirstChild("Server")
   return s and s.Main.Source:sub(1, 120) or "MISSING"
   ```
   Confira que o trecho bate com o arquivo em disco. Status do sync: ver skill `script-sync`.
4. **Play**: `start_stop_play` (iniciar). Espere ~3-5 s.
5. **Console**: prefira o filtro abaixo (economiza contexto) em `execute_luau`, uma vez com
   `datamodel_type = "Server"` e outra com `"Client"`. `get_console_output` também funciona, mas traz
   o log inteiro, incluindo stack traces da Roblox.
   ```lua
   local out = {}
   for _, e in game:GetService("LogService"):GetLogHistory() do
   	if not string.find(e.message, "CorePackages", 1, true) then
   		table.insert(out, e.messageType.Name .. ": " .. string.sub(e.message, 1, 200))
   	end
   end
   return table.concat(out, "\n")
   ```
   Esperado (sem `MessageWarning`/`MessageError` inesperados):
   - Server: `[WorldService] world built: N parts`, `[Server] boot OK (5 services)`,
     `[RoundService] phase Loading -> Intro`, depois `Intro -> Playing` (9 s)
   - Client: `[Client] boot OK (10 controllers)`, `[AdemirPortrait] Local portrait ready`
   - Ignore `[Roblox][CorePackages...UIBlox] FoundationProvider not found` (CoreScripts da Roblox, não é nosso).
6. **Testes**: `execute_luau` com `datamodel_type = "Server"`:
   ```lua
   return require(game:GetService("ServerScriptService").Tests.Run)()
   ```
   Primeira linha deve ser `[Tests] N passed, 0 failed, 0 skipped specs`.
7. **Visual (UI)**: `screen_capture` e confirme o HUD/UI esperado.
8. **Simular jogador** (se precisar): `character_navigation`, `user_keyboard_input`, `user_mouse_input`.
   Receita testada para a SUBESTAÇÃO 9 (seção abaixo).
9. **Parar**: `start_stop_play` (parar). Sempre pare no fim.
10. Erro? Corrija no ARQUIVO em `src/`, rode o check, volte ao passo 3. Nunca corrija no Studio.

## Roteiro de rodada (SUBESTAÇÃO 9)

1. Espere `GameState.Phase == "Playing"` (atributo em `ReplicatedStorage.GameState`).
2. Estado real: `game.ServerStorage.DebugBridge:Invoke("state")` (Server). NÃO use `require` de
   services no `execute_luau`: ele cria cópias novas, com estado zerado.
3. Posição dos fusíveis: `workspace.Substation9.Pickups.Fuses`. Onde ficar de pé:
   `Layout.FuseStands` / `Layout.Stands` (`Server/World/Layout.luau`).
4. Andar: `character_navigation` em trechos curtos (ex.: recepção `(-4, 3, -9)` → sala). O agente
   do MCP é mais largo que o jogador e atravessa portas fechadas no planejamento (região
   PassThrough): se parar diante de uma porta, abra-a com E.
5. Mirar: `user_mouse_input` NÃO gira a câmera travada (LockCenter). No cliente:
   `workspace.CurrentCamera.CFrame = CFrame.lookAt(cam.CFrame.Position, alvo)` (a câmera Classic mantém).
   Confira `PlayerGui.GameUi.Prompt` (texto "[E] ..." e Visible).
6. Agir: `user_keyboard_input` keyPress `E`; reiniciar nas telas finais: `R`.
7. Automação lenta é pega pelo Vigia: congele-o só para o percurso (`Invoke("freezeCreature", true)`).
   A captura/perseguição se testa à parte: `awaken` + `placeCreature` a menos de 7 studs do jogador.
8. Esperado: fusível some e `FusesHeld` sobe. Um 2º `Interact` no mesmo id volta `not_available`.
   O portão sem energia volta "SEM ENERGIA". Depois do quadro: `PowerOn` e 17 luzes. Portão + saída: `Won`.
   R restaura fusíveis, portas, quadro, portão, luzes e criatura.
9. FPS: `game:GetService("Stats").FrameTime` e o painel F3 (`PlayerGui.DebugHud`). Com o Studio em
   segundo plano o quadro fica limitado a ~15 FPS (66,7 ms constantes); compare com
   `RenderCPUFrameTime`/`RenderGPUFrameTime`.

## Dicas

- Testar a rede como um cliente malicioso: `execute_luau` em `Client` chamando
  `ReplicatedStorage.Remotes.<Nome>:InvokeServer(...)` com tipos errados, argumentos a mais e flood;
  o esperado é `invalid_arguments` / `rate_limited` no envelope `Result`.

- Para inspecionar a árvore, filtre por caminho e profundidade (`search_game_tree` com path, ex.
  `ReplicatedStorage/Shared`, depth 2). Ignore CoreGui/CoreScripts.
- Se `search_game_tree`/`inspect_instance`/`script_grep`/`script_search` voltarem só um resumo de
  uma linha (bug conhecido), use `execute_luau` (Edit) e retorne JSON:
  ```lua
  local HttpService = game:GetService("HttpService")
  local root, out = game:GetService("ReplicatedStorage"), {}
  local function walk(inst, depth, path)
  	for _, c in inst:GetChildren() do
  		local p = path .. "/" .. c.Name
  		table.insert(out, p .. " (" .. c.ClassName .. ")")
  		if depth > 1 then walk(c, depth - 1, p) end
  	end
  end
  walk(root, 3, root.Name)
  return HttpService:JSONEncode(out)
  ```
- `execute_luau` no datamodel "Edit" ALTERA a place. Use só para leitura, salvo pedido explícito.
- Não use `generate_*`, `insert_asset`, `upload_image` sem o humano pedir.
