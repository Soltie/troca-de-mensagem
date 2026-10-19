local fs = require('@lune/fs')
local roblox = require('@lune/roblox')
local serde = require('@lune/serde')
local path = 'build/TungTung_BACKUP_ANTES_CODEX_20261019.rbxl'
local data = roblox.deserializePlace(fs.readFile(path))
local report = { backup = path, instances = 0, scripts = 0, identical = {}, different = {}, onlyStudio = {}, onlyDisk = {}, services = {} }
local seen = {}
for _, service in data:GetChildren() do
 table.insert(report.services, service.Name)
end
local function visit(inst, prefix)
 report.instances += 1
 local current = prefix == '' and inst.Name or prefix .. '/' .. inst.Name
 if inst:IsA('LuaSourceContainer') then
  report.scripts += 1
  local ext = inst.ClassName == 'ModuleScript' and '.luau' or (inst.ClassName == 'LocalScript' and '.local.luau' or '.server.luau')
  local file = 'src/' .. current .. ext
  if not fs.isFile(file) and inst.ClassName == 'Script' then
   local client = 'src/' .. current .. '.client.luau'
   if fs.isFile(client) then file = client end
  end
  seen[file] = true
  if fs.isFile(file) then
   local disk = fs.readFile(file):gsub('\r\n', '\n')
   local source = inst.Source:gsub('\r\n', '\n')
   table.insert(disk == source and report.identical or report.different, file)
  else table.insert(report.onlyStudio, current) end
 end
 for _, child in inst:GetChildren() do visit(child, current) end
end
for _, service in data:GetChildren() do visit(service, '') end
local function scan(dir)
 for _, entry in fs.readDir(dir) do
  local file = dir .. '/' .. entry
  if fs.isDir(file) then scan(file)
  elseif file:match('%.luau$') and not seen[file] then table.insert(report.onlyDisk, file) end
 end
end
scan('src')
local out = 'docs/environment/BACKUP_RECONCILIATION.json'
fs.writeFile(out, serde.encode('json', report, true))
print(serde.encode('json', { instances = report.instances, scripts = report.scripts, identical = #report.identical, different = #report.different, onlyStudio = #report.onlyStudio, onlyDisk = #report.onlyDisk, services = report.services }, true))
