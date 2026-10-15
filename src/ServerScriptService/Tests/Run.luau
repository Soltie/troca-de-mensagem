--!strict
--[[
	Runner de testes dentro do Studio. Rode via MCP (execute_luau, datamodel_type = "Server",
	com o playtest rodando):

		return require(game:GetService("ServerScriptService").Tests.Run)()

	Retorna o relatório em texto; a primeira linha é "[Tests] N passed, M failed, K skipped specs".
	Fora do Studio, os specs puros rodam com: lune run scripts/test
]]

local TestKit = require("./TestKit")

local function loadSpecs(folder: Instance): { TestKit.Spec }
	local modules: { ModuleScript } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(modules, child)
		end
	end
	table.sort(modules, function(a, b)
		return a.Name < b.Name
	end)

	local specs: { TestKit.Spec } = {}
	for _, module in modules do
		local ok, result = pcall(require :: any, module)
		if ok then
			table.insert(specs, result)
		else
			local message = tostring(result)
			table.insert(specs, {
				name = module.Name,
				run = function()
					error(`failed to load spec: {message}`, 0)
				end,
			})
		end
	end
	return specs
end

return function(): string
	local folder = (script.Parent :: Instance):FindFirstChild("Specs")
	assert(folder, "[Tests] Specs folder not found next to Run")
	local report = TestKit.run(loadSpecs(folder), { includeRobloxOnly = true })
	local text = TestKit.format(report)
	if report.failed > 0 then
		warn(text)
	else
		print(text)
	end
	return text
end
