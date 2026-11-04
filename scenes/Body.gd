extends Node2D

const SHADER := preload("res://shaders/planet.gdshader")
const MOON_SHADER := preload("res://shaders/moon.gdshader")
const WellViewScript := preload("res://scenes/WellView.gd")
const DISC_RADIUS := 12.0
const MOON_POINTS := 64
## Capacity of the planet scale table (`sc_*` arrays in planet.gdshader).
const PLANET_SCALES := 16

@export var index: int = 0

var _material := ShaderMaterial.new()

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	var base := Palette.OBOD_ACCENT if index == 0 else Palette.MOON
	_material.shader = SHADER if index == 0 else MOON_SHADER
	if index > 0:
		var pts := PackedVector2Array()
		for k in MOON_POINTS:
			pts.append(Vector2.from_angle(TAU * k / MOON_POINTS) * DISC_RADIUS)
		_visual.polygon = pts
		Style.apply_craters(_material)
		_material.set_shader_parameter("radius", DISC_RADIUS)
	_material.set_shader_parameter("lit_color", base)
	_material.set_shader_parameter("dark_color", Palette.shade(base))
	_material.set_shader_parameter("light", Vector3(Palette.LIGHT_DIR.x, Palette.LIGHT_DIR.y, Palette.LIGHT_ELEVATION))
	_visual.material = _material


func _physics_process(_delta: float) -> void:
	visible = index < Tuning.field.bodies.size()
	if visible:
		position = GravityField.body_pos(index, GravityField.time())


func _process(_delta: float) -> void:
	var f := Tuning.field
	_material.set_shader_parameter("seed", surface_seed(Tuning.picture, index))
	Style.apply(_material)
	if index == 0:
		_apply_planet(f.planet_surface_radius)
		return
	var radius: float = f.bodies[index].radius if index < f.bodies.size() else 0.0
	var k := radius / DISC_RADIUS
	_visual.scale = Vector2(k, k)
	var arch: Array = Tuning.picture.get("archetypes", [])
	Style.apply_moon(_material, arch[index - 1] if index - 1 < arch.size() else 0)
	_apply_motion()


## Camera-centred square covering the view; the shader shades the planet in
## world offsets from the camera, with cells anchored by the scale table.
func _apply_planet(radius: float) -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var c := Vector2.ZERO if cam == null else cam.global_position - global_position
	var h := WellViewScript.visible_half_extent(1.0 if cam == null else cam.zoom.x) * WellViewScript.VIEW_MARGIN
	_visual.polygon = PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
	_visual.scale = Vector2.ONE
	_material.set_shader_parameter("cam", c)
	_material.set_shader_parameter("planet_r", radius)
	_material.set_shader_parameter("time", GravityField.time())
	Style.apply_planet(_material)
	var sizes := PackedFloat32Array()
	var s := Style.PLANET_DETAIL_MAX
	while s >= Style.PLANET_DETAIL_MIN * 0.999 and sizes.size() < PLANET_SCALES - 3:
		sizes.append(s)
		s /= Style.PLANET_DETAIL_LACUNARITY
	var detail_count := sizes.size()
	sizes.append_array([Style.PLANET_LAVA_SIZE, Style.PLANET_LAVA_SIZE_FINE, Style.PLANET_LAVA_SIZE * 3.0])
	var t := scale_table(c, sizes)
	var base: PackedVector2Array = t["base"]
	var frac: PackedVector2Array = t["frac"]
	var n := sizes.size()
	sizes.resize(PLANET_SCALES)
	base.resize(PLANET_SCALES)
	frac.resize(PLANET_SCALES)
	for i in range(n, PLANET_SCALES):
		sizes[i] = 1.0
	_material.set_shader_parameter("detail_count", detail_count)
	_material.set_shader_parameter("sc_size", sizes)
	_material.set_shader_parameter("sc_base", base)
	_material.set_shader_parameter("sc_frac", frac)


func _apply_motion() -> void:
	var pic := Tuning.picture
	var h := posmod(hash([pic.get("seed", 0), pic.get("flight", 0), index, "spin"]), 1000) / 1000.0
	var speed := Style.MOON_SPIN_SPEED * (1.0 + Style.MOON_SPIN_VARIATION * (2.0 * h - 1.0))
	var axis := Vector3(0.0, -cos(Style.MOON_SPIN_TILT), sin(Style.MOON_SPIN_TILT))
	_material.set_shader_parameter("spin", Basis(axis, speed * GravityField.time()))
	var to_planet := (GravityField.body_pos(0, GravityField.time()) - position).normalized()
	_material.set_shader_parameter("planet_dir", Vector3(to_planet.x, to_planet.y, Style.MOON_EARTHSHINE_ELEVATION))
	_material.set_shader_parameter("earth_strength", Style.MOON_EARTHSHINE_STRENGTH)
	_material.set_shader_parameter("earth_color", Palette.OBOD_ACCENT)
	_material.set_shader_parameter("earth_falloff", Style.MOON_EARTHSHINE_FALLOFF)


static func surface_seed(picture: Dictionary, i: int) -> float:
	return posmod(hash([picture.get("seed", 0), picture.get("flight", 0), i]), 1000) / 1000.0


## floor(cam / size) and fract(cam / size) per cell size, in doubles from
## the float32 camera position the shader also gets.
static func scale_table(cam: Vector2, sizes: PackedFloat32Array) -> Dictionary:
	var base := PackedVector2Array()
	var frac := PackedVector2Array()
	for size in sizes:
		var qx: float = cam.x / size
		var qy: float = cam.y / size
		base.append(Vector2(floorf(qx), floorf(qy)))
		frac.append(Vector2(qx - floorf(qx), qy - floorf(qy)))
	return {"base": base, "frac": frac}
