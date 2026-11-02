class_name DistortionView
extends Node2D

const STRENGTH_MAX_PX := 10.0
const STRENGTH_MIN_PX := STRENGTH_MAX_PX / 2.0
const FAN_ANGLE_DEG := 70.0
const FAN_SOFT := 0.15
const FAN_INNER_GAP := 0.1
const RING_WIDTH_PX := 8.0
const FEATHER_PX := 6.0
const ABERRATION := 0.425
const HIT_RING_PX := 28.0
const TREMBLE_SPEED := 30.0
const BURST_TIME := 0.3
const BURST_RADIUS_FACTOR := 2.5
const BURST_STRENGTH_PX := 14.0
const BURST_POOL := 4
const BREAK_RATIO_MIN := 0.5

var beam: BeamView
var bursts: Array = []
var _prev_key = null
var _prev_ratio := 0.0
var _prev_pos := Vector2.ZERO
var _prev_radius := 0.0
var _hit: Polygon2D
var _pool: Array[Polygon2D] = []
var _clock := 0.0


func _init() -> void:
	var shader: Shader = load("res://shaders/distortion.gdshader")
	_hit = _make_quad(shader)
	for i in BURST_POOL:
		_pool.append(_make_quad(shader))


func _make_quad(shader: Shader) -> Polygon2D:
	var q := Polygon2D.new()
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("aberration", ABERRATION)
	m.set_shader_parameter("feather_px", FEATHER_PX)
	q.material = m
	q.visible = false
	add_child(q)
	return q


func _process(delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if beam == null:
		beam = get_node_or_null("../BeamView")
	if ship == null or beam == null:
		_hit.visible = false
		for q in _pool:
			q.visible = false
		return
	refresh(ship.state, delta)


static func hit_strength(ratio: float) -> float:
	return lerpf(STRENGTH_MIN_PX, STRENGTH_MAX_PX, ratio)


static func in_fan(rel: Vector2, aim: Vector2) -> bool:
	return rel.length() > 0.0 and rel.normalized().dot(aim.normalized()) >= cos(deg_to_rad(FAN_ANGLE_DEG * 0.5))


static func broke(key, ratio: float, s: ShipState) -> bool:
	if key == null:
		return false
	if key is Vector3i:
		return s.broken.has(key)
	if ratio < BREAK_RATIO_MIN:
		return false
	for b in s.bodies:
		if typeof(b.id) == typeof(key) and b.id == key:
			return false
	return true


func refresh(state: ShipState, delta: float) -> void:
	_clock += delta
	if broke(_prev_key, _prev_ratio, state):
		_spawn(_prev_pos, _prev_radius)
	_prev_key = beam.target_key
	_prev_ratio = beam.ratio
	_prev_pos = beam.target_pos
	_prev_radius = beam.target_radius
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var zoom := cam.zoom.x if cam != null else 1.0
	if beam.has_hit and beam.target_key != null:
		var tr := 1.0 + 0.1 * sin(_clock * TREMBLE_SPEED)
		var st := hit_strength(beam.ratio) * (0.75 + 0.25 * sin(_clock * TREMBLE_SPEED * 1.7))
		_place(_hit, beam.end, HIT_RING_PX * tr, st, zoom, HIT_RING_PX * (1.0 - FAN_INNER_GAP), Vector2.from_angle(beam.aim))
	else:
		_hit.visible = false
	for i in _pool.size():
		var q := _pool[i]
		if i >= bursts.size() or bursts[i]["age"] >= BURST_TIME:
			q.visible = false
			continue
		var b: Dictionary = bursts[i]
		b["age"] += delta
		if b["age"] >= BURST_TIME:
			q.visible = false
			continue
		var k: float = b["age"] / BURST_TIME
		var r_world: float = lerpf(b["radius"], b["radius"] * BURST_RADIUS_FACTOR, 1.0 - (1.0 - k) * (1.0 - k))
		_place(q, b["pos"], r_world * zoom, BURST_STRENGTH_PX * (1.0 - k), zoom, RING_WIDTH_PX, Vector2.ZERO)


func _spawn(pos: Vector2, radius: float) -> void:
	for i in BURST_POOL:
		if i >= bursts.size():
			bursts.append({"pos": pos, "radius": radius, "age": 0.0})
			return
		if bursts[i]["age"] >= BURST_TIME:
			bursts[i] = {"pos": pos, "radius": radius, "age": 0.0}
			return
	bursts[0] = {"pos": pos, "radius": radius, "age": 0.0}


func _place(q: Polygon2D, world: Vector2, radius_px: float, strength: float, zoom: float, width: float, fan: Vector2) -> void:
	var vp := get_viewport()
	var center_px := vp.get_canvas_transform() * world
	var half := (radius_px + FEATHER_PX + strength + 2.0) / zoom
	q.position = world
	q.polygon = PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	var m: ShaderMaterial = q.material
	m.set_shader_parameter("viewport_size", vp.get_visible_rect().size)
	m.set_shader_parameter("center_px", center_px)
	m.set_shader_parameter("radius_px", radius_px)
	m.set_shader_parameter("strength_px", strength)
	m.set_shader_parameter("width_px", width)
	if fan == Vector2.ZERO:
		m.set_shader_parameter("fan_cos", -2.0)
	else:
		m.set_shader_parameter("fan_cos", cos(deg_to_rad(FAN_ANGLE_DEG * 0.5)))
		m.set_shader_parameter("fan_soft", FAN_SOFT)
		m.set_shader_parameter("fan_dir", vp.get_canvas_transform().basis_xform(fan).normalized())
	q.visible = true
