class_name BuildInfo
extends RefCounted

static var info_path := "res://build_info.json"


static func version() -> String:
	return ProjectSettings.get_setting("application/config/version", "")


static func commit() -> String:
	if not FileAccess.file_exists(info_path):
		return "dev"
	var data = JSON.parse_string(FileAccess.get_file_as_string(info_path))
	if data is Dictionary and data.has("commit"):
		return str(data["commit"])
	return "dev"


static func label() -> String:
	return "v%s · %s" % [version(), commit()]
