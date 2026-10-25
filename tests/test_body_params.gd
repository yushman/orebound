extends GutTest

const PATH := "user://test_body_params.tres"


func after_each():
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_radius_defaults_to_zero():
	assert_eq(BodyParams.new().get("radius"), 0.0)


func test_radius_survives_save_load_round_trip():
	var b := BodyParams.new()
	b.set("radius", 1234.5)
	assert_eq(ResourceSaver.save(b, PATH), OK)
	var loaded: BodyParams = ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_eq(loaded.get("radius"), 1234.5)
