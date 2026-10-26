class_name AsteroidView
extends Node2D

const TIER_COLORS := [Palette.ORE_BRIGHT, Palette.ORE, Palette.MOON, Palette.ICE]

var _keys := []


static func color_for(r: float) -> Color:
	var b: Array = WellGenerator.tiers()["boundaries"]
	var i := 0
	while i < 3 and r >= b[i + 1]:
		i += 1
	return TIER_COLORS[i]


func _ready() -> void:
	Tuning.preset_applied.connect(func(): _keys = [null])


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship != null:
		refresh(ship.state.pos, GravityField.time())


func refresh(pos: Vector2, t: float) -> void:
	var list := AsteroidField.near(pos, t, Tuning.planet.chunk_gen_radius)
	var keys := []
	for a in list:
		keys.append([a["band"], a["chunk"], a["idx"], a["radius"], a["points"]])
	if keys != _keys:
		_keys = keys
		var polys := get_children()
		for i in list.size():
			if i >= polys.size():
				var p := Polygon2D.new()
				add_child(p)
				polys.append(p)
			polys[i].visible = true
			polys[i].polygon = list[i]["points"]
			polys[i].color = color_for(list[i]["pos"].length())
		for i in range(list.size(), polys.size()):
			polys[i].visible = false
	var polys := get_children()
	for i in list.size():
		polys[i].position = list[i]["pos"]
		polys[i].rotation = wrapf(list[i]["omega"] * t, -PI, PI)
