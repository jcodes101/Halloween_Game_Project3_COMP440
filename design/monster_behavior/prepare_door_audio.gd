extends SceneTree
## Decode source MP3s with Godot, downmix, and save standard PCM WAV assets.
func _initialize() -> void:
	for event in ["door_open", "door_close"]:
		var source := AudioStreamMP3.new()
		source.data = FileAccess.get_file_as_bytes("res://downloads/audio-approved/" + event + ".mp3")
		var playback := source.instantiate_playback()
		playback.start()
		var pcm := PackedByteArray()
		var frames := playback.mix_audio(1.0, int(source.get_length() * 44100))
		for frame in frames:
			var sample := int(clamp((frame.x + frame.y) * 0.5, -1.0, 1.0) * 32767)
			pcm.append(sample & 255)
			pcm.append((sample >> 8) & 255)
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = 44100
		wav.stereo = false
		wav.data = pcm
		var result := wav.save_to_wav("res://assets/audio/" + event + ".wav")
		assert(result == OK and not frames.is_empty())
		print(event, ": ", frames.size(), " decoded frames")
	quit()
