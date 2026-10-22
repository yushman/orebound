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


func test_full_trajectory_bindings():
	assert_true(InputMap.has_action("ship_full_trajectory"))
	assert_true(_has_key("ship_full_trajectory", KEY_SHIFT))
	var has_stick := false
	for e in InputMap.action_get_events("ship_full_trajectory"):
		if e is InputEventJoypadButton and e.button_index == JOY_BUTTON_LEFT_STICK:
			has_stick = true
	assert_true(has_stick)


func test_brake_bindings():
	assert_true(InputMap.has_action("ship_brake"))
	assert_true(_has_key("ship_brake", KEY_S))
	assert_true(_has_axis("ship_brake", JOY_AXIS_TRIGGER_LEFT))
	assert_almost_eq(InputMap.action_get_deadzone("ship_brake"), 0.5, 0.001)


func test_debug_tuning_panel_binding():
	assert_true(InputMap.has_action("debug_tuning_panel"))
	assert_true(_has_key("debug_tuning_panel", KEY_F1))
