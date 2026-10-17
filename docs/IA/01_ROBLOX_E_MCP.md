# Computador novo: disco, Studio e IA

Este guia é para a IA do colega executar o que for possível e reunir em um único checkpoint o que exigir interface/login do humano. Use os caminhos do computador dele, nunca os caminhos C:/Users/xpg dos relatórios históricos. Não transfira cookies, credenciais, perfis de editor ou configurações privadas do computador original.

## Três conexões diferentes

| Sistema | Função | O que não faz |
| --- | --- | --- |
| Git / GitHub / bundle | transporta fonte, assets versionados, docs e histórico | não sincroniza o Studio nem dá permissão Roblox |
| Script Sync | liga o src/ local aos scripts de uma place | não faz merge Git nem leva Parts, Models, Terrain, tags e propriedades como backup completo |
| MCP oficial Roblox_Studio | permite à IA inspecionar e testar o Studio aberto na mesma máquina | não clona o repo nem conecta o Script Sync sozinho |

Um clone não herda a instalação das ferramentas, a sessão da IA, os logins, o MCP nem o vínculo do Script Sync. Cada PC tem configuração própria. Cada jogo precisa de raiz de código e place próprias.

## Preparar ferramentas

1. Instalar Git, Roblox Studio e Rokit a partir das origens oficiais; entrar no Studio com a conta do colega.
2. Obter este repositório por clone GitHub ou pelo bundle descrito em [compartilhamento](05_COLABORACAO_E_ENVIO.md).
3. Abrir terminal na RAIZ deste projeto, onde existem rokit.toml, src/ e default.project.json.
4. Executar:

~~~powershell
git status --short
git branch --show-current
rokit install
lune run scripts/check
~~~

rokit.toml fixa Rojo 7.7.1, selene 0.32.0, StyLua 2.5.2, luau-lsp 1.70.1 e Lune 0.10.5. Se o terminal não encontrar as ferramentas após instalar, reabrir o terminal e verificar o PATH do Rokit. Não substituir versões para esconder uma falha de check.

Python NÃO é necessário para jogar, criar builds ou rodar os checks Luau. Python 3.10+ é apenas opcional para regenerar o índice de documentação.

## Escolher como usar o Studio

**Só jogar/testar uma versão:** executar:

~~~powershell
lune run scripts/build
~~~

Abrir build/Test.rbxlx. É uma cópia descartável com mundo + código + assets que o projeto Rojo inclui. Não conectar Script Sync a ela. O mesmo vale para a build pronta com o nome do jogo. Um erro corrigido no src/ exige REBUILD e reabrir a build; o arquivo já aberto não se atualiza sozinho.

**Editar código continuamente:** para preservar também os assets não transportados pelo sync, preferir copiar a build completa para um NOVO arquivo local de trabalho; abrir essa cópia, conferir o conteúdo e conectar o src/ correto. Alternativa do template:

~~~powershell
lune run scripts/build dev
~~~

O alvo dev cria places/Dev.rbxlx só com o mundo base e recusa sobrescrever arquivo existente. Não usar --force para contornar essa proteção. Numa Dev sem scripts, o sync leva os scripts; modelos binários como Assets/TungTung.rbxm NÃO chegam por Script Sync. No Sahur, usar a cópia de build completa ou importar o modelo local deliberadamente, conferir Assets/TungTung e validar a criatura.

## Ligar Script Sync na place LOCAL correta

No Explorer, botão direito em ServerScriptService → Script Sync → Sync to… → escolher a pasta src/ deste clone. O Studio acrescenta o nome do serviço: confirmar que o resultado é src/ServerScriptService, sem ServerScriptService/ServerScriptService duplicado. Repetir para ReplicatedStorage apontando para o MESMO src/ deste jogo. Diante do diálogo, inspecionar diferenças e escolher Keep Disk para carregar o código versionado.

Não conectar StarterPlayerScripts/StarterCharacterScripts. O bootstrap cliente está em ReplicatedStorage/Client/Main.client.luau. Não executar rojo serve.

Salvar a place local. Conferir pelo Reveal in Explorer e pela leitura dos Sources que as duas raízes apontam para este clone. Não presumir que um status de sync prova que a pasta de destino é a correta.

No MCP, executar somente leitura em Edit:

~~~lua
local sync = game:GetService("InstanceFileSyncService")
local result = {}
for _, name in { "ServerScriptService", "ReplicatedStorage" } do
    local service = game:GetService(name)
    result[name] = sync:GetStatus(service).Name
end
return game:GetService("HttpService"):JSONEncode(result)
~~~

Esperado: ambas SyncedAsRoot. Conferir scripts/Folder descendentes como SyncedAsDescendant usando a receita em [.agents/skills/script-sync](../../.agents/skills/script-sync/SKILL.md). Assets binários não são sincronizados; não interpretar o estado de um Model como falha de transporte de um script.

Se surgir Errored/AncestorErrored, resolver o conflito; se a pasta estiver duplicada, parar o sync mantendo arquivos e refazer o destino. Não apagar a raiz src/ nem escolher Keep Studio sobre fontes sem antes preservar o que houver na place.

## Conectar a IA pelo MCP oficial

No Studio: Assistant → … → Manage MCP Servers → Enable Studio as MCP server. A interface também oferece Quick connect para clientes compatíveis; reiniciar o cliente da IA após configurar. Conferir o indicador de conexão e a existência local de %LOCALAPPDATA%/Roblox/mcp.bat no Windows. Orientação conferida em 17/10/2026 na [documentação oficial Roblox](https://create.roblox.com/docs/studio/mcp).

Para clientes que aceitam JSON MCP, adicionar apenas esta entrada à configuração existente; não sobrescrever outros servidores:

~~~json
{
  "mcpServers": {
    "Roblox_Studio": {
      "command": "cmd.exe",
      "args": ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
    }
  }
}
~~~

No macOS, o comando do servidor é /Applications/RobloxStudio.app/Contents/MacOS/StudioMCP, sem cmd.exe. Confira o caminho no Studio instalado.

**Claude Code (Windows, PowerShell):**

~~~powershell
claude mcp add --scope user --transport stdio Roblox_Studio -- cmd.exe /c "$env:LOCALAPPDATA\Roblox\mcp.bat"
claude mcp list
~~~

**Codex CLI (Windows, PowerShell):**

~~~powershell
codex mcp add Roblox_Studio -- cmd.exe /c "$env:LOCALAPPDATA\Roblox\mcp.bat"
codex mcp list
~~~

Alternativa para Codex: adicionar uma tabela em ~/.codex/config.toml, preservando o restante:

~~~toml
[mcp_servers.Roblox_Studio]
command = "cmd.exe"
args = ["/c", "%LOCALAPPDATA%\\Roblox\\mcp.bat"]
~~~

A sintaxe de cadastro STDIO e a configuração TOML foram conferidas na [documentação oficial OpenAI](https://developers.openai.com/codex/mcp). Estes exemplos não foram executados no PC do colega. Se o cliente tiver integração gerenciada pelo app/plugin, usar a configuração oferecida por ele e evitar um cadastro duplicado. Uma conversa web sem acesso ao processo local não ganha controle do Studio apenas por receber este documento.

## Aceite da configuração: a IA precisa provar

- git aponta para a raiz e o branch esperados; nenhum remote de outro jogo foi reutilizado por engano.
- check termina ALL GREEN; a build completa abre.
- list_roblox_studios retorna a instância escolhida; anotar o studio_id ATUAL, não copiar IDs deste PC.
- get_studio_state identifica Edit/Play; ler um trecho de cada Main em Edit e comparar ao disco.
- No fluxo com sync: duas raízes corretas e scripts sincronizados. No fluxo build: identificar o arquivo e o commit que a gerou.
- Play, console, runner Server e captura cliente funcionam; encerrar somente o Play iniciado pela própria IA.

Se algo depender do humano, entregar de uma vez: ferramenta ausente, login, janela correta, opção de MCP, diálogo de sync e acesso Roblox/GitHub necessário. Depois do “feito”, verificar cada item. Não começar a adicionar gameplay antes desse aceite.

Referências adicionais: [Script Sync](https://create.roblox.com/docs/scripting/sync), [Rokit](https://github.com/rojo-rbx/rokit), [Git](https://git-scm.com/downloads).
