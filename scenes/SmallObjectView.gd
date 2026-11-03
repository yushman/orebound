class_name SmallObjectView
extends Node2D
## Pieces (3D rocks from their points) and containers (3D boxes) in the
## `AsteroidView` 3D layer, lifted above the asteroids so they stay on top as
## when this view drew after it. Standalone it owns and blits its own layer.
## Large pieces (`is_large`) get the asteroid ore look and a rim twin.

const LIFT_Z := 500.0

## Bodies drawn this frame: `{body, points, pos, color}`.
var shown := []
var layer: Layer3D
var _own := false
var _meshes := {}
var _pool: Array[MeshInstance3D] = []
var _twins: Array[MeshInstance3D] = []


func _ready() -> void:
	var av := get_node_or_null("../AsteroidView")
	if av != null:
		layer = av.layer
	else:
		layer = Layer3D.new()
		layer.name = "Layer3D"
		add_child(layer)
		material = layer.blit_material
		_own = true


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship != null:
		refresh(ship.state.bodies)
	queue_redraw()


func refresh(bodies: Array[FreeBody]) -> void:
	shown = []
	for b in bodies:
		shown.append({"body": b, "points": b.points, "pos": b.pos, "color": AsteroidView.color_of(b.type)})


## Not a container and born above `collect_radius`.
static func is_large(b: FreeBody) -> bool:
	return not b.container and b.radius0 > Tuning.planet.collect_radius


## Mesh built once per body id at its first seen shape, with the radius it
## was built at: pieces shrink uniformly, so the instance scales by
## radius / built radius.
func mesh_of(b: FreeBody) -> Array:
	var c: Array = _meshes.get(b.id, [])
	if c.is_empty():
		var col := AsteroidView.color_of(b.type)
		var m := SolidMesh.box(b.points, b.radius, col) if b.container else SolidMesh.rock(b.points, b.id, col, Style.DOME_INNER_POINTS if is_large(b) else 0)
		c = [m, maxf(b.radius, 1e-6)]
	return c


func transform_of(b: FreeBody, built_radius: float) -> Transform3D:
	var k := b.radius / built_radius
	return Transform3D(Basis.from_scale(Vector3.ONE * k), layer.to_3d(b.pos, LIFT_Z))


func _draw() -> void:
	layer.sync(self)
	place()
	if _own:
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
			_pool.append(_instance(layer.solid, Layer3D.MAIN_LAYER))
			_twins.append(_instance(layer.type_material, Layer3D.TYPE_LAYER))
		var b: FreeBody = shown[i]["body"]
		var c := mesh_of(b)
		var large := is_large(b)
		kept[b.id] = c
		_pool[i].mesh = c[0]
		_pool[i].material_override = layer.asteroid if large else layer.solid
		_pool[i].transform = transform_of(b, c[1])
		_pool[i].visible = true
		_twins[i].mesh = c[0]
		_twins[i].transform = _pool[i].transform
		_twins[i].visible = large
	for i in range(shown.size(), _pool.size()):
		_pool[i].visible = false
		_twins[i].visible = false
	_meshes = kept
