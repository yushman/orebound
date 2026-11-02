class_name SolidMesh
extends RefCounted
## Flat-shaded meshes for `Layer3D`, colour in the vertex COLOR (sRGB).
## UV and UV2.x carry per-triangle barycentrics with the components of soft
## edges held at 1, so `solid.gdshader` strokes hard edges only.
## Layer space: 2D (x, y) -> (x, -y), +Z toward the viewer.

const HARD_EDGE_DEG := 25.0
const DOME_HEIGHT := 0.6
## Inner dome rings: [scale toward the centroid, height fraction].
const DOME_RINGS := [[0.7, 0.55], [0.35, 0.85]]
const DOME_JITTER := 0.12
const BASE_DEPTH := 0.3


## Dome over the convex 2D hull `points`: the rim is the hull itself at z 0,
## inner rings shrink toward the centroid and seeded jitter only moves them
## inward and in z, so the top-down silhouette is exactly `points`.
static func rock(points: PackedVector2Array, seed: int, color: Color) -> ArrayMesh:
	var c := centroid(points)
	var r := 0.0
	for p in points:
		r = maxf(r, p.distance_to(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rings := [ring(points, 0.0)]
	for k in DOME_RINGS:
		var inner := PackedVector3Array()
		for p in points:
			var q: Vector2 = c + (p - c) * k[0] * (1.0 - DOME_JITTER * rng.randf())
			inner.append(Vector3(q.x, -q.y, r * DOME_HEIGHT * k[1] * (1.0 + DOME_JITTER * rng.randf_range(-1.0, 1.0))))
		rings.append(inner)
	var tris := PackedVector3Array()
	for k in rings.size() - 1:
		tris.append_array(_band(rings[k], rings[k + 1]))
	tris.append_array(_fan(rings[-1], Vector3(c.x, -c.y, r * DOME_HEIGHT)))
	tris.append_array(_fan(rings[0], Vector3(c.x, -c.y, -r * BASE_DEPTH)))
	var mesh := ArrayMesh.new()
	add_surface(mesh, tris, color, Vector3(c.x, -c.y, 0.0))
	return mesh


## Prism over the convex 2D hull `points`, z in [-half_height, half_height].
static func box(points: PackedVector2Array, half_height: float, color: Color) -> ArrayMesh:
	var c := centroid(points)
	var top := ring(points, half_height)
	var bottom := ring(points, -half_height)
	var tris := PackedVector3Array()
	tris.append_array(_band(bottom, top))
	tris.append_array(_fan(top, Vector3(c.x, -c.y, half_height)))
	tris.append_array(_fan(bottom, Vector3(c.x, -c.y, -half_height)))
	var mesh := ArrayMesh.new()
	add_surface(mesh, tris, color, Vector3(c.x, -c.y, 0.0))
	return mesh


## Rebuilds an imported mesh surface by surface with the given colours.
static func recolor(src: Mesh, colors: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for i in src.get_surface_count():
		var a := src.surface_get_arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var idx = a[Mesh.ARRAY_INDEX]
		var tris := PackedVector3Array()
		if idx == null or idx.is_empty():
			tris = v
		else:
			for j in idx:
				tris.append(v[j])
		add_surface(mesh, tris, colors[i])
	return mesh


static func centroid(points: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in points:
		c += p
	return c / points.size()


static func ring(points: PackedVector2Array, z: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in points:
		out.append(Vector3(p.x, -p.y, z))
	return out


## Appends flat-shaded triangles; with `center` each one is turned to face
## away from it (Godot front faces are clockwise).
static func add_surface(mesh: ArrayMesh, tris: PackedVector3Array, color: Color, center = null) -> void:
	var n := tris.size() / 3
	var normals: Array[Vector3] = []
	for t in n:
		var a := tris[3 * t]
		var b := tris[3 * t + 1]
		var d := tris[3 * t + 2]
		var nn := (d - a).cross(b - a)
		if center != null and nn.dot((a + b + d) / 3.0 - center) < 0.0:
			tris[3 * t + 1] = d
			tris[3 * t + 2] = b
			nn = -nn
		normals.append(nn.normalized())
	var faces := {}
	for t in n:
		for e in 3:
			var k := _edge_key(tris[3 * t + (e + 1) % 3], tris[3 * t + (e + 2) % 3])
			if not faces.has(k):
				faces[k] = []
			faces[k].append(t)
	var cos_hard := cos(deg_to_rad(HARD_EDGE_DEG))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var cols := PackedColorArray()
	for t in n:
		var hard := []
		for e in 3:
			var f: Array = faces[_edge_key(tris[3 * t + (e + 1) % 3], tris[3 * t + (e + 2) % 3])]
			hard.append(f.size() != 2 or normals[f[0]].dot(normals[f[1]]) < cos_hard)
		for v in 3:
			var bc := Vector3.ONE
			for e in 3:
				if hard[e]:
					bc[e] = 1.0 if v == e else 0.0
			verts.append(tris[3 * t + v])
			norms.append(normals[t])
			uv.append(Vector2(bc.x, bc.y))
			uv2.append(Vector2(bc.z, 0.0))
			cols.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


static func _band(a: PackedVector3Array, b: PackedVector3Array) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for i in a.size():
		var j := (i + 1) % a.size()
		tris.append_array([a[i], a[j], b[j], a[i], b[j], b[i]])
	return tris


static func _fan(r: PackedVector3Array, apex: Vector3) -> PackedVector3Array:
	var tris := PackedVector3Array()
	for i in r.size():
		tris.append_array([r[i], r[(i + 1) % r.size()], apex])
	return tris


static func _edge_key(a: Vector3, b: Vector3) -> String:
	var ka := Vector3i((a * 1000.0).round())
	var kb := Vector3i((b * 1000.0).round())
	return "%s%s" % [ka, kb] if ka < kb else "%s%s" % [kb, ka]
