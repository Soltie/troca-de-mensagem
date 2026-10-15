# Passos manuais (só um humano faz)

Pasta do projeto: `C:\Users\xpg\Documents\roblox-teste`

## Primeira configuração

- [x] **0. Instalar e logar no Roblox Studio.** (feito em 2026-10-14)
- [ ] **1. Ativar o Script Sync (beta).** No Studio: menu **File** → **Beta Features** → marque
      **Script Sync** → **Save** → reinicie o Studio quando ele pedir.
      (Se não aparecer na lista, atualize o Studio.)
- [ ] **2. Abrir a place de trabalho.** **File** → **Open from File…** (Ctrl+O) →
      `C:\Users\xpg\Documents\roblox-teste\places\Dev.rbxlx`
      (só tem o mundo base; o código entra no passo 4).
- [ ] **3. Ligar o MCP.** Botão **Assistant** (canto superior direito) → **⋯** → **Manage MCP Servers**
      → ligue **Enable Studio as MCP server**. Não precisa ligar nada em *Quick connect*:
      o Claude Code já está configurado.
- [ ] **4. Conectar o Script Sync (2 serviços).** No **Explorer**:
      1. botão direito em **ServerScriptService** → **Script Sync** → **Sync to…** → escolha a pasta
         `C:\Users\xpg\Documents\roblox-teste\src` (a pasta `src` em si, não as de dentro) → **Save**.
      2. Se abrir o diálogo de diferenças: clique **Keep Disk** (nunca *Keep Studio* aqui).
      3. Repita para **ReplicatedStorage**.
      4. **Não** sincronize StarterPlayerScripts (o cliente fica em ReplicatedStorage; ver DECISIONS D2).
- [ ] **5. Salvar a place.** **Ctrl+S** (fica em `places/Dev.rbxlx`).
- [ ] **6. Reiniciar o Claude** para carregar as ferramentas do MCP: feche o app Claude por completo,
      abra de novo, volte a esta sessão e responda **"feito"**.
      Em uma sessão nova nesta pasta, diga:
      > Leia docs/SETUP_REPORT.md e continue a partir de "Estado atual / próximo passo".

Se algum prompt de administrador/UAC aparecer em qualquer passo, aceite (é do instalador/atualizador do Studio).

## Toda vez que for trabalhar

1. Abra o Studio → `places/Dev.rbxlx` (o Script Sync retoma sozinho; se aparecer conflito, **Keep Disk**).
2. Confirme que **Enable Studio as MCP server** continua ligado (Assistant → ⋯ → Manage MCP Servers).
3. Abra o Claude Code nesta pasta e peça a tarefa.

## Opcional (quando decidir)

- **Repositório remoto:** criar no GitHub e dar push (o agente não faz isso).
- **Publicar a experiência / DataStore real no Studio:** publicar pelo Studio e ligar
  *Game Settings → Security → Enable Studio Access to API Services*. Com isso o PlayerData sai do mock
  (no Studio usa o store `PlayerData_v1_Studio`).
- **Secrets / HTTP:** *Allow HTTP Requests* e Local Secrets ficam em Experience Settings → Security.
- **macOS:** o MCP é `claude mcp add --scope user --transport stdio Roblox_Studio -- /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP`.
