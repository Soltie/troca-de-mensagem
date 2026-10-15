---
name: script-sync
description: Verificar e diagnosticar o Script Sync do Roblox Studio (src/ <-> Studio) - status com InstanceFileSyncService, regras de nome de arquivo e o que fazer quando um arquivo não aparece no Studio. Use quando um arquivo novo/alterado/apagado não refletir no Studio.
---

# Script Sync

Mapeamento (configurado uma vez pelo humano, "Sync to" apontando para `src/`):

| Disco | Studio |
| --- | --- |
| `src/ServerScriptService/` | `ServerScriptService` |
| `src/ReplicatedStorage/` | `ReplicatedStorage` |

Nomes: `X.luau` ModuleScript, `X.server.luau` Script (Server), `X.client.luau` Script (Client),
`X.local.luau` LocalScript, pasta = Folder. Só Script/LocalScript/ModuleScript/Folder sincronizam.

## Verificar status (MCP)

`execute_luau`, `datamodel_type = "Edit"`:
```lua
local fss = game:GetService("InstanceFileSyncService")
local out = {}
for _, svc in { game:GetService("ServerScriptService"), game:GetService("ReplicatedStorage") } do
	table.insert(out, svc.Name .. "=" .. fss:GetStatus(svc).Name)
	for _, d in svc:GetDescendants() do
		local status = fss:GetStatus(d)
		if status ~= Enum.InstanceFileSyncStatus.SyncedAsDescendant then
			table.insert(out, d:GetFullName() .. "=" .. status.Name)
		end
	end
end
return table.concat(out, "\n")
```
Esperado: as raízes `SyncedAsRoot` e nenhuma outra linha (tudo `SyncedAsDescendant`).
`Errored`/`AncestorErrored` = sync parado; peça ao humano para resolver o diálogo no Studio.

## Quando algo não aparece

1. Nome inválido/duplicado ou caractere estranho? Corrija o nome do arquivo.
2. Arquivo fora de `src/ServerScriptService` ou `src/ReplicatedStorage`? Não sincroniza.
3. Status `Errored`? Há um diálogo de conflito no Studio: o humano escolhe **Keep Disk**.
4. Nunca edite um script sincronizado pelo Studio (`multi_edit`) - edite o arquivo.
5. Nunca rode `rojo serve` junto com o Script Sync (dois escritores = conflito).
6. Não apague a pasta raiz sincronizada no disco (erro no Studio). Apague só filhos.
