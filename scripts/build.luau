--[[
	Gera places com `rojo build`.

	  lune run scripts/build
	      -> build/Test.rbxlx: mundo base + TODO o código de src/ (place descartável para
	         testes/inspeção; não use com Script Sync).

	  lune run scripts/build dev [--force]
	      -> places/Dev.rbxlx: SÓ o mundo base, sem scripts. É a place de trabalho que
	         você abre no Studio; o código entra pelo Script Sync (escolha "Keep Disk").
	         Por segurança, não sobrescreve uma place existente sem --force (você perderia
	         o que fez no Studio e a configuração do Script Sync).
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local Tools = require("./lib/Tools")

Tools.assertRepoRoot()

local target = process.args[1]
local force = table.find(process.args, "--force") ~= nil

local project, output
if target == nil or target == "test" then
	project, output = Tools.PROJECT, "build/Test.rbxlx"
	if not fs.isDir("build") then
		fs.writeDir("build")
	end
elseif target == "dev" then
	project, output = "places/Dev.project.json", "places/Dev.rbxlx"
	if fs.isFile(output) and not force then
		print(`[build] {output} já existe; não vou sobrescrever. Use --force se tiver certeza.`)
		process.exit(1)
	end
else
	print(`[build] alvo desconhecido "{target}". Use: (vazio) | test | dev [--force]`)
	process.exit(2)
end

local result = Tools.run("rojo", { "build", project, "--output", output })
if result.ok then
	print(`[build] ok -> {output}`)
	process.exit(0)
end
print(`[build] FAIL (exit {result.code})`)
process.exit(1)
