class_name SoundBank
extends RefCounted

const RATE := 22050
const LOOPS := [&"engine", &"rough", &"boost", &"hiss", &"tone"]
const SHOTS := [&"click", &"double", &"danger", &"info", &"thud", &"chord"]

static var _cache := {}


static func stream(name: StringName) -> AudioStreamWAV:
	if not _cache.has(name):
		_cache[name] = build(name)
	return _cache[name]


static func build(name: StringName) -> AudioStreamWAV:
	var samples: PackedFloat32Array
	match name:
		&"engine":
			samples = _gen(1.0, func(t: float, _i: int) -> float: return 0.6 * (fposmod(t * 55.0, 1.0) * 2.0 - 1.0) + 0.5 * sin(TAU * 27.0 * t))
		&"rough":
			samples = _noise(1.0, 0.15)
		&"boost":
			samples = _noise(1.0, 0.6, 110.0, 0.5)
		&"hiss":
			samples = _noise(1.0, 0.95)
		&"tone":
			samples = _gen(1.0, func(t: float, _i: int) -> float: return sin(TAU * 660.0 * t))
		&"click":
			samples = _noise(0.03, 0.8, 0.0, 0.0, 120.0)
		&"double":
			samples = _beeps([0.0, 0.16], 700.0, 0.07)
		&"danger":
			samples = _beeps([0.0], 880.0, 0.18)
		&"info":
			samples = _beeps([0.0], 440.0, 0.18)
		&"thud":
			samples = _noise(0.3, 0.1, 55.0, 0.8, 14.0)
		&"chord":
			samples = _gen(0.8, func(t: float, _i: int) -> float: return (sin(TAU * 261.63 * t) + sin(TAU * 329.63 * t) + sin(TAU * 392.0 * t)) / 3.0 * exp(-4.0 * t))
	return _wav(samples, name in LOOPS)


static func _gen(seconds: float, f: Callable) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = f.call(float(i) / RATE, i)
	return out


## Seeded noise through a one-pole low-pass (smooth 0 = rough .. 1 = bright),
## optionally mixed with a saw at saw_hz and shaped by a decay rate.
static func _noise(seconds: float, bright: float, saw_hz := 0.0, saw_mix := 0.0, decay := 0.0) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(seconds, bright, saw_hz, decay))
	var lp := 0.0
	return _gen(seconds, func(t: float, _i: int) -> float:
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), bright)
		var v := lp
		if saw_hz > 0.0:
			v = lerpf(v, fposmod(t * saw_hz, 1.0) * 2.0 - 1.0, saw_mix)
		return v * (exp(-decay * t) if decay > 0.0 else 1.0))


static func _beeps(starts: Array, hz: float, length: float) -> PackedFloat32Array:
	var total: float = starts[-1] + length
	return _gen(total, func(t: float, _i: int) -> float:
		var v := 0.0
		for s in starts:
			var u: float = t - s
			if u >= 0.0 and u < length:
				v += sin(TAU * hz * u) * minf(minf(u / 0.005, (length - u) / 0.01), 1.0)
		return v)


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] / peak * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = false
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w
