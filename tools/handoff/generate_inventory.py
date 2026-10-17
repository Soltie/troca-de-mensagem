"""Read-only lexical source scanner. Python 3.10+, stdlib only.

Run: python tools/handoff/generate_inventory.py
Writes only docs/IA/07_INVENTARIO.md and docs/IA/CODE_MAP.json.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def clean_lines(text):
    text = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m[0].count("\n"), text, flags=re.S)
    return [re.sub(r"\s+--.*$", "", line) if not line.lstrip().startswith("--") else "" for line in text.splitlines()]


def scan(root):
    files = []
    for p in sorted((root / "src").rglob("*.luau")):
        raw = p.read_bytes()
        text = raw.decode("utf-8-sig")
        lines = clean_lines(text)
        rel = p.relative_to(root).as_posix()
        item = dict(path=rel, sha256=hashlib.sha256(raw).hexdigest(), lines=len(text.splitlines()),
                    functions=[], requires=[], hooks=[], attributes=[], remote_calls=[])
        for n, line in enumerate(lines, 1):
            s = line.strip()
            if re.match(r"(?:local\s+)?function\s+[\w.:]+", s) or re.match(r"[\w.:]+\s*=\s*function\b", s):
                item["functions"].append(dict(line=n, declaration=s))
            for m in re.finditer(r'require\(\s*"([^"\n]+)"\s*\)', line):
                name = m[1]
                target = None
                if name.startswith("@game/"):
                    candidate = root / "src" / name[6:]
                elif name.startswith("."):
                    candidate = p.parent / name
                else:
                    candidate = None
                if candidate:
                    resolved = Path(str(candidate) + ".luau").resolve()
                    if resolved.is_file() and resolved.is_relative_to(root):
                        target = resolved.relative_to(root).as_posix()
                item["requires"].append(dict(line=n, request=name, target=target))
            if re.search(r":(?:Connect|Once|BindToRenderStep|BindToClose|GetAttributeChangedSignal|GetPropertyChangedSignal|GetInstanceAddedSignal|GetInstanceRemovedSignal)\s*\(|\.(?:OnInvoke|OnServerInvoke|OnClientInvoke)\s*=|ServerNet\.on(?:Invoke|Event|UnreliableEvent)\s*\(|\.on(?:Capture|Change)\s*\(|\.set\w*Handler\s*\(", s):
                item["hooks"].append(dict(line=n, expression=s))
            if re.search(r'(?:GetAttribute|SetAttribute|GetAttributeChangedSignal|GetPropertyChangedSignal)\s*\(|GameState\.(?:get|set|observe)', s):
                item["attributes"].append(dict(line=n, expression=s))
            if re.search(r'Remotes\.(?:client|server)|ServerNet\.(?:on|isRegistered)|:(?:FireServer|InvokeServer|FireClient|FireAllClients)\s*\(', s):
                item["remote_calls"].append(dict(line=n, expression=s))
        files.append(item)
    return files


def write_inventory(root):
    root = root.resolve()
    files = scan(root)
    source_commit = git(root, "log", "-1", "--format=%H", "--", "src")
    src_dirty = bool(git(root, "status", "--porcelain", "--", "src"))
    data = dict(format_version=1, project=root.name, generated_on="2026-10-17",
                source_commit=source_commit, source_dirty=src_dirty,
                method="lexical source index; no runtime/callgraph proof", files=files)
    out = root / "docs/IA"
    out.mkdir(parents=True, exist_ok=True)
    (out / "CODE_MAP.json").write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    md = ["# Inventário das fontes para a IA", "", f"Projeto: **{root.name}**. Base que alterou src/: **{source_commit}**.",
          "", f"{len(files)} arquivos Luau. src/ com alterações locais no momento da coleta: **{src_dirty}**.",
          "", "Índice lexical gerado por [generate_inventory.py](../../tools/handoff/generate_inventory.py). "
          "Declarações, requires literais, listeners, callbacks e acessos a atributos têm linhas de origem. "
          "Não é análise AST: não resolve aliases dinâmicos, propagação de chamadas, funções anônimas sem nome, "
          "assinaturas multilinha completas nem qual ramo será executado. Uma ocorrência não prova execução. "
          "Leia o corpo da função e confirme no runtime. Hashes permitem detectar documentação desatualizada.",
          "", "Não carregar tudo no contexto: buscar o símbolo/tarefa, ler só o bloco relevante e abrir a fonte. "
          "[CODE_MAP.json](CODE_MAP.json) oferece o mesmo índice estruturado para consultas por IA.", ""]
    for f in files:
        path = f["path"]
        md += [f"## {path}", "", f"[Abrir fonte](../../{path}) · {f['lines']} linhas · SHA-256: {f['sha256']}", ""]
        for key, label in [("functions", "Funções nomeadas / callbacks atribuídos"), ("requires", "Dependências literais"),
                           ("hooks", "Listeners / registros / callbacks"), ("remote_calls", "Rede"), ("attributes", "Estado observado / publicado")]:
            entries = f[key]
            if not entries:
                continue
            md += [f"### {label}", ""]
            if key == "requires":
                for e in entries:
                    dest = f" → [fonte](../../{e['target']})" if e["target"] else " → não resolvido estaticamente"
                    md.append(f"- L{e['line']}: {e['request']}{dest}")
            else:
                md += ["~~~text"]
                for e in entries:
                    md.append(f"L{e['line']}: {e.get('declaration', e.get('expression'))}")
                md += ["~~~"]
            md += [""]
    (out / "07_INVENTARIO.md").write_text("\n".join(md).rstrip() + "\n", encoding="utf-8")
    print(f"{root.name}: {len(files)} files indexed; source_dirty={src_dirty}")


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2]
    write_inventory(root)
