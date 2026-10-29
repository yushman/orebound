extends GutTest

func _single_root(path: String, type: String) -> void:
	var scene := load(path) as PackedScene
	assert_not_null(scene, path)
	if scene == null:
		return
	var node := scene.instantiate()
	assert_true(node.is_class(type), "%s root is %s" % [path, type])
	assert_eq(node.get_child_count(), 0, path + " has a single node")
	node.free()

func _shader(path: String) -> void:
	var shader := load(path) as Shader
	assert_not_null(shader, path)
	if shader == null:
		return
	assert_eq(shader.get_mode(), Shader.MODE_CANVAS_ITEM)

func _uniform_line(src: String, decl: String) -> String:
	for l in src.split("\n"):
		if l.begins_with(decl):
			return l
	return ""

func test_starfield_shader_stub() -> void:
	var shader := load("res://shaders/starfield.gdshader") as Shader
	assert_not_null(shader, "res://shaders/starfield.gdshader")
	if shader == null:
		return
	assert_eq(shader.get_mode(), Shader.MODE_CANVAS_ITEM)
	var types := {"cam": TYPE_VECTOR2, "seed": TYPE_INT, "cell0": TYPE_FLOAT,
		"per_cell": TYPE_INT, "star_px": TYPE_FLOAT, "weights": TYPE_VECTOR3,
		"star_color": TYPE_COLOR}
	var declared := {}
	for d in shader.get_shader_uniform_list():
		declared[d["name"]] = d["type"]
	for u in types:
		assert_eq(declared.get(u, -1), types[u], u)
	var src := FileAccess.get_file_as_string("res://shaders/starfield.gdshader")
	assert_false(src.contains("TIME"), "no TIME")
	assert_true(_uniform_line(src, "uniform float cell0").contains("= 512.0"), "cell0 default 512.0")
	assert_true(_uniform_line(src, "uniform int per_cell").contains("= 1"), "per_cell default 1")
	assert_true(_uniform_line(src, "uniform float star_px").contains("= 1.5"), "star_px default 1.5")
	var line := _uniform_line(src, "uniform vec4 star_color")
	assert_true(line.contains("source_color"), "star_color is source_color")
	var comps := line.get_slice("vec4(", 1).get_slice(")", 0).split(",")
	var want := [155.0 / 255.0, 168.0 / 255.0, 196.0 / 255.0, 1.0]
	assert_eq(comps.size(), 4, "star_color default has 4 components")
	for i in comps.size():
		assert_almost_eq(comps[i].to_float(), want[i], 0.002, "star_color[%d]" % i)

func test_stub_scenes_and_shaders() -> void:
	for p in ["res://scenes/Carrier.tscn", "res://scenes/Field.tscn"]:
		_single_root(p, "Node2D")
	for p in ["res://ui/HUD.tscn"]:
		_single_root(p, "Control")
	_shader("res://shaders/atmosphere.gdshader")
	_shader("res://shaders/gravity_halo.gdshader")
	assert_true(FileAccess.file_exists("res://presets/.gitkeep"))
