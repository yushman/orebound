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
## The 3D layer, shared with `SmallObjectView` (drawn right after it).
var layer := Layer3D.new()
var _meshes := {}
var _pool: Array[MeshInstance3D] = []


static func color_of(type: StringName) -> Color:
	return TYPE_COLORS.get(type, Palette.MOON)


func _ready() -> void:
	layer.name = "Layer3D"
	add_child(layer)
	material = layer.blit_material
	Tuning.preset_applied.connect(func(): _meshes = {})


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship != null:
		refresh(ship.state.pos, GravityField.time(), ship.state.broken)
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
		c = [a["points"], a["color"], SolidMesh.rock(a["points"], hash(a["key"]), a["color"])]
	return c[2]


## Instance transform: the 2D rotation by `rotation` about the entry position.
func transform_of(a: Dictionary) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, -a["rotation"]), layer.to_3d(a["pos"]))


func _draw() -> void:
	layer.sync(self)
	var kept := {}
	for i in shown.size():
		if i >= _pool.size():
			var mi := MeshInstance3D.new()
			mi.material_override = layer.solid
			layer.add_child(mi)
			_pool.append(mi)
		var a: Dictionary = shown[i]
		_pool[i].mesh = mesh_of(a)
		kept[a["key"]] = [a["points"], a["color"], _pool[i].mesh]
		_pool[i].transform = transform_of(a)
		_pool[i].visible = true
	for i in range(shown.size(), _pool.size()):
		_pool[i].visible = false
	_meshes = kept
	layer.blit(self)
