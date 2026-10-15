--[[
	Roda os specs puros fora do Studio (Lune). Specs com robloxOnly = true são pulados;
	esses rodam no Studio via MCP (ver src/ServerScriptService/Tests/Run.luau).

	Uso: lune run scripts/test
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local TestKit = require("../src/ServerScriptService/Tests/TestKit")

local SPEC_DIR = "src/ServerScriptService/Tests/Specs"

local files = {}
for _, entry in fs.readDir(SPEC_DIR) do
	if string.sub(entry, -5) == ".luau" then
		table.insert(files, entry)
	end
end
table.sort(files)

local specs = {}
for _, file in files do
	local modulePath = "../" .. SPEC_DIR .. "/" .. string.sub(file, 1, -6)
	local ok, result = pcall(function()
		return require(modulePath)
	end)
	if ok then
		table.insert(specs, result)
	else
		local message = tostring(result)
		table.insert(specs, {
			name = file,
			run = function()
				error(`failed to load spec: {message}`, 0)
			end,
		})
	end
end

local report = TestKit.run(specs, { includeRobloxOnly = false })
print(TestKit.format(report))
process.exit(if report.failed > 0 then 1 else 0)
