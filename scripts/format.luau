--[[
	Aplica a formatação do StyLua em src/ e scripts/.
	Uso: lune run scripts/format
]]

local process = require("@lune/process")

local Tools = require("./lib/Tools")

Tools.assertRepoRoot()
local result = Tools.run("stylua", { "src", "scripts" })
print(if result.ok then "[format] ok" else `[format] FAIL (exit {result.code})`)
process.exit(if result.ok then 0 else 1)
