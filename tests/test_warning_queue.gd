extends GutTest

var _saved_view


func before_each() -> void:
	_saved_view = Tuning.view
	Tuning.view = Tuning.view.duplicate()


func after_each() -> void:
	Tuning.view = _saved_view


func test_warning_time_defaults_to_2_5() -> void:
	assert_eq(ViewParams.new().warning_time, 2.5)


func test_first_push_becomes_current_on_the_next_tick_once() -> void:
	var q := WarningQueue.new()
	q.push(&"a", "A")
	assert_eq(q.tick(0.1), &"a")
	assert_eq(q.current_type, &"a")
	assert_eq(q.current_text, "A")
	assert_eq(q.tick(0.1), &"")


func test_a_warning_lives_warning_time_then_the_next_one_shows() -> void:
	Tuning.view.warning_time = 1.0
	var q := WarningQueue.new()
	q.push(&"a", "A")
	q.push(&"b", "B")
	assert_eq(q.tick(0.5), &"a")
	assert_almost_eq(q.time_left, 1.0, 1e-6)
	assert_eq(q.tick(0.5), &"")
	assert_almost_eq(q.time_left, 0.5, 1e-6)
	assert_eq(q.tick(0.4), &"")
	assert_eq(q.current_type, &"a")
	assert_eq(q.tick(0.2), &"b")
	assert_eq(q.current_text, "B")
	assert_almost_eq(q.time_left, 1.0, 1e-6)


func test_expiry_with_empty_queue_clears_current() -> void:
	Tuning.view.warning_time = 1.0
	var q := WarningQueue.new()
	q.push(&"a", "A")
	q.tick(0.1)
	assert_eq(q.tick(1.0), &"")
	assert_eq(q.current_type, &"")
	assert_eq(q.current_text, "")


func test_same_type_is_not_queued_while_current_or_queued() -> void:
	Tuning.view.warning_time = 1.0
	var q := WarningQueue.new()
	q.push(&"a", "A")
	q.tick(0.1)
	q.push(&"a", "A2")
	q.push(&"b", "B")
	q.push(&"b", "B2")
	assert_eq(q.tick(1.0), &"b")
	assert_eq(q.current_text, "B")
	assert_eq(q.tick(1.0), &"")
	assert_eq(q.current_type, &"")


func test_type_can_repeat_after_it_expired() -> void:
	Tuning.view.warning_time = 1.0
	var q := WarningQueue.new()
	q.push(&"a", "A")
	q.tick(0.1)
	q.tick(1.0)
	q.push(&"a", "A")
	assert_eq(q.tick(0.1), &"a")
