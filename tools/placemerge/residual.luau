-- Para cada conflito: linhas novas do place (fora da base) que NÃO estão no disco.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local backupPath, base, list = process.args[1], process.args[2], process.args[3]
local function norm(s) return (string.gsub(s, "\r\n", "\n")) end
local function lines(s)
	local t = {}
	for l in string.gmatch(s .. "\n", "(.-)\n") do t[string.match(l, "^%s*(.-)%s*$")] = true end
	return t
end
local model = roblox.deserializeModel(fs.readFile(backupPath))
local root = model[1]
for path in string.gmatch(list, "[^,]+") do
	local node = root
	for part in string.gmatch(path, "[^%.]+") do node = node and node:FindFirstChild(part) end
	local rel = "src/" .. string.gsub(path, "%.", "/")
	local file
	for _, c in { rel .. ".luau", rel .. ".server.luau", rel .. ".client.luau" } do if fs.isFile(c) then file = c end end
	local placeSrc = norm(node.Source)
	local b = process.exec("git", { "show", base .. ":" .. file })
	local baseL = lines(if b.ok then norm(b.stdout) else "")
	local diskL = lines(norm(fs.readFile(file)))
	local residual = {}
	for l in string.gmatch(placeSrc .. "\n", "(.-)\n") do
		local k = string.match(l, "^%s*(.-)%s*$")
		if k ~= "" and not baseL[k] and not diskL[k] then table.insert(residual, l) end
	end
	print(`### {path}: {#residual} linhas só do place`)
	for i = 1, math.min(#residual, 12) do print("  " .. residual[i]) end
end
