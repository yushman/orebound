extends Control

const FONT_SIZE := 20
const TITLE_SIZE := 32
const FUEL_ROWS := [["engine", "двигатель"], ["boost", "ускорение"], ["soft_brake", "торможение"], ["sync", "синхронизация"]]

var _delay_left := -1.0
var _prev_pressed := false
var _title: Label
var _body: Label


static func title_color(outcome: String) -> Color:
	return Palette.SAFE if outcome == "returned" else Palette.DANGER


static func title(outcome: String) -> String:
	return "вернулся" if outcome == "returned" else "гибель"


static func lines(summary: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	out.append(title(summary["outcome"]))
	var cargo: Dictionary = summary["cargo"]
	for type in cargo:
		out.append("%s — %.1f" % [type, cargo[type]])
	if summary["cargo_lost"]:
		out.append("груз потерян")
	var fuel: Dictionary = summary["fuel"]
	for row in FUEL_ROWS:
		out.append("%s — %.2f" % [row[1], fuel[row[0]]])
	var secs := int(summary["time"])
	out.append("время — %02d:%02d" % [secs / 60, secs % 60])
	out.append("Enter / A — следующий вылет")
	return out


func _ready() -> void:
	var back := ColorRect.new()
	back.color = Color(Palette.BACKGROUND, 0.75)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", TITLE_SIZE)
	box.add_child(_title)
	_body = Label.new()
	_body.add_theme_font_size_override("font_size", FONT_SIZE)
	_body.add_theme_color_override("font_color", Palette.HALO)
	box.add_child(_body)
	var ship := get_node_or_null("../../Ship")
	if ship != null:
		ship.flight_ended.connect(show_summary)


func show_summary(summary: Dictionary) -> void:
	var rows := lines(summary)
	_title.text = rows[0]
	_title.add_theme_color_override("font_color", title_color(summary["outcome"]))
	_body.text = "\n".join(rows.slice(1))
	_delay_left = Tuning.view.summary_delay


func _process(delta: float) -> void:
	var pressed := Input.is_action_pressed("flight_next")
	if _delay_left >= 0.0:
		_delay_left -= delta
		if _delay_left < 0.0:
			_delay_left = -1.0
			visible = true
	elif visible and pressed and not _prev_pressed:
		visible = false
		Tuning.regenerate(Telemetry.seed, Telemetry.flight + 1)
	_prev_pressed = pressed
