extends GutTest


func _synced(layer: Layer3D) -> Layer3D:
	var owner_node = add_child_autofree(Node2D.new())
	owner_node.add_child(layer)
	layer.sync(owner_node)
	return layer


func test_rim_layer_has_a_type_pass_and_an_ore_asteroid_material():
	var layer := _synced(Layer3D.new(true))
	assert_not_null(layer.type_view)
	assert_eq(layer.type_view.world_3d, layer.world_3d, "type pass shares the world")
	assert_eq(layer.type_view.size, layer.size)
	assert_eq(layer.camera.cull_mask, Layer3D.MAIN_LAYER)
	assert_eq(layer.type_camera.cull_mask, Layer3D.TYPE_LAYER)
	assert_true(layer.asteroid.get_shader_parameter("incl_on"))
	assert_almost_eq(layer.asteroid.get_shader_parameter("incl_boost"), Style.INCLUSION_BOOST, 1e-6)
	assert_almost_eq(layer.asteroid.get_shader_parameter("dark_strength"), Style.EDGE_DARK_STRENGTH, 1e-6)
	assert_eq(layer.asteroid.get_shader_parameter("dark_lit_only"), Style.EDGE_DARK_LIT_ONLY)
	assert_true(layer.blit_material.get_shader_parameter("rim_on"))
	assert_eq(layer.blit_material.get_shader_parameter("type_tex"), layer.type_view.get_texture())
	assert_almost_eq(layer.blit_material.get_shader_parameter("rim_px"), Style.RIM_PX, 1e-6)
	assert_ne(layer.solid.get_shader_parameter("incl_on"), true, "solid stays plain")


func test_default_layer_has_no_type_pass_no_rim_and_plain_solid():
	var layer := _synced(Layer3D.new())
	assert_null(layer.type_view)
	assert_false(layer.blit_material.get_shader_parameter("rim_on"))
	assert_ne(layer.solid.get_shader_parameter("incl_on"), true)
	var dark = layer.solid.get_shader_parameter("dark_strength")
	assert_true(dark == null or dark == 0.0, "no edge darkening on solid")


func test_rim_direction_follows_the_canvas_rotation():
	var layer := _synced(Layer3D.new(true))
	var rot := layer.get_viewport().get_canvas_transform().get_rotation()
	var want := Palette.LIGHT_DIR.normalized().rotated(rot)
	var got: Vector2 = layer.blit_material.get_shader_parameter("rim_dir")
	assert_almost_eq(got.x, want.x, 1e-5)
	assert_almost_eq(got.y, want.y, 1e-5)


func test_piece_material_boosts_and_others_do_not():
	var layer := _synced(Layer3D.new(true))
	assert_almost_eq(layer.piece.get_shader_parameter("piece_boost"), Style.PIECE_BOOST, 1e-6)
	assert_almost_eq(Style.PIECE_BOOST, 2.5, 1e-6)
	assert_eq(layer.piece.shader, Layer3D.SOLID)
	assert_ne(layer.piece.get_shader_parameter("incl_on"), true)
	for m in [layer.solid, layer.asteroid]:
		var b = m.get_shader_parameter("piece_boost")
		assert_true(b == null or b == 1.0)

