extends GutTest


func _all() -> Array:
	return SoundBank.LOOPS + SoundBank.SHOTS


func test_names_match_the_design() -> void:
	assert_eq(SoundBank.LOOPS, [&"engine", &"rough", &"boost", &"hiss", &"tone"])
	assert_eq(SoundBank.SHOTS, [&"click", &"double", &"danger", &"info", &"thud", &"chord"])


func test_engine_stream_is_a_looping_16_bit_mono_wav() -> void:
	var w := SoundBank.stream(&"engine")
	assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_false(w.stereo)
	assert_eq(w.mix_rate, 22050)
	assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(w.data.size(), 0)


func test_every_stream_is_a_16_bit_mono_wav_at_rate() -> void:
	for n in _all():
		var w := SoundBank.stream(n)
		assert_gt(w.data.size(), 0, n)
		assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS, n)
		assert_false(w.stereo, n)
		assert_eq(w.mix_rate, 22050, n)


func test_loops_loop_and_shots_do_not() -> void:
	for n in SoundBank.LOOPS:
		var w := SoundBank.stream(n)
		assert_eq(w.loop_mode, AudioStreamWAV.LOOP_FORWARD, n)
		assert_eq(w.loop_begin, 0, n)
		assert_eq(w.loop_end, w.data.size() / 2, n)
	for n in SoundBank.SHOTS:
		assert_eq(SoundBank.stream(n).loop_mode, AudioStreamWAV.LOOP_DISABLED, n)


func test_stream_is_cached() -> void:
	for n in _all():
		assert_same(SoundBank.stream(n), SoundBank.stream(n), n)


func test_data_is_deterministic() -> void:
	for n in _all():
		assert_eq(SoundBank.build(n).data, SoundBank.stream(n).data, n)


func test_streams_are_not_silent_and_not_clipped_flat() -> void:
	for n in _all():
		var d := SoundBank.stream(n).data
		var peak := 0
		for i in range(0, d.size(), 2):
			peak = maxi(peak, absi(d.decode_s16(i)))
		assert_gt(peak, 500, n)
		assert_lt(peak, 32767, n)
