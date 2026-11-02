extends GutTest

const EPS := 1e-3

var _saved_planet
var _saved_picture


func before_each():
	_saved_planet = Tuning.planet
	_saved_picture = Tuning.picture
	Tuning.planet = PlanetParams.new()
	Tuning.planet.asteroids_per_band = 20.0
	Tuning.picture = {"seed": 3, "flight": 1, "moons": [], "ring": {}}


func after_each():
	Tuning.planet = _saved_planet
	Tuning.picture = _saved_picture


func _hull(seed: int, rad: float) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return AsteroidField._hull(rng, rad)


func _top_down(mesh: ArrayMesh) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
			out.append(Vector2(v.x, -v.y))
	return out


func _assert_silhouette(mesh: ArrayMesh, points: PackedVector2Array) -> void:
	var proj := _top_down(mesh)
	var grown: PackedVector2Array = Geometry2D.offset_polygon(points, EPS)[0]
	for p in proj:
		assert_true(Geometry2D.is_point_in_polygon(p, grown), "vertex %s inside the hull" % p)
	for q in points:
		var hit := false
		for p in proj:
			if p.distance_to(q) < EPS:
				hit = true
				break
		assert_true(hit, "hull point %s is a mesh vertex" % q)


func test_rock_silhouette_is_its_hull_points():
	for seed in [1, 2, 3, 4, 5]:
		var pts := _hull(seed, 20.0 + 10.0 * seed)
		_assert_silhouette(SolidMesh.rock(pts, seed, Palette.ORE), pts)


func test_container_box_silhouette_is_its_square():
	var r := 10.0
	var pts := PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	_assert_silhouette(SolidMesh.box(pts, r, Palette.ICE), pts)


func test_mesh_carries_colour_and_masks_soft_edges():
	var pts := PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	var a := SolidMesh.box(pts, 5.0, Palette.ICE).surface_get_arrays(0)
	assert_eq(a[Mesh.ARRAY_COLOR][0], Palette.ICE)
	var masked := 0
	var hard := 0
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	for i in range(0, uv.size(), 3):
		if uv[i].x == 1.0 and uv[i + 1].x == 1.0 and uv[i + 2].x == 1.0:
			masked += 1
		else:
			hard += 1
	assert_gt(masked, 0, "fan edges inside a flat face are not stroked")
	assert_gt(hard, 0, "box edges are stroked")


func test_asteroid_instances_put_rims_on_rotated_world_points():
	var v = add_child_autofree(AsteroidView.new())
	var pos := Vector2(Tuning.field.atmosphere_edge + 3.5 * Tuning.planet.band_width, 0.0)
	v.refresh(pos, 3000.0)
	assert_gt(v.shown.size(), 0)
	for a in v.shown:
		var xf: Transform3D = v.transform_of(a)
		var rim: PackedVector3Array = v.mesh_of(a).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for i in a["points"].size():
			var want: Vector3 = v.layer.to_3d(a["pos"] + a["points"][i].rotated(a["rotation"]))
			var found := false
			for p in rim:
				if absf(p.z) < EPS and (xf * p).distance_to(want) < EPS * 10.0:
					found = true
					break
			assert_true(found, "rim vertex on world hull point %d" % i)


func test_shrunk_piece_scales_the_birth_mesh_onto_its_points():
	var v = add_child_autofree(SmallObjectView.new())
	var b := FreeBody.new()
	b.pos = Vector2(100, -50)
	b.points = _hull(9, 30.0)
	b.radius = 30.0
	b.piece = true
	b.id = 42
	var built: Array = v.mesh_of(b)
	var f := 0.49
	for i in b.points.size():
		b.points[i] *= sqrt(f)
	b.radius *= sqrt(f)
	var xf: Transform3D = v.transform_of(b, built[1])
	var verts: PackedVector3Array = built[0].surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for q in b.points:
		var want: Vector3 = v.layer.to_3d(b.pos + q, SmallObjectView.LIFT_Z)
		var found := false
		for p in verts:
			if (xf * p).distance_to(want) < 0.01:
				found = true
				break
		assert_true(found, "shrunk hull point %s matched" % q)
