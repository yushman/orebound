extends GutTest

const KEYS := ["autoscale_overrides", "boost_share", "brake_presses", "brake_time", "cargo", "ceiling_tows", "commit", "crash_cause", "crashes", "damage", "docking_time", "flight", "forced_tows", "fuel", "heat_limited_time", "jettison_cancelled", "jettison_selects", "jettisons", "max_depth", "max_heat", "outcome", "preset", "seed", "seized", "sync_presses", "sync_time", "tier_time", "time", "tow_calls", "tow_cancelled", "tow_fee", "tow_kind", "tow_seized_share", "transfers", "version"]
const DIR := "user://telemetry_test"

var _saved_dir: String
var _saved_ship: Node
var _saved_preset: String


func before_each() -> void:
	_saved_dir = Telemetry.dir
	_saved_ship = Telemetry.ship
	_saved_preset = Tuning.preset_name
	Telemetry.dir = DIR
	Telemetry.ship = null
	_clean()


func after_each() -> void:
	_clean()
	Telemetry.dir = _saved_dir
	Telemetry.ship = _saved_ship
	Tuning.preset_name = _saved_preset
	Telemetry.begin_flight()
	Telemetry.open = false


func _clean() -> void:
	for f in _files():
		DirAccess.remove_absolute(DIR + "/" + f)
	DirAccess.remove_absolute(DIR)


func _files() -> PackedStringArray:
	var d := DirAccess.open(DIR)
	return d.get_files() if d != null else PackedStringArray()


func _sm(outcome := "returned") -> Dictionary:
	return FlightSummary.build(ShipState.new(), outcome, 0.0)


func _state_at(r: float) -> ShipState:
	var s := ShipState.new()
	s.pos = Vector2(r, 0)
	return s


func test_record_keys_match_the_schema() -> void:
	Telemetry.begin_flight()
	var keys := Telemetry.record(_sm()).keys()
	keys.sort()
	assert_eq(keys, KEYS)


func test_apply_sets_preset_name() -> void:
	var p := TuningPreset.new()
	p.name = "Pz"
	p.field = Tuning.field
	p.ship = Tuning.ship
	Tuning.apply(p, false)
	assert_eq(Tuning.preset_name, "Pz")


func test_begin_flight_resets_counters_and_captures_header() -> void:
	Telemetry.crashes = 3
	Telemetry.ceiling_tows = 2
	Telemetry.docking_time = 4.0
	Telemetry.seed = 7
	Telemetry.flight = 9
	Tuning.preset_name = "Px"
	Telemetry.begin_flight()
	Telemetry.seed = 8
	var r := Telemetry.record(_sm())
	assert_eq(r["crashes"], 0)
	assert_eq(r["ceiling_tows"], 0)
	assert_eq(r["docking_time"], 0.0)
	assert_eq(r["seed"], 7)
	assert_eq(r["flight"], 9)
	assert_eq(r["preset"], "Px")
	Telemetry.seed = 1
	Telemetry.flight = 1


func test_sample_accumulates_and_tiers_sum_to_time() -> void:
	Telemetry.begin_flight()
	var f: FieldParams = Tuning.field
	var b: Array = WellGenerator.tiers()["boundaries"]
	var radii := [f.carrier_orbit_radius + 10.0, f.carrier_orbit_radius - 10.0, (b[2] + b[3]) * 0.5, (b[1] + b[2]) * 0.5, (f.atmosphere_edge + b[1]) * 0.5, f.atmosphere_edge - 10.0]
	var input := ShipInput.new()
	for r in radii:
		var s := _state_at(r)
		s.heat = 0.4
		Telemetry.sample(s, input, {"damage": {"atmosphere": 1.0, "moon": 0.0, "asteroid": 0.0, "piece": 0.0}, "heat_limited": true})
	var rec := Telemetry.record(_sm())
	var sum := 0.0
	for k in rec["tier_time"]:
		assert_almost_eq(rec["tier_time"][k], GravityField.DT, 1e-9, k)
		sum += rec["tier_time"][k]
	assert_almost_eq(sum, rec["time"], 1e-9)
	assert_almost_eq(rec["max_depth"], f.carrier_orbit_radius - (f.atmosphere_edge - 10.0), 1e-6)
	assert_eq(rec["max_heat"], 0.4)
	assert_almost_eq(rec["damage"]["atmosphere"], 6.0, 1e-9)
	assert_almost_eq(rec["heat_limited_time"], 6 * GravityField.DT, 1e-9)


func test_sample_counts_sync_and_brake_presses() -> void:
	Telemetry.begin_flight()
	var s := _state_at(Tuning.field.carrier_orbit_radius)
	for sync in [true, true, false, true]:
		var input := ShipInput.new()
		input.drift_sync = sync
		input.soft_brake = not sync
		Telemetry.sample(s, input, {})
	var rec := Telemetry.record(_sm())
	assert_eq(rec["sync_presses"], 2)
	assert_almost_eq(rec["sync_time"], 3 * GravityField.DT, 1e-9)
	assert_eq(rec["brake_presses"], 1)
	assert_almost_eq(rec["brake_time"], GravityField.DT, 1e-9)


func test_crash_cause() -> void:
	Telemetry.begin_flight()
	Telemetry.sample(_state_at(Tuning.field.planet_surface_radius - 1.0), ShipInput.new(), {})
	assert_eq(Telemetry.record(_sm("crashed"))["crash_cause"], "surface")
	Telemetry.sample(_state_at(Tuning.field.atmosphere_edge - 5.0), ShipInput.new(), {})
	assert_eq(Telemetry.record(_sm("crashed"))["crash_cause"], "hull")
	assert_eq(Telemetry.record(_sm("returned"))["crash_cause"], "")


func test_end_flight_writes_one_file_once() -> void:
	Telemetry.begin_flight()
	Telemetry.end_flight(_sm())
	Telemetry.end_flight(_sm())
	var files := _files()
	assert_eq(files.size(), 1)
	var data = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + files[0]))
	assert_eq(data["outcome"], "returned")


func _make() -> Node:
	var ship = load("res://scenes/Ship.tscn").instantiate()
	add_child_autofree(ship)
	return ship


func _tick(ship: Node, n: int) -> void:
	for i in n:
		ship._physics_process(GravityField.DT)


func _read(i := 0) -> Dictionary:
	var files := _files()
	return JSON.parse_string(FileAccess.get_file_as_string(DIR + "/" + files[i]))


func test_crash_writes_exactly_one_file_with_outcome_crashed() -> void:
	var ship = _make()
	ship.state.pos = Vector2(Tuning.field.planet_surface_radius - 10.0, 0.0)
	ship.state.hull = 12.0
	_tick(ship, 3)
	assert_eq(_files().size(), 1)
	var rec := _read()
	assert_eq(rec["outcome"], "crashed")
	assert_eq(rec["crash_cause"], "surface")
	assert_eq(rec["crashes"], 1)


func test_ship_registers_itself() -> void:
	var ship = _make()
	assert_eq(Telemetry.ship, ship)


func test_regenerate_after_a_second_writes_reset_with_the_old_header() -> void:
	var ship = _make()
	var old_seed: int = Telemetry.seed
	_tick(ship, 61)
	Tuning.regenerate(old_seed + 100, 5)
	assert_eq(_files().size(), 1)
	var rec := _read()
	assert_eq(rec["outcome"], "reset")
	assert_eq(rec["seed"], old_seed)
	assert_almost_eq(rec["time"], 61 * GravityField.DT, 1e-6)
	Tuning.regenerate(old_seed, 1)


func test_regenerate_under_a_second_writes_nothing() -> void:
	var ship = _make()
	var old_seed: int = Telemetry.seed
	_tick(ship, 10)
	Tuning.regenerate(old_seed + 100, 5)
	assert_eq(_files().size(), 0)
	Tuning.regenerate(old_seed, 1)


func test_close_request_mid_flight_writes_quit_and_not_on_the_summary() -> void:
	var ship = _make()
	_tick(ship, 5)
	Telemetry._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_files().size(), 1)
	assert_eq(_read()["outcome"], "quit")
	Telemetry._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_files().size(), 1)


func test_close_request_on_the_summary_writes_nothing_more() -> void:
	var ship = _make()
	ship.state.pos = Vector2(Tuning.field.planet_surface_radius - 10.0, 0.0)
	_tick(ship, 2)
	Telemetry._notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(_files().size(), 1)
	assert_eq(_read()["outcome"], "crashed")


func test_record_version_and_commit_equal_build_info() -> void:
	Telemetry.begin_flight()
	var rec := Telemetry.record(_sm())
	assert_eq(rec["version"], BuildInfo.version())
	assert_eq(rec["commit"], BuildInfo.commit())
