extends GutTest

const PredictionScript := preload("res://scenes/Prediction.gd")


func test_held_prediction_input_zeroes_turn_jettison_and_jettison_select() -> void:
	var i := ShipInput.new()
	i.turn = 1.0
	i.jettison = true
	i.jettison_select = true
	i.thrust = true
	i.aim = 0.5
	var h: ShipInput = PredictionScript.held_input(i)
	assert_eq(h.turn, 0.0)
	assert_false(h.jettison)
	assert_false(h.jettison_select)
	assert_true(h.thrust)
	assert_eq(h.aim, 0.5)
	assert_true(i.jettison)
	assert_eq(i.turn, 1.0)
