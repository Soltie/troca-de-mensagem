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
5. **Console**: `get_console_output`. Esperado, sem erros/warnings inesperados:
   - `[Server] boot OK (N services)`
   - `[Client] boot OK (N controllers)`
   - `[PingController] ping OK: "hello" ...` (smoke test; some se o Ping for removido)
6. **Testes**: `execute_luau` com `datamodel_type = "Server"`:
   ```lua
   return require(game:GetService("ServerScriptService").Tests.Run)()
   ```
   Primeira linha deve ser `[Tests] N passed, 0 failed, 0 skipped specs`.
7. **Visual (UI)**: `screen_capture` e confirme o HUD/UI esperado.
8. **Simular jogador** (se precisar): `character_navigation`, `user_keyboard_input`, `user_mouse_input`.
9. **Parar**: `start_stop_play` (parar). Sempre pare no fim.
10. Erro? Corrija no ARQUIVO em `src/`, rode o check, volte ao passo 3. Nunca corrija no Studio.

## Dicas

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
