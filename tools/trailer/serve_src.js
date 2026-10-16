// Servidor local SÓ para QA: entrega a lista de arquivos .luau de src/ (dados JSON) na porta 8765.
// A place descartável lê e grava os Source. Nada é executado a partir daqui.
const fs = require("fs");
const http = require("http");
const path = require("path");
const root = process.argv[2];
const SKIP = new Set(["AdemirFaceData.luau"]);

function collect() {
	const files = [];
	function walk(dir, parts) {
		for (const name of fs.readdirSync(dir)) {
			const full = path.join(dir, name);
			if (fs.statSync(full).isDirectory()) {
				walk(full, parts.concat([name]));
			} else if (name.endsWith(".luau") && !SKIP.has(name)) {
				let base = name.slice(0, -5);
				let kind = "ModuleScript";
				let ctx = "";
				if (base.endsWith(".server")) {
					base = base.slice(0, -7);
					kind = "Script";
					ctx = "Server";
				} else if (base.endsWith(".client")) {
					base = base.slice(0, -7);
					kind = "Script";
					ctx = "Client";
				}
				files.push({ parts: parts.concat([base]), kind, ctx, source: fs.readFileSync(full, "utf8") });
			}
		}
	}
	walk(path.join(root, "src", "ReplicatedStorage"), ["ReplicatedStorage"]);
	walk(path.join(root, "src", "ServerScriptService"), ["ServerScriptService"]);
	return files;
}

http
	.createServer((req, res) => {
		if (req.url === "/files.json") {
			const body = JSON.stringify(collect());
			res.writeHead(200, { "Content-Type": "application/json" });
			res.end(body);
		} else {
			res.writeHead(404);
			res.end();
		}
	})
	.listen(8765, "127.0.0.1", () => console.log("serving on 127.0.0.1:8765"));
