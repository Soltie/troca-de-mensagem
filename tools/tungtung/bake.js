// Converte animações Mixamo (FBX) em deltas por osso no espaço do Roblox (Bone.Transform).
// Uso: node bake.js <bind.fbx> <boneCFrames.json> <saida.luau> <nome=arquivo.fbx>...
const fs = require("fs");
const { parseFbx, child, childrenNamed, props70 } = require("./fbx.js");

const SCALE = 4.2; // mesmo fator usado no importador 3D
const TICKS = 46186158000;
const FPS = 30;

// ---------- matemática (matrizes 4x4 coluna, m[linha][coluna]) ----------
function ident() { return [[1,0,0,0],[0,1,0,0],[0,0,1,0],[0,0,0,1]]; }
function mul(a, b) {
	const r = [[0,0,0,0],[0,0,0,0],[0,0,0,0],[0,0,0,0]];
	for (let i = 0; i < 4; i++) for (let j = 0; j < 4; j++) {
		let s = 0; for (let k = 0; k < 4; k++) s += a[i][k] * b[k][j]; r[i][j] = s;
	}
	return r;
}
function trans(x, y, z) { const m = ident(); m[0][3] = x; m[1][3] = y; m[2][3] = z; return m; }
function rotX(d) { const a = d * Math.PI / 180, c = Math.cos(a), s = Math.sin(a); return [[1,0,0,0],[0,c,-s,0],[0,s,c,0],[0,0,0,1]]; }
function rotY(d) { const a = d * Math.PI / 180, c = Math.cos(a), s = Math.sin(a); return [[c,0,s,0],[0,1,0,0],[-s,0,c,0],[0,0,0,1]]; }
function rotZ(d) { const a = d * Math.PI / 180, c = Math.cos(a), s = Math.sin(a); return [[c,-s,0,0],[s,c,0,0],[0,0,1,0],[0,0,0,1]]; }
// FBX eEulerXYZ: aplica X, depois Y, depois Z => Rz*Ry*Rx
function euler(v) { return mul(rotZ(v[2]), mul(rotY(v[1]), rotX(v[0]))); }
function inverseRigid(m) {
	const r = ident();
	for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) r[i][j] = m[j][i];
	for (let i = 0; i < 3; i++) r[i][3] = -(r[i][0] * m[0][3] + r[i][1] * m[1][3] + r[i][2] * m[2][3]);
	return r;
}
function toQuat(m) {
	const t = m[0][0] + m[1][1] + m[2][2];
	let w, x, y, z;
	if (t > 0) { const s = Math.sqrt(t + 1) * 2; w = 0.25 * s; x = (m[2][1] - m[1][2]) / s; y = (m[0][2] - m[2][0]) / s; z = (m[1][0] - m[0][1]) / s; }
	else if (m[0][0] > m[1][1] && m[0][0] > m[2][2]) { const s = Math.sqrt(1 + m[0][0] - m[1][1] - m[2][2]) * 2; w = (m[2][1] - m[1][2]) / s; x = 0.25 * s; y = (m[0][1] + m[1][0]) / s; z = (m[0][2] + m[2][0]) / s; }
	else if (m[1][1] > m[2][2]) { const s = Math.sqrt(1 + m[1][1] - m[0][0] - m[2][2]) * 2; w = (m[0][2] - m[2][0]) / s; x = (m[0][1] + m[1][0]) / s; y = 0.25 * s; z = (m[1][2] + m[2][1]) / s; }
	else { const s = Math.sqrt(1 + m[2][2] - m[0][0] - m[1][1]) * 2; w = (m[1][0] - m[0][1]) / s; x = (m[0][2] + m[2][0]) / s; y = (m[1][2] + m[2][1]) / s; z = 0.25 * s; }
	const n = Math.hypot(w, x, y, z);
	return [x / n, y / n, z / n, w / n];
}
// Conjugação pela rotação de 180° em Y (o importador gira o FBX) + escala da translação.
const Q = rotY(180);
function toRoblox(m) {
	const r = mul(Q, mul(m, inverseRigid(Q)));
	r[0][3] *= SCALE; r[1][3] *= SCALE; r[2][3] *= SCALE;
	return r;
}

// ---------- leitura do FBX ----------
function loadRig(file) {
	const { root } = parseFbx(file);
	const objects = child(root, "Objects");
	const conns = child(root, "Connections").children.map((c) => ({ type: c.props[0], src: c.props[1], dst: c.props[2], prop: c.props[3] }));
	const models = new Map();
	for (const m of childrenNamed(objects, "Model")) {
		if (m.props[2] !== "LimbNode") continue;
		const p = props70(m);
		models.set(m.props[0], {
			id: m.props[0],
			name: m.props[1].split("\u0000")[0],
			T: p["Lcl Translation"] || [0, 0, 0],
			R: p["Lcl Rotation"] || [0, 0, 0],
			Pre: p.PreRotation || [0, 0, 0],
			Post: p.PostRotation || [0, 0, 0],
			order: p.RotationOrder ? p.RotationOrder[0] : 0,
			curves: {},
		});
	}
	for (const c of conns) {
		if (c.type === "OO" && models.has(c.src) && models.has(c.dst)) models.get(c.src).parent = models.get(c.dst).name;
	}
	// curvas
	const curveNodes = new Map(childrenNamed(objects, "AnimationCurveNode").map((n) => [n.props[0], { name: n.props[1].split("\u0000")[0], target: null, prop: null, axes: {}, defaults: props70(n) }]));
	const curves = new Map(childrenNamed(objects, "AnimationCurve").map((c) => [c.props[0], { times: child(c, "KeyTime").props[0], values: child(c, "KeyValueFloat").props[0] }]));
	for (const c of conns) {
		if (c.type === "OP" && curveNodes.has(c.src) && models.has(c.dst)) {
			const cn = curveNodes.get(c.src); cn.target = c.dst; cn.prop = c.prop;
		}
		if (c.type === "OP" && curves.has(c.src) && curveNodes.has(c.dst)) {
			curveNodes.get(c.dst).axes[c.prop] = curves.get(c.src);
		}
	}
	for (const cn of curveNodes.values()) {
		if (!cn.target) continue;
		const m = models.get(cn.target);
		const key = cn.prop === "Lcl Translation" ? "T" : cn.prop === "Lcl Rotation" ? "R" : null;
		if (!key) continue;
		m.curves[key] = cn;
	}
	const byName = new Map();
	for (const m of models.values()) { if (m.order !== 0) throw new Error("ordem de rotação inesperada em " + m.name); byName.set(m.name, m); }
	const stack = childrenNamed(objects, "AnimationStack")[0];
	const stop = stack ? props70(stack).LocalStop[0] : 0;
	return { bones: byName, duration: stop / TICKS };
}

function sample(curve, t) {
	const ticks = t * TICKS;
	const { times, values } = curve;
	if (ticks <= times[0]) return values[0];
	for (let i = 1; i < times.length; i++) {
		if (ticks <= times[i]) {
			const a = (ticks - times[i - 1]) / (times[i] - times[i - 1]);
			return values[i - 1] + (values[i] - values[i - 1]) * a;
		}
	}
	return values[values.length - 1];
}
function channel(bone, key, t) {
	const base = bone[key];
	const cn = bone.curves[key];
	if (!cn) return base;
	return ["d|X", "d|Y", "d|Z"].map((ax, i) => (cn.axes[ax] ? sample(cn.axes[ax], t) : (cn.defaults[ax] ? cn.defaults[ax][0] : base[i])));
}
function localMatrix(bone, T, R) {
	return mul(trans(T[0], T[1], T[2]), mul(euler(bone.Pre), mul(euler(R), inverseRigid(euler(bone.Post)))));
}

// ---------- principal ----------
const [bindFile, bonesJson, outFile, ...anims] = process.argv.slice(2);
const bind = loadRig(bindFile);
const rbx = JSON.parse(fs.readFileSync(bonesJson, "utf8"));
const boneNames = Object.keys(rbx); // só os ossos que o importador manteve

// validação: bind convertido x Bone.CFrame do Studio
let worst = 0;
for (const name of boneNames) {
	const b = bind.bones.get(name);
	const m = toRoblox(localMatrix(b, b.T, b.R));
	const cf = rbx[name].cf;
	const got = [[cf[3], cf[4], cf[5], cf[0]], [cf[6], cf[7], cf[8], cf[1]], [cf[9], cf[10], cf[11], cf[2]]];
	// o osso raiz é relativo ao centro da MeshPart: compara só a rotação
	const cols = rbx[name].p === "Body" ? 3 : 4;
	for (let i = 0; i < 3; i++) for (let j = 0; j < cols; j++) worst = Math.max(worst, Math.abs(got[i][j] - m[i][j]));
	if (rbx[name].p !== "Body" && rbx[name].p !== b.parent) throw new Error("pai diferente " + name);
}
console.log("validação bind: maior diferença", worst.toFixed(5));
if (worst > 0.01) throw new Error("bind não confere com o Studio");

const bindLocal = new Map(boneNames.map((n) => { const b = bind.bones.get(n); return [n, localMatrix(b, b.T, b.R)]; }));

const result = [];
for (const spec of anims) {
	const [animName, file] = spec.split("=");
	const rig = loadRig(file);
	const frames = Math.max(2, Math.round(rig.duration * FPS) + 1);
	const tracks = boneNames.map((name) => {
		const bone = rig.bones.get(name);
		const L0inv = inverseRigid(bindLocal.get(name));
		const qs = [], ps = [];
		for (let f = 0; f < frames; f++) {
			const t = Math.min(rig.duration, f / FPS);
			const L = localMatrix(bone, channel(bone, "T", t), channel(bone, "R", t));
			const D = toRoblox(mul(L0inv, L));
			let q = toQuat(D);
			if (qs.length) { const p = qs[qs.length - 1]; if (p[0]*q[0] + p[1]*q[1] + p[2]*q[2] + p[3]*q[3] < 0) q = q.map((v) => -v); }
			qs.push(q); ps.push([D[0][3], D[1][3], D[2][3]]);
		}
		let maxMove = 0;
		for (const p of ps) maxMove = Math.max(maxMove, Math.hypot(p[0], p[1], p[2]));
		return { name, qs, ps, hasPos: maxMove > 0.02 };
	});
	result.push({ name: animName, frames, duration: rig.duration, tracks });
	const hips = tracks.find((t) => t.name === "mixamorig:Hips");
	const first = hips.ps[0], last = hips.ps[hips.ps.length - 1];
	console.log(animName, "frames", frames, "dur", rig.duration.toFixed(3), "hips drift", (last[0] - first[0]).toFixed(2), (last[1] - first[1]).toFixed(2), (last[2] - first[2]).toFixed(2), "posTracks", tracks.filter((t) => t.hasPos).map((t) => t.name.replace("mixamorig:", "")).join(","));
}

// ---------- empacotamento: int16 por componente, base64 ----------
const POS_RANGE = 16; // studs
function pack(anim, removeDrift) {
	const posTracks = anim.tracks.filter((t) => t.hasPos);
	const bytes = Buffer.alloc(anim.frames * (anim.tracks.length * 8 + posTracks.length * 6));
	let o = 0;
	for (let f = 0; f < anim.frames; f++) {
		for (const tr of anim.tracks) for (const v of tr.qs[f]) { bytes.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), o); o += 2; }
		for (const tr of posTracks) {
			let p = tr.ps[f];
			if (removeDrift && tr.name === "mixamorig:Hips") {
				const a = f / (anim.frames - 1), p0 = tr.ps[0], p1 = tr.ps[anim.frames - 1];
				p = [p[0] - (p1[0] - p0[0]) * a, p[1], p[2] - (p1[2] - p0[2]) * a];
			}
			for (const v of p) { bytes.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v / POS_RANGE)) * 32767), o); o += 2; }
		}
	}
	return { data: bytes.toString("base64"), posBones: posTracks.map((t) => t.name) };
}

const lines = [];
lines.push("--!strict");
lines.push("-- GERADO por tools/tungtung/bake.js a partir das animações Mixamo do Tung Tung (não editar à mão).");
lines.push("-- Cada quadro guarda, por osso, o Bone.Transform (quaternion int16) e, para ossos com deslocamento,");
lines.push("-- a translação (int16, faixa ±" + POS_RANGE + " studs). Ordem dos ossos: Bones.");
lines.push("");
lines.push("export type Clip = { fps: number, frames: number, loop: boolean, posBones: { string }, data: string }");
lines.push("");
lines.push("local TungTungClips = {}");
lines.push("");
lines.push("TungTungClips.PosRange = " + POS_RANGE);
lines.push("TungTungClips.Bones = {");
for (const n of boneNames) lines.push('\t"' + n + '",');
lines.push("}");
lines.push("");
lines.push("TungTungClips.Clips = {");
const LOOPS = { walk: true, run: true, strafe: true, idle: true };
for (const anim of result) {
	const loop = LOOPS[anim.name] === true;
	const packed = pack(anim, loop);
	lines.push("\t" + anim.name + " = {");
	lines.push("\t\tfps = " + FPS + ",");
	lines.push("\t\tframes = " + anim.frames + ",");
	lines.push("\t\tloop = " + loop + ",");
	lines.push("\t\tposBones = { " + packed.posBones.map((n) => '"' + n + '"').join(", ") + " },");
	// strings longas em pedaços para não estourar linhas
	const chunks = packed.data.match(/.{1,100}/g);
	lines.push("\t\tdata = table.concat({");
	for (const c of chunks) lines.push('\t\t\t"' + c + '",');
	lines.push("\t\t}),");
	lines.push("\t} :: Clip,");
}
lines.push("}");
lines.push("");
lines.push("return TungTungClips");
fs.writeFileSync(outFile, lines.join("\n") + "\n");
console.log("escrito", outFile, fs.statSync(outFile).size, "bytes");
