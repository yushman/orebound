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
## inward and in z, so the top-down silhouette is exactly `points`. With
## `inner_points` > 0 the inner rings use that many points sampled on the
## hull, joined to the rim by a strip. Each facet carries a CUSTOM0 inclusion
## flag (`_facets`).
static func rock(points: PackedVector2Array, seed: int, color: Color, inner_points := 0) -> ArrayMesh:
	var c := centroid(points)
	var r := 0.0
	for p in points:
		r = maxf(r, p.distance_to(c))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var rings := [ring(points, 0.0)]
	var src := _hull_samples(points, c, inner_points) if inner_points > 0 else points
	for k in DOME_RINGS:
		var inner := PackedVector3Array()
		for p in src:
			var q: Vector2 = c + (p - c) * k[0] * (1.0 - DOME_JITTER * rng.randf())
			inner.append(Vector3(q.x, -q.y, r * DOME_HEIGHT * k[1] * (1.0 + DOME_JITTER * rng.randf_range(-1.0, 1.0))))
		rings.append(inner)
	var tris := PackedVector3Array()
	for k in rings.size() - 1:
		var a: PackedVector3Array = rings[k]
		var b: PackedVector3Array = rings[k + 1]
		tris.append_array(_band(a, b) if a.size() == b.size() else _strip(a, b, c))
	tris.append_array(_fan(rings[-1], Vector3(c.x, -c.y, r * DOME_HEIGHT)))
	tris.append_array(_fan(rings[0], Vector3(c.x, -c.y, -r * BASE_DEPTH)))
	var mesh := ArrayMesh.new()
	# decimated rings: the top is a height field, so face +z above the rim
	# and -z below it (the centroid rule fails on the strip triangles)
	add_surface(mesh, tris, color, "z" if inner_points > 0 else Vector3(c.x, -c.y, 0.0), seed)
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
## away from it, with "z" away from z 0 (Godot front faces are clockwise).
## With `facet_seed` the surface carries `_facets` in CUSTOM0.
static func add_surface(mesh: ArrayMesh, tris: PackedVector3Array, color: Color, center = null, facet_seed = null) -> void:
	var n := tris.size() / 3
	var normals: Array[Vector3] = []
	for t in n:
		var a := tris[3 * t]
		var b := tris[3 * t + 1]
		var d := tris[3 * t + 2]
		var nn := (d - a).cross(b - a)
		var mid := (a + b + d) / 3.0
		if center != null and (nn.z * mid.z if center is String else nn.dot(mid - center)) < 0.0:
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
	var custom := PackedFloat32Array()
	var inclusions := _facets(tris, faces, facet_seed) if facet_seed != null else []
	for t in n:
		var hard := []
		for e in 3:
			var f: Array = faces[_edge_key(tris[3 * t + (e + 1) % 3], tris[3 * t + (e + 2) % 3])]
			hard.append(f.size() != 2 or normals[f[0]].dot(normals[f[1]]) < cos_hard)
		var flag := 1.0 if facet_seed != null and inclusions[t] else 0.0
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
			custom.append_array([0.0, 0.0, 0.0, flag])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = cols
	if facet_seed == null:
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return
	arrays[Mesh.ARRAY_CUSTOM0] = custom
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)


## Inclusion flag per triangle: top facets (z sum > 0), picked up to
## `Style.INCLUSION_FRACTION` of them, each grown from a picked neighbour
## with chance `Style.INCLUSION_CLUSTER`.
static func _facets(tris: PackedVector3Array, faces: Dictionary, seed: int) -> Array:
	var n := tris.size() / 3
	var r := RandomNumberGenerator.new()
	r.seed = seed ^ 0x5bd1e995
	var is_top := []
	var top := []
	for t in n:
		var up := tris[3 * t].z + tris[3 * t + 1].z + tris[3 * t + 2].z > 0.0
		is_top.append(up)
		if up:
			top.append(t)
	var on := []
	on.resize(n)
	on.fill(false)
	var picked := []
	var want := roundi(Style.INCLUSION_FRACTION * top.size())
	while picked.size() < want:
		var t := -1
		if not picked.is_empty() and r.randf() < Style.INCLUSION_CLUSTER:
			var near := []
			for a in picked:
				for e in 3:
					for b in faces[_edge_key(tris[3 * a + (e + 1) % 3], tris[3 * a + (e + 2) % 3])]:
						if b != a and not on[b] and is_top[b]:
							near.append(b)
			if not near.is_empty():
				t = near[int(r.randf() * near.size())]
		if t < 0:
			var free := top.filter(func(x): return not on[x])
			t = free[int(r.randf() * free.size())]
		on[t] = true
		picked.append(t)
	return on


static func _signed_area(points: PackedVector2Array) -> float:
	var a := 0.0
	for i in points.size():
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		a += p.x * q.y - q.x * p.y
	return a


## Points where rays from `c` at even angles (half-step offset, in the
## hull's winding direction) leave the convex polygon.
static func _hull_samples(points: PackedVector2Array, c: Vector2, count: int) -> PackedVector2Array:
	var dir := 1.0 if _signed_area(points) >= 0.0 else -1.0
	var a0 := (points[0] - c).angle()
	var out := PackedVector2Array()
	for j in count:
		var d := Vector2.from_angle(a0 + dir * TAU * (j + 0.5) / count)
		var best := INF
		for i in points.size():
			var p := points[i]
			var e := points[(i + 1) % points.size()] - p
			var den := d.cross(e)
			if absf(den) < 1e-12:
				continue
			var w := p - c
			var t := w.cross(e) / den
			var u := w.cross(d) / den
			if t > 0.0 and u >= -1e-9 and u <= 1.0 + 1e-9:
				best = minf(best, t)
		out.append(c + d * best)
	return out


## Band between rings of different sizes with the same winding: merge both
## by angle around `c` (2D, y-down) and advance the ring whose next vertex
## comes first, so every triangle has one edge on a ring.
static func _strip(a: PackedVector3Array, b: PackedVector3Array, c: Vector2) -> PackedVector3Array:
	var pa := PackedVector2Array()
	for v in a:
		pa.append(Vector2(v.x, -v.y))
	var dir := 1.0 if _signed_area(pa) >= 0.0 else -1.0
	var ang := func(v: Vector3) -> float: return atan2(-v.y - c.y, v.x - c.x)
	var base: float = ang.call(a[0])
	var off := func(v: Vector3) -> float: return fposmod(dir * (ang.call(v) - base), TAU)
	var A := PackedFloat64Array([0.0])
	for i in range(1, a.size()):
		var x: float = off.call(a[i])
		A.append(x if x != 0.0 else TAU)
	var j0 := 0
	for j in range(1, b.size()):
		if off.call(b[j]) < off.call(b[j0]):
			j0 = j
	var B := PackedFloat64Array()
	for k in b.size():
		B.append(off.call(b[(j0 + k) % b.size()]))
	for k in range(1, B.size()):
		if B[k] <= B[k - 1]:
			B[k] += TAU
	A.append(TAU)
	B.append(B[0] + TAU)
	var tris := PackedVector3Array()
	var i := 0
	var k := 0
	while i < a.size() or k < b.size():
		if k >= b.size() or (i < a.size() and A[i + 1] <= B[k + 1]):
			tris.append_array([a[i % a.size()], a[(i + 1) % a.size()], b[(j0 + k) % b.size()]])
			i += 1
		else:
			tris.append_array([a[i % a.size()], b[(j0 + k + 1) % b.size()], b[(j0 + k) % b.size()]])
			k += 1
	return tris


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
