class_name SmallObjectView
extends Node2D


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship != null:
		refresh(ship.state.bodies)


func refresh(bodies: Array[FreeBody]) -> void:
	var polys := get_children()
	for i in bodies.size():
		if i >= polys.size():
			var p := Polygon2D.new()
			add_child(p)
			polys.append(p)
		polys[i].visible = true
		polys[i].polygon = bodies[i].points
		polys[i].position = bodies[i].pos
		polys[i].color = AsteroidView.color_of(bodies[i].type)
	for i in range(bodies.size(), polys.size()):
		polys[i].visible = false
