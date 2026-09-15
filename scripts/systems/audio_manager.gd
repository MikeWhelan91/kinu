extends Node
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var voice_index: int = 0
var last_impact: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for category in ["tap", "rotate", "drop", "land", "heavy", "combo", "escape", "over", "record", "nudge"]:
		sounds[category] = load("res://assets/audio/" + category + ".wav")
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	music = AudioStreamPlayer.new()
	music.stream = load("res://assets/audio/garden.ogg")
	add_child(music)
	apply_settings()

func start_music() -> void:
	if music and not music.playing:
		music.play()

func apply_settings() -> void:
	if music:
		music.volume_db = linear_to_db(maxf(0.00001, float(Save.data.music))) - 8.0

func play(category: String, pitch: float = 1.0) -> void:
	if not sounds.has(category) or float(Save.data.sfx) < 0.001:
		return
	if category in ["land", "heavy"]:
		if Time.get_ticks_msec() - last_impact < 140:
			return
		last_impact = Time.get_ticks_msec()
	var player := voices[voice_index % voices.size()]
	voice_index += 1
	player.stream = sounds[category]
	player.volume_db = linear_to_db(float(Save.data.sfx)) - 9.0
	player.pitch_scale = pitch
	player.play()

func shutdown() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in voices:
		player.stop()
		player.stream = null
	sounds.clear()
