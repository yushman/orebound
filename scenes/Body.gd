extends Node2D

const DISC_RADIUS := 12.0
const PLANET_POINTS := 512
const MOON_POINTS := 64
const PLANET_LIT_POINTS := 256
const MOON_LIT_POINTS := 32

@export var index: int = 0

@onready var _visual: Polygon2D = $Visual
@onready var _lit: Polygon2D = $Visual/Lit


func _ready() -> void:
	var base := Palette.OBOD_ACCENT if index == 0 else Palette.MOON
	var n := PLANET_POINTS if index == 0 else MOON_POINTS
	var lit_n := PLANET_LIT_POINTS if index == 0 else MOON_LIT_POINTS
	var pts := PackedVector2Array()
	for k in n:
		pts.append(Vector2.from_angle(TAU * k / n) * DISC_RADIUS)
	_visual.polygon = pts
	_visual.color = Palette.shade(base)
	_lit.polygon = Palette.lit_half(DISC_RADIUS, lit_n, Palette.LIGHT_DIR)
	_lit.color = base


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
