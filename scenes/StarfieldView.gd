class_name StarfieldView
extends Node2D
## Static starfield (M11): world-fixed procedural stars in 3 hash layers.
## View-only; reads Tuning on every refresh, no TIME in the shader.

const SHADER := preload("res://shaders/starfield.gdshader")
const WellViewScript := preload("res://scenes/WellView.gd")

const LAYERS := 3
const CELL_STEP := 8.0
const FADE0 := 2.5
const FADE1 := 4.5
const HASH_A := 374761393
const HASH_B := 668265263
const HASH_C := 2246822519
const HASH_D := 3266489917
const BRIGHT_LOW := 0.35
const BRIGHT_STEP := 0.325
const U32 := 0xFFFFFFFF

var _material := ShaderMaterial.new()


static func _u32(v: int) -> int:
	return v & U32


## pcg-style 32-bit int hash, mirrored line-for-line by the shader's star_hash.
static func _star_hash(cx: int, cy: int, base: int) -> int:
	var h := (_u32(cx) * HASH_A + _u32(cy) * HASH_B + base) & U32
	h = _u32((h ^ (h >> 15)) * HASH_C)
	h = _u32((h ^ (h >> 13)) * HASH_D)
	return _u32(h ^ (h >> 16))


static func _base(k: int, layer: int) -> int:
	return (_u32(Tuning.picture.seed) + _u32(layer) * 2654435761 + _u32(k) * 40503) & U32


static func cell_size(layer: int) -> float:
	return Tuning.view.star_cell0 * pow(CELL_STEP, float(layer))


static func cell_hash(cx: int, cy: int, k: int, layer: int) -> int:
	return _star_hash(cx, cy, _base(k, layer))


static func star_pos(cx: int, cy: int, k: int, layer: int) -> Vector2:
	var h := cell_hash(cx, cy, k, layer)
	var frac := Vector2(float(h & 0xFFFF), float((h >> 16) & 0xFFFF)) / 65536.0
	return (Vector2(cx, cy) + frac) * cell_size(layer)


static func brightness(cx: int, cy: int, k: int, layer: int) -> float:
	var h := _star_hash(cx, cy, (_base(k, layer) + 1013904223) & U32)
	return BRIGHT_LOW + BRIGHT_STEP * float(h % 3)


## Layer cross-fade over log2(s): layer 0 is gone by the x8 cell step (log2 3),
## layer 1 hands over half-way to the next step (the zoom cap at 40 cuts the
## ladder before log2 6), weights sum to 1.
static func layer_weights(s: float) -> Vector3:
	var f: float = Tuning.view.star_fade
	var lg := log(maxf(s, 1.0)) / log(2.0)
	var ss0 := smoothstep(FADE0 - f * 0.5, FADE0 + f * 0.5, lg)
	var ss1 := smoothstep(FADE1 - f * 0.5, FADE1 + f * 0.5, lg)
	return Vector3(1.0 - ss0, ss0 * (1.0 - ss1), ss0 * ss1)


## CPU mirror of the stars the shader draws: cells of every layer inside the
## drawn square, weighted by the layer weight.
static func expected_stars(cam: Vector2, s: float) -> float:
	var h := WellViewScript.visible_half_extent(1.0 / s) * WellViewScript.VIEW_MARGIN
	var w := layer_weights(s)
	var per: int = Tuning.view.star_per_cell
	var total := 0.0
	for i in LAYERS:
		var c := cell_size(i)
		var nx := int(floor((cam.x + h) / c)) - int(floor((cam.x - h) / c)) + 1
		var ny := int(floor((cam.y + h) / c)) - int(floor((cam.y - h) / c)) + 1
		total += w[i] * float(nx * ny * per)
	return total


static func build_uniforms(cam: Vector2, s: float) -> Dictionary:
	var w: ViewParams = Tuning.view
	return {
		"cam": cam,
		"seed": Tuning.picture.seed,
		"cell0": w.star_cell0,
		"per_cell": w.star_per_cell,
		"star_px": w.star_px,
		"weights": layer_weights(s),
	}


func _ready() -> void:
	_material.shader = SHADER
	material = _material
	Tuning.preset_applied.connect(refresh)
	refresh()


func _process(_delta: float) -> void:
	refresh()


func refresh() -> void:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var zoom := 1.0 if cam == null else cam.zoom.x
	var u := build_uniforms(Vector2.ZERO if cam == null else cam.position, 1.0 / zoom)
	for k in u:
		_material.set_shader_parameter(k, u[k])
	_material.set_shader_parameter("star_color", Color(Palette.STAR.r, Palette.STAR.g, Palette.STAR.b))
	queue_redraw()


func _draw() -> void:
	var cam := get_viewport().get_camera_2d()
	var center := Vector2.ZERO if cam == null else cam.position
	var h := WellViewScript.visible_half_extent(1.0 if cam == null else cam.zoom.x) * WellViewScript.VIEW_MARGIN
	draw_rect(Rect2(center - Vector2(h, h), Vector2(2.0 * h, 2.0 * h)), Color.WHITE)
