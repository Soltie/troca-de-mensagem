// Leitor mínimo de FBX binário (7.x). Devolve árvore de nós { name, props, children }.
const fs = require("fs");
const zlib = require("zlib");

function parseFbx(path) {
	const buf = fs.readFileSync(path);
	const magic = buf.toString("latin1", 0, 20);
	if (magic !== "Kaydara FBX Binary  ") throw new Error("not binary fbx");
	const version = buf.readUInt32LE(23);
	const is64 = version >= 7500;
	let off = 27;

	function readArray(type) {
		const len = buf.readUInt32LE(off);
		const enc = buf.readUInt32LE(off + 4);
		const clen = buf.readUInt32LE(off + 8);
		off += 12;
		let data = buf.subarray(off, off + clen);
		off += clen;
		if (enc === 1) data = zlib.inflateSync(data);
		const out = new Array(len);
		for (let i = 0; i < len; i++) {
			switch (type) {
				case "f": out[i] = data.readFloatLE(i * 4); break;
				case "d": out[i] = data.readDoubleLE(i * 8); break;
				case "l": out[i] = Number(data.readBigInt64LE(i * 8)); break;
				case "i": out[i] = data.readInt32LE(i * 4); break;
				case "b": out[i] = data[i]; break;
			}
		}
		return out;
	}

	function readProp() {
		const t = String.fromCharCode(buf[off]);
		off += 1;
		switch (t) {
			case "Y": { const v = buf.readInt16LE(off); off += 2; return v; }
			case "C": { const v = buf[off]; off += 1; return v !== 0; }
			case "I": { const v = buf.readInt32LE(off); off += 4; return v; }
			case "F": { const v = buf.readFloatLE(off); off += 4; return v; }
			case "D": { const v = buf.readDoubleLE(off); off += 8; return v; }
			case "L": { const v = Number(buf.readBigInt64LE(off)); off += 8; return v; }
			case "f": case "d": case "l": case "i": case "b": return readArray(t);
			case "S": case "R": {
				const len = buf.readUInt32LE(off); off += 4;
				const s = t === "S" ? buf.toString("latin1", off, off + len) : buf.subarray(off, off + len);
				off += len; return s;
			}
			default: throw new Error("bad prop type " + t + " at " + off);
		}
	}

	function readNode() {
		const end = is64 ? Number(buf.readBigUInt64LE(off)) : buf.readUInt32LE(off);
		const numProps = is64 ? Number(buf.readBigUInt64LE(off + 8)) : buf.readUInt32LE(off + 4);
		off += is64 ? 24 : 12;
		const nameLen = buf[off]; off += 1;
		const name = buf.toString("latin1", off, off + nameLen); off += nameLen;
		if (end === 0) return null;
		const props = [];
		for (let i = 0; i < numProps; i++) props.push(readProp());
		const children = [];
		while (off < end) {
			const c = readNode();
			if (c === null) break;
			children.push(c);
		}
		off = end;
		return { name, props, children };
	}

	const root = { name: "root", props: [], children: [] };
	while (off < buf.length) {
		const n = readNode();
		if (n === null) break;
		root.children.push(n);
	}
	return { version, root };
}

function child(n, name) { return n.children.find((c) => c.name === name); }
function childrenNamed(n, name) { return n.children.filter((c) => c.name === name); }

// Properties70 -> { nome: [valores] }
function props70(n) {
	const p = child(n, "Properties70");
	const out = {};
	if (!p) return out;
	for (const c of p.children) out[c.props[0]] = c.props.slice(4);
	return out;
}

module.exports = { parseFbx, child, childrenNamed, props70 };
