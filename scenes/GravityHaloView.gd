class_name GravityHaloView
extends Node2D

const MAX_BODIES := 16

const SHADER := preload("res://shaders/gravity_halo.gdshader")
const WellViewScript := preload("res://scenes/WellView.gd")

var _material := ShaderMaterial.new()


## Camera-relative moon uniforms (body 0 is never included); rel is a camera-relative Vector2 (float32, sub-pixel error).
static func build_uniforms(cam: Vector2, t: float) -> Dictionary:
	var f: FieldParams = Tuning.field
	var rel := PackedVector2Array()
	var outer := PackedFloat32Array()
	rel.resize(MAX_BODIES)
	outer.resize(MAX_BODIES)
	var n := 0
	for i in range(1, f.bodies.size()):
		var b: BodyParams = f.bodies[i]
		if b.influence_radius <= 0.0 or n >= MAX_BODIES:
			continue
		rel[n] = GravityField.body_pos(i, t) - cam
		outer[n] = b.influence_radius * (1.0 + f.fade_width)
		n += 1
	return {"moon_count": n, "rel": rel, "outer": outer}


static func ring_phase(u: float) -> float:
	return pow(u, 1.5) if u < 1.0 else 0.0


static func halo_alpha(u: float) -> float:
	return Tuning.view.halo_alpha * (1.0 - u) * (1.0 - u) if u < 1.0 else 0.0


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	Tuning.preset_applied.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var c := Vector2.ZERO if cam == null else cam.position
	position = c
	var u := build_uniforms(c, GravityField.time())
	for k in u:
		_material.set_shader_parameter(k, u[k])
	var w: ViewParams = Tuning.view
	_material.set_shader_parameter("halo_alpha", w.halo_alpha)
	_material.set_shader_parameter("ring_count", w.ring_count)
	_material.set_shader_parameter("ring_period", w.ring_period)
	_material.set_shader_parameter("ring_px", w.ring_px)
	_material.set_shader_parameter("ring_alpha", w.ring_alpha)
	_material.set_shader_parameter("halo_color", Color(Palette.HALO.r, Palette.HALO.g, Palette.HALO.b))
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var h := WellViewScript.visible_half_extent(1.0 if cam == null else cam.zoom.x) * WellViewScript.VIEW_MARGIN
	draw_rect(Rect2(Vector2(-h, -h), Vector2(2.0 * h, 2.0 * h)), Color.WHITE)
