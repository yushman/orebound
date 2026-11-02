class_name SmallObjectView
extends Node2D
## Pieces (3D rocks from their points) and containers (3D boxes) in the
## `AsteroidView` 3D layer, lifted above the asteroids so they stay on top as
## when this view drew after it. Standalone it owns and blits its own layer.

const LIFT_Z := 500.0

## Bodies drawn this frame: `{body, points, pos, color}`.
var shown := []
var layer: Layer3D
var _own := false
var _meshes := {}
var _pool: Array[MeshInstance3D] = []


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


## Mesh built once per body id at its first seen shape, with the radius it
## was built at: pieces shrink uniformly, so the instance scales by
## radius / built radius.
func mesh_of(b: FreeBody) -> Array:
	var c: Array = _meshes.get(b.id, [])
	if c.is_empty():
		var col := AsteroidView.color_of(b.type)
		var m := SolidMesh.box(b.points, b.radius, col) if b.container else SolidMesh.rock(b.points, b.id, col)
		c = [m, maxf(b.radius, 1e-6)]
	return c


func transform_of(b: FreeBody, built_radius: float) -> Transform3D:
	var k := b.radius / built_radius
	return Transform3D(Basis.from_scale(Vector3.ONE * k), layer.to_3d(b.pos, LIFT_Z))


func _draw() -> void:
	layer.sync(self)
	var kept := {}
	for i in shown.size():
		if i >= _pool.size():
			var mi := MeshInstance3D.new()
			mi.material_override = layer.solid
			layer.add_child(mi)
			_pool.append(mi)
		var b: FreeBody = shown[i]["body"]
		var c := mesh_of(b)
		kept[b.id] = c
		_pool[i].mesh = c[0]
		_pool[i].transform = transform_of(b, c[1])
		_pool[i].visible = true
	for i in range(shown.size(), _pool.size()):
		_pool[i].visible = false
	_meshes = kept
	if _own:
		layer.blit(self)
