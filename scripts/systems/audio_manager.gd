extends Node
var music: AudioStreamPlayer
## The claw machine's motor, held on while its controls are worked. Its own player because it
## loops for as long as the player keeps hold, rather than firing once like the other sounds.
var motor: AudioStreamPlayer
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
	# The cheer, for the two moments worth cheering: a new best, and a prize out of the claw.
	"yay": "yay.mp3",
	"cashregister": "cashregister.mp3", "wardrobe": "wardrobe.mp3", "book": "book.mp3",
	"mistake": "mistake.mp3", "drop": "drop.mp3", "sauce": "sauce.mp3",
}

## Per-category trim on top of the usual sfx volume, for clips mixed louder than the rest.
const VOLUME_TRIM := {"gameover": -6.0}

## Each room's ambient loop, keyed by its KinuDecor id. Every room has its own; anything left
## out falls back to the default tofu shop track, which is the Tofu Shop's own music.
const ROOM_MUSIC_FILES := {
	"night": "nightmarket.mp3", "winter": "winter.mp3", "bamboo_grove": "bamboo.mp3",
	"autumn_temple": "autumn.mp3", "onsen": "onsen.mp3", "festival": "summer.mp3",
	"moon_viewing": "moon.mp3", "neon_alley": "neon.mp3", "sakura_street": "sakura.mp3",
	"arcade": "game.mp3", "dragon_palace": "dragonpalace.mp3", "tea_fields": "fuji.mp3",
	"sweets": "wagashi.mp3", "aurora": "aurora.mp3", "moon_base": "moonbase.mp3",
	"sky_shrine": "skyshrine.mp3", "beach": "summerbeach.mp3", "lantern_river": "lantern.mp3",
	"castle": "castle.mp3",
	# Not a room you can equip: the Claw Machine page, which has a loop of its own rather than
	# borrowing the Game Centre's.
	"catcher": "clawmachinemusic.mp3",
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
	motor = AudioStreamPlayer.new()
	var claw := load("res://assets/audio/clawmachine.mp3") as AudioStreamMP3
	if claw:
		# Held longer than the clip runs, the motor simply keeps going.
		claw.loop = true
		motor.stream = claw
	add_child(motor)
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

## Runs the claw motor while its controls are being worked, and cuts it the moment they are let
## go. Safe to call every frame: it only starts or stops on an actual change.
func claw_motor(on: bool) -> void:
	if not is_instance_valid(motor) or motor.stream == null:
		return
	if float(Save.data.sfx) < 0.001:
		on = false
	if on == motor.playing:
		return
	if on:
		motor.volume_db = linear_to_db(float(Save.data.sfx)) - 9.0
		motor.play()
	else:
		motor.stop()

func shutdown() -> void:
	if is_instance_valid(motor):
		motor.stop()
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in voices:
		player.stop()
		player.stream = null
	sounds.clear()
