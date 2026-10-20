--[[
	Merge de 3 vias entre o place publicado e o repo (uso único da integração de 20/10/2026).

	lune run tools/placemerge/merge <backup.rbxmx> <base-commit> <saida-dir>

	- Lê os scripts do backup do place (pasta Backup_Place_* com ServerScriptService/ e ReplicatedStorage/).
	- Para cada script: base = git <base-commit>, nosso = disco (src/), deles = place.
	  place == disco: nada; place == base: fica o disco; disco == base: fica o place (copia para o disco);
	  senão `git merge-file` (conflito vira relatório e o script não é aplicado).
	- Scripts só do place vão para o disco (trazer PvP/Mansion para o repo); só do disco são criados no place.
	- Gera <saida>/patch.rbxm: Folder "ScriptPatch" com um StringValue por script a aplicar
	  (Name = caminho com pontos, Value = Source, atributos Class e RunContext) e <saida>/report.txt.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local backupPath, baseCommit, outDir = process.args[1], process.args[2], process.args[3]
assert(backupPath and baseCommit and outDir, "uso: merge <backup.rbxmx> <base> <saida>")
fs.writeDir(outDir)

local function norm(s: string): string
	return (string.gsub(s, "\r\n", "\n"))
end

-- Caminho de instância ("ServerScriptService.Server.Main") -> arquivo no repo.
local function fileFor(path: string, class: string, runContext: string?): string
	local rel = "src/" .. string.gsub(path, "%.", "/")
	for _, candidate in { rel .. ".luau", rel .. ".server.luau", rel .. ".client.luau", rel .. "/init.luau" } do
		if fs.isFile(candidate) then
			return candidate
		end
	end
	if class == "Script" then
		return rel .. (if runContext == "Client" then ".client.luau" else ".server.luau")
	elseif class == "LocalScript" then
		return rel .. ".client.luau"
	end
	return rel .. ".luau"
end

local function gitShow(file: string): string?
	local result = process.exec("git", { "show", baseCommit .. ":" .. file })
	return if result.ok then norm(result.stdout) else nil
end

-- Scripts do place.
local place: { [string]: { source: string, class: string, runContext: string? } } = {}
local model = roblox.deserializeModel(fs.readFile(backupPath))
local backup = model[1]
for _, svc in backup:GetChildren() do
	for _, d in svc:GetDescendants() do
		if d:IsA("LuaSourceContainer") then
			local parts = {}
			local node = d
			while node and node ~= backup do
				table.insert(parts, 1, node.Name)
				node = node.Parent
			end
			local path = table.concat(parts, ".")
			local rc = if d.ClassName == "Script" then tostring((d :: any).RunContext) else nil
			place[path] = { source = norm((d :: any).Source), class = d.ClassName, runContext = rc and string.match(rc, "%.(%w+)$") or rc }
		end
	end
end

-- Arquivos .luau do disco (src/ServerScriptService e src/ReplicatedStorage).
local diskPaths: { [string]: string } = {}
local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local full = dir .. "/" .. name
		if fs.isDir(full) then
			walk(full)
		elseif string.match(name, "%.luau$") then
			local inst = string.gsub(string.gsub(full, "^src/", ""), "%.server%.luau$", "")
			inst = string.gsub(string.gsub(inst, "%.client%.luau$", ""), "%.luau$", "")
			inst = string.gsub(string.gsub(inst, "/init$", ""), "/", ".")
			diskPaths[inst] = full
		end
	end
end
walk("src/ServerScriptService")
walk("src/ReplicatedStorage")

local patch = roblox.Instance.new("Folder")
patch.Name = "ScriptPatch"
local report = {}
local counts = { same = 0, applied = 0, toDisk = 0, conflict = 0, created = 0 }

local function emit(path: string, source: string, class: string, runContext: string?)
	local value = roblox.Instance.new("StringValue")
	value.Name = path
	value.Value = source
	value:SetAttribute("Class", class)
	if runContext then
		value:SetAttribute("RunContext", runContext)
	end
	value.Parent = patch
end

local function classOf(file: string): (string, string?)
	if string.match(file, "%.server%.luau$") then
		return "Script", "Server"
	elseif string.match(file, "%.client%.luau$") then
		return "Script", "Client"
	end
	return "ModuleScript", nil
end

-- O disco não é tocado: o que mudaria em src/ vai para <saida>/src (aplicar depois, com cuidado).
local function stage(file: string, content: string)
	local target = outDir .. "/" .. file
	fs.writeDir(string.match(target, "^(.*)/[^/]+$") :: string)
	fs.writeFile(target, content)
end

-- Resolução escolhida à mão por arquivo (<saida>/resolve.txt: "Caminho=ours|union|disk|place").
local resolve: { [string]: string } = {}
if fs.isFile(outDir .. "/resolve.txt") then
	for line in string.gmatch(fs.readFile(outDir .. "/resolve.txt"), "[^\r\n]+") do
		local k, v = string.match(line, "^%s*(.-)%s*=%s*(%a+)")
		if k then
			resolve[k] = v
		end
	end
end

local tmp = outDir .. "/tmp"
fs.writeDir(tmp)

for path, info in place do
	local file = fileFor(path, info.class, info.runContext)
	local disk = if fs.isFile(file) then norm(fs.readFile(file)) else nil
	if disk == nil then
		-- Só no place: traz para o repo.
		stage(file, info.source)
		counts.toDisk += 1
		table.insert(report, "PLACE->DISK (novo) " .. file)
	elseif disk == info.source then
		counts.same += 1
	else
		local base = gitShow(file)
		if base == info.source then
			emit(path, disk, info.class, info.runContext)
			counts.applied += 1
			table.insert(report, "DISK->PLACE " .. path)
		elseif base == disk then
			stage(file, info.source)
			counts.toDisk += 1
			table.insert(report, "PLACE->DISK " .. file)
		else
			local oursF, baseF, theirsF = tmp .. "/ours.luau", tmp .. "/base.luau", tmp .. "/theirs.luau"
			fs.writeFile(oursF, disk)
			fs.writeFile(baseF, base or "")
			fs.writeFile(theirsF, info.source)
			local mode = resolve[path]
			local flags = { "merge-file", "-p" }
			if mode == "ours" or mode == "union" then
				table.insert(flags, "--" .. mode)
			end
			for _, extra in { "-L", "disco", "-L", "base", "-L", "place", oursF, baseF, theirsF } do
				table.insert(flags, extra)
			end
			local merged = if mode == "disk"
				then { code = 0, stdout = disk }
				elseif mode == "place" then { code = 0, stdout = info.source }
				else process.exec("git", flags)
			if merged.code == 0 then
				local result = norm(merged.stdout)
				stage(file, result)
				if result ~= info.source then
					emit(path, result, info.class, info.runContext)
				end
				counts.applied += 1
				table.insert(report, "MERGE " .. path)
			else
				fs.writeFile(outDir .. "/conflict_" .. path .. ".luau", merged.stdout)
				counts.conflict += 1
				table.insert(report, `CONFLITO ({merged.code}) {path} -> {outDir}/conflict_{path}.luau`)
			end
		end
	end
end
for path, file in diskPaths do
	if not place[path] then
		local class, rc = classOf(file)
		emit(path, norm(fs.readFile(file)), class, rc)
		counts.created += 1
		table.insert(report, "CRIAR " .. path)
	end
end

table.sort(report)
table.insert(
	report,
	1,
	`iguais={counts.same} aplicar={counts.applied} disco<-place={counts.toDisk} criar={counts.created} conflitos={counts.conflict}`
)
fs.writeFile(outDir .. "/report.txt", table.concat(report, "\n"))
fs.writeFile(outDir .. "/patch.rbxm", roblox.serializeModel({ patch }))
print(report[1])
