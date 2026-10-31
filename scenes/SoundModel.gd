class_name SoundModel
extends RefCounted

const HUD_SCRIPT := preload("res://ui/HUD.gd")
const IDLE_VOLUME := 0.15
const ROUGH_FROM := 0.5


static func thrust_level(s: ShipState, inp: ShipInput) -> float:
	if not (inp.thrust or inp.boost) or Hold.energy(s) <= Hold.EPS:
		return 0.0
	var p: ShipParams = Tuning.ship
	var level := lerpf(p.ramp_min_fraction, 1.0, clampf(s.hold_time / p.ramp_time, 0.0, 1.0))
	if s.heat > p.heat_threshold:
		level *= lerpf(1.0, p.min_thrust_fraction, (s.heat - p.heat_threshold) / (1.0 - p.heat_threshold))
	return level


static func engine_pitch(mass: float, level: float) -> float:
	return clampf(sqrt(Tuning.ship.ref_mass / maxf(mass, 0.001)) * lerpf(0.8, 1.2, level), 0.4, 2.0)


static func engine_volume(level: float) -> float:
	return lerpf(IDLE_VOLUME, 1.0, clampf(level, 0.0, 1.0))


static func rough_mix(heat: float) -> float:
	return clampf((heat - ROUGH_FROM) / (1.0 - ROUGH_FROM), 0.0, 1.0)


static func boost_on(inp: ShipInput, level: float) -> bool:
	return inp.boost and level > 0.0


static func hiss_volume(density: float) -> float:
	return clampf(density, 0.0, 1.0)


static func heat_click(prev_heat: float, heat: float) -> bool:
	var th: float = Tuning.ship.heat_threshold
	return prev_heat < th and heat >= th


static func crack_due(ticks: int) -> bool:
	return ticks % maxi(ceili(Tuning.view.crack_period / GravityField.DT), 1) == 0


static func reserve_mode(state: HUD_SCRIPT.State) -> StringName:
	match state:
		HUD_SCRIPT.State.NEAR:
			return &"double"
		HUD_SCRIPT.State.BELOW:
			return &"tone"
	return &"click"


static func reserve_beat(mode: StringName, ticks: int) -> bool:
	var period: float
	match mode:
		&"click":
			period = Tuning.view.reserve_click_period
		&"double":
			period = Tuning.view.reserve_beep_period
		_:
			return false
	return ticks % maxi(ceili(period / GravityField.DT), 1) == 0


static func cue_for(type: StringName) -> StringName:
	match type:
		&"tow", &"tow_refused":
			return &"info"
		&"impact":
			return &"thud"
	return &"danger"
