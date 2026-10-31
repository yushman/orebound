extends GutTest

var _saved_seed: int
var _saved_flight: int
var _saved_field
var _saved_picture


func before_each() -> void:
	_saved_seed = Telemetry.seed
	_saved_flight = Telemetry.flight
	_saved_field = Tuning.field
	_saved_picture = Tuning.picture
	Tuning.field = _saved_field.duplicate(true)


func after_each() -> void:
	Input.action_release("flight_next")
	Tuning.field = _saved_field
	Tuning.picture = _saved_picture
	Telemetry.seed = _saved_seed
	Telemetry.flight = _saved_flight


func _sample(outcome := "returned") -> Dictionary:
	return {
		"outcome": outcome,
		"cargo": {&"ice": 1.5, &"ore_middle": 4.0},
		"cargo_lost": outcome == "crashed",
		"fuel": {"engine": 1.25, "boost": 0.5, "soft_brake": 0.0, "sync": 2.0},
		"time": 83.0,
	}


func _make() -> Control:
	var s: Control = load("res://ui/Summary.tscn").instantiate()
	add_child_autofree(s)
	return s


func _joined(summary: Dictionary) -> String:
	return "\n".join(load("res://ui/Summary.gd").lines(summary))


func test_lines_show_outcome_title_cargo_rows_fuel_rows_and_time() -> void:
	var text := _joined(_sample())
	assert_string_contains(text, "вернулся")
	assert_string_contains(text, "ice — 1.5")
	assert_string_contains(text, "ore_middle — 4.0")
	assert_false("потерян" in text)
	assert_string_contains(text, "1.25")
	assert_string_contains(text, "2.00")
	assert_string_contains(text, "01:23")
	assert_string_contains(text, "Enter / A — следующий вылет")


func test_lines_crash_shows_title_and_cargo_lost() -> void:
	var text := _joined(_sample("crashed"))
	assert_string_contains(text, "гибель")
	assert_string_contains(text, "груз потерян")


func test_title_color_by_outcome() -> void:
	var cls = load("res://ui/Summary.gd")
	assert_eq(cls.title_color("returned"), Palette.SAFE)
	assert_eq(cls.title_color("crashed"), Palette.DANGER)


func test_screen_is_hidden_then_shows_after_summary_delay() -> void:
	var s := _make()
	assert_false(s.visible)
	s.show_summary(_sample())
	assert_false(s.visible)
	s._process(Tuning.view.summary_delay - 0.1)
	assert_false(s.visible)
	s._process(0.2)
	assert_true(s.visible)


func test_fresh_press_starts_next_flight_and_hides() -> void:
	var s := _make()
	Tuning.regenerate(7, 3)
	s.show_summary(_sample())
	s._process(Tuning.view.summary_delay + 0.1)
	assert_true(s.visible)
	Input.action_press("flight_next")
	s._process(0.016)
	assert_eq(Telemetry.flight, 4)
	assert_eq(Telemetry.seed, 7)
	assert_false(s.visible)


func test_press_held_from_before_it_appeared_is_ignored() -> void:
	var s := _make()
	Tuning.regenerate(7, 3)
	Input.action_press("flight_next")
	s._process(0.016)
	s.show_summary(_sample())
	s._process(Tuning.view.summary_delay + 0.1)
	assert_true(s.visible)
	s._process(0.016)
	assert_eq(Telemetry.flight, 3)
	Input.action_release("flight_next")
	s._process(0.016)
	Input.action_press("flight_next")
	s._process(0.016)
	assert_eq(Telemetry.flight, 4)


func test_press_before_summary_is_visible_does_nothing() -> void:
	var s := _make()
	Tuning.regenerate(7, 3)
	s.show_summary(_sample())
	Input.action_press("flight_next")
	s._process(0.1)
	assert_eq(Telemetry.flight, 3)


func test_towed_title_color_and_lines() -> void:
	assert_eq(load("res://ui/Summary.gd").title("towed"), "буксир")
	assert_eq(load("res://ui/Summary.gd").title_color("towed"), Palette.SAFE)
	var d := _sample("towed")
	d["seized_share"] = 0.37
	d["seized"] = {&"ore_middle": 2.5}
	var rows: PackedStringArray = load("res://ui/Summary.gd").lines(d)
	assert_true("изъято 37%" in rows)
	assert_true("изъято: ore_middle — 2.5" in rows)
	assert_false("изъято 0%" in load("res://ui/Summary.gd").lines(_sample()))


func test_tow_kind_lines() -> void:
	var d := _sample("towed")
	d["tow_kind"] = "ceiling"
	assert_true("потолок" in load("res://ui/Summary.gd").lines(d))
	d["tow_kind"] = "forced"
	assert_true("ниже границы буксира" in load("res://ui/Summary.gd").lines(d))
	d["tow_kind"] = "manual"
	var rows: PackedStringArray = load("res://ui/Summary.gd").lines(d)
	assert_false("потолок" in rows)
	assert_false("ниже границы буксира" in rows)
