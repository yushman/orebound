class_name CollectorView
extends Polygon2D

const ARC_POINTS := 16
const LINE_WIDTH_PX := 1.5
const LINE_SPACING_PX := 24.0
const LINE_SPEED_PX := 80.0
const LINE_ALPHA := 0.7
const FADE_TIME := 0.15

var fade := 0.0
var radius_px := 0.0
var half_angle := 0.0


func _init() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/collector_lines.gdshader")
	m.set_shader_parameter("color", Palette.ICE)
	m.set_shader_parameter("line_width_px", LINE_WIDTH_PX)
	m.set_shader_parameter("spacing_px", LINE_SPACING_PX)
	m.set_shader_parameter("speed_px", LINE_SPEED_PX)
	m.set_shader_parameter("alpha", LINE_ALPHA)
	material = m
	texture = ImageTexture.create_from_image(Image.create_empty(1, 1, false, Image.FORMAT_RGBA8))
	visible = false


func _process(delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship == null:
		fade = 0.0
		visible = false
		return
	refresh(ship.state, ship.input, delta)


func refresh(state: ShipState, input: ShipInput, delta := FADE_TIME) -> void:
	fade = clampf(fade + (delta if input.collect else -delta) / FADE_TIME, 0.0, 1.0)
	visible = fade > 0.0
	if not visible:
		return
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	var zoom := cam.zoom.x if cam != null else 1.0
	var r := Tuning.ship.beam_range * 0.5
	var half := deg_to_rad(Tuning.ship.collect_angle) * 0.5
	var pts := PackedVector2Array([state.pos])
	var uvs := PackedVector2Array([Vector2.ZERO])
	for i in ARC_POINTS + 1:
		var k := 2.0 * i / ARC_POINTS - 1.0
		pts.append(state.pos + Vector2.RIGHT.rotated(input.aim + half * k) * r)
		uvs.append(Vector2(1.0, k))
	polygon = pts
	uv = uvs
	radius_px = r * zoom
	half_angle = half
	var mat: ShaderMaterial = material
	mat.set_shader_parameter("radius_px", radius_px)
	mat.set_shader_parameter("fade", fade)
