--[[
	Checagem completa do repositório (o "verde" antes de qualquer commit):
	  1. format  - StyLua --check (src e scripts)
	  2. lint    - selene (src e scripts)
	  3. sourcemap - rojo sourcemap (para o luau-lsp entender a DataModel)
	  4. types   - luau-lsp analyze, modo strict, definições Roblox fixadas
	  5. tests   - specs puros no Lune (scripts/test)

	Uso: lune run scripts/check
	Todas as etapas rodam mesmo se uma falhar; exit code 1 se qualquer uma falhar.
	Para corrigir formatação automaticamente: lune run scripts/format
]]

local process = require("@lune/process")

local Tools = require("./lib/Tools")

Tools.assertRepoRoot()

type Step = {
	name: string,
	run: () -> Tools.RunResult,
}

-- Linhas de log informativo do luau-lsp que não são problemas do código.
local function filterLuauLsp(output: string): string
	local kept = {}
	for line in string.gmatch(output, "[^\r\n]+") do
		local noise = string.find(line, "^%[INFO%]") or string.find(line, "didChangeWatchedFiles", 1, true)
		if not noise then
			table.insert(kept, line)
		end
	end
	return table.concat(kept, "\n")
end

local steps: { Step } = {
	{
		name = "format (stylua --check)",
		run = function()
			return Tools.run("stylua", { "--check", "src", "scripts" })
		end,
	},
	{
		name = "lint (selene)",
		run = function()
			return Tools.run("selene", { "--display-style", "quiet", "src", "scripts" })
		end,
	},
	{
		name = "sourcemap (rojo)",
		run = function()
			return Tools.sourcemap()
		end,
	},
	{
		name = "types (luau-lsp analyze, strict)",
		run = function()
			local definitions = Tools.robloxDefinitions()
			local result = Tools.run("luau-lsp", {
				"analyze",
				"--platform=roblox",
				`--sourcemap={Tools.SOURCEMAP}`,
				`--definitions=@roblox={definitions}`,
				"src",
			}, true)
			local output = filterLuauLsp(result.output)
			if output ~= "" then
				print(output)
			end
			return { ok = result.ok, code = result.code, output = "" }
		end,
	},
	{
		name = "tests (lune run scripts/test)",
		run = function()
			return Tools.run("lune", { "run", "scripts/test" })
		end,
	},
}

local failed = {}
for index, step in steps do
	print(`\n[check {index}/{#steps}] {step.name}`)
	local result = step.run()
	if result.ok then
		print("  -> ok")
	else
		if result.output ~= "" then
			print(result.output)
		end
		print(`  -> FAIL (exit {result.code})`)
		table.insert(failed, step.name)
	end
end

print("")
if #failed == 0 then
	print("[check] ALL GREEN")
	process.exit(0)
else
	print(`[check] {#failed} step(s) failed: {table.concat(failed, ", ")}`)
	process.exit(1)
end
