class_name AsteroidView
extends Node2D

const TYPE_COLORS := {
	&"ice": Palette.ICE,
	&"ore_base": Palette.ORE_BASE,
	&"ore_middle": Palette.ORE,
	&"ore_rare": Palette.ORE_RARE,
	&"ore_unique": Palette.ORE_BRIGHT,
}

## Entries drawn this frame: `near` output plus `color` and `rotation`.
var shown := []
## The 3D layer with the rim pass, shared with `SmallObjectView` (drawn
## right after it).
var layer := Layer3D.new(true)
var _meshes := {}
var _pool: Array[MeshInstance3D] = []
var _twins: Array[MeshInstance3D] = []
## Beam target (`BeamView.target_key`, `ratio`, hit point `end`): drawn
## with `layer.target` (cracks) and shaken while the ratio is above 0.
var target_key = null
var target_ratio := 0.0
var target_hit := Vector2.ZERO
var shake_phase := 0.0


## Shake offset of the beam target in screen px (y down); 0 at ratio 0.
static func shake_offset(ratio: float, phase: float) -> Vector2:
	return ratio * Style.SHAKE_PX_MAX * Vector2(sin(phase), sin(phase * 1.37))


## Shake phase advanced by `delta` at the ratio's frequency.
static func advance_shake(phase: float, ratio: float, delta: float) -> float:
	return fmod(phase + TAU * lerpf(Style.SHAKE_HZ_MIN, Style.SHAKE_HZ_MAX, ratio) * delta, TAU * 100.0)


## Shake of `ratio` / `phase` as a layer-space offset (screen px through
## the canvas transform of `ci`).
static func shake_3d(ci: CanvasItem, ratio: float, phase: float) -> Vector3:
	var d := ci.get_viewport().get_canvas_transform().affine_inverse().basis_xform(shake_offset(ratio, phase))
	return Vector3(d.x, -d.y, 0.0)


static func same_key(a, b) -> bool:
	return a != null and b != null and typeof(a) == typeof(b) and a == b


## Pushes the crack uniforms of `m` for a target at object-space hit point
## `origin`; `seed_` picks the crack pattern.
static func push_crack(m: ShaderMaterial, ratio: float, origin: Vector2, radius: float, seed_: int) -> void:
	m.set_shader_parameter("crack_ratio", ratio)
	m.set_shader_parameter("crack_origin", origin)
	m.set_shader_parameter("crack_radius", radius)
	m.set_shader_parameter("crack_seed", fmod(absf(float(seed_)) * 0.618034, 97.0))


func set_target(key, ratio: float, hit: Vector2) -> void:
	target_key = key
	target_ratio = ratio
	target_hit = hit


static func color_of(type: StringName) -> Color:
	return TYPE_COLORS.get(type, Palette.MOON)


func _ready() -> void:
	layer.name = "Layer3D"
	add_child(layer)
	material = layer.blit_material
	Tuning.preset_applied.connect(func(): _meshes = {})


func _process(delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship != null:
		refresh(ship.state.pos, GravityField.time(), ship.state.broken)
	var beam := get_node_or_null("../BeamView")
	if beam != null and beam.has_hit:
		set_target(beam.target_key, beam.ratio, beam.end)
	else:
		set_target(null, 0.0, Vector2.ZERO)
	shake_phase = advance_shake(shake_phase, target_ratio, delta)
	queue_redraw()


func refresh(pos: Vector2, t: float, broken := {}) -> void:
	shown = []
	for a in AsteroidField.near(pos, t, Tuning.planet.chunk_gen_radius):
		a["key"] = Vector3i(a["band"], a["chunk"], a["idx"])
		a = Beam.layer(a, broken)
		if a.is_empty():
			continue
		# ring boulders (M6) are ore_middle but draw the obod accent,
		# discriminated by the band index of the entry key
		a["color"] = Palette.OBOD_ACCENT if AsteroidField._ring_band(a["band"]) else color_of(a["type"])
		a["rotation"] = wrapf(a["omega"] * t, -PI, PI)
		shown.append(a)


## Rock mesh of an entry, cached by key while its points and colour hold.
func mesh_of(a: Dictionary) -> ArrayMesh:
	var c: Array = _meshes.get(a["key"], [])
	if c.is_empty() or c[0] != a["points"] or c[1] != a["color"]:
		c = [a["points"], a["color"], SolidMesh.rock(a["points"], hash(a["key"]), a["color"], Style.DOME_INNER_POINTS)]
	return c[2]


## Instance transform: the 2D rotation by `rotation` about the entry position.
func transform_of(a: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, -a["rotation"]), layer.to_3d(a["pos"]))


func _draw() -> void:
	layer.sync(self)
	place()
	layer.blit(self)


func _instance(m: Material, mask: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.material_override = m
	mi.layers = mask
	layer.add_child(mi)
	return mi


func place() -> void:
	var kept := {}
	for i in shown.size():
		if i >= _pool.size():
			_pool.append(_instance(layer.asteroid, Layer3D.MAIN_LAYER))
			_twins.append(_instance(layer.type_material, Layer3D.TYPE_LAYER))
		var a: Dictionary = shown[i]
		_pool[i].mesh = mesh_of(a)
		kept[a["key"]] = [a["points"], a["color"], _pool[i].mesh]
		_pool[i].transform = transform_of(a)
		_pool[i].material_override = layer.asteroid
		if target_ratio > 0.0 and same_key(a["key"], target_key):
			var local: Vector3 = _pool[i].transform.affine_inverse() * layer.to_3d(target_hit)
			push_crack(layer.target, target_ratio, Vector2(local.x, local.y), a["radius"], hash(a["key"]))
			_pool[i].material_override = layer.target
			_pool[i].transform.origin += shake_3d(self, target_ratio, shake_phase)
		_pool[i].visible = true
		_twins[i].mesh = _pool[i].mesh
		_twins[i].transform = _pool[i].transform
		_twins[i].visible = true
	for i in range(shown.size(), _pool.size()):
		_pool[i].visible = false
		_twins[i].visible = false
	_meshes = kept
