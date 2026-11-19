extends Node
## Original synthesized sounds and a loop with no external audio dependencies.

const RATE := 16000
const SOUNDS := {"button": [540.0, 680.0], "select": [650.0], "swap": [460.0, 610.0],
	"match": [523.25, 659.25, 783.99], "combo": [659.25, 783.99, 1046.5],
	"power": [240.0, 160.0, 90.0], "win": [392.0, 523.25, 659.25, 783.99],
	"fail": [440.0, 349.23, 261.63]}
var effects := AudioStreamPlayer.new()
var music := AudioStreamPlayer.new()
var clips := {}

func _ready() -> void:
	add_child(effects)
	add_child(music)
	for key in SOUNDS:
		clips[key] = _synthesize(SOUNDS[key], 0.075 if key != "win" else 0.13, false)
	music.stream = _synthesize([392.0, 0.0, 523.25, 659.25, 587.33, 0.0, 440.0, 493.88,
		392.0, 0.0, 349.23, 523.25, 440.0, 0.0, 493.88, 392.0], 0.29, true)

func levels(effect: float, soundtrack: float) -> void:
	effects.volume_db = linear_to_db(maxf(0.001, effect * 0.46))
	effects.stream_paused = effect <= 0.0
	music.volume_db = linear_to_db(maxf(0.001, soundtrack * 0.24))
	if soundtrack <= 0.0:
		music.stop()
	elif not music.playing:
		music.play()

func play(kind: String) -> void:
	if effects.stream_paused:
		return
	effects.stream = clips.get(kind, clips.button)
	effects.play()

func _synthesize(notes: Array, duration: float, loop: bool) -> AudioStreamWAV:
	var samples := roundi(RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * notes.size() * 2)
	for index in notes.size():
		var frequency: float = notes[index]
		if frequency == 0.0:
			continue
		for sample in samples:
			var time := float(sample) / RATE
			var tail := maxf(0, 1.0 - time / duration)
			var envelope := minf(1, time * 130.0) * tail * tail
			var angle := TAU * frequency * time
			var wave := sin(angle) + 0.24 * sin(angle * 2.002) + 0.12 * sin(angle * 3.0)
			if loop:
				wave += 0.21 * sin(TAU * 130.8128 * time)
			bytes.encode_s16((index * samples + sample) * 2, roundi(wave * envelope * 13400))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples * notes.size()
	return wav
