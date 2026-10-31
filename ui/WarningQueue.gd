class_name WarningQueue
extends RefCounted

var current_type: StringName = &""
var current_text := ""
var time_left := 0.0
var _queue: Array = []


func push(type: StringName, text: String) -> void:
	if type == current_type:
		return
	for e in _queue:
		if e[0] == type:
			return
	_queue.append([type, text])


func tick(dt: float) -> StringName:
	if current_type != &"":
		time_left -= dt
		if time_left > 0.0:
			return &""
		current_type = &""
		current_text = ""
	if _queue.is_empty():
		return &""
	var next: Array = _queue.pop_front()
	current_type = next[0]
	current_text = next[1]
	time_left = Tuning.view.warning_time
	return current_type
