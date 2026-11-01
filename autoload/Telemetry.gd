extends Node

const LOG_PERIOD := 1.0
const RESET_MIN_TIME := 1.0

var crashes: int = 0
var jettisons: int = 0
var jettison_selects: int = 0
var jettison_cancelled: int = 0
var transfers: int = 0
var tow_calls: int = 0
var tow_cancelled: int = 0
var tow_fee: float = 0.0
var tow_seized_share: float = 0.0
var ceiling_tows: int = 0
var forced_tows: int = 0
var docking_time: float = 0.0
var docking_real_time: float = 0.0
var seed: int = 1
var flight: int = 1
var dir := "user://telemetry"
var ship: Node
var preset := "default"
var start_seed := 1
var start_flight := 1
var flight_time := 0.0
var real_time := 0.0
var warp_time := 0.0
var open := false
var max_heat := 0.0
var heat_limited_time := 0.0
var min_r := INF
var sync_presses := 0
var sync_time := 0.0
var brake_presses := 0
var brake_time := 0.0
var autoscale_overrides := 0
var damage := {}
var tier_time := {}
var _last_r := 0.0
var _sync_on := false
var _brake_on := false
var flight_log := "--flight-log" in OS.get_cmdline_user_args()
var _ship: Node
var _since := 0.0
var _last_cells := -1


func _physics_process(delta: float) -> void:
	if not flight_log:
		return
	if _ship == null:
		_ship = get_tree().current_scene.get_node_or_null("Ship") if get_tree().current_scene != null else null
		if _ship == null:
			return
	var s: ShipState = _ship.state
	_since += delta
	var cells := s.hold.size() * 100 + s.tank.size()
	if _since < LOG_PERIOD and cells == _last_cells:
		return
	_since = 0.0
	_last_cells = cells
	var hold := []
	for c in s.hold:
		hold.append("%s:%.2f" % [c.type, c.fill])
	print("FLOG t=%.2f r=%.0f v=%.1f energy=%.3f tank=%d mass=%.2f hull=%.1f need=%.3f burn[eng=%.3f boost=%.3f brake=%.3f sync=%.3f] hold=[%s]" % [
		GravityField.time(), s.pos.length(), s.vel.length(), Hold.energy(s), s.tank.size(), Hold.mass(s), s.hull,
		Fuel.climb_energy(s.pos.length(), s.vel.length(), Hold.mass(s)),
		s.fuel_engine, s.fuel_boost, s.fuel_soft_brake, s.fuel_sync, ", ".join(hold)])


func begin_flight() -> void:
	start_seed = seed
	start_flight = flight
	preset = Tuning.preset_name
	crashes = 0
	jettisons = 0
	jettison_selects = 0
	jettison_cancelled = 0
	transfers = 0
	tow_calls = 0
	tow_cancelled = 0
	tow_fee = 0.0
	tow_seized_share = 0.0
	ceiling_tows = 0
	forced_tows = 0
	docking_time = 0.0
	docking_real_time = 0.0
	flight_time = 0.0
	real_time = 0.0
	warp_time = 0.0
	max_heat = 0.0
	heat_limited_time = 0.0
	min_r = INF
	sync_presses = 0
	sync_time = 0.0
	brake_presses = 0
	brake_time = 0.0
	autoscale_overrides = 0
	damage = {"atmosphere": 0.0, "moon": 0.0, "asteroid": 0.0, "piece": 0.0}
	tier_time = {"above": 0.0, "t1": 0.0, "t2": 0.0, "t3": 0.0, "t4": 0.0, "atmosphere": 0.0}
	_last_r = 0.0
	_sync_on = false
	_brake_on = false
	open = true


func sample(state: ShipState, input: ShipInput, report: Dictionary, warp := 1.0) -> void:
	var r := state.pos.length()
	_last_r = r
	flight_time += GravityField.DT
	real_time += TimeWarp.real_step(warp)
	if warp > 1.0:
		warp_time += GravityField.DT
	tier_time[_tier_key(r)] += GravityField.DT
	min_r = minf(min_r, r)
	max_heat = maxf(max_heat, state.heat)
	if report.get("heat_limited", false):
		heat_limited_time += GravityField.DT
	if input.drift_sync:
		sync_time += GravityField.DT
		if not _sync_on:
			sync_presses += 1
	_sync_on = input.drift_sync
	if input.soft_brake:
		brake_time += GravityField.DT
		if not _brake_on:
			brake_presses += 1
	_brake_on = input.soft_brake
	var d: Dictionary = report.get("damage", {})
	for k in d:
		damage[k] += d[k]


func _tier_key(r: float) -> String:
	var f: FieldParams = Tuning.field
	if r > f.carrier_orbit_radius:
		return "above"
	if r < f.atmosphere_edge:
		return "atmosphere"
	var b: Array = WellGenerator.tiers()["boundaries"]
	if r >= b[3]:
		return "t1"
	if r >= b[2]:
		return "t2"
	if r >= b[1]:
		return "t3"
	return "t4"


func record(summary: Dictionary) -> Dictionary:
	var fuel: Dictionary = summary["fuel"]
	var total: float = fuel["engine"] + fuel["soft_brake"] + fuel["sync"] + fuel["boost"]
	var outcome: String = summary["outcome"]
	var cause := ""
	if outcome == "crashed":
		cause = "surface" if _last_r <= Tuning.field.planet_surface_radius else "hull"
	return {
		"version": BuildInfo.version(),
		"commit": BuildInfo.commit(),
		"seed": start_seed,
		"flight": start_flight,
		"preset": preset,
		"outcome": outcome,
		"time": flight_time,
		"real_time": real_time,
		"warp_time": warp_time,
		"fuel": fuel.duplicate(),
		"boost_share": fuel["boost"] / total if total > 0.0 else 0.0,
		"heat_limited_time": heat_limited_time,
		"max_heat": max_heat,
		"tier_time": tier_time.duplicate(),
		"max_depth": 0.0 if min_r == INF else maxf(Tuning.field.carrier_orbit_radius - min_r, 0.0),
		"crashes": crashes,
		"crash_cause": cause,
		"tow_kind": summary.get("tow_kind", ""),
		"tow_fee": tow_fee,
		"tow_seized_share": tow_seized_share,
		"ceiling_tows": ceiling_tows,
		"forced_tows": forced_tows,
		"damage": damage.duplicate(),
		"jettisons": jettisons,
		"jettison_selects": jettison_selects,
		"jettison_cancelled": jettison_cancelled,
		"transfers": transfers,
		"tow_calls": tow_calls,
		"tow_cancelled": tow_cancelled,
		"docking_time": docking_time,
		"docking_real_time": docking_real_time,
		"sync_presses": sync_presses,
		"sync_time": sync_time,
		"brake_presses": brake_presses,
		"brake_time": brake_time,
		"autoscale_overrides": autoscale_overrides,
		"cargo": summary.get("cargo", {}).duplicate(),
		"seized": summary.get("seized", {}).duplicate(),
	}


func end_flight(summary: Dictionary) -> void:
	if not open:
		return
	open = false
	if flight_log:
		print("FLOG end outcome=%s t=%.2f crashes=%d jettisons=%d jettison_selects=%d jettison_cancelled=%d transfers=%d" % [summary["outcome"], GravityField.time(), crashes, jettisons, jettison_selects, jettison_cancelled, transfers])
	DirAccess.make_dir_recursive_absolute(dir)
	var d := Time.get_datetime_dict_from_system()
	var base := "%s/%04d%02d%02d-%02d%02d%02d_s%d_f%d" % [dir, d["year"], d["month"], d["day"], d["hour"], d["minute"], d["second"], start_seed, start_flight]
	var path := base + ".json"
	var n := 2
	while FileAccess.file_exists(path):
		path = "%s_%d.json" % [base, n]
		n += 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("telemetry: cannot write " + path)
		return
	f.store_string(JSON.stringify(record(summary), "\t"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and open and ship != null:
		end_flight(FlightSummary.build(ship.state, "quit", flight_time, {}, real_time))
