extends Control

signal warning_shown(type: StringName)

const TOP_Y := 64.0
const WARN_FONT_SIZE := 28
const HUD_SCRIPT := preload("res://ui/HUD.gd")

var ship: Node
var queue := WarningQueue.new()
var _prev := {}


func _ready() -> void:
	ship = get_node_or_null("../../Ship")
	if ship != null:
		ship.respawned.connect(_on_respawned)


static func snapshot(ship: Node) -> Dictionary:
	if ship == null:
		return {}
	var s: ShipState = ship.state
	return {
		"r": s.pos.length(),
		"hull": s.hull,
		"atmo_loss": Tuning.planet.atmosphere_damage * ShipFlight.atmosphere_density(s.pos) * GravityField.DT,
		"reserve": int(HUD_SCRIPT.ship_reserve(s)),
		"violation": ship.violation,
		"tow_left": ship.tow_left,
		"notice": ship.tow_notice,
		"notice_left": ship.tow_notice_left,
	}


func _on_respawned() -> void:
	_prev = {}


func _physics_process(delta: float) -> void:
	if ship == null or ship.phase == ship.Phase.ENDED:
		return
	var now := snapshot(ship)
	if not _prev.is_empty():
		for e in WarningEvents.detect(_prev, now):
			queue.push(e[0], e[1])
	_prev = now
	var shown := queue.tick(delta)
	if shown != &"":
		warning_shown.emit(shown)
	queue_redraw()


func _draw() -> void:
	if queue.current_type == &"":
		return
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(queue.current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, WARN_FONT_SIZE).x
	draw_string(font, Vector2((size.x - w) * 0.5, TOP_Y), queue.current_text, HORIZONTAL_ALIGNMENT_LEFT, -1, WARN_FONT_SIZE, Palette.SAFE)
