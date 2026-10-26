extends GutTest


func test_flight_vector_color_is_halo_with_alpha_kept() -> void:
	var c: Color = load("res://scenes/FlightVector.gd").COLOR
	assert_eq(Color(c.r, c.g, c.b), Color(Palette.HALO.r, Palette.HALO.g, Palette.HALO.b))
	assert_almost_eq(c.a, 0.85, 0.0001)


func test_prediction_default_color_is_halo() -> void:
	var line: Line2D = load("res://scenes/Prediction.gd").new()
	assert_eq(line.default_color, Palette.HALO)
	line.free()
