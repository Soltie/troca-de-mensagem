-- Servidor HTTP local só para o upload_image do Studio MCP (lê .cache/env-assets). Uso: lune run tools/environment/serve 8765
local net = require("@lune/net")
local fs = require("@lune/fs")
local process = require("@lune/process")
local port = tonumber(process.args[1]) or 8765
local root = ".cache/env-assets/"
local types = { png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg" }
net.serve(port, function(request)
	local path = string.gsub(request.path, "%.%.", "")
	local file = root .. string.sub(path, 2)
	local ext = string.match(file, "%.(%w+)$")
	if ext and types[ext] and fs.isFile(file) then
		return { status = 200, headers = { ["Content-Type"] = types[ext] }, body = fs.readFile(file) }
	end
	return { status = 404, body = "not found" }
end)
print("serving " .. root .. " on " .. port)
