extends Line2D
## Short trajectory prediction line, shown only while an engine action is held
## (thrust, boost, soft brake or drift sync); the stroke keeps a constant
## SCREEN width (world width = WIDTH_PX * semantic zoom s). View-only.

const WIDTH_PX := 2.0

@onready var ship: Node2D = get_node("../Ship")

var _task := -1
var _task_gen := 0
var _task_tick := -1000000
var _gen := 0
var _fresh := false
var _held := false
var _result := PackedVector2Array()


func _init() -> void:
	default_color = Palette.HALO


func _ready() -> void:
	ship.respawned.connect(_on_respawned)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _process(_delta: float) -> void:
	width = WIDTH_PX / _camera_zoom()


func _physics_process(_delta: float) -> void:
	var tick := GravityField.tick
	var engine_held: bool = ship.input.thrust or ship.input.boost \
			or ship.input.soft_brake or ship.input.drift_sync
	if not engine_held:
		visible = false
		_held = false
		if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
		return
	if not _held:
		_held = true
		_gen += 1
		points = PackedVector2Array()
		_fresh = true
		visible = true
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _task_gen == _gen:
			points = _result.slice(tick - _task_tick) if tick - _task_tick < _result.size() else PackedVector2Array()
	if _task < 0 and (_fresh or tick - _task_tick >= maxi(Tuning.ship.predict_every, 1)):
		_start(tick)


func _on_respawned() -> void:
	_gen += 1
	_fresh = true
	points = PackedVector2Array()


func _start(tick: int) -> void:
	var held := held_input(ship.input)
	_fresh = false
	_task_gen = _gen
	_task_tick = tick
	_task = WorkerThreadPool.add_task(_run.bind(ship.state.copy(), held, tick, Tuning.ship.predict_short_steps))


static func held_input(input: ShipInput) -> ShipInput:
	var held := input.copy()
	held.turn = 0.0
	held.jettison = false
	held.jettison_select = false
	held.transfer = false
	return held


func _run(state: ShipState, held: ShipInput, tick: int, steps: int) -> void:
	Tuning.lock.lock()
	_result = ShipPrediction.run(state, held, tick, steps)
	Tuning.lock.unlock()


func _camera_zoom() -> float:
	var vp := get_viewport()
	var cam := vp.get_camera_2d() if vp != null else null
	return cam.zoom.x if cam != null else 1.0
