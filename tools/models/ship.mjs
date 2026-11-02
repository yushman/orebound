// Builds the ship hull and writes assets/models/ship.glb.
// Axes: nose +Y, top +Z (toward the 2D camera), units = 2D world units.
// Material names "hull" / "wing" are mapped to Palette colours in Godot.
import { writeFileSync, mkdirSync } from 'node:fs';
import * as THREE from 'three';
import { GLTFExporter } from 'three/addons/exporters/GLTFExporter.js';

globalThis.FileReader = class {
	readAsArrayBuffer(blob) {
		blob.arrayBuffer().then((buf) => {
			this.result = buf;
			this.onloadend?.();
		});
	}
};

// Convex solid from a list of faces (each a list of points); faces are
// flipped outward around the centroid and flat shaded.
function solid(faces) {
	const all = faces.flat();
	const c = all.reduce((a, p) => a.add(p), new THREE.Vector3()).divideScalar(all.length);
	const pos = [];
	for (const f of faces) {
		for (let i = 1; i < f.length - 1; i++) {
			let [a, b, d] = [f[0], f[i], f[i + 1]];
			const n = new THREE.Vector3().subVectors(b, a).cross(new THREE.Vector3().subVectors(d, a));
			const mid = a.clone().add(b).add(d).divideScalar(3).sub(c);
			if (n.dot(mid) < 0) [b, d] = [d, b];
			pos.push(...a.toArray(), ...b.toArray(), ...d.toArray());
		}
	}
	const g = new THREE.BufferGeometry();
	g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
	g.computeVertexNormals();
	return g;
}

const v = (x, y, z) => new THREE.Vector3(x, y, z);

// Hexagonal cross-section at station y: half width, top and bottom heights.
function section(y, hw, top, bottom) {
	return [v(hw, y, 0), v(hw * 0.5, y, top), v(-hw * 0.5, y, top), v(-hw, y, 0), v(-hw * 0.5, y, bottom), v(hw * 0.5, y, bottom)];
}

function loft(sections, nose) {
	const faces = [];
	const n = sections[0].length;
	for (let i = 0; i < n; i++) faces.push([nose, sections[0][i], sections[0][(i + 1) % n]]);
	for (let s = 0; s < sections.length - 1; s++) {
		const a = sections[s];
		const b = sections[s + 1];
		for (let i = 0; i < n; i++) {
			const j = (i + 1) % n;
			faces.push([a[i], a[j], b[j]], [a[i], b[j], b[i]]);
		}
	}
	faces.push(sections[sections.length - 1]);
	return faces;
}

function prism(outline, z0, z1) {
	const lo = outline.map(([x, y]) => v(x, y, z0));
	const hi = outline.map(([x, y]) => v(x, y, z1));
	const faces = [lo, hi];
	for (let i = 0; i < outline.length; i++) {
		const j = (i + 1) % outline.length;
		faces.push([lo[i], lo[j], hi[j], hi[i]]);
	}
	return faces;
}

const hullMat = new THREE.MeshStandardMaterial({ name: 'hull', color: 0xd9e0eb, roughness: 0.6, metalness: 0.1 });
const wingMat = new THREE.MeshStandardMaterial({ name: 'wing', color: 0x99a6b8, roughness: 0.7, metalness: 0.1 });

const ship = new THREE.Group();
ship.name = 'Ship';

const hull = new THREE.Mesh(solid(loft([
	section(8, 2.2, 2.0, -1.2),
	section(-2, 4.2, 3.0, -1.8),
	section(-8, 6.0, 2.4, -1.6),
], v(0, 16, 0.4))), hullMat);
hull.name = 'Hull';
ship.add(hull);

const canopy = new THREE.Mesh(solid(loft([
	section(4, 1.4, 3.2, 1.0),
	section(-3, 2.0, 3.8, 1.0),
], v(0, 9, 1.6))), wingMat);
canopy.name = 'Canopy';
ship.add(canopy);

for (const side of [-1, 1]) {
	const wing = new THREE.Mesh(solid(prism([[4 * side, 2], [12 * side, -12], [5 * side, -8]], -0.6, 0.6)), wingMat);
	wing.name = side < 0 ? 'WingLeft' : 'WingRight';
	ship.add(wing);
}

const nozzle = new THREE.Mesh(solid(loft([section(-8, 3.2, 1.4, -1.0), section(-10, 2.4, 1.0, -0.8)], v(0, -6, 0.2))), wingMat);
nozzle.name = 'Nozzle';
ship.add(nozzle);

const exporter = new GLTFExporter();
const glb = await exporter.parseAsync(ship, { binary: true });
const out = new URL('../../assets/models/ship.glb', import.meta.url);
mkdirSync(new URL('.', out), { recursive: true });
writeFileSync(out, Buffer.from(glb));
console.log('wrote', out.pathname, glb.byteLength, 'bytes');
