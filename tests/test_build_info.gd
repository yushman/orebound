extends GutTest

const PATH := "user://build_info_test.json"

var _saved_path: String


func before_each() -> void:
	_saved_path = BuildInfo.info_path


func after_each() -> void:
	BuildInfo.info_path = _saved_path
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_commit_is_dev_without_build_info() -> void:
	BuildInfo.info_path = "user://missing_build_info.json"
	assert_eq(BuildInfo.commit(), "dev")


func test_commit_reads_the_file() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string('{"commit": "abc1234-dirty"}')
	f.close()
	BuildInfo.info_path = PATH
	assert_eq(BuildInfo.commit(), "abc1234-dirty")


func test_version_comes_from_project_setting() -> void:
	assert_eq(BuildInfo.version(), "0.1.0")


func test_label_joins_version_and_commit() -> void:
	BuildInfo.info_path = "user://missing_build_info.json"
	assert_eq(BuildInfo.label(), "v0.1.0 · dev")
