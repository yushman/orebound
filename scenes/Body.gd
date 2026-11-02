extends Node2D

const SHADER := preload("res://shaders/body.gdshader")
const MOON_SHADER := preload("res://shaders/moon.gdshader")
const DISC_RADIUS := 12.0
const PLANET_POINTS := 512
const MOON_POINTS := 64

@export var index: int = 0

var _material := ShaderMaterial.new()

@onready var _visual: Polygon2D = $Visual


func _ready() -> void:
	var base := Palette.OBOD_ACCENT if index == 0 else Palette.MOON
	var n := PLANET_POINTS if index == 0 else MOON_POINTS
	var pts := PackedVector2Array()
	for k in n:
		pts.append(Vector2.from_angle(TAU * k / n) * DISC_RADIUS)
	_visual.polygon = pts
	_material.shader = SHADER if index == 0 else MOON_SHADER
	if index > 0:
		Style.apply_craters(_material)
	_material.set_shader_parameter("lit_color", base)
	_material.set_shader_parameter("dark_color", Palette.shade(base))
	_material.set_shader_parameter("light", Vector3(Palette.LIGHT_DIR.x, Palette.LIGHT_DIR.y, Palette.LIGHT_ELEVATION))
	_material.set_shader_parameter("radius", DISC_RADIUS)
	_visual.material = _material


func _physics_process(_delta: float) -> void:
	visible = index < Tuning.field.bodies.size()
	if visible:
		position = GravityField.body_pos(index, GravityField.time())


func _process(_delta: float) -> void:
	var f := Tuning.field
	var radius := 0.0
	if index == 0:
		radius = f.planet_surface_radius
	elif index < f.bodies.size():
		radius = f.bodies[index].radius
	var k := radius / DISC_RADIUS
	_visual.scale = Vector2(k, k)
	_material.set_shader_parameter("seed", surface_seed(Tuning.picture, index))
	Style.apply(_material)


static func surface_seed(picture: Dictionary, i: int) -> float:
	return posmod(hash([picture.get("seed", 0), picture.get("flight", 0), i]), 1000) / 1000.0
