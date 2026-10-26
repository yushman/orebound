extends Line2D
## Short trajectory prediction line, always shown; the stroke keeps a constant
## SCREEN width (world width = WIDTH_PX * semantic zoom s). View-only.

const WIDTH_PX := 2.0

@onready var ship: Node2D = get_node("../Ship")


func _init() -> void:
	default_color = Palette.HALO


func _ready() -> void:
	Tuning.preset_applied.connect(_update)


func _process(_delta: float) -> void:
	width = WIDTH_PX / _camera_zoom()


func _physics_process(_delta: float) -> void:
	if GravityField.tick % maxi(Tuning.ship.predict_every, 1) == 0:
		_update()


func _update() -> void:
	var held: ShipInput = ship.input.copy()
	held.turn = 0.0
	points = ShipPrediction.run(ship.state, held, GravityField.tick, Tuning.ship.predict_short_steps)
	width = WIDTH_PX / _camera_zoom()


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0
