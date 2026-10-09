extends SceneTree
## Create a one-second excerpt from the approved CC0 preview.
func _initialize() -> void:
	var source := AudioStreamMP3.new()
	source.data = FileAccess.get_file_as_bytes("res://downloads/audio-approved/horror_sting.mp3")
	var playback := source.instantiate_playback()
	playback.start()
	var frames := playback.mix_audio(1.0, int(source.get_length() * 44100))
	var start := 0
	while start < frames.size() and frames[start].abs().length() < 0.02:
		start += 1
	assert(start < frames.size())
	var count := mini(44100, frames.size() - start)
	var pcm := PackedByteArray()
	for i in count:
		var value: float = (frames[start + i].x + frames[start + i].y) * 0.5
		value *= minf(1.0, float(count - 1 - i) / 1102.0)
		var sample := int(clampf(value, -1.0, 1.0) * 32767)
		pcm.append(sample & 255)
		pcm.append((sample >> 8) & 255)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	assert(wav.save_to_wav("res://assets/audio/capture_sting.wav") == OK)
	print("Capture excerpt: ", count, " frames; source start: ", float(start) / 44100.0)
	quit()
