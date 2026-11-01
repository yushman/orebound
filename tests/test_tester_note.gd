extends GutTest

const NOTE := "res://tools/tester/README-macOS.md"


func test_note_contains_macos_telemetry_path_of_user_dir() -> void:
	if OS.get_name() != "macOS":
		pending("macOS only")
		return
	var home := OS.get_environment("HOME")
	var user_dir := OS.get_user_data_dir().replace(home, "~")
	var text := FileAccess.get_file_as_string(NOTE)
	assert_string_contains(text, user_dir + "/telemetry")


func test_note_describes_space_as_time_warp() -> void:
	var text := FileAccess.get_file_as_string(NOTE)
	assert_string_contains(text, "| Space (держать) | ускорение времени ×4 |")
	assert_false(text.contains("форсаж"))

