class_name RingView
extends Node2D

const MAX_PARTICLES := 4000
const PARTICLE_SIZE := 40.0
const PARTICLE_COLOR := Color(Palette.ICE, 0.6)
const DUST_MAX := 16000
const DUST_SIZE := 10.0
const DUST_COLOR := Color(Palette.ICE, 0.25)
const DUST_LEVELS := [1.0, 0.7]

var positions := PackedVector2Array()
var _particles := MultiMeshInstance2D.new()
var _dust := MultiMeshInstance2D.new()


static func particle_count(density: float) -> int:
	return roundi(clampf(density, 0.0, 1.0) * MAX_PARTICLES)


static func dust_count(density: float) -> int:
	return roundi(clampf(density, 0.0, 1.0) * DUST_MAX)


static func rotation_at(ring: Dictionary, t: float) -> float:
	return ring.phase + WellGenerator.relative_omega(ring.radius) * t


func _ready() -> void:
	_particles.name = "Particles"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	var quad := QuadMesh.new()
	quad.size = Vector2(PARTICLE_SIZE, PARTICLE_SIZE)
	mm.mesh = quad
	_particles.multimesh = mm
	_particles.modulate = PARTICLE_COLOR
	add_child(_particles)
	_dust.name = "Dust"
	var dm := MultiMesh.new()
	dm.transform_format = MultiMesh.TRANSFORM_2D
	dm.use_colors = true
	var dust_quad := QuadMesh.new()
	dust_quad.size = Vector2(DUST_SIZE, DUST_SIZE)
	dm.mesh = dust_quad
	_dust.multimesh = dm
	add_child(_dust)
	Tuning.preset_applied.connect(rebuild)
	rebuild()


func _process(_delta: float) -> void:
	refresh(GravityField.time())


func refresh(t: float) -> void:
	if visible:
		rotation = rotation_at(Tuning.picture.ring, t)


static func particle_positions(ring: Dictionary, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Tuning.picture.seed, Tuning.picture.flight, "ring"])
	for i in n:
		var r: float = ring.radius + rng.randf_range(-0.5, 0.5) * ring.width
		var a := rng.randf_range(0.0, TAU)
		pts.append(Vector2(r * cos(a), r * sin(a)))
	return pts


static func dust_positions(ring: Dictionary, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Tuning.picture.seed, Tuning.picture.flight, "ring-dust"])
	for i in n:
		var r: float = ring.radius + rng.randf_range(-0.5, 0.5) * ring.width
		var a := rng.randf_range(0.0, TAU)
		pts.append(Vector2(r * cos(a), r * sin(a)))
	return pts


static func dust_colors(n: int) -> PackedColorArray:
	var cols := PackedColorArray()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([Tuning.picture.seed, Tuning.picture.flight, "ring-dust"])
	for i in n:
		var level: float = DUST_LEVELS[rng.randi_range(0, DUST_LEVELS.size() - 1)]
		cols.append(Color(DUST_COLOR.r * level, DUST_COLOR.g * level, DUST_COLOR.b * level, DUST_COLOR.a))
	return cols


func rebuild() -> void:
	var ring: Dictionary = Tuning.picture.ring
	var mm := _particles.multimesh
	var dm := _dust.multimesh
	if ring.is_empty():
		visible = false
		mm.instance_count = 0
		dm.instance_count = 0
		positions = PackedVector2Array()
		return
	var n := particle_count(Tuning.planet.ring_density)
	mm.instance_count = n
	positions = particle_positions(ring, n)
	for i in n:
		mm.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
	var dn := dust_count(Tuning.planet.ring_dust_density)
	dm.instance_count = dn
	var dust := dust_positions(ring, dn)
	var colors := dust_colors(dn)
	for i in dn:
		dm.set_instance_transform_2d(i, Transform2D(0.0, dust[i]))
		dm.set_instance_color(i, colors[i])
	visible = true
	refresh(GravityField.time())
