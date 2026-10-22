extends Line2D

@onready var ship: Node2D = get_node("../Ship")


func _ready() -> void:
	Tuning.preset_applied.connect(_update)


func _physics_process(_delta: float) -> void:
	if GravityField.tick % maxi(Tuning.ship.predict_every, 1) == 0:
		_update()


func _update() -> void:
	var p := Tuning.ship
	if Input.is_action_pressed("ship_full_trajectory"):
		points = ShipPrediction.run(ship.state, ShipInput.new(), GravityField.tick, p.predict_full_steps)
	else:
		points = ShipPrediction.run(ship.state, ship.input, GravityField.tick, p.predict_short_steps)
