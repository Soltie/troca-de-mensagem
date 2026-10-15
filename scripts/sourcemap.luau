--[[
	Gera sourcemap.json (usado pelo luau-lsp para resolver a DataModel).
	Uso: lune run scripts/sourcemap
	No VS Code, a extensão luau-lsp já regenera sozinha (luau-lsp.sourcemap.autogenerate).
]]

local process = require("@lune/process")

local Tools = require("./lib/Tools")

Tools.assertRepoRoot()
local result = Tools.sourcemap()
if result.ok then
	print(`[sourcemap] ok -> {Tools.SOURCEMAP}`)
	process.exit(0)
end
print(result.output)
print(`[sourcemap] FAIL (exit {result.code})`)
process.exit(1)
