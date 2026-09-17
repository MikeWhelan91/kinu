extends Node
var music: AudioStreamPlayer
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var room_music: Dictionary = {}
var current_room: String = ""
var voice_index: int = 0
var last_impact: int = 0
var landing_sounds: Array[AudioStream] = []
var landing_index: int = 0

const SOUND_FILES := {
	"homeplay": "homeplay.mp3", "gameover": "newgameover.mp3",
	"highscore": "highscore.mp3", "special": "possibleforspecialdropormilestoneingame.mp3",
	"cashregister": "cashregister.mp3", "wardrobe": "wardrobe.mp3", "book": "book.mp3",
	"mistake": "mistake.mp3", "drop": "drop.mp3", "sauce": "sauce.mp3",
}

## Per-category trim on top of the usual sfx volume, for clips mixed louder than the rest.
const VOLUME_TRIM := {"gameover": -6.0}

## Each room's ambient loop, keyed by its KinuDecor id. Rooms left out fall back to the
## default tofu shop track.
const ROOM_MUSIC_FILES := {
	"night": "nightmarket.mp3", "winter": "winter.mp3", "bamboo_grove": "bamboo.mp3",
	"autumn_temple": "autumn.mp3", "onsen": "onsen.mp3", "festival": "summer.mp3",
	"moon_viewing": "moon.mp3", "neon_alley": "neon.mp3", "sakura_street": "sakura.mp3",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for category in SOUND_FILES:
		sounds[category] = load("res://assets/audio/" + SOUND_FILES[category])
	landing_sounds = [
		load("res://assets/audio/369952__mischy__plop_1.wav"),
		load("res://assets/audio/369959__mischy__plop_2hi.wav"),
	]
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	music = AudioStreamPlayer.new()
	add_child(music)
	apply_settings()

## Loads and caches the looping track for a room, falling back to the default shop theme.
func _room_stream(room_id: String) -> AudioStream:
	if not room_music.has(room_id):
		var file: String = ROOM_MUSIC_FILES.get(room_id, "backgroundmusic.mp3")
		var stream := load("res://assets/audio/" + file) as AudioStreamMP3
		if stream:
			stream.loop = true
		room_music[room_id] = stream
	return room_music[room_id]

## Switches the background loop to match the given room, unless it's already playing.
func play_room_music(room_id: String) -> void:
	if room_id == current_room and music.playing:
		return
	current_room = room_id
	music.stream = _room_stream(room_id)
	music.play()

func start_music() -> void:
	play_room_music(str(Save.data.room))

func apply_settings() -> void:
	if music:
		music.volume_db = linear_to_db(maxf(0.00001, float(Save.data.music))) - 8.0

func play(category: String, pitch: float = 1.0) -> void:
	if (category not in ["land", "plop"] and not sounds.has(category)) or float(Save.data.sfx) < 0.001:
		return
	if category in ["land", "plop"]:
		if Time.get_ticks_msec() - last_impact < 140:
			return
		last_impact = Time.get_ticks_msec()
	var player := voices[voice_index % voices.size()]
	voice_index += 1
	if category in ["land", "plop"]:
		player.stream = landing_sounds[landing_index % landing_sounds.size()]
		landing_index += 1
	else:
		player.stream = sounds[category]
	player.volume_db = linear_to_db(float(Save.data.sfx)) - 9.0 + float(VOLUME_TRIM.get(category, 0.0))
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
