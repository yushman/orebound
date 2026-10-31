extends GutHookScript


func run() -> void:
	Telemetry.dir = "user://telemetry_test"
	var d := DirAccess.open(Telemetry.dir)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(Telemetry.dir + "/" + f)
