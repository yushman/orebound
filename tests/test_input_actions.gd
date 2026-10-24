extends GutTest


func _has_key(action: String, keycode: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey and e.physical_keycode == keycode:
			return true
	return false


func _has_axis(action: String, axis: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadMotion and e.axis == axis:
			return true
	return false


func _has_mouse_button(action: String, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventMouseButton and e.button_index == button:
			return true
	return false


func _has_joy_button(action: String, button: int) -> bool:
	for e in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and e.button_index == button:
			return true
	return false


func test_input_actions_exist():
	for a in ["ship_rotate_left", "ship_rotate_right", "ship_thrust", "ship_boost",
			"ship_heading_left", "ship_heading_right", "ship_heading_up", "ship_heading_down"]:
		assert_true(InputMap.has_action(a), a)


func test_keyboard_bindings():
	assert_true(_has_key("ship_rotate_left", KEY_A))
	assert_true(_has_key("ship_rotate_right", KEY_D))
	assert_true(_has_key("ship_thrust", KEY_W))
	assert_true(_has_key("ship_boost", KEY_SPACE))


func test_gamepad_bindings():
	assert_true(_has_axis("ship_thrust", JOY_AXIS_TRIGGER_RIGHT))
	assert_almost_eq(InputMap.action_get_deadzone("ship_thrust"), 0.5, 0.001)
	var has_a := false
	for e in InputMap.action_get_events("ship_boost"):
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A:
			has_a = true
	assert_true(has_a)
	assert_true(_has_axis("ship_heading_left", JOY_AXIS_LEFT_X))
	assert_true(_has_axis("ship_heading_right", JOY_AXIS_LEFT_X))
	assert_true(_has_axis("ship_heading_up", JOY_AXIS_LEFT_Y))
	assert_true(_has_axis("ship_heading_down", JOY_AXIS_LEFT_Y))


func test_drift_sync_bindings():
	assert_true(InputMap.has_action("ship_drift_sync"))
	assert_true(_has_key("ship_drift_sync", KEY_SHIFT))
	assert_true(_has_joy_button("ship_drift_sync", JOY_BUTTON_LEFT_STICK))


func test_full_trajectory_action_removed():
	assert_false(InputMap.has_action("ship_full_trajectory"))


func test_brake_bindings():
	assert_true(InputMap.has_action("ship_brake"))
	assert_true(_has_key("ship_brake", KEY_S))
	assert_true(_has_axis("ship_brake", JOY_AXIS_TRIGGER_LEFT))
	assert_almost_eq(InputMap.action_get_deadzone("ship_brake"), 0.5, 0.001)


func test_debug_tuning_panel_binding():
	assert_true(InputMap.has_action("debug_tuning_panel"))
	assert_true(_has_key("debug_tuning_panel", KEY_F1))


func test_zoom_actions_bound():
	assert_true(InputMap.has_action("camera_zoom_in"))
	assert_true(_has_mouse_button("camera_zoom_in", MOUSE_BUTTON_WHEEL_UP))
	assert_true(_has_joy_button("camera_zoom_in", JOY_BUTTON_DPAD_LEFT))
	assert_true(InputMap.has_action("camera_zoom_out"))
	assert_true(_has_mouse_button("camera_zoom_out", MOUSE_BUTTON_WHEEL_DOWN))
	assert_true(_has_joy_button("camera_zoom_out", JOY_BUTTON_DPAD_RIGHT))
