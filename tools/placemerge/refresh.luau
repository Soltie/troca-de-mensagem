-- Atualiza o patch.rbxm com o conteúdo final de <saida>/src (depois de format/ajustes).
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local outDir = process.args[1]
local model = roblox.deserializeModel(fs.readFile(outDir .. "/patch.rbxm"))
local patch = model[1]
local changed = 0
for _, value in patch:GetChildren() do
	local rel = outDir .. "/src/" .. string.gsub(value.Name, "%.", "/")
	for _, c in { rel .. ".luau", rel .. ".server.luau", rel .. ".client.luau" } do
		if fs.isFile(c) then
			local s = string.gsub(fs.readFile(c), "\r\n", "\n")
			if s ~= value.Value then
				value.Value = s
				changed += 1
			end
		end
	end
end
fs.writeFile(outDir .. "/patch.rbxm", roblox.serializeModel({ patch }))
print("entries", #patch:GetChildren(), "refreshed", changed)
