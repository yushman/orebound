class_name TimeWarp
extends RefCounted

const BASE_TICKS := 60
const BASE_STEPS := 8


static func ticks_per_second(warp_mode: bool, held: bool, flying: bool, mult: int) -> int:
	if warp_mode and held and flying:
		return BASE_TICKS * maxi(mult, 1)
	return BASE_TICKS


static func max_steps(ticks: int) -> int:
	return maxi(BASE_STEPS, ticks / BASE_TICKS * 2)
