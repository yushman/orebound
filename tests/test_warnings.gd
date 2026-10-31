extends GutTest

const WARNINGS_SCENE := preload("res://ui/Warnings.tscn")
const SHIP_SCENE := preload("res://scenes/Ship.tscn")

var _saved_ship
var _saved_planet
var _ship
var _w


func before_each() -> void:
	_saved_ship = Tuning.ship
	_saved_planet = Tuning.planet
	Tuning.ship = Tuning.ship.duplicate()
	Tuning.planet = Tuning.planet.duplicate()
	var root := Node.new()
	add_child_autofree(root)
	_ship = SHIP_SCENE.instantiate()
	_ship.name = "Ship"
	root.add_child(_ship)
	var layer := Node.new()
	root.add_child(layer)
	_w = WARNINGS_SCENE.instantiate()
	layer.add_child(_w)


func after_each() -> void:
	Tuning.ship = _saved_ship
	Tuning.planet = _saved_planet


func test_snapshot_has_all_the_keys() -> void:
	var d: Dictionary = _w.snapshot(_ship)
	for k in ["r", "hull", "atmo_loss", "reserve", "violation", "tow_left", "notice", "notice_left"]:
		assert_true(d.has(k), k)
	assert_almost_eq(d.r, _ship.state.pos.length(), 1e-3)
	assert_eq(d.atmo_loss, 0.0)


func test_a_crossing_seen_by_the_node_emits_warning_shown_once() -> void:
	Tuning.ship.service_boat = false
	watch_signals(_w)
	_w._physics_process(GravityField.DT)
	assert_signal_not_emitted(_w, "warning_shown")
	_ship.state.pos = Vector2(0, WellGenerator.tiers().tow - 10.0)
	_w._physics_process(GravityField.DT)
	assert_signal_emit_count(_w, "warning_shown", 1)
	assert_signal_emitted_with_parameters(_w, "warning_shown", [&"boundary"])
	_w._physics_process(GravityField.DT)
	_w._physics_process(GravityField.DT)
	assert_signal_emit_count(_w, "warning_shown", 1)
	assert_eq(_w.queue.current_type, &"boundary")


func test_no_events_on_the_first_tick_after_respawn() -> void:
	Tuning.ship.service_boat = false
	_w._physics_process(GravityField.DT)
	_ship.state.pos = Vector2(0, WellGenerator.tiers().tow - 10.0)
	_ship.respawn()
	_ship.state.pos = Vector2(0, WellGenerator.tiers().tow - 10.0)
	watch_signals(_w)
	_w._physics_process(GravityField.DT)
	assert_signal_not_emitted(_w, "warning_shown")


func test_nothing_while_the_flight_is_ended() -> void:
	Tuning.ship.service_boat = false
	_w._physics_process(GravityField.DT)
	_ship.phase = _ship.Phase.ENDED
	_ship.state.pos = Vector2(0, WellGenerator.tiers().tow - 10.0)
	watch_signals(_w)
	_w._physics_process(GravityField.DT)
	assert_signal_not_emitted(_w, "warning_shown")


func test_the_node_is_null_safe_without_a_ship() -> void:
	var w = WARNINGS_SCENE.instantiate()
	add_child_autofree(w)
	assert_null(w.ship)
	w._physics_process(GravityField.DT)
	assert_eq(w.snapshot(null), {})


func test_run_scene_has_warnings_after_hud() -> void:
	var state: SceneState = (load("res://scenes/Run.tscn") as PackedScene).get_state()
	var hud := -1
	var warnings := -1
	for i in state.get_node_count():
		if str(state.get_node_path(i)) == "./CanvasLayer/HUD":
			hud = i
		elif str(state.get_node_path(i)) == "./CanvasLayer/Warnings":
			warnings = i
	assert_gt(hud, -1)
	assert_gt(warnings, hud)
