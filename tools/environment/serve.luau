-- Servidor HTTP local (só localhost) para o fluxo de assets com o Studio MCP:
-- GET  /<arquivo>   entrega imagens de .cache/env-assets para o upload_image;
-- POST /rbxm/<nome> recebe um .rbxm em hexadecimal (SerializationService) e grava em .cache/env-assets/rbxm/.
-- Uso: lune run tools/environment/serve 8765
local net = require("@lune/net")
local fs = require("@lune/fs")
local process = require("@lune/process")
local port = tonumber(process.args[1]) or 8765
local root = ".cache/env-assets/"
local types = { png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg" }
net.serve(port, function(request)
	local path = string.gsub(request.path, "%.%.", "")
	local name = string.match(path, "^/rbxm/([%w_]+)$")
	if request.method == "POST" and name then
		local hex = string.gsub(request.body, "%s", "")
		local bytes = string.gsub(hex, "%x%x", function(pair)
			return string.char(tonumber(pair, 16) :: number)
		end)
		if not fs.isDir(root .. "rbxm") then
			fs.writeDir(root .. "rbxm")
		end
		fs.writeFile(root .. "rbxm/" .. name .. ".rbxm", bytes)
		return { status = 200, body = tostring(#bytes) }
	end
	local file = root .. string.sub(path, 2)
	local ext = string.match(file, "%.(%w+)$")
	if ext and types[ext] and fs.isFile(file) then
		return { status = 200, headers = { ["Content-Type"] = types[ext] }, body = fs.readFile(file) }
	end
	return { status = 404, body = "not found" }
end)
print("serving " .. root .. " on " .. port)
