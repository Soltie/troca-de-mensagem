--[[
	Helpers compartilhados pelos scripts Lune (scripts/*.luau).
	Todos os scripts assumem que o diretório atual é a raiz do repositório.
]]

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Tools = {}

Tools.CACHE_DIR = ".cache"
Tools.SOURCEMAP = "sourcemap.json"
Tools.PROJECT = "default.project.json"

function Tools.assertRepoRoot()
	if not fs.isFile("rokit.toml") or not fs.isFile(Tools.PROJECT) then
		print("[scripts] rode a partir da raiz do repositório (onde estão rokit.toml e default.project.json)")
		process.exit(2)
	end
end

export type RunResult = {
	ok: boolean,
	code: number,
	output: string,
}

-- Executa uma ferramenta. `quiet` captura a saída (para filtrar/mostrar depois);
-- caso contrário a saída vai direto para o terminal.
function Tools.run(program: string, args: { string }, quiet: boolean?): RunResult
	local ok, result = pcall(process.exec, program, args, {
		stdio = if quiet then "default" else "forward",
	})
	if not ok then
		return { ok = false, code = -1, output = `failed to start {program}: {result}` }
	end
	return {
		ok = result.ok,
		code = result.code,
		output = (result.stdout or "") .. (result.stderr or ""),
	}
end

-- Versão fixada de uma ferramenta no rokit.toml (ex.: "1.70.1").
function Tools.pinnedVersion(tool: string): string
	local manifest = serde.decode("toml", fs.readFile("rokit.toml"))
	local spec = manifest.tools and manifest.tools[tool]
	assert(type(spec) == "string", `tool "{tool}" not found in rokit.toml`)
	local version = string.match(spec, "@(.+)$")
	assert(version, `tool "{tool}" has no pinned version in rokit.toml`)
	return version
end

-- Baixa (uma vez) as definições de tipos do Roblox usadas pelo luau-lsp analyze,
-- do repositório oficial do luau-lsp, na MESMA tag fixada no rokit.toml.
-- Nível de segurança "None" = o que scripts de jogo podem acessar.
function Tools.robloxDefinitions(): string
	local version = Tools.pinnedVersion("luau-lsp")
	local path = `{Tools.CACHE_DIR}/globalTypes.None.{version}.d.luau`
	if fs.isFile(path) then
		return path
	end
	if not fs.isDir(Tools.CACHE_DIR) then
		fs.writeDir(Tools.CACHE_DIR)
	end
	local url = `https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/{version}/scripts/globalTypes.None.d.luau`
	print(`[scripts] baixando definições Roblox: {url}`)
	local response = net.request(url)
	assert(response.ok, `download failed ({response.statusCode}): {url}`)
	fs.writeFile(path, response.body)
	return path
end

function Tools.sourcemap(): RunResult
	return Tools.run("rojo", { "sourcemap", Tools.PROJECT, "--output", Tools.SOURCEMAP }, true)
end

return Tools
