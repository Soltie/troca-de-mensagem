--!strict
--[[
	Ciclo de vida determinístico de Services (servidor) e Controllers (cliente).

	1. Valida a lista: cada módulo é uma tabela com `Name` único e `Init`/`Start` opcionais.
	2. Chama `Init()` de todos, na ordem da lista (preparar estado, conectar dependências).
	3. Chama `Start()` de todos, na mesma ordem (começar a trabalhar; loops longos via task.spawn).

	Qualquer erro interrompe o boot com uma mensagem clara, por exemplo:
		[Server] Init failed in PlayerDataService: <erro + traceback>

	Puro: roda no Roblox e no Lune.
]]

export type Module = {
	Name: string,
	Init: (() -> ())?,
	Start: (() -> ())?,
}

export type Options = {
	-- Prefixo das mensagens de erro, ex.: "Server" ou "Client".
	label: string,
}

type Phase = "Init" | "Start"

local Loader = {}

function Loader.validate(label: string, modules: { any }): { Module }
	local seen: { [string]: boolean } = {}
	for index, module in modules do
		if type(module) ~= "table" then
			error(`[{label}] module #{index} is not a table (got {typeof(module)})`, 0)
		end
		local name = module.Name
		if type(name) ~= "string" or name == "" then
			error(`[{label}] module #{index} is missing a non-empty string "Name"`, 0)
		end
		if seen[name] then
			error(`[{label}] duplicate module name "{name}"`, 0)
		end
		seen[name] = true
		for _, hook in { "Init", "Start" } do
			local fn = module[hook]
			if fn ~= nil and type(fn) ~= "function" then
				error(`[{label}] {name}.{hook} must be a function (got {typeof(fn)})`, 0)
			end
		end
	end
	return modules :: { Module }
end

local function runPhase(label: string, phase: Phase, modules: { Module })
	for _, module in modules do
		local fn = if phase == "Init" then module.Init else module.Start
		if fn then
			local ok, err = xpcall(fn, debug.traceback)
			if not ok then
				error(`[{label}] {phase} failed in {module.Name}: {err}`, 0)
			end
		end
	end
end

-- Executa Init e depois Start de todos os módulos. Retorna quantos módulos subiram.
function Loader.boot(modules: { any }, options: Options): number
	local validated = Loader.validate(options.label, modules)
	runPhase(options.label, "Init", validated)
	runPhase(options.label, "Start", validated)
	return #validated
end

return Loader
