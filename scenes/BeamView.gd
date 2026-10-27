class_name BeamView
extends Line2D

const WIDTH_PX := 2.0


func _init() -> void:
	default_color = Palette.ICE
	visible = false


func _process(_delta: float) -> void:
	var ship := get_node_or_null("../Ship")
	if ship == null:
		visible = false
		return
	refresh(ship.state, ship.input, GravityField.time())
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	width = WIDTH_PX / (cam.zoom.x if cam != null else 1.0)


func refresh(state: ShipState, input: ShipInput, t: float) -> void:
	visible = input.beam
	if not input.beam:
		return
	var range_ := Tuning.ship.beam_range
	var cands := ShipFlight.beam_candidates(state, t)
	var h := Beam.hit(state.pos, input.aim, range_, cands)
	var end: Vector2 = h["point"] if not h.is_empty() else state.pos + Vector2.RIGHT.rotated(input.aim) * range_
	points = PackedVector2Array([state.pos, end])
