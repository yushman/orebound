extends Control

const REGEN_PROPS := ["moon_mass_k", "moon_mass_exp", "moon_influence_k", "moon_margin", "ring_width", "ring_density"]

const GRAVITY_PROPS := ["k", "eps", "fade_width", "mass", "p"]

const ROWS := [
	["field", "k", 1.0, 10000.0, 1.0],
	["field", "eps", 0.01, 10.0, 0.01],
	["field", "fade_width", 0.01, 2.0, 0.01],
	[0, "p", 0.5, 3.0, 0.01],
	[1, "p", 0.5, 3.0, 0.01],
	[2, "p", 0.5, 3.0, 0.01],
	[0, "mass", 1.0, 2e7, 0.01],
	[1, "mass", 1.0, 2e7, 0.01],
	[2, "mass", 1.0, 2e7, 0.01],
	[1, "influence_radius", 0.0, 20000.0, 10.0],
	[2, "influence_radius", 0.0, 20000.0, 10.0],
	["ship", "thrust_accel", 0.0, 50.0, 0.5],
	["ship", "boost_accel_mult", 1.0, 10.0, 0.05],
	["ship", "boost_fuel_mult", 0.0, 10.0, 0.05],
	["ship", "brake_accel", 0.0, 50.0, 0.1],
	["ship", "brake_fuel_mult", 0.0, 10.0, 0.05],
	["ship", "fuel_per_dv", 0.0, 0.01, 0.0001],
	["ship", "ramp_time", 0.0, 5.0, 0.05],
	["ship", "ramp_min_fraction", 0.0, 1.0, 0.01],
	["ship", "heat_growth_engine", 0.0, 0.5, 0.005],
	["ship", "heat_growth_boost", 0.0, 1.0, 0.01],
	["ship", "heat_threshold", 0.0, 1.0, 0.01],
	["ship", "heat_cooldown", 0.0, 0.5, 0.005],
	["ship", "min_thrust_fraction", 0.0, 1.0, 0.01],
	["ship", "sync_accel", 0.0, 30.0, 0.1],
	["ship", "sync_fuel_mult", 0.0, 10.0, 0.05],
	["ship", "predict_every", 1.0, 30.0, 1.0],
	["ship", "predict_short_steps", 300.0, 1800.0, 1.0],
	["ship", "hull_max", 1.0, 1000.0, 1.0],
	["planet", "atmosphere_drag", 0.0, 2.0, 0.005],
	["planet", "atmosphere_damage", 0.0, 100.0, 0.1],
	["planet", "density_shape", 0.5, 5.0, 0.05],
	["planet", "moon_mass_k", 0.0001, 0.01, 0.00001],
	["planet", "moon_mass_exp", 1.0, 3.0, 0.01],
	["planet", "moon_influence_k", 1.0, 3.0, 0.01],
	["planet", "moon_margin", 0.0, 1000.0, 10.0],
	["planet", "moon_bounce", 0.0, 1.0, 0.01],
	["planet", "moon_impact_damage", 0.0, 1.0, 0.005],
	["planet", "ring_width", 100.0, 5000.0, 10.0],
	["planet", "ring_density", 0.0, 1.0, 0.01],
	["planet", "band_width", 200.0, 5000.0, 10.0],
	["planet", "chunk_arc", 500.0, 20000.0, 50.0],
	["planet", "chunk_gen_radius", 2000.0, 60000.0, 100.0],
	["planet", "asteroids_per_band", 100.0, 500.0, 1.0],
	["planet", "drop_start", 0.0, 30.0, 1.0],
	["planet", "drop_ratio", 0.05, 1.0, 0.01],
	["planet", "above_factor", 0.0, 1.0, 0.01],
	["planet", "field_radius", 50.0, 3000.0, 10.0],
	["planet", "ast_radius_min", 5.0, 500.0, 1.0],
	["planet", "ast_radius_max", 5.0, 500.0, 1.0],
	["planet", "asteroid_bounce", 0.0, 1.0, 0.01],
	["planet", "asteroid_impact_damage", 0.0, 1.0, 0.005],
	["planet", "rest_speed", 0.0, 2.0, 0.01],
	["view", "halo_alpha", 0.0, 1.0, 0.01],
	["view", "ring_count", 1.0, 12.0, 1.0],
	["view", "ring_period", 0.2, 10.0, 0.1],
	["view", "ring_px", 0.5, 5.0, 0.05],
	["view", "ring_alpha", 0.0, 1.0, 0.01],
	["view", "cargo_fill", 0.0, 1.0, 0.01],
]

var sliders := {}
var row_boxes := {}
var presets_dir := "res://presets"
var preset_select: OptionButton
var load_button: Button
var save_button: Button
var seed_box: SpinBox
var next_seed_button: Button
var _requested_seed := 0
var _values := {}
var readout: Label
var ship: Node
var _box: VBoxContainer


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	visible = false
	readout = Label.new()
	readout.focus_mode = Control.FOCUS_NONE
	var scroll := ScrollContainer.new()
	scroll.focus_mode = Control.FOCUS_NONE
	scroll.custom_minimum_size = Vector2(380, 760)
	add_child(scroll)
	_box = VBoxContainer.new()
	_box.focus_mode = Control.FOCUS_NONE
	scroll.add_child(_box)
	_box.add_child(readout)
	_add_header()
	for row in ROWS:
		_add_row(row)
	_sync()
	Tuning.preset_applied.connect(_sync)


func _process(_delta: float) -> void:
	if not visible:
		return
	if ship == null:
		ship = get_node_or_null("../../Ship")
	if ship == null:
		readout.text = "crashes %d" % Telemetry.crashes
		return
	var st: ShipState = ship.state
	readout.text = "hull %s  density %s  crashes %d" % [
		_fmt(st.hull), snappedf(ShipFlight.atmosphere_density(st.pos), 0.001), Telemetry.crashes]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_tuning_panel"):
		visible = not visible
		get_viewport().set_input_as_handled()


func _add_header() -> void:
	var hb := HBoxContainer.new()
	hb.focus_mode = Control.FOCUS_NONE
	preset_select = OptionButton.new()
	preset_select.focus_mode = Control.FOCUS_NONE
	for n in ["P1 Ньютон", "P2 Плоский 2D", "P3 Компромисс", "P4 Смешанный"]:
		preset_select.add_item(n)
	preset_select.select(3)
	load_button = Button.new()
	load_button.text = "Load"
	load_button.focus_mode = Control.FOCUS_NONE
	load_button.pressed.connect(_on_load)
	save_button = Button.new()
	save_button.text = "Save"
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.pressed.connect(_on_save)
	hb.add_child(preset_select)
	hb.add_child(load_button)
	hb.add_child(save_button)
	_box.add_child(hb)
	var sb := HBoxContainer.new()
	sb.focus_mode = Control.FOCUS_NONE
	seed_box = SpinBox.new()
	seed_box.min_value = 0
	seed_box.max_value = 2147483647
	seed_box.rounded = true
	seed_box.value = Telemetry.seed
	_requested_seed = Telemetry.seed
	seed_box.value_changed.connect(func(v: float) -> void:
		_requested_seed = int(v)
		Tuning.regenerate(_requested_seed, 1))
	seed_box.focus_mode = Control.FOCUS_NONE
	var seed_edit := seed_box.get_line_edit()
	seed_edit.focus_mode = Control.FOCUS_CLICK
	seed_edit.text_submitted.connect(func(_t: String) -> void:
		seed_box.apply()
		seed_edit.release_focus())
	next_seed_button = Button.new()
	next_seed_button.text = "Next seed"
	next_seed_button.focus_mode = Control.FOCUS_NONE
	next_seed_button.pressed.connect(func() -> void:
		_requested_seed = maxi(_requested_seed, Telemetry.seed) + 1
		Tuning.regenerate(_requested_seed, Telemetry.flight))
	sb.add_child(seed_box)
	sb.add_child(next_seed_button)
	_box.add_child(sb)


func _preset_path() -> String:
	return "%s/p%d.tres" % [presets_dir.trim_suffix("/"), preset_select.selected + 1]


func _on_load() -> void:
	var preset := Tuning.load_preset(_preset_path())
	if preset == null:
		push_error("TuningPanel: cannot load %s" % _preset_path())
		return
	Tuning.apply(preset, false)
	Tuning.regenerate(Telemetry.seed, Telemetry.flight)


func _on_save() -> void:
	var err := Tuning.save_preset(_preset_path(), preset_select.get_item_text(preset_select.selected))
	if err != OK:
		push_error("TuningPanel: save to %s failed (%d)" % [_preset_path(), err])


func _id(target: Variant, prop: String) -> String:
	if target is int:
		return "body%d.%s" % [target, prop]
	return "%s.%s" % [target, prop]


func _holder(target: Variant) -> Object:
	if target is int:
		return Tuning.field.bodies[target]
	if target == "planet":
		return Tuning.planet
	if target == "view":
		return Tuning.view
	return Tuning.field if target == "field" else Tuning.ship


func _add_row(row: Array) -> void:
	var target: Variant = row[0]
	var prop: String = row[1]
	var id := _id(target, prop)
	var hb := HBoxContainer.new()
	hb.focus_mode = Control.FOCUS_NONE
	var label := Label.new()
	label.text = id
	label.custom_minimum_size.x = 150
	label.focus_mode = Control.FOCUS_NONE
	var s := HSlider.new()
	s.min_value = row[2]
	s.max_value = row[3]
	s.step = row[4]
	s.exp_edit = prop == "mass"
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	var val := Label.new()
	val.custom_minimum_size.x = 70
	val.focus_mode = Control.FOCUS_NONE
	hb.add_child(label)
	hb.add_child(s)
	hb.add_child(val)
	_box.add_child(hb)
	row_boxes[id] = hb
	sliders[id] = s
	_values[id] = val
	s.value_changed.connect(_on_changed.bind(target, prop, val))


func _on_changed(v: float, target: Variant, prop: String, val: Label) -> void:
	var holder := _holder(target)
	holder.set(prop, int(v) if holder.get(prop) is int else v)
	val.text = _fmt(v)
	if target is String and target == "planet" and prop in REGEN_PROPS:
		Tuning.regenerate(Telemetry.seed, Telemetry.flight)
	elif (target is int and target == 0 or target is String and target == "field") and prop in GRAVITY_PROPS:
		Tuning.regenerate(Telemetry.seed, Telemetry.flight)


func _fmt(v: float) -> String:
	return str(snappedf(v, 0.0001))


func _sync() -> void:
	seed_box.set_value_no_signal(Telemetry.seed)
	# Rows of bodies the field does not have stay hidden and unsynced.
	var body_count := Tuning.field.bodies.size()
	for row in ROWS:
		var id := _id(row[0], row[1])
		if row[0] is int and row[0] >= body_count:
			row_boxes[id].visible = false
			continue
		row_boxes[id].visible = true
		var v: float = _holder(row[0]).get(row[1])
		var s: HSlider = sliders[id]
		s.allow_lesser = true
		s.allow_greater = true
		s.set_value_no_signal(v)
		s.allow_lesser = false
		s.allow_greater = false
		_values[id].text = _fmt(v)
