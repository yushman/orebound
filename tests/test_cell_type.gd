extends GutTest

const TMP := "user://test_cell_type_preset.tres"


func after_all() -> void:
	DirAccess.remove_absolute(TMP)


func test_tuning_resources_table_has_economy_values() -> void:
	var expected := {
		&"ice": [1.0, 1.0, 1.0],
		&"ore_base": [1.0, 1.0, 0.0],
		&"ore_middle": [2.0, 1.0, 0.0],
		&"ore_rare": [3.0, 1.0, 0.0],
		&"ore_unique": [3.0, 1.0, 0.0],
		&"fuel": [3.0, 1.0, 3.0],
	}
	assert_eq(Tuning.resources.size(), expected.size())
	for key in expected:
		var c: CellType = Tuning.resources.get(key)
		assert_not_null(c, str(key))
		if c == null:
			continue
		assert_eq([c.mass, c.volume, c.energy], expected[key], str(key))


func test_apply_and_save_leave_resources_untouched() -> void:
	var before: Dictionary = Tuning.resources
	var pr := TuningPreset.new()
	pr.field = Tuning._default_field()
	pr.ship = ShipParams.new()
	Tuning.apply(pr, false)
	assert_same(Tuning.resources, before)
	assert_eq(Tuning.save_preset(TMP, "R"), OK)
	assert_same(Tuning.resources, before)
	var loaded: TuningPreset = Tuning.load_preset(TMP)
	for prop in loaded.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_ne(prop.name, "resources")
