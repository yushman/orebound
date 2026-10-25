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

func test_stub_scenes_and_shaders() -> void:
	for p in ["res://scenes/Carrier.tscn", "res://scenes/Field.tscn"]:
		_single_root(p, "Node2D")
	for p in ["res://ui/HUD.tscn"]:
		_single_root(p, "Control")
	_shader("res://shaders/atmosphere.gdshader")
	_shader("res://shaders/gravity_halo.gdshader")
	assert_true(FileAccess.file_exists("res://presets/.gitkeep"))
