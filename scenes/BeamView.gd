class_name BeamView
extends Polygon2D

const CORE_PX := 2.0
const OUTLINE_PX := 2.0
const WIGGLE_MIN_PX := 6.0
const WIGGLE_MAX_PX := 16.0
const BEAMS := 4
const SPEED := 1.0
const FADE_TIME := 0.15
const WAVELENGTH_PX := 40.0
const FREQUENCY := 10

var energy := 0.0
var end := Vector2.ZERO
var _fade := 0.0
var _len := 0.0
var _aim := 0.0
var _zoom := 1.0
var _mat := ShaderMaterial.new()


func _init() -> void:
	_mat.shader = load("res://shaders/beam.gdshader")
	_mat.set_shader_parameter("color", Palette.ICE.lightened(0.6))
	_mat.set_shader_parameter("outline_color", Palette.ICE)
	_mat.set_shader_parameter("beams", BEAMS)
	_mat.set_shader_parameter("speed", SPEED)
	_mat.set_shader_parameter("frequency", FREQUENCY)
	material = _mat
	texture = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	visible = false


func _process(delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship == null:
		_fade = 0.0
		visible = false
		return
	refresh(ship.state, ship.input, GravityField.time(), delta)


func refresh(state: ShipState, input: ShipInput, t: float, delta := FADE_TIME) -> void:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	_zoom = cam.zoom.x if cam != null else 1.0
	if input.beam:
		var range_ := Tuning.ship.beam_range
		var cands := ShipFlight.beam_candidates(state, t)
		var h := Beam.hit(state.pos, input.aim, range_, cands)
		end = h["point"] if not h.is_empty() else state.pos + Vector2.RIGHT.rotated(input.aim) * range_
		_aim = input.aim
		_len = state.pos.distance_to(end)
		energy = _energy(state, h, cands)
	_fade = clampf(_fade + (delta if input.beam else -delta) / FADE_TIME, 0.0, 1.0)
	visible = _fade > 0.0
	if visible:
		_build(state.pos)


func _energy(state: ShipState, h: Dictionary, cands: Array) -> float:
	var ratio := 0.0
	if not h.is_empty():
		for e in cands:
			if typeof(e["key"]) == typeof(h["key"]) and e["key"] == h["key"]:
				var threshold: float = Tuning.planet.break_per_sqrt_radius * sqrt(sqrt(AsteroidField._area(e["points"]) / PI))
				ratio = clampf(state.beam_charge / threshold, 0.0, 1.0)
				break
	return lerpf(WIGGLE_MIN_PX, WIGGLE_MAX_PX, ratio) / (0.01 * _height_px())


func _height_px() -> float:
	return 2.0 * (CORE_PX * 0.5 + OUTLINE_PX + 2.0 * WIGGLE_MAX_PX)


func _build(origin: Vector2) -> void:
	var h_px := _height_px()
	var half := h_px * 0.5 / _zoom
	position = origin
	rotation = _aim
	polygon = PackedVector2Array([Vector2(0, -half), Vector2(_len, -half), Vector2(_len, half), Vector2(0, half)])
	uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var cells := 1.0 / (WAVELENGTH_PX * FREQUENCY)
	_mat.set_shader_parameter("noise_scale", Vector2(_len * _zoom * cells, h_px * cells))
	_mat.set_shader_parameter("thickness", CORE_PX * 0.5 / h_px)
	_mat.set_shader_parameter("outline_thickness", OUTLINE_PX / h_px)
	_mat.set_shader_parameter("energy", energy)
	_mat.set_shader_parameter("progress", _fade)
