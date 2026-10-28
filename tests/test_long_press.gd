extends GutTest

const DT := 0.1

var _lp: LongPress


func before_each() -> void:
	_lp = LongPress.new(0.7, 2.0, 0.7)


func _hold(seconds: float) -> Array:
	var events := []
	for i in roundi(seconds / DT):
		events.append(_lp.update(true, DT))
	return events


func test_release_before_tap_time_returns_tap() -> void:
	_hold(0.3)
	assert_eq(_lp.update(false, DT), LongPress.Event.TAP)


func test_idle_returns_none() -> void:
	assert_eq(_lp.update(false, DT), LongPress.Event.NONE)
	assert_eq(_lp.update(false, DT), LongPress.Event.NONE)


func test_hold_returns_none_before_hold_time() -> void:
	for e in _hold(1.5):
		assert_eq(e, LongPress.Event.NONE)


func test_fire_at_hold_time_then_every_interval() -> void:
	var events := _hold(3.5)
	var fires := []
	for i in events.size():
		if events[i] == LongPress.Event.FIRE:
			fires.append(i)
	assert_eq(fires, [19, 26, 33])


func test_release_after_fire_is_none() -> void:
	_hold(2.2)
	assert_eq(_lp.update(false, DT), LongPress.Event.NONE)


func test_release_in_cancel_window_returns_cancel() -> void:
	_hold(1.0)
	assert_eq(_lp.update(false, DT), LongPress.Event.CANCEL)


func test_release_after_cancel_window_returns_none() -> void:
	_hold(1.8)
	assert_eq(_lp.update(false, DT), LongPress.Event.NONE)


func test_cancel_window_clipped_by_hold_time() -> void:
	var lp := LongPress.new(0.7, 1.2, 0.7)
	for i in 11:
		lp.update(true, DT)
	assert_eq(lp.update(false, DT), LongPress.Event.CANCEL)
	var lp2 := LongPress.new(0.7, 1.2, 0.7)
	var fired := false
	for i in 12:
		fired = lp2.update(true, DT) == LongPress.Event.FIRE or fired
	assert_true(fired)
	assert_eq(lp2.update(false, DT), LongPress.Event.NONE)


func test_new_press_after_release_starts_fresh() -> void:
	_hold(0.3)
	_lp.update(false, DT)
	_hold(0.3)
	assert_eq(_lp.update(false, DT), LongPress.Event.TAP)
