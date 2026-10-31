class_name AsteroidView
extends Node2D

const TYPE_COLORS := {
	&"ice": Palette.ICE,
	&"ore_base": Palette.ORE_BASE,
	&"ore_middle": Palette.ORE,
	&"ore_rare": Palette.ORE_RARE,
	&"ore_unique": Palette.ORE_BRIGHT,
}

var _keys := []


static func color_of(type: StringName) -> Color:
	return TYPE_COLORS.get(type, Palette.MOON)


func _ready() -> void:
	Tuning.preset_applied.connect(func(): _keys = [null])


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship != null:
		refresh(ship.state.pos, GravityField.time(), ship.state.broken)


func refresh(pos: Vector2, t: float, broken := {}) -> void:
	var list := []
	for a in AsteroidField.near(pos, t, Tuning.planet.chunk_gen_radius):
		a["key"] = Vector3i(a["band"], a["chunk"], a["idx"])
		a = Beam.layer(a, broken)
		if not a.is_empty():
			list.append(a)
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
			# ring boulders (M6) are ore_middle but draw the obod accent,
			# discriminated by the band index of the entry key
			polys[i].color = Palette.OBOD_ACCENT if AsteroidField._ring_band(list[i]["band"]) else color_of(list[i]["type"])
		for i in range(list.size(), polys.size()):
			polys[i].visible = false
	var polys := get_children()
	for i in list.size():
		polys[i].position = list[i]["pos"]
		polys[i].rotation = wrapf(list[i]["omega"] * t, -PI, PI)
