extends Node2D
## Atmosphere glow (W3): camera-centred square shaded orange with alpha
## ATMO_ALPHA * density. View-only; reads Tuning on every refresh.

const GLOW_COLOR := Color(1.0, 0.55, 0.15)
const ATMO_ALPHA := 0.45

const SHADER := preload("res://shaders/atmosphere.gdshader")
const WellViewScript := preload("res://scenes/WellView.gd")

var _material := ShaderMaterial.new()


static func build_uniforms(cam: Vector2) -> Dictionary:
	var f: FieldParams = Tuning.field
	return {
		"cam": cam,
		"surface": f.planet_surface_radius,
		"edge": f.atmosphere_edge,
		"shape": Tuning.planet.density_shape,
	}


static func density(r: float, u: Dictionary) -> float:
	var depth: float = (u["edge"] - r) / (u["edge"] - u["surface"])
	return pow(clampf(depth, 0.0, 1.0), u["shape"])


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	Tuning.preset_applied.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var u := build_uniforms(Vector2.ZERO if cam == null else cam.position)
	for k in u:
		_material.set_shader_parameter(k, u[k])
	_material.set_shader_parameter("GLOW_COLOR", GLOW_COLOR)
	_material.set_shader_parameter("ATMO_ALPHA", ATMO_ALPHA)
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var center := Vector2.ZERO if cam == null else cam.position
	var h := WellViewScript.visible_half_extent(1.0 if cam == null else cam.zoom.x) * WellViewScript.VIEW_MARGIN
	draw_rect(Rect2(center - Vector2(h, h), Vector2(2.0 * h, 2.0 * h)), Color.WHITE)
